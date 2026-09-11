// DictusKeyboard/HostAppResolver.swift
import UIKit
import ObjectiveC
import DictusCore

/// Names the app this keyboard is typing into, so a cold-start dictation can send the
/// user back to it (#23).
///
/// ## The problem this solves
///
/// When the keyboard launches DictusApp to record, iOS puts DictusApp in the foreground
/// and the user has to swipe back by hand. Returning them automatically needs one fact
/// the keyboard has never had: *which app am I in*. An April 2026 investigation concluded
/// no API provides it and closed the question; the swipe-back overlay has been the answer
/// since. That conclusion was wrong, and the reason is that all thirteen of its probes
/// interrogated the input view controller, its parent chain, its `extensionContext` or its
/// window scene. The bundle ID lives on none of them. It lives on
/// `_UIKeyboardArbiterClient`, a UIKit singleton outside the view controller graph.
///
/// ## The algorithm, and why it is not the obvious one
///
/// The obvious implementation reads `sourceBundleIdentifier` off the arbiter and uses it.
/// **That is wrong and this file must never do it.** Across 190 device probe lines over 16
/// keyboard appearances (iPhone 15 Pro Max, iOS 26.6.1), the arbiter named a stale host on
/// 7 of them, and in 4 of those it never corrected — ten seconds of polling, still naming
/// an app the user had left. Reading it directly would have opened the wrong app one time
/// in four. Opening the wrong app is worse than opening none: it also resurrects an app
/// the user had closed.
///
/// What the same capture showed is that no pid was ever seen against two different bundle
/// identifiers, and that `_hostProcessIdentifier` — read on our own view controller — was
/// correct at `elapsedMs=0` on all 16 appearances. So:
///
/// 1. every time the arbiter is read, the pair `(processIdentifier, sourceBundleIdentifier)`
///    goes into a pid → bundle table;
/// 2. the current host is `_hostProcessIdentifier`, which is never stale;
/// 3. the answer is `table[hostPid]` — never `sourceBundleIdentifier` directly.
///
/// The indirection turns a *wrong* answer into a *missing* one, and a missing one costs
/// only the swipe-back overlay the user gets today. All 60 stale lines in the capture were
/// resolvable this way, with no exceptions.
///
/// ## The table is never persisted, and that is load-bearing
///
/// Not to the App Group, not to `UserDefaults`, not anywhere that outlives this process.
/// iOS recycles process identifiers. A table that survives the extension eventually maps a
/// recycled pid onto a dead app's bundle ID and confidently opens the wrong app — which is
/// precisely the failure the pid indirection exists to remove, reintroduced through the
/// back door. `SharedKeys.sourceAppScheme` was deleted in the same change for the same
/// reason: it looked like the right key and was the wrong shape.
///
/// ## This is private API, and one line of it is active
///
/// Everything is resolved by name at runtime so nothing is linked, and every KVC read is
/// guarded — `value(forKey:)` against a missing key raises `NSUnknownKeyException`, which
/// Swift cannot catch, and this repo has already crashed a keyboard that way once (PR
/// #282). Reads degrade to nil.
///
/// `activateArbiter()` does not. See its own comment.
enum HostAppResolver {

    // MARK: - Names resolved at runtime

    /// The two spellings the arbiter class could have. Only the underscored one exists —
    /// measured, 85/85 on device — but the un-underscored spelling is what the reference
    /// analysis used, and trying both costs three lines against a device round trip.
    private static let arbiterClassNames = ["UIKeyboardArbiterClient", "_UIKeyboardArbiterClient"]

    /// Class-level accessor for the arbiter singleton.
    private static let sharedClientSelectorName = "automaticSharedArbiterClient"

    // MARK: - Process-local state

    /// What the keyboard has learned about which process is which app.
    ///
    /// **Never persisted** — not to the App Group, not to `UserDefaults`, nowhere that
    /// outlives this process. The rules that stop it ever answering wrongly, and why a
    /// plain dictionary is unsafe, are in `HostPidTable`.
    private static var table = HostPidTable()

    /// The last arbiter claim written to the log, so `harvest()` stays silent while
    /// nothing moves.
    ///
    /// WHY the filter: `harvest()` runs on every keyboard appearance, every keystroke and
    /// every caret move. Writing a line per call would add thousands of identical entries
    /// to a session and push the interesting ones out of the export window. A claim that
    /// has not changed carries nothing the previous line did not already carry.
    private static var lastLoggedClaim: String?

    // MARK: - Public surface

    /// Reads the arbiter and records what it saw. Called on every keyboard appearance and
    /// again at the mic tap.
    ///
    /// WHY also at the tap, when the appearance already harvested: on the *first*
    /// appearance after a fresh extension process the arbiter's client state does not
    /// exist yet — it is populated about 200 ms after activation, measured at nil at
    /// 106 ms and correct at 210 ms. A user who taps the mic inside that window would
    /// otherwise meet an empty table. Harvesting again at the tap costs one read and
    /// closes exactly that gap.
    static func harvest() {
        let state = currentClientState()
        noteHarvestClaim(arbiterClaim(state: state))
        guard let state else { return }
        guard let bundleId = read("sourceBundleIdentifier", from: state) as? String,
              let pid = (read("processIdentifier", from: state) as? NSNumber)?.intValue,
              !bundleId.isEmpty, pid > 0
        else {
            return
        }
        table.record(bundleId: bundleId, forPid: pid)
    }

    /// What a resolution attempt produced, and why when it produced nothing.
    ///
    /// The distinction is not academic. `noHostPid` means the private surface is gone or
    /// the controller is detached — nothing about the table would help. `tableMiss` means
    /// the host is real and known but the arbiter never named it while we were reading,
    /// which is a harvest-coverage problem and the thing to widen next. Collapsing both
    /// into nil, as the first version of this did, cost a round of device testing that
    /// could not tell them apart.
    enum Resolution {
        case resolved(String, pid: Int)
        case noHostPid
        case tableMiss(pid: Int)

        /// The bundle identifier, or nil. The only accessor that may drive behaviour.
        var hostId: String? {
            if case .resolved(let id, _) = self { return id }
            return nil
        }

        /// A log-safe reason, for the one `notice` line per hand-off.
        ///
        /// A miss carries the state of every hop, because `known=0` alone says the table
        /// is empty and not which link broke — and the four candidates want four
        /// different fixes. That gap cost a device round trip: a whole session of
        /// `known=0` that could not say whether the swizzle had failed to install or had
        /// installed and woken nothing.
        var reason: String {
            switch self {
            case .resolved(_, let pid):
                // The claim rides the hits too, and that is what makes the misses
                // readable: without a baseline for what the arbiter says when it agrees
                // with us, a mismatch on a failure has nothing to be a mismatch *from*.
                return "resolved hostPid=\(pid) \(HostAppResolver.arbiterClaimNow)"
            case .noHostPid: return "no-host-pid \(HostAppResolver.hopDiagnostics)"
            case .tableMiss(let pid):
                return "table-miss(pid=\(pid),known=\(HostAppResolver.tableSize)"
                    + ",trusted=\(HostAppResolver.trustedCount),seen=\(HostAppResolver.hasEverSeen(pid: pid)))"
                    + " \(HostAppResolver.hopDiagnostics)"
            }
        }
    }

    /// What the table holds, for the log line above. `known=0` is an arbiter that never
    /// answered at all; `known=3 trusted=0` is one that answered in an earlier appearance
    /// whose evidence has since been retired; `seen=true` says this very pid is in the
    /// history and is no longer trusted — the recycling guard doing its job.
    static var tableSize: Int { table.count }
    static var trustedCount: Int { table.trustedCount }
    static func hasEverSeen(pid: Int) -> Bool { table.hasEverSeen(pid: pid) }

    /// Retires the previous appearance's evidence. Called when the keyboard appears,
    /// before that appearance's first harvest — the keyboard appearing is the event that
    /// can change the host, so it is the event that expires the old evidence.
    static func noteKeyboardAppeared() {
        table.noteAppearance()
        // Forget what was last logged, so every appearance opens with the arbiter's claim
        // at that moment even when it repeats the value the previous appearance ended on.
        // That repetition is the symptom under investigation in #543 — an arbiter still
        // naming a host the user left minutes ago — and a filter that hid it would hide
        // the evidence.
        lastLoggedClaim = nil
    }

    /// Writes one line when the arbiter's claim changes, and nothing when it does not.
    ///
    /// WHY this exists (#543): the arbiter used to be logged only at the mic tap, which is
    /// the instant of failure and nothing before it. A miss could not say whether the
    /// arbiter had named the correct host earlier in that appearance and then gone stale,
    /// or had never named it at all — two different defects wanting two different fixes.
    /// Recording every change turns an appearance into a trace instead of a snapshot.
    ///
    /// `hostId` is `none` because this line is an observation about the arbiter, not a
    /// hand-off outcome; only the tap-time lines carry a resolution.
    private static func noteHarvestClaim(_ claim: String) {
        guard claim != lastLoggedClaim else { return }
        lastLoggedClaim = claim
        PersistentLog.log(.hostReturn(hostId: "none", outcome: "harvest \(claim)"))
    }

    /// The state of every hop between us and the host's bundle identifier.
    ///
    /// Four facts, each of which fails differently:
    ///
    /// - `swizzle=` what the load-time constructor did, and `retry=` what a fresh attempt
    ///   does now — `no-class` on both means the private class is simply not there;
    /// - `arbiterClass=` whether the class resolves at this instant;
    /// - `sharedSel=` whether the singleton accessor still responds;
    /// - `sharedClient=` whether it actually hands one back, which is the hop that was
    ///   silently nil for a whole device session.
    static var hopDiagnostics: String {
        let arbiterClass = resolveArbiterClass()
        let respondsToShared = arbiterClass.map {
            ($0 as AnyObject).responds(to: NSSelectorFromString(sharedClientSelectorName))
        }
        let client = arbiterClass.flatMap(sharedArbiterClient(of:))
        let state = client.flatMap { read("currentClientState", from: $0) } as? NSObject
        return "swizzle=\(loadTimeActivation) retry=\(activateArbiter())"
            + " arbiterClass=\(arbiterClass != nil)"
            + " sharedSel=\(respondsToShared.map(String.init) ?? "n/a")"
            + " sharedClient=\(client != nil)"
            + " clientState=\(state != nil)"
            + " \(arbiterClaim(state: state))"
    }

    /// What the arbiter is saying *right now*, as a whole pair.
    ///
    /// ## The question this exists to answer
    ///
    /// Our resolution refuses to use `sourceBundleIdentifier` unless its `processIdentifier`
    /// matches the host pid. VivaDicta reads `sourceBundleIdentifier` directly, with no
    /// cross-check, and in side-by-side testing under the same conditions they return the
    /// user every time where we miss roughly a third.
    ///
    /// That leaves exactly two possibilities on a miss, and a boolean cannot tell them
    /// apart — only the pair can:
    ///
    /// - the arbiter named **the right app** under a stale pid. Then our cross-check is
    ///   throwing away a correct answer, and the guard is costing more than it protects.
    /// - the arbiter named **a different app**. Then it really was stale, the guard just
    ///   prevented a wrong app from opening, and VivaDicta is carrying a risk that has
    ///   not yet bitten them.
    ///
    /// Logged next to `hostPid` on every miss so the two can be compared directly. The
    /// bundle identifier here is the same category of data `hostId` already is — it names
    /// an app, never what was typed into it, and `PRIVACY.md` covers it.
    ///
    /// **Measurement only.** Nothing reads this, and the resolution policy is unchanged:
    /// it is the safety property of this feature and it does not move on a hypothesis.
    /// The arbiter's current claim, resolving the chain itself. For the hit path, which
    /// does not otherwise pay for the full hop diagnostics.
    static var arbiterClaimNow: String {
        arbiterClaim(state: currentClientState())
    }

    private static func arbiterClaim(state: NSObject?) -> String {
        guard let state else { return "arbiterSays=<no-state>" }
        let bundleId = read("sourceBundleIdentifier", from: state) as? String
        let pid = (read("processIdentifier", from: state) as? NSNumber)?.intValue
        return "arbiterSays=\(bundleId ?? "nil")@pid\(pid.map(String.init) ?? "nil")"
    }

    /// Resolves the app `controller` is serving.
    ///
    /// Anything other than `.resolved` means the same thing to the caller — no
    /// auto-return, show the overlay — and none of them may be turned into a guess.
    static func currentHost(for controller: UIInputViewController) -> Resolution {
        harvest()
        guard let pid = hostProcessIdentifier(of: controller) else { return .noHostPid }
        guard let bundleId = table.bundleId(forPid: pid) else { return .tableMiss(pid: pid) }
        return .resolved(bundleId, pid: pid)
    }

    /// Ensures the arbiter is switched on, and reports what happened.
    ///
    /// The swizzle itself is installed by a load-time constructor in
    /// `HostArbiterActivation.m` — before `main`, before any controller exists. This is
    /// the retry and the reporter, not the installer.
    ///
    /// WHY a retry exists at all: a failure is deliberately **not** remembered. The first
    /// version of this latched every outcome, including the failures, so a swizzle that
    /// could not find its class at one moment was never attempted again for the life of
    /// the process — and the log then said `already(<no-class>)` forever. Only success is
    /// sticky now; `no-class` and `no-method` are retried on every appearance, because a
    /// class that is not loaded at constructor time can be loaded a second later.
    ///
    /// Returns `installed`, `already`, `no-class` or `no-method`.
    @discardableResult
    static func activateArbiter() -> String {
        DictusHostArbiterActivation.activate()
    }

    /// What the load-time constructor produced, for the one line that reports it.
    static var loadTimeActivation: String {
        DictusHostArbiterActivation.loadTimeOutcome()
    }

    // MARK: - The swizzle, and what it costs

    // `activateArbiter` above is the most invasive line in this repository, and a reader
    // from outside the project should understand it in ten seconds: **it replaces the
    // implementation of a private UIKit class method, for the whole extension process,
    // for the rest of its life.**
    //
    // It is here because the arbiter is switched off by default. Reading the chain on a
    // physical iPhone 85 times returned nil every single time while the class resolved and
    // its accessor responded — the mechanism was not withdrawn, it was dormant.
    // Disassembling the KeyboardKit binary shows it doing exactly this:
    // `NSClassFromString` → `NSSelectorFromString("enabled")` → `class_getClassMethod` →
    // `imp_implementationWithBlock` → `method_setImplementation`. With the same swizzle in
    // place the arbiter answers, and answers correctly.
    //
    // Reading a private property is passive: Apple removes it, the read returns nil, and
    // the feature degrades to the swipe-back overlay that ships today. Swizzling is not
    // passive. If Apple changes `+enabled`'s signature or its meaning the failure is not a
    // nil — it is a keyboard extension that behaves differently, or does not start. That
    // is why both hops are guarded and why a missing class or method is a clean no-op:
    // the keyboard extension launching is the most fragile path in this product, and a
    // regression has reached it four times.
    //
    // Two App Store apps ship this technique. That makes it documented, not safe. The
    // decision to take the risk was taken deliberately, on 2026-09-10, with this written
    // down.

    // MARK: - The arbiter chain

    /// The arbiter's current client state, or nil at the first hop that yields nothing.
    private static func currentClientState() -> NSObject? {
        guard let arbiterClass = resolveArbiterClass(),
              let client = sharedArbiterClient(of: arbiterClass),
              let state = read("currentClientState", from: client) as? NSObject
        else {
            return nil
        }
        return state
    }

    /// The first of `arbiterClassNames` the runtime knows.
    private static func resolveArbiterClass() -> NSObject.Type? {
        for name in arbiterClassNames {
            if let cls = NSClassFromString(name) as? NSObject.Type { return cls }
        }
        return nil
    }

    /// The arbiter singleton, via a class method sent by name.
    ///
    /// `perform` rather than class-level KVC: the accessor is a class method, and sending
    /// it to the class object says so, where `value(forKey:)` on a metatype leaves a
    /// reader guessing which of KVC's lookup paths is in play. `takeUnretainedValue` is
    /// correct — the selector is not in the `alloc`/`new`/`copy`/`mutableCopy` family, so
    /// the result comes back autoreleased rather than owned.
    private static func sharedArbiterClient(of arbiterClass: NSObject.Type) -> NSObject? {
        let selector = NSSelectorFromString(sharedClientSelectorName)
        let classObject = arbiterClass as AnyObject
        guard classObject.responds(to: selector) else { return nil }
        return classObject.perform(selector)?.takeUnretainedValue() as? NSObject
    }

    /// The pid of the app this controller is serving, read on the controller itself.
    ///
    /// This is the trustworthy half of the design. It was correct at `elapsedMs=0` on
    /// 16/16 measured appearances, including every one where the arbiter was stale. Note
    /// it is read on the *controller* — the 2026-04 investigation read the same-named
    /// property on `_UIViewServiceViewControllerOperator` and got 0, which is what sent it
    /// down the wrong path.
    private static func hostProcessIdentifier(of controller: UIInputViewController) -> Int? {
        guard let pid = (read("_hostProcessIdentifier", from: controller) as? NSNumber)?.intValue,
              pid > 0
        else {
            return nil
        }
        return pid
    }

    /// A KVC read that cannot trap. An unguarded `value(forKey:)` against a missing key
    /// raises an Objective-C exception Swift has no way to catch.
    private static func read(_ key: String, from object: NSObject) -> Any? {
        guard object.responds(to: NSSelectorFromString(key)) else { return nil }
        return object.value(forKey: key)
    }

    // MARK: - Why the table is a necessity and not an optimisation

    // The obvious simplification is to skip the harvest and translate the host pid
    // directly. It is not available: `proc_pidpath` and `sysctl(KERN_PROC_PID)` both
    // return `EPERM` inside a keyboard extension — measured on a physical iPhone, 7
    // attempts across 7 hand-offs, iOS 26.6.1, 2026-09-11. A sandboxed extension cannot
    // observe another process at all.
    //
    // A simulator says otherwise, and that is the trap: both calls succeed there and
    // return the correct bundle identifier, because a simulator is a macOS process with
    // far weaker sandboxing than an iPhone. Wiring anything to that measurement would
    // have shipped dead code.
    //
    // So the arbiter is the only source, and `HostPidTable` is what makes its answers safe
    // to use rather than an optimisation over something better.
}
