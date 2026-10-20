// DictusCore/Tests/DictusCoreTests/ProPaywallPlansTests.swift
// The paywall's plan list and its end-of-trial monthly offer (#724).
import XCTest
@testable import DictusCore

final class ProPaywallPlansTests: XCTestCase {

    private let all: Set<String> = ProProductID.all

    // MARK: - Visible plans

    func testYearlyAndLifetimeAreVisibleAndMonthlyIsBehindTheLink() {
        let yearly = ProProductID.yearly
        XCTAssertTrue(ProPaywallPlans.isVisible(ProProductID.yearly, showsAllPlans: false, selectedID: yearly))
        XCTAssertTrue(ProPaywallPlans.isVisible(ProProductID.lifetime, showsAllPlans: false, selectedID: yearly))
        XCTAssertFalse(ProPaywallPlans.isVisible(ProProductID.monthly, showsAllPlans: false, selectedID: yearly))
        XCTAssertTrue(ProPaywallPlans.showsSeeAllPlansLink(loaded: all, showsAllPlans: false, selectedID: yearly))
    }

    func testTheLinkRevealsMonthlyAndThenGoesAway() {
        let yearly = ProProductID.yearly
        XCTAssertTrue(ProPaywallPlans.isVisible(ProProductID.monthly, showsAllPlans: true, selectedID: yearly))
        XCTAssertFalse(ProPaywallPlans.showsSeeAllPlansLink(loaded: all, showsAllPlans: true, selectedID: yearly))
    }

    func testASelectedMonthlyIsAlwaysVisible() {
        // The yearly failed to load and the selection fell onto the monthly: its row
        // must be the checked one the CTA charges, not a hidden one.
        XCTAssertTrue(ProPaywallPlans.isVisible(
            ProProductID.monthly, showsAllPlans: false, selectedID: ProProductID.monthly))
        XCTAssertFalse(ProPaywallPlans.showsSeeAllPlansLink(
            loaded: [ProProductID.monthly, ProProductID.lifetime], showsAllPlans: false,
            selectedID: ProProductID.monthly))
    }

    func testNoLinkWhenMonthlyDidNotLoad() {
        XCTAssertFalse(ProPaywallPlans.showsSeeAllPlansLink(
            loaded: [ProProductID.yearly, ProProductID.lifetime], showsAllPlans: false,
            selectedID: ProProductID.yearly))
    }

    // MARK: - Monthly offer on close

    func testClosingTheEndOfTrialPaywallOffersMonthlyOnce() {
        XCTAssertTrue(ProPaywallPlans.offersMonthlyOnClose(
            isEndOfTrialPaywall: true, sawPlans: true, isPaid: false, monthlyLoaded: true, alreadyOffered: false))
        XCTAssertFalse(ProPaywallPlans.offersMonthlyOnClose(
            isEndOfTrialPaywall: true, sawPlans: true, isPaid: false, monthlyLoaded: true, alreadyOffered: true), "once")
    }

    func testNoOfferWhenLeavingFromTheRecap() {
        XCTAssertFalse(ProPaywallPlans.offersMonthlyOnClose(
            isEndOfTrialPaywall: true, sawPlans: false, isPaid: false, monthlyLoaded: true, alreadyOffered: false))
    }

    func testNoOfferFromAnyOtherEntryPoint() {
        XCTAssertFalse(ProPaywallPlans.offersMonthlyOnClose(
            isEndOfTrialPaywall: false, sawPlans: true, isPaid: false, monthlyLoaded: true, alreadyOffered: false))
    }

    func testNoOfferToABuyerOrWithoutAMonthlyPrice() {
        XCTAssertFalse(ProPaywallPlans.offersMonthlyOnClose(
            isEndOfTrialPaywall: true, sawPlans: true, isPaid: true, monthlyLoaded: true, alreadyOffered: false), "bought")
        XCTAssertFalse(ProPaywallPlans.offersMonthlyOnClose(
            isEndOfTrialPaywall: true, sawPlans: true, isPaid: false, monthlyLoaded: false, alreadyOffered: false), "no price")
    }
}
