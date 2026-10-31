// DictusCore/Tests/DictusCoreTests/AppleIntelligenceStepStateTests.swift
// What a return to the Apple Intelligence step shows (#683).
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

    func testTheInstructionsDoNotRecheckOnTheirOwn() {
        XCTAssertFalse(AppleIntelligenceStepState(isAvailable: false).rechecksQuietly)
    }

    // MARK: - Opening state by reason (#846)

    /// Decision of 2026-10-28: `modelNotReady` opens on the setting-up screen, which
    /// keeps the Siri hint, and re-reads quietly from the start.
    func testModelNotReadyOpensOnSettingUp() {
        let state = AppleIntelligenceStepState(engineState: .modelNotReady)
        XCTAssertEqual(state.phase, .settingUp)
        XCTAssertTrue(state.rechecksQuietly)
    }

    func testModelNotReadyCanStillShowTheSteps() {
        var state = AppleIntelligenceStepState(engineState: .modelNotReady)
        state.showInstructionsAgain()
        XCTAssertEqual(state.phase, .instructions)
    }

    func testModelNotReadyTurnsReadyOnAQuietReRead() {
        var state = AppleIntelligenceStepState(engineState: .modelNotReady)
        XCTAssertEqual(state.availabilityRead(isAvailable: true, at: at(3)), .becameAvailable(afterSeconds: nil))
        XCTAssertEqual(state.phase, .ready)
    }

    func testOtherNotReadyReasonsOpenOnTheInstructions() {
        XCTAssertEqual(AppleIntelligenceStepState(engineState: .appleIntelligenceNotEnabled).phase, .instructions)
        XCTAssertEqual(AppleIntelligenceStepState(engineState: .other("x")).phase, .instructions)
    }

    func testAvailableEngineOpensReady() {
        XCTAssertEqual(AppleIntelligenceStepState(engineState: .available).phase, .ready)
    }

    // MARK: - Return

    /// Device test of 2026-10-10: Apple's model in place, the first read on return is
    /// already `available`.
    func testComingBackReadyIsReadyAtOnce() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        XCTAssertEqual(state.appBecameActive(isAvailable: true, at: start), .becameAvailable(afterSeconds: 0))
        XCTAssertEqual(state.phase, .ready)
    }

    /// No countdown: not available goes straight to the setting-up screen.
    func testComingBackNotReadyShowsSettingUpAtOnce() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        XCTAssertEqual(state.appBecameActive(isAvailable: false, at: start), .settingUpShown)
        XCTAssertEqual(state.phase, .settingUp)
        XCTAssertTrue(state.rechecksQuietly)
    }

    func testTheSecondReadAfterAReturnCanStillTurnReady() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        XCTAssertEqual(
            state.availabilityRead(isAvailable: true, at: at(AppleIntelligenceStepState.returnRecheckDelay)),
            .becameAvailable(afterSeconds: 2)
        )
        XCTAssertEqual(state.phase, .ready)
        XCTAssertFalse(state.rechecksQuietly)
    }

    func testAnotherReturnWhileSettingUpIsNotLoggedAgain() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        XCTAssertNil(state.appBecameActive(isAvailable: false, at: at(30)))
        XCTAssertEqual(state.phase, .settingUp)
    }

    // MARK: - Setting up

    /// Device test of 2026-10-11: Apple Intelligence turned ready a while later. The quiet
    /// re-reads catch it, measured from the return.
    func testAQuietReReadTurnsReadyLater() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        XCTAssertNil(state.availabilityRead(isAvailable: false, at: at(5)))
        XCTAssertEqual(state.availabilityRead(isAvailable: true, at: at(95)), .becameAvailable(afterSeconds: 95))
        XCTAssertEqual(state.phase, .ready)
    }

    func testSeeTheStepsAgainGoesBackToTheInstructions() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        state.showInstructionsAgain()
        XCTAssertEqual(state.phase, .instructions)
        XCTAssertFalse(state.rechecksQuietly)
    }

    func testAReturnFromTheInstructionsShownAgainIsSettingUpAgain() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        state.appBecameActive(isAvailable: false, at: start)
        state.showInstructionsAgain()
        XCTAssertEqual(state.appBecameActive(isAvailable: false, at: at(60)), .settingUpShown)
    }

    // MARK: - Ready

    func testAvailableBeforeAnyReturnHasNoDelay() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        XCTAssertEqual(state.availabilityRead(isAvailable: true, at: start), .becameAvailable(afterSeconds: nil))
    }

    func testReadyIsLoggedOnce() {
        var state = AppleIntelligenceStepState(isAvailable: true)
        XCTAssertNil(state.availabilityRead(isAvailable: true, at: start))
        XCTAssertNil(state.appBecameActive(isAvailable: true, at: start))
    }

    func testReadsThatAreNotAvailableChangeNothing() {
        var state = AppleIntelligenceStepState(isAvailable: false)
        XCTAssertNil(state.availabilityRead(isAvailable: false, at: start))
        XCTAssertEqual(state.phase, .instructions)
    }
}
