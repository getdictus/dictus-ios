// DictusCore/Tests/DictusCoreTests/PrimaryMicAnchorTests.swift
// Pins the arithmetic that puts the recording screen's button at the height of Home's mic (#788).
import XCTest
@testable import DictusCore

final class PrimaryMicAnchorTests: XCTestCase {

    func testSpacingPutsTheSlotCentreOnTheAnchor() {
        // iPhone 15 Pro Max shape: safe area ends at 898 pt, Home's mic centred at 734 pt.
        let spacing = PrimaryMicAnchor.bottomSpacing(
            anchorY: 734, containerMaxY: 898, slotHeight: 100, fallback: 40
        )
        XCTAssertEqual(spacing, 114)
        // The slot's centre is its bottom edge minus half its height.
        XCTAssertEqual(898 - spacing - 50, 734)
    }

    func testNoAnchorKeepsTheFallback() {
        let spacing = PrimaryMicAnchor.bottomSpacing(
            anchorY: nil, containerMaxY: 898, slotHeight: 100, fallback: 40
        )
        XCTAssertEqual(spacing, 40)
    }

    func testAnAnchorBelowTheSlotNeverGoesNegative() {
        let spacing = PrimaryMicAnchor.bottomSpacing(
            anchorY: 880, containerMaxY: 898, slotHeight: 100, fallback: 40
        )
        XCTAssertEqual(spacing, 0)
    }

    @MainActor
    func testReportRoundsToHalfPointsAndIgnoresNoise() {
        let anchor = PrimaryMicAnchor()
        anchor.report(centerY: 734.2)
        XCTAssertEqual(anchor.centerY, 734)
        anchor.report(centerY: 734.7)
        XCTAssertEqual(anchor.centerY, 734.5)
    }
}
