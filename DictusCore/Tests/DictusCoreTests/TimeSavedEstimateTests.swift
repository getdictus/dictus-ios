// DictusCore/Tests/DictusCoreTests/TimeSavedEstimateTests.swift
// The time-saved formula behind the end-of-trial recap (#726).
import XCTest
@testable import DictusCore

final class TimeSavedEstimateTests: XCTestCase {

    func testTheBaselineIsThePapersEnglishKeyboardRate() {
        // Ruan et al. 2017, Table 3 and section 5: 52.24 WPM, iOS keyboard, English.
        XCTAssertEqual(TimeSavedEstimate.keyboardWordsPerMinute, 52.24)
    }

    func testSavedIsTypingTimeMinusSpokenTime() {
        // 5 224 words typed at 52.24 WPM: 100 min = 6 000 s. Spoken in 1 000 s.
        XCTAssertEqual(TimeSavedEstimate.seconds(words: 5_224, audioSeconds: 1_000), 5_000)
        // 100 words: 114.85 s of typing, 30 s spoken, rounded down.
        XCTAssertEqual(TimeSavedEstimate.seconds(words: 100, audioSeconds: 30), 84)
    }

    func testSavedIsNeverNegative() {
        // Three words over a long pause: the audio outlasts the typing estimate.
        XCTAssertEqual(TimeSavedEstimate.seconds(words: 3, audioSeconds: 60), 0)
        XCTAssertEqual(TimeSavedEstimate.seconds(words: 0, audioSeconds: 0), 0)
        XCTAssertEqual(TimeSavedEstimate.seconds(words: -5, audioSeconds: -5), 0)
    }

    func testRoundingGoesDownToMinutesThenToWholeHours() {
        XCTAssertNil(TimeSavedEstimate.rounded(seconds: 0))
        XCTAssertNil(TimeSavedEstimate.rounded(seconds: 59), "under a minute says nothing")
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 60), .minutes(1))
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 59 * 60 + 59), .minutes(59))
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 3_600), .hours(1))
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 4 * 3_600 + 59 * 60), .hours(4), "about 4 h, never 5")
    }
}
