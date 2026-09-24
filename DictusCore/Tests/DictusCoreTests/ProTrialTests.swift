// DictusCore/Tests/DictusCoreTests/ProTrialTests.swift
// The reverse trial (#593): the entitlement rule, who gets a trial, the Keychain-backed
// record, and the counters behind the end-of-trial recap. Every clock here is injected.
//
// Nothing in this file touches the real Keychain or the real App Group: each test gets
// its own `UserDefaults` suite and an in-memory keychain, so the suite can run on the
// Mac without the hang #560 had to fix, and a failure cannot leave a trial behind on
// the developer's machine.
import XCTest
@testable import DictusCore

/// A keychain that lives as long as the test that made it. Surviving a "reinstall" is
/// modelled by handing the same instance to a store built on a fresh defaults suite.
private final class InMemoryKeychain: ProTrialKeychain {
    var record: ProTrialRecord?
    var refusesWrites = false

    func read() -> ProTrialRecord? { record }

    func write(_ record: ProTrialRecord) -> Bool {
        guard !refusesWrites else { return false }
        self.record = record
        return true
    }

    func delete() { record = nil }
}

/// A clock the test moves by hand.
private final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(days: Double) { now = now.addingTimeInterval(days * 86_400) }
}

final class ProTrialTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    private var suiteNames: [String] = []

    private func makeDefaults() -> UserDefaults {
        let name = "dictus.tests.proTrial.\(UUID().uuidString)"
        suiteNames.append(name)
        // swiftlint:disable:next force_unwrapping
        return UserDefaults(suiteName: name)!  // A fresh, non-App-Group suite name is always valid.
    }

    override func tearDown() {
        suiteNames.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        suiteNames = []
        super.tearDown()
    }

    // MARK: - State

    func testAStateResolvesAgainstTheClock() {
        let record = ProTrialRecord.starting(at: t0)
        XCTAssertEqual(record.endsAt.timeIntervalSince(t0), 14 * 86_400)
        XCTAssertEqual(ProTrialState(record: nil, now: t0), .neverStarted)
        XCTAssertEqual(ProTrialState(record: record, now: t0), .running(endsAt: record.endsAt))
        XCTAssertEqual(
            ProTrialState(record: record, now: record.endsAt.addingTimeInterval(-1)),
            .running(endsAt: record.endsAt)
        )
        // At the end instant the user has had every second they were promised.
        XCTAssertEqual(ProTrialState(record: record, now: record.endsAt), .expired(endedAt: record.endsAt))
    }

    func testDaysLeftRoundUpAndTheReminderOpensTwoDaysOut() {
        let state = ProTrialState(record: .starting(at: t0), now: t0)
        XCTAssertEqual(state.daysLeft(now: t0), 14, "a trial that just started reads the fourteen it was announced with")
        XCTAssertFalse(state.isInReminderWindow(now: t0))

        let endsAt = t0.addingTimeInterval(14 * 86_400)
        XCTAssertEqual(state.daysLeft(now: endsAt.addingTimeInterval(-2.5 * 86_400)), 3)
        XCTAssertFalse(state.isInReminderWindow(now: endsAt.addingTimeInterval(-2.5 * 86_400)))
        XCTAssertEqual(state.daysLeft(now: endsAt.addingTimeInterval(-1.5 * 86_400)), 2)
        XCTAssertTrue(state.isInReminderWindow(now: endsAt.addingTimeInterval(-1.5 * 86_400)))
        XCTAssertEqual(state.daysLeft(now: endsAt.addingTimeInterval(-60)), 1, "never 0 days while Pro is still on")

        XCTAssertNil(ProTrialState.neverStarted.daysLeft(now: t0))
        XCTAssertNil(ProTrialState.expired(endedAt: t0).daysLeft(now: t0))
    }

    // MARK: - Entitlement rule

    /// The five cases the issue names, against the pure rule.
    func testEntitlementIsPaidOrTrialRunning() {
        let running = ProTrialState.running(endsAt: t0)
        let expired = ProTrialState.expired(endedAt: t0)

        XCTAssertTrue(ProEntitlement.isActive(isPaid: true, trial: .neverStarted, trialsEnabled: true), "paid")
        XCTAssertTrue(ProEntitlement.isActive(isPaid: false, trial: running, trialsEnabled: true), "trial running")
        XCTAssertFalse(ProEntitlement.isActive(isPaid: false, trial: expired, trialsEnabled: true), "trial expired")
        XCTAssertFalse(ProEntitlement.isActive(isPaid: false, trial: .neverStarted, trialsEnabled: true), "never started")
        XCTAssertTrue(ProEntitlement.isActive(isPaid: true, trial: expired, trialsEnabled: true),
                      "subscribing after the trial keeps Pro on")
    }

    /// #279: with the paywall hidden a trial record grants nothing, even one a build
    /// with the flag up left behind. A purchase still does: it is not a promotion.
    func testWithTrialsDisabledOnlyAPurchaseCounts() {
        XCTAssertFalse(ProEntitlement.isActive(isPaid: false, trial: .running(endsAt: t0), trialsEnabled: false))
        XCTAssertTrue(ProEntitlement.isActive(isPaid: true, trial: .neverStarted, trialsEnabled: false))
    }

    /// The same five cases through `ProStatusManager.entitlement(in:now:trialsEnabled:)`,
    /// the function `isProActiveStatic` (and so `FeatureGate` and the keyboard) runs:
    /// real App-Group-shaped storage, injected clock.
    func testTheStaticEntitlementReadsTheMirrorAgainstTheClock() {
        let defaults = makeDefaults()
        let store = ProTrialStore(keychain: InMemoryKeychain(), defaults: defaults)

        XCTAssertFalse(ProStatusManager.entitlement(in: defaults, now: t0, trialsEnabled: true), "never started")

        XCTAssertNotNil(store.startIfNeverStarted(now: t0))
        XCTAssertTrue(ProStatusManager.entitlement(in: defaults, now: t0, trialsEnabled: true), "trial running")
        XCTAssertTrue(ProStatusManager.entitlement(
            in: defaults, now: t0.addingTimeInterval(14 * 86_400 - 1), trialsEnabled: true
        ), "last second of the trial")

        let afterEnd = t0.addingTimeInterval(14 * 86_400)
        XCTAssertFalse(ProStatusManager.entitlement(in: defaults, now: afterEnd, trialsEnabled: true), "trial expired")

        defaults.set(true, forKey: SharedKeys.proActive)
        XCTAssertTrue(ProStatusManager.entitlement(in: defaults, now: afterEnd, trialsEnabled: true), "paid")

        defaults.set(false, forKey: SharedKeys.proActive)
        XCTAssertFalse(ProStatusManager.entitlement(in: defaults, now: t0, trialsEnabled: false),
                       "paywall hidden: the running trial grants nothing")
    }

    // MARK: - Who gets a trial (decision 2)

    func testATrialStartsOnlyOnACapableDeviceForSomeoneWhoNeverHadOne() {
        func mayStart(visible: Bool = true, capable: Bool = true, paid: Bool = false,
                      trial: ProTrialState = .neverStarted) -> Bool {
            ProTrialPolicy.mayStart(paywallVisible: visible, deviceIsCapable: capable, isPaid: paid, trial: trial)
        }
        XCTAssertTrue(mayStart())
        XCTAssertFalse(mayStart(capable: false), "deviceNotEligible / osTooOld: no trial, ever")
        XCTAssertFalse(mayStart(visible: false), "paywall hidden: nothing starts (#279)")
        XCTAssertFalse(mayStart(paid: true), "a subscriber has nothing to try")
        XCTAssertFalse(mayStart(trial: .running(endsAt: t0)), "no second trial")
        XCTAssertFalse(mayStart(trial: .expired(endedAt: t0)), "no second trial")
    }

    /// The capability input is `isRecoverable` read as a capability question: the
    /// definitive reasons refuse, Apple Intelligence switched off does not.
    func testCapabilityIsTheDefinitiveReasonsOnly() {
        XCTAssertFalse(SmartModeUnavailableReason.deviceNotEligible.isRecoverable)
        XCTAssertFalse(SmartModeUnavailableReason.osTooOld.isRecoverable)
        XCTAssertTrue(SmartModeUnavailableReason.appleIntelligenceNotEnabled.isRecoverable,
                      "a capable iPhone with Apple Intelligence off gets the trial")
    }

    func testTheAnnouncementWaitsForOnboarding() {
        XCTAssertFalse(ProTrialPolicy.announcementDue(
            onboardingCompleted: false, paywallVisible: true, deviceIsCapable: true, isPaid: false, trial: .neverStarted
        ))
        XCTAssertTrue(ProTrialPolicy.announcementDue(
            onboardingCompleted: true, paywallVisible: true, deviceIsCapable: true, isPaid: false, trial: .neverStarted
        ))
        XCTAssertFalse(ProTrialPolicy.announcementDue(
            onboardingCompleted: true, paywallVisible: true, deviceIsCapable: false, isPaid: false, trial: .neverStarted
        ))
    }

    func testTheEndOfTrialPaywallIsDueOnceAfterExpiryForNonSubscribers() {
        let expired = ProTrialState.expired(endedAt: t0)
        XCTAssertTrue(ProTrialPolicy.endOfTrialPaywallDue(
            paywallVisible: true, isPaid: false, trial: expired, alreadyShown: false))
        XCTAssertFalse(ProTrialPolicy.endOfTrialPaywallDue(
            paywallVisible: true, isPaid: false, trial: expired, alreadyShown: true), "once")
        XCTAssertFalse(ProTrialPolicy.endOfTrialPaywallDue(
            paywallVisible: true, isPaid: true, trial: expired, alreadyShown: false), "subscribed")
        XCTAssertFalse(ProTrialPolicy.endOfTrialPaywallDue(
            paywallVisible: true, isPaid: false, trial: .running(endsAt: t0), alreadyShown: false))
        XCTAssertFalse(ProTrialPolicy.endOfTrialPaywallDue(
            paywallVisible: true, isPaid: false, trial: .neverStarted, alreadyShown: false),
                       "an ineligible device never had a trial to end")
        XCTAssertFalse(ProTrialPolicy.endOfTrialPaywallDue(
            paywallVisible: false, isPaid: false, trial: expired, alreadyShown: false))
    }

    func testTheBadgeIsForAnUnpaidRunningTrialOnly() {
        let running = ProTrialState(record: .starting(at: t0), now: t0)
        XCTAssertEqual(ProTrialPolicy.badgeDaysLeft(paywallVisible: true, isPaid: false, trial: running, now: t0), 14)
        XCTAssertNil(ProTrialPolicy.badgeDaysLeft(paywallVisible: true, isPaid: true, trial: running, now: t0))
        XCTAssertNil(ProTrialPolicy.badgeDaysLeft(paywallVisible: false, isPaid: false, trial: running, now: t0))
        XCTAssertNil(ProTrialPolicy.badgeDaysLeft(
            paywallVisible: true, isPaid: false, trial: .expired(endedAt: t0), now: t0))
    }

    // MARK: - Promotion (decisions 2 and 3)

    func testPromotionEntryPoints() {
        let endsAt = t0.addingTimeInterval(14 * 86_400)
        let running = ProTrialState.running(endsAt: endsAt)
        func entry(visible: Bool = true, capable: Bool = true, paid: Bool = false, entitled: Bool = false,
                   trial: ProTrialState = .neverStarted, now: Date? = nil) -> ProPromotionEntry {
            ProPromotion.entry(paywallVisible: visible, deviceIsCapable: capable, isPaid: paid,
                               isEntitled: entitled, trial: trial, now: now ?? t0)
        }
        XCTAssertEqual(entry(), .upgrade)
        XCTAssertEqual(entry(visible: false), .hidden, "#236")
        XCTAssertEqual(entry(capable: false), .hidden, "decision 2: no promotion on a device that can never run Smart Modes")
        XCTAssertEqual(entry(paid: true, entitled: true), .hidden)
        XCTAssertEqual(entry(entitled: true, trial: running), .hidden, "no nag during the trial")
        XCTAssertEqual(entry(entitled: true, trial: running, now: endsAt.addingTimeInterval(-1.5 * 86_400)),
                       .trialEnding(daysLeft: 2), "decision 3")
        XCTAssertEqual(entry(paid: true, entitled: true, trial: running, now: endsAt.addingTimeInterval(-60)),
                       .hidden, "subscribed during the trial: nothing to remind")
        XCTAssertEqual(entry(trial: .expired(endedAt: endsAt), now: endsAt), .upgrade)
    }

    // MARK: - Store: Keychain truth, App Group mirror

    func testAStartWritesBothAndASecondStartIsRefused() {
        let keychain = InMemoryKeychain()
        let defaults = makeDefaults()
        let store = ProTrialStore(keychain: keychain, defaults: defaults)

        let record = store.startIfNeverStarted(now: t0)
        XCTAssertEqual(record, .starting(at: t0))
        XCTAssertEqual(keychain.record, record)
        XCTAssertEqual(store.mirroredRecord, record)

        XCTAssertNil(store.startIfNeverStarted(now: t0.addingTimeInterval(30 * 86_400)), "no second trial")
        XCTAssertEqual(keychain.record, record, "the first trial is untouched")
    }

    /// Acceptance: deleting and reinstalling the app does not start a new trial. The
    /// App Group goes with the app; the Keychain item does not.
    func testAReinstallFindsTheOldTrialInTheKeychain() {
        let keychain = InMemoryKeychain()
        let first = ProTrialStore(keychain: keychain, defaults: makeDefaults())
        let original = first.startIfNeverStarted(now: t0)

        let reinstalled = ProTrialStore(keychain: keychain, defaults: makeDefaults())
        XCTAssertNil(reinstalled.mirroredRecord, "a fresh install's App Group is empty")
        XCTAssertEqual(reinstalled.reconcile(), original)
        XCTAssertEqual(reinstalled.mirroredRecord, original, "the launch reconcile restores the mirror")
        XCTAssertNil(reinstalled.startIfNeverStarted(now: t0.addingTimeInterval(20 * 86_400)))
    }

    /// Even without the launch reconcile, a start consults the Keychain first.
    func testAStartConsultsTheKeychainEvenWithAnEmptyMirror() {
        let keychain = InMemoryKeychain()
        keychain.record = .starting(at: t0)
        let store = ProTrialStore(keychain: keychain, defaults: makeDefaults())
        XCTAssertNil(store.startIfNeverStarted(now: t0.addingTimeInterval(20 * 86_400)))
        XCTAssertEqual(store.mirroredRecord, .starting(at: t0))
    }

    func testAMirrorOnlyRecordIsAdoptedNotForgotten() {
        let keychain = InMemoryKeychain()
        keychain.refusesWrites = true
        let defaults = makeDefaults()
        let store = ProTrialStore(keychain: keychain, defaults: defaults)
        // Written by hand: the only way to reach this state is a Keychain write that
        // failed after the mirror existed.
        defaults.set(t0.timeIntervalSince1970, forKey: SharedKeys.proTrialStartedAt)
        defaults.set(t0.addingTimeInterval(14 * 86_400).timeIntervalSince1970, forKey: SharedKeys.proTrialEndsAt)

        keychain.refusesWrites = false
        XCTAssertEqual(store.reconcile(), .starting(at: t0))
        XCTAssertEqual(keychain.record, .starting(at: t0))
    }

    /// Fails closed: a trial only the App Group knew about is one a reinstall would
    /// hand out again.
    func testAKeychainThatRefusesTheWriteStartsNothing() {
        let keychain = InMemoryKeychain()
        keychain.refusesWrites = true
        let store = ProTrialStore(keychain: keychain, defaults: makeDefaults())
        XCTAssertNil(store.startIfNeverStarted(now: t0))
        XCTAssertNil(store.mirroredRecord)
    }

    // MARK: - ProStatusManager, end to end with an injected clock

    @MainActor
    private func makeManager(capable: Bool = true,
                             visible: Bool = true,
                             clock: TestClock,
                             keychain: InMemoryKeychain = InMemoryKeychain(),
                             defaults: UserDefaults? = nil) -> (ProStatusManager, UserDefaults) {
        let defaults = defaults ?? makeDefaults()
        let environment = ProTrialEnvironment(
            now: { clock.now },
            deviceIsCapable: { capable },
            paywallVisible: visible,
            defaults: defaults,
            store: ProTrialStore(keychain: keychain, defaults: defaults)
        )
        return (ProStatusManager(environment: environment), defaults)
    }

    @MainActor
    func testATrialRunsThenSwitchesOffOnTheClock() {
        let clock = TestClock(t0)
        let (manager, _) = makeManager(clock: clock)
        XCTAssertFalse(manager.isProActive)
        XCTAssertEqual(manager.trialState, .neverStarted)

        XCTAssertTrue(manager.startTrialIfEligible())
        XCTAssertTrue(manager.isProActive)
        XCTAssertFalse(manager.isPaid)
        XCTAssertEqual(manager.trialBadgeDaysLeft, 14)
        XCTAssertFalse(manager.endOfTrialPaywallDue)

        clock.advance(days: 13)
        manager.refreshFromAppGroup()
        XCTAssertTrue(manager.isProActive)
        XCTAssertEqual(manager.promotionEntry, .trialEnding(daysLeft: 1))

        clock.advance(days: 1)
        manager.refreshFromAppGroup()
        XCTAssertFalse(manager.isProActive, "moving the clock past the end switches Pro off")
        XCTAssertTrue(manager.trialState.isExpired)
        XCTAssertTrue(manager.endOfTrialPaywallDue)
        manager.markEndOfTrialPaywallShown()
        XCTAssertFalse(manager.endOfTrialPaywallDue, "shown once")

        XCTAssertFalse(manager.startTrialIfEligible(), "no second trial")
    }

    @MainActor
    func testSubscribingDuringOrAfterTheTrialKeepsProOnWithNoGap() {
        let clock = TestClock(t0)
        let (manager, _) = makeManager(clock: clock)
        manager.startTrialIfEligible()

        clock.advance(days: 5)
        manager.setProActive(true)
        XCTAssertTrue(manager.isProActive)
        XCTAssertTrue(manager.isPaid)
        XCTAssertNil(manager.trialBadgeDaysLeft, "a subscriber's Pro does not run out")

        clock.advance(days: 30)
        manager.refreshFromAppGroup()
        XCTAssertTrue(manager.isProActive, "the trial's end does not touch a subscription")
        XCTAssertFalse(manager.endOfTrialPaywallDue)
    }

    @MainActor
    func testAnIneligibleDeviceNeverStartsATrialAndIsNeverPromotedTo() {
        let clock = TestClock(t0)
        let keychain = InMemoryKeychain()
        let (manager, _) = makeManager(capable: false, clock: clock, keychain: keychain)
        XCTAssertFalse(manager.mayStartTrial)
        XCTAssertFalse(manager.startTrialIfEligible())
        XCTAssertNil(keychain.record)
        XCTAssertFalse(manager.isProActive)
        XCTAssertEqual(manager.promotionEntry, .hidden)
        XCTAssertFalse(manager.endOfTrialPaywallDue)
        // Still purchasable: a purchase is honoured like anywhere else.
        manager.setProActive(true)
        XCTAssertTrue(manager.isProActive)
    }

    @MainActor
    func testWithThePaywallHiddenNothingStartsAndNothingShows() {
        let clock = TestClock(t0)
        let (manager, _) = makeManager(visible: false, clock: clock)
        XCTAssertFalse(manager.startTrialIfEligible())
        XCTAssertFalse(manager.isProActive)
        XCTAssertNil(manager.trialBadgeDaysLeft)
        XCTAssertEqual(manager.promotionEntry, .hidden)
    }

    @MainActor
    func testTheAnnouncedStartIsTheStoredStart() {
        let clock = TestClock(t0)
        let (manager, _) = makeManager(clock: clock)
        let shownAt = t0
        clock.advance(days: 0.5)
        XCTAssertTrue(manager.startTrialIfEligible(from: shownAt))
        XCTAssertEqual(manager.trialState, .running(endsAt: ProTrialRecord.starting(at: shownAt).endsAt))
    }

    @MainActor
    func testAReinstalledManagerRestoresTheTrialInsteadOfOfferingOne() {
        let clock = TestClock(t0)
        let keychain = InMemoryKeychain()
        let (first, _) = makeManager(clock: clock, keychain: keychain)
        first.startTrialIfEligible()

        clock.advance(days: 3)
        let (reinstalled, _) = makeManager(clock: clock, keychain: keychain)
        XCTAssertEqual(reinstalled.trialState, .neverStarted, "before the launch reconcile, the App Group is empty")
        reinstalled.reconcileTrial()
        XCTAssertTrue(reinstalled.trialState.isRunning)
        XCTAssertEqual(reinstalled.trialBadgeDaysLeft, 11)
        XCTAssertFalse(reinstalled.mayStartTrial)
    }

    // MARK: - Recap counters (decision 5)

    func testTheCountersOnlyCountWhileAnUnpaidTrialRuns() {
        let defaults = makeDefaults()
        let store = ProTrialStore(keychain: InMemoryKeychain(), defaults: defaults)
        func count(_ n: Int = 1, at date: Date, enabled: Bool = true) {
            ProTrialUsage.increment(SharedKeys.proTrialSmartModeUses, by: n, in: defaults, now: date,
                                    trialsEnabled: enabled)
            ProTrialUsage.increment(SharedKeys.proTrialVocabularyFixes, by: n * 2, in: defaults, now: date,
                                    trialsEnabled: enabled)
        }

        count(at: t0)
        XCTAssertTrue(ProTrialUsage.snapshot(in: defaults).isEmpty, "before the trial")

        store.startIfNeverStarted(now: t0)
        count(at: t0.addingTimeInterval(60))
        count(at: t0.addingTimeInterval(86_400))
        count(at: t0.addingTimeInterval(86_400), enabled: false)
        count(0, at: t0.addingTimeInterval(86_400))
        XCTAssertEqual(ProTrialUsage.snapshot(in: defaults), .init(smartModeUses: 2, vocabularyFixes: 4))

        count(at: t0.addingTimeInterval(15 * 86_400))
        XCTAssertEqual(ProTrialUsage.snapshot(in: defaults), .init(smartModeUses: 2, vocabularyFixes: 4),
                       "after the trial")

        defaults.set(true, forKey: SharedKeys.proActive)
        count(at: t0.addingTimeInterval(86_400))
        XCTAssertEqual(ProTrialUsage.snapshot(in: defaults), .init(smartModeUses: 2, vocabularyFixes: 4),
                       "a subscriber is not on trial")
    }
}
