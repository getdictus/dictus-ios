// DictusCore/Tests/DictusCoreTests/ProHubTests.swift
// The Dictus Pro hub's state rule (#216): which block sits under the feature cards.
import XCTest
@testable import DictusCore

final class ProHubTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var inThreeDays: Date { now.addingTimeInterval(3 * ProTrial.secondsPerDay) }

    private func block(paywallVisible: Bool = true,
                       isPaid: Bool = false,
                       isEntitled: Bool = false,
                       trial: ProTrialState = .neverStarted,
                       ownership: ProOwnership? = nil) -> ProHubBottomBlock {
        ProHub.bottomBlock(paywallVisible: paywallVisible, isPaid: isPaid, isEntitled: isEntitled,
                           trial: trial, now: now, ownership: ownership)
    }

    private func subscription(_ id: String, renews: Bool? = true) -> ProActiveSubscription {
        ProActiveSubscription(productID: id, periodEnd: inThreeDays, willAutoRenew: renews)
    }

    // MARK: - Free

    func testFreeUserGetsTodaysPaywall() {
        let result = block()
        XCTAssertEqual(result, .offers(trialEndsAt: nil, daysLeft: nil))
        XCTAssertFalse(result.cardsAreActive, "a free user's cards stay informational")
        XCTAssertTrue(result.sellsPlans)
    }

    func testExpiredTrialIsFree() {
        let result = block(trial: .expired(endedAt: now.addingTimeInterval(-60)))
        XCTAssertEqual(result, .offers(trialEndsAt: nil, daysLeft: nil))
        XCTAssertFalse(result.cardsAreActive)
    }

    // MARK: - Trial

    func testRunningTrialActivatesCardsAndStillSells() {
        let result = block(isEntitled: true, trial: .running(endsAt: inThreeDays))
        XCTAssertEqual(result, .offers(trialEndsAt: inThreeDays, daysLeft: 3))
        XCTAssertTrue(result.cardsAreActive)
        XCTAssertTrue(result.sellsPlans, "subscribing during the trial is what the trial is for")
    }

    func testTrialIsIgnoredWithThePaywallHidden() {
        // A record left by a development build with the flag up grants nothing (#279).
        let result = block(paywallVisible: false, trial: .running(endsAt: inThreeDays))
        XCTAssertEqual(result, .offers(trialEndsAt: nil, daysLeft: nil))
    }

    // MARK: - Paid

    func testMonthlyAndYearlySubscribersSeeTheirPlan() {
        for id in [ProProductID.monthly, ProProductID.yearly] {
            let sub = subscription(id)
            let result = block(isPaid: true, isEntitled: true,
                               ownership: ProOwnership(ownsLifetime: false, subscription: sub))
            XCTAssertEqual(result, .subscription(sub))
            XCTAssertTrue(result.cardsAreActive)
            XCTAssertFalse(result.sellsPlans)
        }
        XCTAssertEqual(subscription(ProProductID.monthly).period, .monthly)
        XCTAssertEqual(subscription(ProProductID.yearly).period, .yearly)
        XCTAssertEqual(subscription("some.future.plan").period, .unlabelled)
    }

    func testSubscriptionTakenDuringTheTrialWins() {
        let sub = subscription(ProProductID.yearly)
        let result = block(isPaid: true, isEntitled: true, trial: .running(endsAt: inThreeDays),
                           ownership: ProOwnership(ownsLifetime: false, subscription: sub))
        XCTAssertEqual(result, .subscription(sub))
    }

    func testLifetimeOwnerGetsNoManageButton() {
        let result = block(isPaid: true, isEntitled: true,
                           ownership: ProOwnership(ownsLifetime: true, subscription: nil))
        XCTAssertEqual(result, .lifetime(alsoSubscribed: nil))
        XCTAssertTrue(result.cardsAreActive)
        XCTAssertFalse(result.sellsPlans)
    }

    func testLifetimeOwnerStillPayingASubscriptionCanManageIt() {
        let sub = subscription(ProProductID.monthly, renews: true)
        let result = block(isPaid: true, isEntitled: true,
                           ownership: ProOwnership(ownsLifetime: true, subscription: sub))
        XCTAssertEqual(result, .lifetime(alsoSubscribed: sub))
    }

    func testLifetimeOwnerWithACancelledSubscriptionHasNothingToManage() {
        let sub = subscription(ProProductID.monthly, renews: false)
        let result = block(isPaid: true, isEntitled: true,
                           ownership: ProOwnership(ownsLifetime: true, subscription: sub))
        XCTAssertEqual(result, .lifetime(alsoSubscribed: nil))
    }

    func testPaidBeforeTheScanLandsWaits() {
        XCTAssertEqual(block(isPaid: true, isEntitled: true, ownership: nil), .paidPlanPending)
    }

    func testPaidWithNothingRecognisedStillOffersManage() {
        XCTAssertEqual(block(isPaid: true, isEntitled: true, ownership: ProOwnership.none), .paidPlanUnknown)
    }

    // MARK: - DEBUG force

    func testEntitledWithoutPurchaseSellsNothing() {
        // The DEBUG forced entitlement, paywall hidden (#460, #577).
        let result = block(paywallVisible: false, isEntitled: true)
        XCTAssertEqual(result, .entitledWithoutPurchase)
        XCTAssertTrue(result.cardsAreActive, "the forced entitlement must reach the feature screens")
        XCTAssertFalse(result.sellsPlans)
    }
}

final class ProOwnershipRecheckTests: XCTestCase {

    func testTheRecheckIsBoundedToAboutTenSeconds() {
        let total = ProOwnershipRecheck.delays.reduce(0, +)
        XCTAssertGreaterThanOrEqual(total, 8, "too short to catch a cancellation StoreKit delivers late")
        XCTAssertLessThanOrEqual(total, 12, "a recheck, not a polling loop")
        XCTAssertTrue(ProOwnershipRecheck.delays.allSatisfy { $0 > 0 })
    }

    func testItStopsAtTheFirstChange() {
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        let renewing = ProOwnership(ownsLifetime: false, subscription:
            ProActiveSubscription(productID: ProProductID.monthly, periodEnd: end, willAutoRenew: true))
        let cancelled = ProOwnership(ownsLifetime: false, subscription:
            ProActiveSubscription(productID: ProProductID.monthly, periodEnd: end, willAutoRenew: false))

        XCTAssertFalse(ProOwnershipRecheck.isSettled(before: renewing, after: renewing))
        XCTAssertTrue(ProOwnershipRecheck.isSettled(before: renewing, after: cancelled))
        XCTAssertTrue(ProOwnershipRecheck.isSettled(before: renewing, after: ProOwnership.none))
    }
}

final class ProLifetimeUpgradeTests: XCTestCase {

    private let end = Date(timeIntervalSince1970: 1_800_000_000)

    private func subscriber(_ id: String, renews: Bool?) -> ProHubBottomBlock {
        .subscription(ProActiveSubscription(productID: id, periodEnd: end, willAutoRenew: renews))
    }

    func testAMonthlyOrYearlySubscriberGetsTheRow() {
        for id in [ProProductID.monthly, ProProductID.yearly] {
            XCTAssertNotNil(ProLifetimeUpgrade.offer(for: subscriber(id, renews: true), paywallVisible: true))
        }
    }

    /// Decision 15 as amended on 2026-10-05: never sold over a renewing subscription.
    func testPurchasableOnlyOnceTheSubscriptionNoLongerRenews() {
        XCTAssertEqual(ProLifetimeUpgrade.offer(for: subscriber(ProProductID.monthly, renews: true), paywallVisible: true),
                       ProLifetimeUpgrade(isPurchasable: false))
        XCTAssertEqual(ProLifetimeUpgrade.offer(for: subscriber(ProProductID.yearly, renews: false), paywallVisible: true),
                       ProLifetimeUpgrade(isPurchasable: true))
        XCTAssertEqual(ProLifetimeUpgrade.offer(for: subscriber(ProProductID.monthly, renews: nil), paywallVisible: true),
                       ProLifetimeUpgrade(isPurchasable: false),
                       "an unreadable renewal status counts as renewing")
    }

    /// The live transition: cancelling in Apple's sheet moves the block from renewing
    /// to cancelled, and the same row turns purchasable with no other input.
    func testCancellingTurnsTheRowPurchasable() {
        let renewing = subscriber(ProProductID.monthly, renews: true)
        let cancelled = subscriber(ProProductID.monthly, renews: false)
        XCTAssertEqual(ProLifetimeUpgrade.offer(for: renewing, paywallVisible: true)?.isPurchasable, false)
        XCTAssertEqual(ProLifetimeUpgrade.offer(for: cancelled, paywallVisible: true)?.isPurchasable, true)
    }

    /// Buying from the purchasable row lands on plain lifetime: the subscription it
    /// leaves behind no longer renews, so the hub offers nothing to manage.
    func testBuyingFromTheRowLandsOnPlainLifetime() {
        let afterPurchase = ProHub.bottomBlock(
            paywallVisible: true, isPaid: true, isEntitled: true, trial: .neverStarted, now: end,
            ownership: ProOwnership(ownsLifetime: true, subscription:
                ProActiveSubscription(productID: ProProductID.monthly, periodEnd: end, willAutoRenew: false))
        )
        XCTAssertEqual(afterPurchase, .lifetime(alsoSubscribed: nil))
    }

    func testNoRowForAnyoneElse() {
        let others: [ProHubBottomBlock] = [
            .offers(trialEndsAt: nil, daysLeft: nil),
            .offers(trialEndsAt: end, daysLeft: 3),
            .lifetime(alsoSubscribed: nil),
            .lifetime(alsoSubscribed: ProActiveSubscription(productID: ProProductID.monthly, periodEnd: end, willAutoRenew: true)),
            .paidPlanPending,
            .paidPlanUnknown,
            .entitledWithoutPurchase
        ]
        for block in others {
            XCTAssertNil(ProLifetimeUpgrade.offer(for: block, paywallVisible: true), "\(block)")
        }
    }

    func testNothingIsSoldWithThePaywallHidden() {
        XCTAssertNil(ProLifetimeUpgrade.offer(for: subscriber(ProProductID.yearly, renews: true), paywallVisible: false))
    }
}
