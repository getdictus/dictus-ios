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

    func testRoundingGoesDownToMinutesThenToHoursAndMinutes() {
        XCTAssertNil(TimeSavedEstimate.rounded(seconds: 0))
        XCTAssertNil(TimeSavedEstimate.rounded(seconds: 59), "under a minute says nothing")
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 60), .minutes(1))
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 59 * 60 + 59), .minutes(59))
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 3_600), .hours(1, minutes: 0))
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 3_600 + 58 * 60), .hours(1, minutes: 58), "1 h 58, not 1 h")
        XCTAssertEqual(TimeSavedEstimate.rounded(seconds: 4 * 3_600 + 59 * 60 + 59), .hours(4, minutes: 59),
                       "rounded down, never 5 h")
    }

    /// The figure the user reads never drops when the time saved grows, across the
    /// hour and every boundary after it. Whole hours from 60 min did: 1 h 58 read
    /// "about 1 h", less than the "about 59 min" just under it.
    func testTheRoundedFigureNeverDecreasesAsTimeSavedGrows() {
        func shownMinutes(_ seconds: Int) -> Int {
            switch TimeSavedEstimate.rounded(seconds: seconds) {
            case nil: return 0
            case .minutes(let minutes): return minutes
            case .hours(let hours, let minutes): return hours * 60 + minutes
            }
        }
        var previous = 0
        for seconds in stride(from: 0, through: 3 * 3_600, by: 30) {
            let shown = shownMinutes(seconds)
            XCTAssertGreaterThanOrEqual(shown, previous, "dropped at \(seconds) s")
            XCTAssertLessThanOrEqual(shown * 60, seconds, "claims more than the formula at \(seconds) s")
            previous = shown
        }
    }
}
