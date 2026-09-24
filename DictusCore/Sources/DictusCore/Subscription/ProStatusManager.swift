// DictusCore/Sources/DictusCore/Subscription/ProStatusManager.swift
// Lightweight Pro status manager for App Group cross-process sync.
import Foundation
import SwiftUI

/// What the reverse trial depends on, gathered so the tests can replace every input
/// at once (#593).
///
/// WHY a value and not four init parameters: `ProStatusManager()` is built in a dozen
/// places (the app, previews, tests) and every one of them wants production behaviour.
/// One default, `.live`, keeps them all as they were, and a test builds one value that
/// cannot mix a fake clock with a real Keychain by accident.
public struct ProTrialEnvironment {
    /// The clock. Injected so expiry is testable without waiting fourteen days.
    public var now: () -> Date
    /// `SmartModeAvailability.deviceIsCapable`, the decision-2 input. Read once per
    /// manager: the definitive reasons it reflects (hardware, OS, SDK) cannot change
    /// inside a process, and the live read asks `SystemLanguageModel`.
    public var deviceIsCapable: () -> Bool
    /// `PremiumFlags.paywallVisible`. With it down no trial starts and nothing about
    /// one appears (#279).
    public var paywallVisible: Bool
    /// The App Group, or a test suite.
    public var defaults: UserDefaults
    /// Where the trial is recorded. Built from `defaults` in `.live`.
    public var store: ProTrialStore

    public init(now: @escaping () -> Date,
                deviceIsCapable: @escaping () -> Bool,
                paywallVisible: Bool,
                defaults: UserDefaults,
                store: ProTrialStore) {
        self.now = now
        self.deviceIsCapable = deviceIsCapable
        self.paywallVisible = paywallVisible
        self.defaults = defaults
        self.store = store
    }

    /// Production: the real clock, the real device, the shipping flag, the App Group
    /// and the Keychain.
    public static var live: ProTrialEnvironment {
        ProTrialEnvironment(
            now: Date.init,
            deviceIsCapable: { SmartModeAvailability.deviceIsCapable },
            paywallVisible: PremiumFlags.paywallVisible,
            defaults: AppGroup.defaults,
            store: .live
        )
    }
}

/// Manages Pro subscription status in App Group UserDefaults.
///
/// WHY ObservableObject with @Published:
/// SwiftUI views observe this to reactively show/hide Pro UI elements.
/// When SubscriptionManager (in DictusApp) calls setProActive(),
/// the @Published property triggers UI refresh across all observing views.
///
/// WHY separate from SubscriptionManager:
/// ProStatusManager lives in DictusCore (shared framework) so both the
/// main app AND the keyboard extension can read Pro status. SubscriptionManager
/// lives in DictusApp only (StoreKit is too heavy for the ~50MB keyboard extension).
///
/// **Entitlement is "paid or trial running" since #593.** Paid is driven entirely by
/// StoreKit entitlements, tested through the local StoreKitConfig.storekit in
/// development and the free sandbox on TestFlight. The reverse trial is the other
/// half: every user gets Pro for `ProTrial.durationDays` without subscribing, then
/// the paywall. The two are published separately because they answer different
/// questions: `isProActive` is what the user may use, `isPaid` is whether there is
/// anything left to sell them. The paywall needs the second, or a user on trial could
/// never subscribe before it ends.
@MainActor
public final class ProStatusManager: ObservableObject {
    /// Entitled to Pro right now: paid, or a trial running. What every Pro surface reads.
    @Published public private(set) var isProActive: Bool

    /// A StoreKit entitlement exists. What the paywall reads to decide whether to sell.
    @Published public private(set) var isPaid: Bool

    /// Where the reverse trial stands, as of the last refresh.
    @Published public private(set) var trialState: ProTrialState

    private let environment: ProTrialEnvironment

    /// Read once: see `ProTrialEnvironment.deviceIsCapable`.
    public let deviceIsCapable: Bool

    public init(environment: ProTrialEnvironment = .live) {
        self.environment = environment
        self.deviceIsCapable = environment.deviceIsCapable()

        // Runs at every app launch (DictusApp.init), which is what makes the
        // seeding idempotent and always ahead of the first read.
        ProStatusManager.seedFeatureTogglesIfNeeded()

        // Through the static rule rather than reading the key directly, so the app's own
        // observed value and every `FeatureGate` answer come from one expression (#460).
        let now = environment.now()
        self.isProActive = ProStatusManager.entitlement(
            in: environment.defaults, now: now, trialsEnabled: environment.paywallVisible
        )
        self.isPaid = ProStatusManager.isPaid(in: environment.defaults)
        self.trialState = ProTrialState(record: environment.store.mirroredRecord, now: now)
    }

    /// Writes the per-feature Pro toggles into the App Group the first time, so that
    /// the keyboard extension and the app read the same answer (issue #401).
    ///
    /// WHY a write and not `register(defaults:)`, which is what this replaced:
    /// registration is per-process and never hits disk. DictusApp runs this init and
    /// read `true` for an un-toggled feature; the keyboard extension never runs it and
    /// read `false`. Same key, two processes, two answers -- a subscriber who never
    /// opened the Settings toggle got a locked Smart Mode fan while Settings showed it
    /// on. The App Group is the source of truth both sides already assume it is, so
    /// the value has to actually be in it.
    ///
    /// WHY `object(forKey:) == nil` and not an unconditional write: seed, never
    /// assign. `SubscriptionManager.updateProStatus()` runs on every launch, so an
    /// unconditional write would silently switch a feature back on for a user who
    /// deliberately turned it off. `bool(forKey:)` cannot tell "never set" from "set
    /// to false"; `object(forKey:)` can.
    ///
    /// WHY no `register(defaults:)` survives alongside it: a registered value makes
    /// `object(forKey:)` return non-nil, which would disarm the guard above and leave
    /// the keys unpersisted all over again.
    ///
    /// Seeding is deliberately not conditioned on Pro being active: `FeatureGate`
    /// checks `isProActive` first, so a stored `true` grants a free user nothing --
    /// it is only the on-by-default state waiting for the day they subscribe, which
    /// is exactly what the registration used to express.
    nonisolated public static func seedFeatureTogglesIfNeeded() {
        let defaults = AppGroup.defaults
        let unseeded = ProFeature.allCases.filter {
            defaults.object(forKey: $0.settingsKey) == nil
        }
        guard !unseeded.isEmpty else { return }

        unseeded.forEach { defaults.set(true, forKey: $0.settingsKey) }
        // Same reason as setProActive below: the reader is another process.
        defaults.synchronize()
    }

    /// Called by SubscriptionManager after transaction updates (DictusApp only).
    ///
    /// Writes the **paid** half of the entitlement only (#593). A trial running under it
    /// is untouched, which is what keeps Pro on with no gap when someone subscribes
    /// during or after the trial: StoreKit sets this, and `isProActive` was already
    /// true or becomes true in the same refresh.
    ///
    /// WHY write to App Group AND update @Published:
    /// App Group write makes it visible to keyboard extension on next read.
    /// @Published update triggers immediate SwiftUI refresh in the main app.
    public func setProActive(_ active: Bool) {
        environment.defaults.set(active, forKey: SharedKeys.proActive)
        environment.defaults.synchronize()
        // Re-read rather than assign `active` (#460 review). The stored value is what
        // was just written; the *entitlement* is what `isProActiveStatic` answers, and
        // since #460 those two can differ under the debug override. Assigning `active`
        // here made `SubscriptionManager.updateProStatus()` — which runs at every
        // launch and calls `setProActive(false)` with no subscription — publish false
        // while `FeatureGate` and the keyboard both said true. One expression decides
        // entitlement or the two processes disagree, which is the whole of #401.
        refreshFromAppGroup()
    }

    /// Re-read entitlement from the shared state, without writing anything.
    ///
    /// The published property is a cache of `isProActiveStatic`, and a cache needs an
    /// invalidation. Anything that changes an *input* to that answer without going
    /// through `setProActive` calls this: today that is the debug override's switch
    /// in Settings (#460), which must not write `SharedKeys.proActive` — a forced
    /// entitlement that persisted into the real key would outlive the switch being
    /// turned off, and would be indistinguishable from a genuine subscription.
    ///
    /// Also what makes the trial end on screen: expiry is a clock passing an instant,
    /// which publishes nothing, so DictusApp calls this whenever it becomes active.
    public func refreshFromAppGroup() {
        let now = environment.now()
        isProActive = ProStatusManager.entitlement(
            in: environment.defaults, now: now, trialsEnabled: environment.paywallVisible
        )
        isPaid = ProStatusManager.isPaid(in: environment.defaults)
        trialState = ProTrialState(record: environment.store.mirroredRecord, now: now)
    }

    // MARK: - Reverse trial (#593)

    /// Bring the App Group mirror in line with the Keychain. DictusApp calls this once
    /// per launch, before anything asks whether a trial may start, so a reinstall finds
    /// its old trial rather than a fresh "never started".
    public func reconcileTrial() {
        environment.store.reconcile()
        refreshFromAppGroup()
    }

    /// Whether a trial would start if `startTrialIfEligible()` were called now.
    public var mayStartTrial: Bool {
        ProTrialPolicy.mayStart(
            paywallVisible: environment.paywallVisible,
            deviceIsCapable: deviceIsCapable,
            isPaid: isPaid,
            trial: trialState
        )
    }

    /// Start the reverse trial if this user may have one, and say whether it started.
    ///
    /// **The API onboarding calls** (#494): after the first successful dictation, once
    /// the disclosure is on screen. DictusApp also calls it when the user dismisses the
    /// trial announcement, which is how an existing user updated to the Pro version
    /// gets theirs, and how a new user gets it until #494's screens exist.
    ///
    /// Refuses, and changes nothing, when `ProTrialPolicy.mayStart` does: paywall
    /// hidden, a device that can never run Smart Modes (decision 2), a subscriber, or
    /// any trial already recorded on this device, reinstalls included.
    ///
    /// - Parameter start: when the trial counts from. The announcement passes the
    ///   instant it was shown, so the end date it printed is the end date stored, even
    ///   if the user leaves it open past midnight. Defaults to now.
    @discardableResult
    public func startTrialIfEligible(from start: Date? = nil) -> Bool {
        // Re-read first: a subscription or a trial may have landed since the last
        // refresh, from StoreKit or from another launch of the flow.
        refreshFromAppGroup()
        guard mayStartTrial else {
            PersistentLog.log(.diagnosticProbe(
                component: "proTrial", instanceID: "0", action: "startRefused",
                details: "paywallVisible=\(environment.paywallVisible) capable=\(deviceIsCapable) paid=\(isPaid) state=\(trialState.slug)"
            ))
            return false
        }
        let now = environment.now()
        let from = min(start ?? now, now)
        guard let record = environment.store.startIfNeverStarted(now: from) else {
            PersistentLog.log(.diagnosticProbe(
                component: "proTrial", instanceID: "0", action: "startFailed",
                details: "reason=keychain-or-existing-record"
            ))
            refreshFromAppGroup()
            return false
        }
        PersistentLog.log(.diagnosticProbe(
            component: "proTrial", instanceID: "0", action: "started",
            details: "days=\(ProTrial.durationDays) endsAt=\(Int(record.endsAt.timeIntervalSince1970))"
        ))
        refreshFromAppGroup()
        return true
    }

    /// The number on the `Pro · N days left` badge, or nil for no badge.
    public var trialBadgeDaysLeft: Int? {
        ProTrialPolicy.badgeDaysLeft(
            paywallVisible: environment.paywallVisible, isPaid: isPaid, trial: trialState, now: environment.now()
        )
    }

    /// What the home banner shows (#279, #593 decisions 2 and 3).
    public var promotionEntry: ProPromotionEntry {
        ProPromotion.entry(
            paywallVisible: environment.paywallVisible,
            deviceIsCapable: deviceIsCapable,
            isPaid: isPaid,
            isEntitled: isProActive,
            trial: trialState,
            now: environment.now()
        )
    }

    /// Whether the end-of-trial paywall should open now. Once, ever.
    public var endOfTrialPaywallDue: Bool {
        ProTrialPolicy.endOfTrialPaywallDue(
            paywallVisible: environment.paywallVisible,
            isPaid: isPaid,
            trial: trialState,
            alreadyShown: environment.defaults.bool(forKey: SharedKeys.proTrialEndPaywallShown)
        )
    }

    /// Record that the end-of-trial paywall was shown, so it never opens by itself again.
    public func markEndOfTrialPaywallShown() {
        environment.defaults.set(true, forKey: SharedKeys.proTrialEndPaywallShown)
    }

    /// The end-of-trial recap's numbers.
    public var trialUsage: ProTrialUsage.Snapshot {
        ProTrialUsage.snapshot(in: environment.defaults)
    }

    #if DEBUG
    /// DEBUG tooling: rewrite the trial so it ends `daysLeft` days from now (negative
    /// for already ended). What lets the maintainer see the badge, the J-2 reminder
    /// and the end-of-trial paywall on a device without waiting two weeks.
    public func debugSetTrial(endingInDays daysLeft: Double) {
        let now = environment.now()
        let ends = now.addingTimeInterval(daysLeft * ProTrial.secondsPerDay)
        environment.store.debugOverwrite(
            ProTrialRecord(startedAt: ends.addingTimeInterval(-ProTrial.duration), endsAt: ends)
        )
        refreshFromAppGroup()
    }

    /// DEBUG tooling: forget the trial, its counters and its paywall, as on a device
    /// that never had one.
    public func debugResetTrial() {
        environment.store.debugReset()
        ProTrialUsage.debugReset(in: environment.defaults)
        environment.defaults.removeObject(forKey: SharedKeys.proTrialEndPaywallShown)
        refreshFromAppGroup()
    }
    #endif

    /// Lightweight static read for keyboard extension (no StoreKit, no ObservableObject).
    ///
    /// WHY static: The keyboard extension doesn't need reactive updates --
    /// it reads Pro status once at viewDidLoad/viewWillAppear. A static method
    /// avoids instantiating an ObservableObject in the memory-constrained extension.
    ///
    /// **This is the one place entitlement is decided** (#460). `FeatureGate.isProActive`,
    /// the keyboard's toolbar and this class's own published property all come through
    /// here, which is what makes a single debug override possible instead of one force
    /// path per surface. Since #593 it answers "paid or trial running", and no call site
    /// had to change for it.
    nonisolated public static var isProActiveStatic: Bool {
        entitlement(in: AppGroup.defaults, now: Date(), trialsEnabled: PremiumFlags.paywallVisible)
    }

    /// The entitlement rule against explicit inputs: which store, which instant, and
    /// whether trials are enabled at all.
    ///
    /// `isProActiveStatic` is this with the App Group, the wall clock and the shipping
    /// flag. The tests call it directly, because the shipping flag is a compile-time
    /// `false` that would otherwise make the trial branch unreachable to them.
    nonisolated public static func entitlement(in defaults: UserDefaults,
                                               now: Date,
                                               trialsEnabled: Bool) -> Bool {
        #if DEBUG
        // Compiled out of Release entirely, along with the flag and its key. See
        // `PremiumFlags.debugProEntitlementForced` for why it has to exist at all: #460
        // hides the Smart Mode surface from everyone, the maintainer included, and the
        // feature is still being built.
        if PremiumFlags.debugProEntitlementForced { return true }
        #endif
        return ProEntitlement.isActive(
            isPaid: isPaid(in: defaults),
            trial: ProTrialState(record: ProTrialStore.mirroredRecord(in: defaults), now: now),
            trialsEnabled: trialsEnabled
        )
    }

    /// The StoreKit half alone. Written only by `setProActive`.
    nonisolated static func isPaid(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: SharedKeys.proActive)
    }

    /// Whether the keyboard's Pro surfaces carry their small `Pro` mark: a trial is
    /// running and nothing is paid (#593). The mark is how a user on trial learns which
    /// features they would lose; a subscriber loses nothing and gets no mark.
    nonisolated public static func showsTrialProMarks(now: Date) -> Bool {
        guard PremiumFlags.paywallVisible, !isPaid(in: AppGroup.defaults) else { return false }
        return ProTrialState(record: ProTrialStore.mirroredRecord(in: AppGroup.defaults), now: now).isRunning
    }

    /// What the keyboard panel's Pro pill shows. The keyboard's twin of
    /// `promotionEntry`, reading the App Group rather than a published cache.
    ///
    /// - Parameter deviceIsCapable: `SmartModeAvailability.deviceIsCapable`, passed in
    ///   because it asks `SystemLanguageModel` and the caller decides when that read
    ///   is affordable (once per panel open).
    nonisolated public static func promotionEntryStatic(now: Date, deviceIsCapable: Bool) -> ProPromotionEntry {
        let defaults = AppGroup.defaults
        return ProPromotion.entry(
            paywallVisible: PremiumFlags.paywallVisible,
            deviceIsCapable: deviceIsCapable,
            isPaid: isPaid(in: defaults),
            isEntitled: isProActiveStatic,
            trial: ProTrialState(record: ProTrialStore.mirroredRecord(in: defaults), now: now),
            now: now
        )
    }
}

extension ProTrialState {
    /// Stable name for logs.
    var slug: String {
        switch self {
        case .neverStarted: return "neverStarted"
        case .running: return "running"
        case .expired: return "expired"
        }
    }
}
