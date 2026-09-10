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

    // MARK: - Series configuration

    /// How many one-second readings follow each appearance of the keyboard.
    ///
    /// Ten, because the lag is the measurement. VivaDicta captured their resolver naming
    /// an app that had been terminated for three seconds, 1.3 s after the keyboard moved
    /// to a different host, and every reading taken 8 s or more after a host appeared was
    /// correct. A series that stopped before 8 s would reproduce their conclusion by
    /// construction instead of testing it.
    private static let seriesTickCount = 10

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

    /// Whether this process has already stated its iOS version. Once is enough: the
    /// version cannot change inside a process, and repeating it on 12 lines per
    /// appearance would spend a 1 MB budgeted log on a constant.
    private static var hasLoggedSystemVersion = false

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
        emit(moment: "viewWillAppear")
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
    }

    // MARK: - Emission

    private static func emit(moment: String) {
        var details = read()
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

        let bundleId = read("sourceBundleIdentifier", from: state) as? String
        let pid = (read("processIdentifier", from: state) as? NSNumber)?.intValue
        out.append("sourceBundleIdentifier=\(bundleId ?? describeMissing(state, selector: "sourceBundleIdentifier"))")
        out.append("processIdentifier=\(pid.map(String.init) ?? describeMissing(state, selector: "processIdentifier"))")

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
