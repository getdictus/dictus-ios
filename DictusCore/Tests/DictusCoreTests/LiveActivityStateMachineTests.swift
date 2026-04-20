// DictusCore/Tests/DictusCoreTests/LiveActivityStateMachineTests.swift
// Unit tests for LiveActivityStateMachine transition validation and watchdog flag.

import XCTest
@testable import DictusCore

final class LiveActivityStateMachineTests: XCTestCase {

    // MARK: - Valid Transitions

    func testIdleToStandbySucceeds() {
        var sm = LiveActivityStateMachine()
        XCTAssertTrue(sm.transition(to: .standby))
        XCTAssertEqual(sm.currentPhase, .standby)
    }

    func testStandbyToRecordingSucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        XCTAssertTrue(sm.transition(to: .recording))
        XCTAssertEqual(sm.currentPhase, .recording)
    }

    func testRecordingToTranscribingSucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        XCTAssertTrue(sm.transition(to: .transcribing))
        XCTAssertEqual(sm.currentPhase, .transcribing)
    }

    func testRecordingToStandbySucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        XCTAssertTrue(sm.transition(to: .standby))
        XCTAssertEqual(sm.currentPhase, .standby)
    }

    func testTranscribingToReadySucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        sm.transition(to: .transcribing)
        XCTAssertTrue(sm.transition(to: .ready))
        XCTAssertEqual(sm.currentPhase, .ready)
    }

    func testTranscribingToFailedSucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        sm.transition(to: .transcribing)
        XCTAssertTrue(sm.transition(to: .failed))
        XCTAssertEqual(sm.currentPhase, .failed)
    }

    func testReadyToStandbySucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        sm.transition(to: .transcribing)
        sm.transition(to: .ready)
        XCTAssertTrue(sm.transition(to: .standby))
        XCTAssertEqual(sm.currentPhase, .standby)
    }

    func testReadyToRecordingSucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        sm.transition(to: .transcribing)
        sm.transition(to: .ready)
        XCTAssertTrue(sm.transition(to: .recording))
        XCTAssertEqual(sm.currentPhase, .recording)
    }

    func testFailedToStandbySucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        sm.transition(to: .transcribing)
        sm.transition(to: .failed)
        XCTAssertTrue(sm.transition(to: .standby))
        XCTAssertEqual(sm.currentPhase, .standby)
    }

    func testFailedToRecordingSucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        sm.transition(to: .transcribing)
        sm.transition(to: .failed)
        XCTAssertTrue(sm.transition(to: .recording))
        XCTAssertEqual(sm.currentPhase, .recording)
    }

    func testFailedToIdleSucceeds() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        sm.transition(to: .transcribing)
        sm.transition(to: .failed)
        XCTAssertTrue(sm.transition(to: .idle))
        XCTAssertEqual(sm.currentPhase, .idle)
    }

    // MARK: - Invalid Transitions

    func testIdleToRecordingFails() {
        var sm = LiveActivityStateMachine()
        XCTAssertFalse(sm.transition(to: .recording))
        XCTAssertEqual(sm.currentPhase, .idle)
    }

    func testStandbyToTranscribingFails() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        XCTAssertFalse(sm.transition(to: .transcribing))
        XCTAssertEqual(sm.currentPhase, .standby)
    }

    func testRecordingToReadyFails() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        XCTAssertFalse(sm.transition(to: .ready))
        XCTAssertEqual(sm.currentPhase, .recording)
    }

    func testRecordingToFailedFails() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        XCTAssertFalse(sm.transition(to: .failed))
        XCTAssertEqual(sm.currentPhase, .recording)
    }

    // MARK: - Watchdog Flag

    func testNeedsWatchdogTrueOnlyWhenRecording() {
        var sm = LiveActivityStateMachine()
        XCTAssertFalse(sm.needsWatchdog, "idle should not need watchdog")

        sm.transition(to: .standby)
        XCTAssertFalse(sm.needsWatchdog, "standby should not need watchdog")

        sm.transition(to: .recording)
        XCTAssertTrue(sm.needsWatchdog, "recording should need watchdog")

        sm.transition(to: .transcribing)
        XCTAssertFalse(sm.needsWatchdog, "transcribing should not need watchdog")
    }

    // MARK: - Reset

    func testResetSetsPhaseToIdle() {
        var sm = LiveActivityStateMachine()
        sm.transition(to: .standby)
        sm.transition(to: .recording)
        sm.reset()
        XCTAssertEqual(sm.currentPhase, .idle)
    }
}
