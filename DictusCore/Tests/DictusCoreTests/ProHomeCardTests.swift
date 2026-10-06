// DictusCore/Tests/DictusCoreTests/ProHomeCardTests.swift
// The Home Pro card (#216 decision 16): visible in every state, calm once paid.
import XCTest
@testable import DictusCore

final class ProHomeCardTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func content(paywallVisible: Bool = true,
                         promotion: ProPromotionEntry = .upgrade,
                         isPaid: Bool = false,
                         isEntitled: Bool = false,
                         trial: ProTrialState = .neverStarted,
                         activeFeatures: Int = 4) -> ProHomeCardContent {
        ProHomeCard.content(paywallVisible: paywallVisible, promotion: promotion, isPaid: isPaid,
                            isEntitled: isEntitled, trial: trial, activeFeatures: activeFeatures)
    }

    func testFreeAndTrialKeepTodaysCard() {
        XCTAssertEqual(content(promotion: .upgrade), .upgrade)
        XCTAssertEqual(content(promotion: .trialEnding(daysLeft: 2), isEntitled: true,
                               trial: .running(endsAt: now.addingTimeInterval(86_400))), .trialEnding(daysLeft: 2))
        // Early trial: the calm card (decision 16, answered 2026-10-05).
        XCTAssertEqual(content(promotion: .hidden, isEntitled: true,
                               trial: .running(endsAt: now.addingTimeInterval(10 * 86_400)), activeFeatures: 4),
                       .member(activeFeatures: 4))
        // A device that can never run Smart Modes, nothing owned: no promotion (#593).
        XCTAssertEqual(content(promotion: .hidden), .hidden)
    }

    func testAPayingUserGetsTheCalmCard() {
        XCTAssertEqual(content(promotion: .hidden, isPaid: true, isEntitled: true, activeFeatures: 3),
                       .member(activeFeatures: 3))
        // Paid during a trial: the plan wins, as in the hub.
        XCTAssertEqual(content(promotion: .hidden, isPaid: true, isEntitled: true,
                               trial: .running(endsAt: now.addingTimeInterval(86_400)), activeFeatures: 4),
                       .member(activeFeatures: 4))
    }

    func testTheDebugForceShowsTheCalmCardOnlyWithTheFlagUp() {
        XCTAssertEqual(content(promotion: .hidden, isEntitled: true), .member(activeFeatures: 4))
        XCTAssertEqual(content(paywallVisible: false, promotion: .hidden, isEntitled: true), .hidden)
    }

    func testNothingWithThePaywallHidden() {
        XCTAssertEqual(content(paywallVisible: false, promotion: .upgrade, isPaid: true, isEntitled: true), .hidden)
    }
}
