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

    /// The class-level switch that decides whether the arbiter runs at all.
    private static let enabledSelectorName = "enabled"

    // MARK: - Process-local state

    /// pid → bundle identifier, learned from the arbiter and **never persisted**. See the
    /// type comment: persisting this reintroduces the wrong-app bug through pid reuse.
    private static var bundleIdsByPid: [Int: String] = [:]

    /// Insertion order for `bundleIdsByPid`, so the table can be bounded.
    ///
    /// A keyboard process that outlived 64 distinct host apps has never been observed, and
    /// each entry is a few tens of bytes — but this runs in an extension with a ~50 MB
    /// ceiling, where "it will never get big" is the kind of assumption that shows up in a
    /// jetsam report. The cap is cheap and it removes the question.
    private static var pidInsertionOrder: [Int] = []

    /// The most entries the table keeps. Oldest evicted first; the current host is by
    /// definition the newest, so eviction cannot lose the answer that is about to be used.
    private static let maxTableEntries = 64

    /// What happened the first time this process tried to install the activation swizzle,
    /// or nil if it has not tried. Doubles as the idempotency latch.
    private static var activationOutcome: String?

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
        guard let state = currentClientState() else { return }
        guard let bundleId = read("sourceBundleIdentifier", from: state) as? String,
              let pid = (read("processIdentifier", from: state) as? NSNumber)?.intValue,
              !bundleId.isEmpty, pid > 0
        else {
            return
        }
        record(bundleId: bundleId, forPid: pid)
    }

    /// The bundle identifier of the app `controller` is serving, or nil.
    ///
    /// Nil whenever anything is missing: no swizzle, no arbiter, no host pid, or a host
    /// pid the table has never seen. Every one of those means the same thing to the
    /// caller — no auto-return, show the overlay — and none of them may be turned into a
    /// guess.
    static func currentHostId(for controller: UIInputViewController) -> String? {
        harvest()
        guard let pid = hostProcessIdentifier(of: controller) else { return nil }
        return bundleIdsByPid[pid]
    }

    /// Installs the activation swizzle once per process. Safe to call repeatedly.
    ///
    /// Returns `installed`, `<no-class>`, `<no-method>` or `already(...)`, which the
    /// caller logs.
    @discardableResult
    static func activateArbiter() -> String {
        if let outcome = activationOutcome { return "already(\(outcome))" }

        guard let arbiterClass = resolveArbiterClass() else {
            activationOutcome = "<no-class>"
            return "<no-class>"
        }
        guard let method = class_getClassMethod(arbiterClass, NSSelectorFromString(enabledSelectorName)) else {
            activationOutcome = "<no-method>"
            return "<no-method>"
        }

        // A class method's block takes the class object as its receiver and no `_cmd`.
        // `ObjCBool` rather than `Bool` so the return type is Objective-C's `BOOL` by name
        // and not by the coincidence that the two agree on arm64.
        let replacement: @convention(block) (AnyObject) -> ObjCBool = { _ in ObjCBool(true) }
        _ = method_setImplementation(method, imp_implementationWithBlock(replacement))
        activationOutcome = "installed"
        return "installed"
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

    // MARK: - The table

    /// Records one pid → bundle pairing, evicting the oldest entry past the cap.
    private static func record(bundleId: String, forPid pid: Int) {
        if bundleIdsByPid[pid] == nil {
            pidInsertionOrder.append(pid)
            if pidInsertionOrder.count > maxTableEntries {
                let evicted = pidInsertionOrder.removeFirst()
                bundleIdsByPid[evicted] = nil
            }
        }
        bundleIdsByPid[pid] = bundleId
    }
}
