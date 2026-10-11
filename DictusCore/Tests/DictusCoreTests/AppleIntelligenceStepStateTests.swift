// DictusCore/Tests/DictusCoreTests/AppleIntelligenceStepStateTests.swift
// The Apple Intelligence step's check on return and its countdown (#683).
import XCTest
@testable import DictusCore

final class AppleIntelligenceStepStateTests: XCTestCase {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    // MARK: - First visit

    func testTheFirstVisitShowsTheInstructions() {
        XCTAssertEqual(AppleIntelligenceStepState(isAvailable: false).phase, .instructions)
    }

    func testAlreadyAvailableShowsReady() {
        XCTAssertEqual(AppleIntelligenceStepState(isAvailable: true).phase, .ready)
    }

    // MARK: - Return

    func testComingBackNotReadyStartsTheCheck() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        XCTAssertEqual(state.appBecameActive(isAvailable: false, at: start), .checkingStarted)
        XCTAssertEqual(state.phase, .checking(startedAt: start))
        XCTAssertEqual(state.secondsLeft(at: start), 15)
    }

    func testComingBackReadyGoesStraightToReady() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        XCTAssertEqual(state.appBecameActive(isAvailable: true, at: start), .becameAvailable(afterSeconds: nil))
        XCTAssertEqual(state.phase, .ready)
    }

    func testAnotherReturnStartsTheCountdownOver() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        state.appBecameActive(isAvailable: false, at: at(9))
        XCTAssertEqual(state.secondsLeft(at: at(9)), 15)
    }

    func testAReturnFromTheSettingUpScreenChecksAgain() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        state.availabilityRead(isAvailable: false, at: at(15))
        XCTAssertEqual(state.phase, .settingUp)
        XCTAssertEqual(state.appBecameActive(isAvailable: false, at: at(60)), .checkingStarted)
    }

    // MARK: - During the check

    func testAvailableDuringTheCheckIsReady() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        XCTAssertNil(state.availabilityRead(isAvailable: false, at: at(2)))
        XCTAssertEqual(state.availabilityRead(isAvailable: true, at: at(4)), .becameAvailable(afterSeconds: 4))
        XCTAssertEqual(state.phase, .ready)
    }

    func testTheCountdownRunsFifteenToOne() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        XCTAssertEqual(state.secondsLeft(at: at(0.1)), 15)
        XCTAssertEqual(state.secondsLeft(at: at(14.2)), 1)
        XCTAssertEqual(state.elapsedFraction(at: at(7.5)), 0.5, accuracy: 0.0001)
    }

    func testNoTransitionBeforeTheEnd() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        XCTAssertNil(state.availabilityRead(isAvailable: false, at: at(14.9)))
        XCTAssertEqual(state.phase, .checking(startedAt: start))
    }

    func testTheEndOfTheCountdownIsTheSettingUpScreen() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        XCTAssertEqual(state.availabilityRead(isAvailable: false, at: at(15)), .countdownElapsed)
        XCTAssertEqual(state.phase, .settingUp)
        XCTAssertEqual(state.secondsLeft(at: at(16)), 0)
    }

    // MARK: - After the check

    func testSeeTheStepsAgainGoesBackToTheInstructions() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        state.availabilityRead(isAvailable: false, at: at(15))
        state.showInstructionsAgain()
        XCTAssertEqual(state.phase, .instructions)
    }

    func testReadsOutsideTheCheckChangeNothingUnlessAvailable() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        XCTAssertNil(state.availabilityRead(isAvailable: false, at: at(100)))
        XCTAssertEqual(state.phase, .instructions)
        XCTAssertEqual(state.availabilityRead(isAvailable: true, at: at(101)), .becameAvailable(afterSeconds: nil))
    }

    func testReadyIsLoggedOnce() {
        var state = AppleIntelligenceStepState(isAvailable: true)
        XCTAssertNil(state.availabilityRead(isAvailable: true, at: start))
        XCTAssertNil(state.appBecameActive(isAvailable: true, at: start))
    }
}
