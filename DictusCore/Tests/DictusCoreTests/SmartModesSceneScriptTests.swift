// DictusCore/Tests/DictusCoreTests/SmartModesSceneScriptTests.swift
// The onboarding's Smart Modes scene: its fan, its loop, and the clock that drives it (#679).
import CoreGraphics
import XCTest
@testable import DictusCore

final class SmartModesSceneScriptTests: XCTestCase {

    /// The fan area of a standard iPhone (`SmartModeFanLayout.rowHeight`'s 205 pt) and the
    /// mic pill's centre, 24 pt above it in the 52 pt toolbar.
    private let areaHeight: CGFloat = 205
    private let micY: CGFloat = -24
    private let entryCount = 4

    private typealias Script = SmartModesSceneScript
    private typealias Beat = SmartModesSceneScript.Beat

    private func frame(at time: Double) -> Script.Frame {
        Script.frame(at: time, entryCount: entryCount, fanAreaHeight: areaHeight, micY: micY)
    }

    /// Every frame of the loop, 10 ms apart.
    private func everyFrame() -> [(time: Double, frame: Script.Frame)] {
        stride(from: 0.0, to: Script.loopSeconds, by: 0.01).map { ($0, frame(at: $0)) }
    }

    private let leg2 = SmartModesSceneScript.normalLegSeconds

    // MARK: - The fan

    func testTheFanIsNormalMessageListAndEnglishForAFrenchSpeaker() {
        XCTAssertEqual(
            Script.entries(spokenLanguage: "fr").map(\.id),
            ["normal", SmartModeCatalogue.messageIdentifier, SmartModeCatalogue.notesIdentifier,
             SmartModeCatalogue.translateIdentifier(target: .english)]
        )
    }

    func testAnEnglishSpeakerIsNotShownTranslateToEnglish() {
        let entries = Script.entries(spokenLanguage: "en")
        XCTAssertEqual(entries.count, 4)
        XCTAssertFalse(entries.contains { $0.id == SmartModeCatalogue.translateIdentifier(target: .english) })
        XCTAssertEqual(entries.last?.smartMode?.badge, .text("FR"))
    }

    func testTheFanFitsTheRealFan() {
        XCTAssertLessThanOrEqual(Script.entries(spokenLanguage: nil).count, SmartModeFanLayout.maximumEntries)
    }

    // MARK: - The sentence

    func testAFrenchSpeakerDictatesInFrenchAndGetsEnglish() {
        let languages = Script.sentenceLanguages(spokenLanguage: "fr", interfaceLanguage: "fr")
        XCTAssertEqual(languages.original, "fr")
        XCTAssertEqual(languages.translated, "en")
    }

    func testAnEnglishSpeakerDictatesInEnglishAndGetsFrench() {
        let languages = Script.sentenceLanguages(spokenLanguage: "en", interfaceLanguage: "en")
        XCTAssertEqual(languages.original, "en")
        XCTAssertEqual(languages.translated, "fr")
    }

    func testTheTwoSentencesAreAlwaysInDifferentLanguages() {
        for spoken in [nil, "fr", "en", "es", "de", "zh"] {
            for interface in [nil, "fr", "en"] {
                let languages = Script.sentenceLanguages(spokenLanguage: spoken, interfaceLanguage: interface)
                XCTAssertNotEqual(languages.original, languages.translated, "\(String(describing: spoken)) \(String(describing: interface))")
                XCTAssertTrue(Script.sentenceLanguages.contains(languages.original))
                XCTAssertTrue(Script.sentenceLanguages.contains(languages.translated))
            }
        }
    }

    // MARK: - The loop

    func testTheLoopLastsEighteenToTwentySeconds() {
        // #649 decision 14 (10 to 20 s), and the 18 to 20 s asked for on #679.
        XCTAssertGreaterThanOrEqual(Script.loopSeconds, 18)
        XCTAssertLessThanOrEqual(Script.loopSeconds, 20)
    }

    func testTheLoopClosesOnItself() {
        let start = frame(at: 0)
        let end = frame(at: Script.loopSeconds - 0.001)
        XCTAssertEqual(start, end)
        XCTAssertEqual(start.keyboard, .keys)
        XCTAssertEqual(start.fieldText, .translated)
        XCTAssertEqual(start.armedIndex, 3)
        XCTAssertNil(start.finger)
        XCTAssertEqual(frame(at: Script.loopSeconds + 1), frame(at: 1))
    }

    func testTheSceneOpensOnAnEmptyField() {
        let opening = frame(at: Script.openingSeconds)
        XCTAssertNil(opening.fieldText)
        XCTAssertEqual(opening.keyboard, .keys)
    }

    func testTheStillFrameIsTheEndState() {
        // The translated sentence in the field and the mode's badge on the mic.
        let still = frame(at: Script.stillSeconds)
        XCTAssertEqual(still.fieldText, .translated)
        XCTAssertEqual(still.armedIndex, 3)
        XCTAssertEqual(still.keyboard, .keys)
        XCTAssertNil(still.finger)
    }

    // MARK: - The order of the states

    /// The keyboard states of one leg, in order, without repeats.
    private func phases(from start: Double, to end: Double) -> [String] {
        var names: [String] = []
        for time in stride(from: start, to: end, by: 0.01) {
            let name: String
            switch frame(at: time).keyboard {
            case .keys: name = "keys"
            case .fan: name = "fan"
            case .recording: name = "recording"
            case .transcribing: name = "transcribing"
            case .processing: name = "processing"
            }
            if names.last != name { names.append(name) }
        }
        return names
    }

    func testTheNormalLegRecordsThenTranscribes() {
        XCTAssertEqual(phases(from: 0, to: leg2), ["keys", "fan", "recording", "transcribing", "keys"])
    }

    func testTheTranslationLegAlsoProcesses() {
        XCTAssertEqual(
            phases(from: leg2, to: Script.loopSeconds),
            ["keys", "fan", "recording", "transcribing", "processing", "keys"]
        )
    }

    func testTheFanOpensOnlyAfterTheRealLongPressDelay() {
        XCTAssertEqual(frame(at: Beat.press + 0.01).finger?.isPressed, true)
        XCTAssertFalse(frame(at: Beat.press + Script.longPressSeconds - 0.01).isFanOpen)
        XCTAssertTrue(frame(at: Beat.press + Script.longPressSeconds + 0.01).isFanOpen)
    }

    func testReleasingOnARowStartsTheRecording() {
        // `KeyboardSmartModeFan.commit()` arms and starts recording in one go.
        guard case .recording(let elapsed) = frame(at: Beat.release + 0.01).keyboard else {
            return XCTFail("not recording")
        }
        XCTAssertEqual(elapsed, 0.01, accuracy: 1e-9)
        XCTAssertNil(frame(at: Beat.release + 0.01).armedIndex)
        XCTAssertEqual(frame(at: leg2 + Beat.release + 0.01).armedIndex, 3)
    }

    func testTappingTheCheckStopsTheRecording() {
        XCTAssertEqual(frame(at: Beat.stopPress + 0.01).finger?.isPressed, true)
        if case .recording = frame(at: Beat.stopRelease - 0.01).keyboard {} else { XCTFail("still recording") }
        guard case .transcribing(let elapsed) = frame(at: Beat.stopRelease + 0.01).keyboard else {
            return XCTFail("not transcribing")
        }
        XCTAssertEqual(elapsed, 0.01, accuracy: 1e-9)
    }

    // MARK: - The field

    func testEachLegClearsTheFieldWithUndoThenShowsItsSentence() {
        // Normal leg: the translation goes, the original comes.
        XCTAssertEqual(frame(at: Beat.undoPress).fieldText, .translated)
        XCTAssertTrue(frame(at: Beat.undoPress).offersUndo)
        XCTAssertEqual(frame(at: Beat.undoPress).finger?.place, .undoButton)
        XCTAssertNil(frame(at: Beat.undoRelease + 0.01).fieldText)
        XCTAssertFalse(frame(at: Beat.undoRelease + 0.01).offersUndo)
        XCTAssertEqual(frame(at: Beat.transcriptionEnd + 0.01).fieldText, .original)
        XCTAssertTrue(frame(at: Beat.transcriptionEnd + 0.01).offersUndo)

        // Translation leg: the original goes, the same sentence comes back translated.
        XCTAssertEqual(frame(at: leg2 + Beat.undoPress).fieldText, .original)
        XCTAssertNil(frame(at: leg2 + Beat.undoRelease + 0.01).fieldText)
        XCTAssertNil(frame(at: leg2 + Beat.smartModeProcessingEnd - 0.01).fieldText)
        XCTAssertEqual(frame(at: leg2 + Beat.smartModeProcessingEnd + 0.01).fieldText, .translated)
    }

    func testNothingIsInsertedWhileTheKeyboardIsBusy() {
        for (time, frame) in everyFrame() where frame.keyboard.isOverlay || frame.keyboard == .fan {
            XCTAssertFalse(frame.offersUndo, "\(time)")
        }
    }

    // MARK: - The finger

    func testHoldingOnTheMicLightsNoRow() {
        let held = frame(at: Beat.fanOpens + 0.1)
        XCTAssertTrue(held.isFanOpen)
        XCTAssertNil(held.highlightedIndex)
    }

    func testTheNormalLegLightsNormalAndTheTranslationLegSlidesThroughEveryRow() {
        func lit(from start: Double) -> [Int] {
            var rows: [Int] = []
            for time in stride(from: start + Beat.slideStart, to: start + Beat.release, by: 0.01) {
                if let index = frame(at: time).highlightedIndex, rows.last != index { rows.append(index) }
            }
            return rows
        }
        XCTAssertEqual(lit(from: 0), [0])
        XCTAssertEqual(lit(from: leg2), [0, 1, 2, 3])
    }

    func testTheFingerRestsOnTheRowItChooses() {
        // Where it lets go, the keyboard's own mapping says it is on that row.
        for (start, row) in [(0.0, 0), (leg2, 3)] {
            let finger = frame(at: start + Beat.release - 0.01).finger
            XCTAssertEqual(finger?.columnTravel ?? 0, 1, accuracy: 0.0001)
            XCTAssertEqual(
                finger.flatMap {
                    SmartModeFanLayout.entryIndex(atY: $0.y, availableHeight: areaHeight, entryCount: entryCount, showsReason: false)
                },
                row
            )
        }
    }

    func testTheCheckIsTappedWhereTheMicWas() {
        let finger = frame(at: Beat.stopPress + 0.01).finger
        XCTAssertEqual(finger?.place, .keyboard)
        XCTAssertEqual(finger?.y, micY)
        XCTAssertEqual(finger?.columnTravel, 0)
    }

    func testTheFingerNeverCutsAcrossTheRows() {
        // Device feedback on PR #705: along the toolbar first, then straight down the
        // column. At no moment of either leg do the two coordinates move together.
        var previous: Script.Finger?
        for (time, current) in everyFrame() {
            if let finger = current.finger, let before = previous, finger.place == before.place {
                let movedAcross = abs(finger.columnTravel - before.columnTravel) > 1e-9
                let movedDown = abs(finger.y - before.y) > 1e-9
                XCTAssertFalse(movedAcross && movedDown, "diagonal at \(time)")
                // Over the rows, the finger is in the column.
                if finger.y >= 0 { XCTAssertEqual(finger.columnTravel, 1, accuracy: 1e-9, "\(time)") }
                // Along the toolbar, no row lights.
                if movedAcross { XCTAssertNil(current.highlightedIndex, "\(time)") }
            }
            previous = current.finger
        }
    }

    func testTheFingerFadesInAndOut() {
        XCTAssertEqual(frame(at: Beat.fingerIn).finger?.opacity, 0)
        XCTAssertEqual(frame(at: Beat.press).finger?.opacity ?? 0, 1, accuracy: 0.0001)
        XCTAssertNil(frame(at: Beat.release + Beat.fade).finger)
    }

    // MARK: - The waveform

    func testTheRecordingWaveformHasTheKeyboardsThirtyBarsInRange() {
        for elapsed in stride(from: 0.0, to: 3, by: 0.1) {
            let levels = Script.recordingLevels(elapsed: elapsed)
            XCTAssertEqual(levels.count, ProcessingWaveform.barCount)
            XCTAssertTrue(levels.allSatisfy { $0 == 0 || ($0 >= 0.05 && $0 <= 1) }, "\(elapsed)")
        }
        XCTAssertTrue(Script.recordingLevels(elapsed: 0).allSatisfy { $0 == 0 }, "a recording starts silent")
        XCTAssertGreaterThan(Script.recordingLevels(elapsed: 2).max() ?? 0, 0.5, "and then speaks")
    }

    // MARK: - The clock

    func testTheClockWrapsAndStartsWhereAsked() {
        var clock = SceneLoopClock(loopSeconds: 12, startSeconds: 3)
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.loopTime(at: 100), 3)
        clock.resume(at: 100)
        XCTAssertEqual(clock.loopTime(at: 105), 8, accuracy: 0.0001)
        XCTAssertEqual(clock.loopTime(at: 110), 1, accuracy: 0.0001)
    }

    func testTheClockDoesNotCountTheTimeAway() {
        var clock = SceneLoopClock(loopSeconds: 12)
        clock.resume(at: 0)
        clock.pause(at: 4)
        XCTAssertEqual(clock.loopTime(at: 60), 4, accuracy: 0.0001)
        clock.resume(at: 60)
        XCTAssertEqual(clock.loopTime(at: 61), 5, accuracy: 0.0001)
        // Resume and pause are idempotent.
        clock.resume(at: 61)
        clock.pause(at: 62)
        clock.pause(at: 70)
        XCTAssertEqual(clock.loopTime(at: 80), 6, accuracy: 0.0001)
    }
}
