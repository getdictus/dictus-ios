// DictusCore/Tests/DictusCoreTests/OnboardingPhoneFitTests.swift
// The drawn iPhone of an onboarding scene narrows to fit a short screen (#700).
import XCTest
@testable import DictusCore

final class OnboardingPhoneFitTests: XCTestCase {

    /// The Smart Modes scene: 402 × 473 pt, in a card adding 34 pt across and 17 pt down.
    private func width(_ availableWidth: Double, _ availableHeight: Double) -> Double {
        OnboardingPhoneFit.cardWidth(
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            sceneAspectRatio: 402.0 / 473.0,
            horizontalChrome: 34,
            verticalChrome: 17
        )
    }

    func testATallScreenKeepsThePageWidth() {
        XCTAssertEqual(width(354, 600), 354)
    }

    func testAShortScreenNarrowsTheCardSoTheWholeDrawingFits() {
        let card = width(327, 280)
        XCTAssertLessThan(card, 327)
        // The narrowed card is exactly as tall as the room it has.
        let height = (card - 34) / (402.0 / 473.0) + 17
        XCTAssertEqual(height, 280, accuracy: 0.001)
    }

    func testExactlyEnoughRoomKeepsThePageWidth() {
        let needed = (327.0 - 34) / (402.0 / 473.0) + 17
        XCTAssertEqual(width(327, needed), 327)
    }

    func testNoRoomLeavesOnlyTheChrome() {
        XCTAssertEqual(width(327, 0), 34)
    }
}
