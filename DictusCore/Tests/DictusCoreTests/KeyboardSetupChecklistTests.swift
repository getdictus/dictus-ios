// DictusCore/Tests/DictusCoreTests/KeyboardSetupChecklistTests.swift
// The keyboard step's checklist: which line is ticked when, and when PiP is used (#682).
import XCTest
@testable import DictusCore

final class KeyboardSetupChecklistTests: XCTestCase {

    private typealias Checklist = KeyboardSetupChecklist

    // MARK: - Lines

    func testThreeLinesInTheOrderOfTheTapsInSettings() {
        XCTAssertEqual(KeyboardSetupChecklistLine.allCases, [
            .tapKeyboards, .turnOnDictus, .turnOnFullAccessAndAllow
        ])
    }

    // MARK: - Demo loop

    func testDemoStartsWithEveryLinePending() {
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: 0)), [.pending, .pending, .pending])
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: 0.79)), [.pending, .pending, .pending])
    }

    func testDemoWalksTheLinesOnTheDrawnSettingsSchedule() {
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: 0.8)), [.current, .pending, .pending])
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: 2.0)), [.done, .current, .pending])
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: 3.2)), [.done, .done, .current])
    }

    func testDemoHoldsEverythingTickedWhileTheDrawingHoldsItsFinalState() {
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: 4.6)), [.done, .done, .done])
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: 5.99)), [.done, .done, .done])
    }

    func testDemoWrapsEveryCycle() {
        let cycle = Checklist.demoCycle
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: cycle)), [.pending, .pending, .pending])
        XCTAssertEqual(
            Checklist.states(for: .demo(elapsed: cycle * 3 + 2.5)),
            Checklist.states(for: .demo(elapsed: 2.5))
        )
    }

    func testDemoTreatsANegativeClockAsTheReset() {
        XCTAssertEqual(Checklist.states(for: .demo(elapsed: -1)), [.pending, .pending, .pending])
    }

    func testDemoScheduleFitsInsideOneCycleInOrder() {
        // One entry per line, plus the moment everything is ticked.
        XCTAssertEqual(Checklist.demoSchedule.count, KeyboardSetupChecklistLine.allCases.count + 1)
        XCTAssertEqual(Checklist.demoSchedule, Checklist.demoSchedule.sorted())
        XCTAssertLessThan(Checklist.demoSchedule.last ?? .infinity, Checklist.demoCycle)
    }

    // MARK: - Guide (after the tap on Open Settings)

    func testGuideBeforeTheKeyboardIsAddedPointsAtTheKeyboardsRow() {
        XCTAssertEqual(Checklist.states(for: .guide(keyboardAdded: false)), [.current, .pending, .pending])
    }

    func testAddingTheKeyboardTicksTheFirstTwoLinesAndLightsFullAccess() {
        XCTAssertEqual(Checklist.states(for: .guide(keyboardAdded: true)), [.done, .done, .current])
        XCTAssertEqual(Checklist.state(of: .turnOnFullAccessAndAllow, in: .guide(keyboardAdded: true)), .current)
    }

    func testCompleteTicksEverything() {
        XCTAssertEqual(Checklist.states(for: .complete), [.done, .done, .done])
    }

    // MARK: - The trip to Settings

    func testPictureInPictureOnlyWhenSupportedAndPossible() {
        XCTAssertEqual(
            Checklist.settingsTrip(isSupported: true, isPossible: true, isForcedOff: false),
            .pictureInPictureThenSettings
        )
    }

    func testFallbackWhenPictureInPictureIsUnsupported() {
        XCTAssertEqual(
            Checklist.settingsTrip(isSupported: false, isPossible: false, isForcedOff: false),
            .settingsOnly(reason: "unsupported")
        )
    }

    func testFallbackWhenPictureInPictureCannotStartNow() {
        XCTAssertEqual(
            Checklist.settingsTrip(isSupported: true, isPossible: false, isForcedOff: false),
            .settingsOnly(reason: "notPossible")
        )
    }

    func testForcedFallbackWinsOverAnAvailablePictureInPicture() {
        XCTAssertEqual(
            Checklist.settingsTrip(isSupported: true, isPossible: true, isForcedOff: true),
            .settingsOnly(reason: "forcedOff")
        )
    }
}
