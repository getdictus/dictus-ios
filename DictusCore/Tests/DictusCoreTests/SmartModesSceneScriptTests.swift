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

    private func frame(at time: Double) -> SmartModesSceneScript.Frame {
        SmartModesSceneScript.frame(at: time, entryCount: entryCount, fanAreaHeight: areaHeight, micY: micY)
    }

    // MARK: - The fan

    func testTheFanIsNormalMessageListAndEnglishForAFrenchSpeaker() {
        XCTAssertEqual(
            SmartModesSceneScript.entries(spokenLanguage: "fr").map(\.id),
            ["normal", SmartModeCatalogue.messageIdentifier, SmartModeCatalogue.notesIdentifier,
             SmartModeCatalogue.translateIdentifier(target: .english)]
        )
    }

    func testAnEnglishSpeakerIsNotShownTranslateToEnglish() {
        let entries = SmartModesSceneScript.entries(spokenLanguage: "en")
        XCTAssertEqual(entries.count, 4)
        XCTAssertFalse(entries.contains { $0.id == SmartModeCatalogue.translateIdentifier(target: .english) })
        XCTAssertEqual(entries.last?.smartMode?.badge, .text("FR"))
    }

    func testTheFanFitsTheRealFan() {
        XCTAssertLessThanOrEqual(SmartModesSceneScript.entries(spokenLanguage: nil).count, SmartModeFanLayout.maximumEntries)
    }

    // MARK: - The loop

    func testTheLoopLastsBetweenTenAndTwentySeconds() {
        // #649 decision 14.
        XCTAssertGreaterThanOrEqual(SmartModesSceneScript.loopSeconds, 10)
        XCTAssertLessThanOrEqual(SmartModesSceneScript.loopSeconds, 20)
    }

    func testTheLoopClosesOnItself() {
        let start = frame(at: 0)
        let end = frame(at: SmartModesSceneScript.loopSeconds - 0.001)
        XCTAssertEqual(start, end)
        XCTAssertFalse(start.isFanOpen)
        XCTAssertNil(start.armedIndex)
        XCTAssertNil(start.finger)
        XCTAssertEqual(frame(at: SmartModesSceneScript.loopSeconds + 1), frame(at: 1))
    }

    func testTheFanOpensOnlyAfterTheRealLongPressDelay() {
        let press = SmartModesSceneScript.Beat.press
        XCTAssertEqual(frame(at: press + 0.01).finger?.isPressed, true)
        XCTAssertFalse(frame(at: press + SmartModesSceneScript.longPressSeconds - 0.01).isFanOpen)
        XCTAssertTrue(frame(at: press + SmartModesSceneScript.longPressSeconds + 0.01).isFanOpen)
    }

    func testHoldingOnTheMicLightsNoRow() {
        let held = frame(at: SmartModesSceneScript.Beat.fanOpens + 0.1)
        XCTAssertTrue(held.isFanOpen)
        XCTAssertNil(held.highlightedIndex)
    }

    func testTheFirstPassSlidesThroughEveryRowAndArmsTheTranslation() {
        var lit: [Int] = []
        var time = SmartModesSceneScript.Beat.slideStart
        while time < SmartModesSceneScript.Beat.release {
            if let index = frame(at: time).highlightedIndex, lit.last != index { lit.append(index) }
            time += 0.01
        }
        XCTAssertEqual(lit, [0, 1, 2, 3])

        XCTAssertNil(frame(at: SmartModesSceneScript.Beat.release - 0.01).armedIndex)
        let released = frame(at: SmartModesSceneScript.Beat.release + 0.01)
        XCTAssertFalse(released.isFanOpen)
        XCTAssertEqual(released.armedIndex, 3)
        XCTAssertEqual(frame(at: SmartModesSceneScript.passSeconds - 0.01).armedIndex, 3)
    }

    func testTheSecondPassGoesBackToNormal() {
        let pass = SmartModesSceneScript.passSeconds
        XCTAssertEqual(frame(at: pass + 0.1).armedIndex, 3)
        XCTAssertEqual(frame(at: pass + SmartModesSceneScript.Beat.release - 0.05).highlightedIndex, 0)
        XCTAssertNil(frame(at: pass + SmartModesSceneScript.Beat.release + 0.01).armedIndex)
    }

    func testTheFingerRestsOnTheRowItChooses() {
        // Where it lets go, the keyboard's own mapping says it is on that row.
        let finger = frame(at: SmartModesSceneScript.Beat.release - 0.01).finger
        XCTAssertEqual(finger?.travel ?? 0, 1, accuracy: 0.0001)
        XCTAssertEqual(
            finger.flatMap {
                SmartModeFanLayout.entryIndex(atY: $0.y, availableHeight: areaHeight, entryCount: entryCount, showsReason: false)
            },
            3
        )
    }

    func testTheStillFrameIsTheFanOpenOnTheTranslation() {
        let still = frame(at: SmartModesSceneScript.stillSeconds)
        XCTAssertTrue(still.isFanOpen)
        XCTAssertEqual(still.highlightedIndex, 3)
    }

    func testTheFingerFadesInAndOut() {
        XCTAssertEqual(frame(at: SmartModesSceneScript.Beat.fingerIn).finger?.opacity, 0)
        XCTAssertEqual(frame(at: SmartModesSceneScript.Beat.press).finger?.opacity ?? 0, 1, accuracy: 0.0001)
        XCTAssertNil(frame(at: SmartModesSceneScript.Beat.fingerOut).finger)
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
