// DictusKeyboard/HostAppProbe.swift
import UIKit
import ObjectiveC
import DictusCore

/// Reads the private keyboard arbiter for the bundle ID of the app this keyboard is
/// serving, and writes what it finds to the persistent debug log.
///
/// ## Why this exists (#23, phase 0)
///
/// Auto-return after a cold-start dictation needs one fact the keyboard has never been
/// able to get: *which app am I in*. The April 2026 ADR concluded no API provides it and
/// closed the question. That conclusion was falsified on 2026-09-10 — thirteen probes had
/// all interrogated the input view controller, its parent chain, its `extensionContext`
/// and its window scene, and the bundle ID lives on none of them. It lives on
/// `UIKeyboardArbiterClient`, a UIKit singleton outside the view controller graph, read
/// out of the shipping KeyboardKit binary that an open-source competitor links.
///
/// That is evidence about a *binary*, not about this device. This file turns it into a
/// measurement. It answers three questions and nothing else:
///
/// 1. does the arbiter return a correct bundle ID on the iOS we ship against;
/// 2. how long after the keyboard changes host does that value become correct;
/// 3. on which iOS version was that measured — the API can vanish in any release.
///
/// ## What it deliberately is not
///
/// Observation only. Nothing here changes anything a user can reach: no auto-return, no
/// URL parameter, no catalogue, no `UIApplication.open`. Whether Dictus ships private API
/// at all is a decision that has not been taken, and this probe does not need it taken —
/// it exists to tell that decision whether it is worth taking.
///
/// ## Two rules the implementation is built around
///
/// **Everything is resolved by name at runtime.** `UIKeyboardArbiterClient` is private
/// UIKit and must never be linked, so every hop is `NSClassFromString` /
/// `NSSelectorFromString` / KVC. A `nil` at any hop is a *result* to be logged, not a
/// failure to recover from.
///
/// **Every KVC read is guarded by `responds(to:)`.** `value(forKey:)` against an object
/// that does not implement the key raises `NSUnknownKeyException`, an Objective-C
/// exception Swift cannot catch — so an unguarded read is a crash, not a nil. This repo
/// has already paid for that once: the `documentIdentifier` probe in PR #282 trapped on
/// every keyboard launch. A missing selector and a present selector returning nil are
/// logged as two different things (`<no-selector>` vs `nil`), because they are two
/// different answers about whether the API still exists.
enum HostAppProbe {

    // MARK: - Naming

    /// The two spellings the class could have.
    ///
    /// The evidence is genuinely ambiguous: the string found in KeyboardKit's
    /// `__TEXT,__cstring` is `_UIKeyboardArbiterClient` with a leading underscore, while
    /// the reference snippet on #23 looks it up without one. Trying both and reporting
    /// which one resolved costs three lines and removes a whole round trip to a physical
    /// device — which is the expensive resource here, not CPU.
    private static let arbiterClassNames = ["UIKeyboardArbiterClient", "_UIKeyboardArbiterClient"]

    /// Class-level accessor for the arbiter singleton.
    private static let sharedClientSelectorName = "automaticSharedArbiterClient"

    /// The class-level switch that decides whether the arbiter runs at all.
    ///
    /// Spelled in clear here. KeyboardKit assembles the same seven characters from four
    /// `movk` immediates as a Swift small string, which is precisely why the earlier
    /// strings-based analysis of their binary recovered every other name in this feature
    /// and missed this one — it had to be disassembled out of `+0x2028a4`.
    private static let enabledSelectorName = "enabled"

    // MARK: - Series configuration

    /// How many one-second readings follow each appearance of the keyboard.
    ///
    /// Ten, because the lag is the measurement. VivaDicta captured their resolver naming
    /// an app that had been terminated for three seconds, 1.3 s after the keyboard moved
    /// to a different host, and every reading taken 8 s or more after a host appeared was
    /// correct. A series that stopped before 8 s would reproduce their conclusion by
    /// construction instead of testing it.
    private static let seriesTickCount = 10

    /// Sub-second offsets, in milliseconds, sampled before the one-second grid starts.
    ///
    /// Added in round 2 because the grid turned out to be too coarse for the question it
    /// was asked. With the arbiter activated, the first simulator capture read
    /// `clientState=nil` at 1 ms and the correct bundle ID at 1003 ms — which settles
    /// that `viewWillAppear` alone is not enough, and says nothing about how long a
    /// resolve would actually have to wait. Phase 1 has to bound that wait, and a bound
    /// of "somewhere under a second" is a guess with extra steps.
    ///
    /// Five samples, not fifty: each one is a line in a log budgeted at 1 MB, and the
    /// decision they feed needs an order of magnitude, not a millisecond.
    private static let earlySampleOffsetsMs = [100, 200, 300, 500, 750]

    // MARK: - State

    /// When the keyboard last appeared. Every line's `elapsedMs` is measured from here,
    /// so a reading's age is on the line rather than inferred by subtracting timestamps
    /// across two processes whose writes lag relative to each other.
    private static var appearedAt = Date()

    /// The running series, held so a second appearance replaces the first rather than
    /// interleaving with it.
    ///
    /// A block-based timer with no `target:`. `Timer.scheduledTimer(target: self, …)`
    /// makes the run loop retain its target for the timer's lifetime, which is how #390
    /// deleted text after the finger had left the key and how #416 is still doing it — a
    /// diagnostic is the last place that trap belongs.
    private static var seriesTimer: Timer?

    /// Which appearance the queued sub-second samples belong to. Bumped on every start
    /// and every stop, so a sample that fires late finds its ticket stale and says
    /// nothing. See `scheduleEarlySamples`.
    private static var earlySampleGeneration = 0

    /// Whether this process has already stated its iOS version. Once is enough: the
    /// version cannot change inside a process, and repeating it on 12 lines per
    /// appearance would spend a 1 MB budgeted log on a constant.
    private static var hasLoggedSystemVersion = false

    /// Whether this appearance has already carried the arbiter inventory. Reset on every
    /// appearance so a host change gets its own reading, which is the comparison the
    /// pointers exist for.
    private static var hasInventoriedThisAppearance = false

    /// What happened the first time this process tried to install the activation
    /// swizzle, or nil if it has not tried yet. Doubles as the idempotency latch: a
    /// second call returns `already(...)` rather than stacking another IMP.
    private static var activationOutcome: String?

    /// The controller that last appeared, for the `_hostProcessIdentifier` cross-check.
    ///
    /// Held here rather than read from `KeyboardState.shared.controller` alone because
    /// `viewWillAppear` takes its reading *before* that reference is repointed, and the
    /// first line of a capture is the one that reports the moment the keyboard arrived
    /// in a new host — the least useful line to have blank. Weak, for the same reason
    /// `KeyboardState` holds it weakly: the controller owns the view that owns the state.
    private static weak var appearedController: UIInputViewController?

    // MARK: - Call sites

    /// Anchors the elapsed clock and takes the first reading. Called from
    /// `viewWillAppear`, which passes itself.
    static func keyboardDidAppear(_ controller: UIInputViewController) {
        appearedController = controller
        appearedAt = Date()
        // Activation first, so even the elapsedMs=0 reading is taken with the arbiter
        // switched on. Everything after this is a plain read.
        let activation = activateArbiter()
        hasInventoriedThisAppearance = false
        emit(moment: "viewWillAppear", activation: activation)
    }

    /// Takes a reading at the mic tap — the moment phase 1 would actually need the
    /// answer, and therefore the only one whose accuracy decides anything.
    static func micTapped() {
        emit(moment: "micTap")
    }

    /// Starts the once-per-second series that measures the lag curve.
    ///
    /// Restarted on every appearance: switching host apps is exactly the event under
    /// measurement, and each switch brings the keyboard up again.
    static func startAppearanceSeries() {
        stopAppearanceSeries()
        scheduleEarlySamples()
        var tick = 0
        seriesTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            tick += 1
            emit(moment: String(format: "series%02d", tick))
            if tick >= seriesTickCount {
                timer.invalidate()
                seriesTimer = nil
            }
        }
    }

    /// Stops a running series. Called when the keyboard goes off screen, so a keyboard
    /// the user dismissed after two seconds does not go on writing eight more lines
    /// about a host it is no longer serving.
    static func stopAppearanceSeries() {
        seriesTimer?.invalidate()
        seriesTimer = nil
        earlySampleGeneration &+= 1
    }

    /// Queues the sub-second readings that bracket the population delay.
    ///
    /// `asyncAfter` rather than more timers: five one-shot waits are simpler than five
    /// `Timer`s to invalidate, and the generation counter is what cancels them — a
    /// dispatch work item cannot be un-queued once it is on the main queue, so the ticket
    /// it captured is checked when it runs instead. A keyboard dismissed at 150 ms
    /// therefore writes no line at 750 ms, and a second appearance cannot interleave its
    /// samples with the first's.
    private static func scheduleEarlySamples() {
        earlySampleGeneration &+= 1
        let ticket = earlySampleGeneration
        for offset in earlySampleOffsetsMs {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(offset)) {
                guard earlySampleGeneration == ticket else { return }
                emit(moment: "early\(String(format: "%04d", offset))")
            }
        }
    }

    // MARK: - Emission

    private static func emit(moment: String, activation: String? = nil) {
        var details = read()
        if let activation {
            // Only on the appearance lines, not on the ten series ticks that follow: the
            // value cannot change within an appearance, and one line per appearance is
            // what makes the idempotency visible — the first says `installed`, every
            // later one says `already(installed)`.
            details = "swizzle=\(activation) " + details
        }
        if !hasLoggedSystemVersion {
            hasLoggedSystemVersion = true
            // Prepended, not appended: this API can be withdrawn in any iOS release, so
            // the version is the first thing a reader needs in order to know what the
            // rest of the capture is evidence *about*.
            details = "iosVersion=\(UIDevice.current.systemVersion) " + details
        }
        PersistentLog.log(.hostAppProbe(
            moment: moment,
            elapsedMs: Int(Date().timeIntervalSince(appearedAt) * 1000),
            details: details
        ))
    }

    // MARK: - Activation

    /// Switches the keyboard arbiter on, by making `+[_UIKeyboardArbiterClient enabled]`
    /// answer `true`. Runs at most once per keyboard process.
    ///
    /// ## Why a swizzle at all
    ///
    /// Round 1 of this probe read the arbiter chain on a physical iPhone 85 times across
    /// eight changes of host app and got `sharedClient=nil` every single time, while the
    /// class itself resolved and its accessor responded. The mechanism is not withdrawn;
    /// it is switched off. Disassembling the KeyboardKit binary — rather than only
    /// reading its strings, which is where the first analysis stopped — shows it doing
    /// exactly this: `NSClassFromString` → `NSSelectorFromString("enabled")` →
    /// `class_getClassMethod` → `imp_implementationWithBlock` → `method_setImplementation`,
    /// with a replacement block that returns a `Bool`.
    ///
    /// That the swizzle is what *causes* `automaticSharedArbiterClient` to stop returning
    /// nil is an inference, not an observation. This function exists to settle it in one
    /// device pass, and the `swizzle=` field on the appearance lines is what makes the
    /// answer readable: a nil after a failed install and a nil despite a successful one
    /// are two different results.
    ///
    /// ## What it costs, stated plainly
    ///
    /// This is the most invasive line in the repository, and a reader from outside the
    /// project should understand it in ten seconds: **it replaces the implementation of a
    /// private UIKit class method, for the whole process, for the rest of its life.**
    ///
    /// Reading a private property is passive — Apple removes it, the read returns nil,
    /// and the feature degrades to the manual swipe-back overlay that ships today.
    /// Swizzling is not passive. If Apple changes this method's signature or its meaning,
    /// the failure is not a nil: it is a keyboard extension that behaves differently, or
    /// does not start. It is also far more visible to static analysis than a KVC read.
    ///
    /// Two App Store apps ship this technique. That makes it documented, not safe.
    /// Whether Dictus ships it is a decision that has not been taken; this file is the
    /// measurement that decision is waiting on, and nothing here reaches a user.
    ///
    /// ## Why it cannot double-install
    ///
    /// `method_setImplementation` overwrites rather than chains, so a second call would
    /// not leak an IMP — but it would allocate a second trampoline and make the log lie
    /// about how many times this ran. `activationOutcome` latches on the first attempt,
    /// including the failing attempts: a class that is not there will not appear later.
    ///
    /// Returns `installed`, `<no-class>`, `<no-method>`, or `already(...)`.
    private static func activateArbiter() -> String {
        if let outcome = activationOutcome { return "already(\(outcome))" }

        guard let (_, arbiterClass) = resolveArbiterClass() else {
            activationOutcome = "<no-class>"
            return "<no-class>"
        }
        guard let method = class_getClassMethod(arbiterClass, NSSelectorFromString(enabledSelectorName)) else {
            // A result, not a failure to recover from: it says Apple has taken the
            // switch away, which is the one outcome that closes this line of enquiry.
            activationOutcome = "<no-method>"
            return "<no-method>"
        }

        // A class method's block takes the class object as its receiver and no `_cmd`.
        // `ObjCBool` rather than `Bool` so the return type is the Objective-C `BOOL`
        // by name and not by the coincidence that the two agree on arm64.
        let replacement: @convention(block) (AnyObject) -> ObjCBool = { _ in ObjCBool(true) }
        _ = method_setImplementation(method, imp_implementationWithBlock(replacement))
        activationOutcome = "installed"
        return "installed"
    }

    // MARK: - The read

    /// One traversal of the arbiter chain, rendered in the shared key=value format.
    ///
    /// The chain is
    /// `UIKeyboardArbiterClient.automaticSharedArbiterClient.currentClientState`, whose
    /// `sourceBundleIdentifier` is the payload and whose `processIdentifier` is the pid
    /// that pairs with it. `hostPid` is the independent cross-check KeyboardKit keeps:
    /// `_hostProcessIdentifier` read on our own input view controller. If the two pids
    /// agree, the bundle ID names the app we are actually serving; if they disagree, the
    /// arbiter is lagging and the disagreement is the lag.
    ///
    /// Returns early at the first hop that yields nothing, carrying what it learned. A
    /// short line is a result: it says exactly how far down the chain iOS still goes.
    private static func read() -> String {
        guard let (name, arbiterClass) = resolveArbiterClass() else {
            return "arbiterClass=none tried=\(arbiterClassNames.joined(separator: ",")) \(hostPidDetails())"
        }
        var out = ["arbiterClass=\(name)"]

        guard let client = sharedArbiterClient(of: arbiterClass) else {
            out.append("sharedClient=\(describeMissing(arbiterClass as AnyObject, selector: sharedClientSelectorName))")
            out.append(classAccessorInventory(of: arbiterClass))
            return (out + [hostPidDetails()]).joined(separator: " ")
        }
        out.append("sharedClient=ok")

        guard let state = read("currentClientState", from: client) as? NSObject else {
            out.append("clientState=\(describeMissing(client, selector: "currentClientState"))")
            return (out + [hostPidDetails()]).joined(separator: " ")
        }
        out.append("clientStateClass=\(type(of: state))")
        // The inventory rides the first line of each appearance that actually has a
        // client state — not `viewWillAppear`, where it would be blank every time: the
        // state does not exist yet at elapsedMs=0, that is the population delay this
        // probe measures. One line per appearance, always carrying data.
        if !hasInventoriedThisAppearance {
            hasInventoriedThisAppearance = true
            out.append(inventory(client: client, state: state))
        }

        let bundleId = read("sourceBundleIdentifier", from: state) as? String
        let pid = (read("processIdentifier", from: state) as? NSNumber)?.intValue
        out.append("sourceBundleIdentifier=\(bundleId ?? describeMissing(state, selector: "sourceBundleIdentifier"))")
        out.append("processIdentifier=\(pid.map(String.init) ?? describeMissing(state, selector: "processIdentifier"))")

        // The *other* pair the client state carries. The inventory above is what found
        // them: `_UIKeyboardChangedInformation` declares `hostBundleIdentifier` and
        // `hostProcessIdentifier` next to the `source*` pair this probe was built around,
        // and nothing in the KeyboardKit analysis mentions them.
        //
        // Worth reading because the simulator showed the `source*` pair freezing at the
        // value it had when the arbiter was activated while the real host kept changing.
        // If `host*` tracks where `source*` sticks, the freeze is us reading the wrong
        // field rather than anything being stale — which is the cheapest possible fix and
        // the sort of difference the control experiment says to look for.
        let hostBundleId = read("hostBundleIdentifier", from: state) as? String
        let hostStatePid = (read("hostProcessIdentifier", from: state) as? NSNumber)?.intValue
        out.append("hostBundleIdentifier=\(hostBundleId ?? describeMissing(state, selector: "hostBundleIdentifier"))")
        out.append("hostProcessIdentifier=\(hostStatePid.map(String.init) ?? describeMissing(state, selector: "hostProcessIdentifier"))")

        // The scene identity the state was built for. Pairs with the class method the
        // round-1 inventory turned up, `keyboardClientFBSSceneIdentityStringOrIdentifierFromScene:`
        // — if this ever disagrees with the host we are actually serving, it names which
        // scene the stale reading belongs to.
        let sceneIdentity = read("sourceSceneIdentityString", from: state) as? String
        out.append("sourceScene=\(sceneIdentity ?? describeMissing(state, selector: "sourceSceneIdentityString"))")

        return (out + [hostPidDetails()]).joined(separator: " ")
    }

    /// The cross-check: the host pid as our own input view controller reports it.
    ///
    /// Read on the controller itself, which is *not* where the 2026-04 probe #12 looked —
    /// that one read `_hostProcessIdentifier` on `_UIViewServiceViewControllerOperator`
    /// and got 0. Carried on every line even when the arbiter chain fails, because if the
    /// arbiter is gone but this survives, the pid is the route worth pursuing.
    private static func hostPidDetails() -> String {
        guard let controller = appearedController ?? KeyboardState.shared.controller else {
            return "hostPid=<no-controller>"
        }
        let pid = (read("_hostProcessIdentifier", from: controller) as? NSNumber)?.intValue
        return "hostPid=\(pid.map(String.init) ?? describeMissing(controller, selector: "_hostProcessIdentifier"))"
    }

    /// What our own process can see around the arbiter, once per appearance.
    ///
    /// ## Why these fields exist (the control of 2026-09-10)
    ///
    /// VivaDicta, installed from the App Store, teleports back to the host app on the
    /// same iPhone and the same iOS that this probe runs on. So Apple has not closed the
    /// path and the API is alive today. **Anything we cannot read is therefore a
    /// difference between our input view controller and theirs, not a limit of iOS** —
    /// which turns every blank or stale field here from a dead end into a lead.
    ///
    /// The immediate lead is the one the simulator produced: after the client state is
    /// first populated it stops tracking changes of host, while `hostPid` keeps up. Two
    /// of these fields separate the candidate explanations directly.
    ///
    /// - `clientPtr` / `statePtr`: whether the arbiter hands back the *same objects* on
    ///   every appearance. A stable `statePtr` across two different hosts means the state
    ///   is cached and never rebuilt; a fresh pointer carrying stale contents means the
    ///   source it is built from is what has gone stale. Those want different fixes.
    /// - `stateProps`: the property names on the client state's class. If one of them is
    ///   a timestamp, the staleness stops being an inference; if one of them carries a
    ///   scene identity, that is a second route to a fresh value.
    ///
    /// Reads only, capped, and on one line in sixteen. Nothing here is acted on.
    private static func inventory(client: NSObject, state: NSObject) -> String {
        "clientPtr=\(address(of: client)) statePtr=\(address(of: state))"
            + " stateProps=[\(propertyNames(of: type(of: state)).joined(separator: ","))]"
    }

    /// An object's address, so two readings can be compared for identity in a log that
    /// has no other way to say "the same instance came back".
    ///
    /// The real pointer, not a hash of it: a hash would compare equal just as well, but
    /// it would print as something that looks like an address and is not, and the next
    /// reader would waste time trying to correlate it with one.
    private static func address(of object: AnyObject) -> String {
        "0x" + String(UInt(bitPattern: Unmanaged.passUnretained(object).toOpaque()), radix: 16)
    }

    /// The declared property names of `cls`, capped so one line cannot run away.
    private static func propertyNames(of cls: AnyClass) -> [String] {
        var count: UInt32 = 0
        guard let list = class_copyPropertyList(cls, &count) else { return [] }
        defer { free(list) }
        return (0..<Int(count))
            .map { String(cString: property_getName(list[$0])) }
            .prefix(16)
            .map { $0 }
    }

    // MARK: - Runtime plumbing

    /// The first of `arbiterClassNames` that the runtime knows, with the name that worked.
    private static func resolveArbiterClass() -> (String, NSObject.Type)? {
        for name in arbiterClassNames {
            if let cls = NSClassFromString(name) as? NSObject.Type {
                return (name, cls)
            }
        }
        return nil
    }

    /// The arbiter singleton, via a class method sent by name.
    ///
    /// `perform` rather than class-level KVC: the accessor is a class method, and sending
    /// it directly to the class object says so, where `value(forKey:)` on a metatype
    /// leaves a Swift reader guessing which of KVC's several lookup paths is in play.
    /// `takeUnretainedValue` is correct here — the selector is not in the `alloc`/`new`/
    /// `copy`/`mutableCopy` family, so the result comes back autoreleased, not owned.
    private static func sharedArbiterClient(of arbiterClass: NSObject.Type) -> NSObject? {
        let selector = NSSelectorFromString(sharedClientSelectorName)
        let classObject = arbiterClass as AnyObject
        guard classObject.responds(to: selector) else { return nil }
        return classObject.perform(selector)?.takeUnretainedValue() as? NSObject
    }

    /// A KVC read that cannot trap. See the type comment: an unguarded `value(forKey:)`
    /// against a missing key raises an Objective-C exception Swift has no way to catch.
    private static func read(_ key: String, from object: NSObject) -> Any? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        return object.value(forKey: key)
    }

    /// The class methods this class exposes that could plausibly hand out an instance.
    ///
    /// Emitted only when `automaticSharedArbiterClient` yields nothing, and it is what
    /// makes that outcome actionable instead of terminal. `sharedClient=nil` on its own
    /// says "the accessor exists and is empty" and leaves the next step to guesswork —
    /// which on a physical device costs another build, another install and another
    /// capture. The inventory names the accessors that do exist, so the next attempt is
    /// a read rather than a guess.
    ///
    /// Filtered and capped: the point is the handful of names that look like vendors of
    /// an instance, not a full method dump in a log budgeted at 1 MB.
    private static func classAccessorInventory(of arbiterClass: NSObject.Type) -> String {
        var count: UInt32 = 0
        guard let methods = class_copyMethodList(object_getClass(arbiterClass), &count) else {
            return "classMethods=none"
        }
        defer { free(methods) }
        let names = (0..<Int(count)).map { String(cString: sel_getName(method_getName(methods[$0]))) }
        let interesting = names
            .filter { $0.contains("hared") || $0.contains("lient") || $0.contains("rbiter") }
            .prefix(12)
        return "classMethods=\(count) vendors=[\(interesting.joined(separator: ","))]"
    }

    /// Why a hop produced nothing: the selector is gone, or it answered with nil.
    ///
    /// Worth the extra call. "Apple withdrew the property" and "the property is there and
    /// empty right now" look identical in a log that only prints `nil`, and they are the
    /// difference between the lane closing and the timing needing work.
    private static func describeMissing(_ object: AnyObject, selector name: String) -> String {
        object.responds(to: NSSelectorFromString(name)) ? "nil" : "<no-selector>"
    }
}
