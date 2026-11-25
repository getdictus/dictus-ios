// DictusAppTests/StuckStageEndingTests.swift
// A transcription the stage watchdog gives up on ends on an error, not on silence (#933).
import XCTest
import DictusCore
@testable import DictusApp

/// WHY a hosted app test: the ending lives on `DictationCoordinator`, which is DictusApp's,
/// and what it must leave behind is App Group state the keyboard reads on its next refresh.
///
/// Before #933 the watchdog ended a stuck transcription on `cancelDictation()` alone: it
/// wrote `idle` and nothing to `DictationErrorChannel`, so the keyboard took its overlay
/// down with no text and no message. That is the ending this pins.
@MainActor
final class StuckStageEndingTests: XCTestCase {

    override func tearDown() async throws {
        DictationCoordinator.shared.resetStatus()
        DictationErrorChannel.clear()
    }

    func testAStuckTranscriptionEndsOnAnErrorTheKeyboardCanShow() {
        let coordinator = DictationCoordinator.shared
        DictationErrorChannel.clear()
        coordinator.enterTranscription(audioSeconds: 19)
        XCTAssertEqual(AppGroup.defaults.string(forKey: SharedKeys.dictationStatus), DictationStatus.transcribing.rawValue)

        coordinator.endStuckStage()

        XCTAssertEqual(
            AppGroup.defaults.string(forKey: SharedKeys.dictationStatus), DictationStatus.failed.rawValue,
            "the keyboard reads idle and shows nothing"
        )
        XCTAssertEqual(DictationErrorChannel.current, DictationFailureMessage.unexplainedFailure)
    }
}
