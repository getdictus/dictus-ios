// DictusCore/Tests/DictusCoreTests/IntroAutoAdvanceTests.swift
// The intro carousel's auto-advance rules and its pausable page timer (#676).
import XCTest
@testable import DictusCore

final class IntroAutoAdvanceTests: XCTestCase {

    // MARK: - Policy

    func testAdvancesOnlyWithoutVoiceOverAndWithoutReduceMotion() {
        XCTAssertTrue(IntroAutoAdvance.isEnabled(voiceOverRunning: false, reduceMotion: false))
        XCTAssertFalse(IntroAutoAdvance.isEnabled(voiceOverRunning: true, reduceMotion: false))
        XCTAssertFalse(IntroAutoAdvance.isEnabled(voiceOverRunning: false, reduceMotion: true))
        XCTAssertFalse(IntroAutoAdvance.isEnabled(voiceOverRunning: true, reduceMotion: true))
    }

    func testReduceMotionShowsTheStillInsteadOfThePlayer() {
        XCTAssertTrue(IntroAutoAdvance.playsVideo(reduceMotion: false))
        XCTAssertFalse(IntroAutoAdvance.playsVideo(reduceMotion: true))
    }

    // MARK: - Dwell timer

    func testANewTimerIsPausedWithItsWholeDwellLeft() {
        let timer = IntroDwellTimer(dwellSeconds: 5.5)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: 100), 5.5)
    }

    func testRunningTimeCountsDownToZeroAndNoFurther() {
        var timer = IntroDwellTimer(dwellSeconds: 5.5)
        timer.resume(at: 10)
        XCTAssertEqual(timer.remaining(at: 12), 3.5, accuracy: 1e-9)
        XCTAssertEqual(timer.remaining(at: 15.5), 0, accuracy: 1e-9)
        XCTAssertEqual(timer.remaining(at: 30), 0)
    }

    /// The app in the background: the page's time stops with the player and picks up
    /// where it was on return.
    func testTimeInTheBackgroundDoesNotCount() {
        var timer = IntroDwellTimer(dwellSeconds: 6.5)
        timer.resume(at: 0)
        timer.pause(at: 2)
        XCTAssertEqual(timer.remaining(at: 500), 4.5, accuracy: 1e-9)
        timer.resume(at: 500)
        XCTAssertEqual(timer.remaining(at: 503), 1.5, accuracy: 1e-9)
    }

    func testRepeatedResumeAndPauseAreHarmless() {
        var timer = IntroDwellTimer(dwellSeconds: 5.5)
        timer.resume(at: 0)
        timer.resume(at: 3) // still counting from 0
        XCTAssertEqual(timer.remaining(at: 4), 1.5, accuracy: 1e-9)
        timer.pause(at: 4)
        timer.pause(at: 9) // already paused
        XCTAssertEqual(timer.remaining(at: 9), 1.5, accuracy: 1e-9)
    }

    func testAClockGoingBackwardsNeverAddsTime() {
        var timer = IntroDwellTimer(dwellSeconds: 5.5)
        timer.resume(at: 10)
        XCTAssertEqual(timer.remaining(at: 8), 5.5)
        timer.pause(at: 8)
        XCTAssertEqual(timer.remaining(at: 8), 5.5)
    }
}
