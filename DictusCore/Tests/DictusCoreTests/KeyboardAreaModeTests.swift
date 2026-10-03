// DictusCore/Tests/DictusCoreTests/KeyboardAreaModeTests.swift
// Contract tests for the single keyboard-area mode value (#271).
import XCTest
@testable import DictusCore

final class KeyboardAreaModeTests: XCTestCase {

    // MARK: - Cases

    /// The count is the point, not the number: `KeyboardViewController.applyLayout`
    /// switches exhaustively over this enum and every case has to set the hosting
    /// height, the bottom anchor and the grid's visibility explicitly. A case added
    /// without that is the #271 bug returning.
    func testEnumHasExactlySixCases() {
        XCTAssertEqual(KeyboardAreaMode.allCases.count, 6)
    }

    func testPanelCaseExistsForIssue241() {
        XCTAssertTrue(KeyboardAreaMode.allCases.contains(.panel))
    }

    func testSmartModeFanCaseExistsForIssue79() {
        XCTAssertTrue(KeyboardAreaMode.allCases.contains(.smartModeFan))
    }

    func testRawValues() {
        XCTAssertEqual(KeyboardAreaMode.keys.rawValue, "keys")
        XCTAssertEqual(KeyboardAreaMode.emoji.rawValue, "emoji")
        XCTAssertEqual(KeyboardAreaMode.panel.rawValue, "panel")
        XCTAssertEqual(KeyboardAreaMode.smartModeFan.rawValue, "smartModeFan")
        XCTAssertEqual(KeyboardAreaMode.recording.rawValue, "recording")
        // Quoted by the `hostingSet_voiceNoteResult` and `mode=` probes in device logs.
        XCTAssertEqual(KeyboardAreaMode.voiceNoteResult.rawValue, "voiceNoteResult")
    }

    // MARK: - The voice note reader (#637)

    /// A dictation entering an owning status replaces the reader: the overlay owns
    /// the whole area while a dictation is in flight, whatever the area showed.
    func testADictationReplacesTheVoiceNoteReader() {
        for status in DictationStatus.allCases where status.ownsKeyboardArea {
            XCTAssertEqual(
                KeyboardAreaMode.resolving(status: status, current: .voiceNoteResult),
                .recording,
                "status=\(status.rawValue)"
            )
        }
    }

    /// Leaving the dictation returns to the keys, not to the reader. The notes are
    /// still waiting — the keyboard rereads them on that transition and the chip is
    /// back — but the surface is not taken over again under the user's thumb
    /// (#637 decision 1).
    func testLeavingADictationStartedFromTheReaderReturnsToTheKeys() {
        let during = KeyboardAreaMode.resolving(status: .recording, current: .voiceNoteResult)
        for status in [DictationStatus.idle, .ready, .failed] {
            XCTAssertEqual(
                KeyboardAreaMode.resolving(status: status, current: during),
                .keys,
                "status=\(status.rawValue)"
            )
        }
    }

    /// An idle status write leaves the reader alone: it is closed by its own `✕` or
    /// `Insert`, never by a status write the keyboard re-applies on every refresh.
    func testAnIdleStatusLeavesTheReaderOpen() {
        for status in [DictationStatus.idle, .ready, .failed] {
            XCTAssertEqual(
                KeyboardAreaMode.resolving(status: status, current: .voiceNoteResult),
                .voiceNoteResult
            )
        }
    }

    /// The two full-surface modes are the gated ones: a stale controller must draw
    /// neither the overlay nor an `Insert` that writes into a text field.
    func testOnlyTheFullSurfaceModesRequireTheVisibleOwner() {
        XCTAssertTrue(KeyboardAreaMode.recording.requiresVisibleOwner)
        XCTAssertTrue(KeyboardAreaMode.voiceNoteResult.requiresVisibleOwner)
        XCTAssertFalse(KeyboardAreaMode.keys.requiresVisibleOwner)
        XCTAssertFalse(KeyboardAreaMode.emoji.requiresVisibleOwner)
        XCTAssertFalse(KeyboardAreaMode.panel.requiresVisibleOwner)
        XCTAssertFalse(KeyboardAreaMode.smartModeFan.requiresVisibleOwner)
    }

    /// A dictation takes the area from the fan, exactly as it does from the pickers —
    /// the fan is a menu, and the overlay owns the whole area while a dictation is in
    /// flight (#79).
    func testDictationTakesTheAreaFromTheFan() {
        XCTAssertEqual(
            KeyboardAreaMode.resolving(status: .recording, current: .smartModeFan),
            .recording
        )
    }

    /// And an idle status leaves it alone: the fan is dismissed by its own gesture
    /// ending, not by a status write.
    func testIdleStatusLeavesTheFanOpen() {
        XCTAssertEqual(
            KeyboardAreaMode.resolving(status: .idle, current: .smartModeFan),
            .smartModeFan
        )
    }

    // MARK: - Which statuses own the keyboard area

    func testInFlightStatusesOwnTheKeyboardArea() {
        XCTAssertTrue(DictationStatus.requested.ownsKeyboardArea)
        XCTAssertTrue(DictationStatus.recording.ownsKeyboardArea)
        XCTAssertTrue(DictationStatus.transcribing.ownsKeyboardArea)
        XCTAssertTrue(DictationStatus.processing.ownsKeyboardArea)
    }

    func testTerminalStatusesDoNotOwnTheKeyboardArea() {
        XCTAssertFalse(DictationStatus.idle.ownsKeyboardArea)
        XCTAssertFalse(DictationStatus.ready.ownsKeyboardArea)
        XCTAssertFalse(DictationStatus.failed.ownsKeyboardArea)
    }

    // MARK: - Transitions

    func testDictationTakesOverFromEveryMode() {
        for mode in KeyboardAreaMode.allCases {
            XCTAssertEqual(
                KeyboardAreaMode.resolving(status: .requested, current: mode),
                .recording,
                "a requested dictation must take the area from \(mode.rawValue)"
            )
        }
    }

    /// The acceptance criterion "starting a dictation from the emoji picker
    /// dismisses the picker" is this transition — no coordination between flags.
    func testStartingADictationDismissesTheEmojiPicker() {
        XCTAssertEqual(
            KeyboardAreaMode.resolving(status: .recording, current: .emoji),
            .recording
        )
    }

    func testEndingADictationReturnsToTheKeyGrid() {
        for status in [DictationStatus.idle, .ready, .failed] {
            XCTAssertEqual(
                KeyboardAreaMode.resolving(status: status, current: .recording),
                .keys,
                "leaving a dictation via \(status.rawValue) must restore the key grid"
            )
        }
    }

    /// The picker is not restored after a dictation that started from it — the
    /// pre-#271 code cleared its emoji flag when the overlay appeared.
    func testTheEmojiPickerIsNotRestoredAfterADictation() {
        let duringDictation = KeyboardAreaMode.resolving(status: .recording, current: .emoji)
        XCTAssertEqual(KeyboardAreaMode.resolving(status: .idle, current: duringDictation), .keys)
    }

    func testAnIdleStatusLeavesAFullAreaPresentationAlone() {
        XCTAssertEqual(KeyboardAreaMode.resolving(status: .idle, current: .emoji), .emoji)
        XCTAssertEqual(KeyboardAreaMode.resolving(status: .idle, current: .panel), .panel)
        XCTAssertEqual(KeyboardAreaMode.resolving(status: .idle, current: .keys), .keys)
    }

    func testResolvingIsIdempotent() {
        for status in DictationStatus.allCases {
            for mode in KeyboardAreaMode.allCases {
                let once = KeyboardAreaMode.resolving(status: status, current: mode)
                let twice = KeyboardAreaMode.resolving(status: status, current: once)
                XCTAssertEqual(once, twice, "status=\(status.rawValue) mode=\(mode.rawValue)")
            }
        }
    }
}
