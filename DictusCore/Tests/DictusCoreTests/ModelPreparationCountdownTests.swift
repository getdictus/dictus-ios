import XCTest
@testable import DictusCore

/// Issue #533: the preparation screen said how long a first compile takes but never how
/// far along it was. These tests hold the countdown's rules, above all the one #432 bites
/// on: it may never announce an end it cannot deliver.
final class ModelPreparationCountdownTests: XCTestCase {

    /// Turbo 632 MB's measured first preparation, the reading the countdown runs against.
    private let turbo = 236

    // MARK: - The Turbo walk-through

    /// 4 → 3 → 2 → under a minute: three visible decrements across the wait, which is the
    /// amended criterion 1 of the issue.
    func testTurboStepsFromFourMinutesToTheFloor() {
        let expectations: [(elapsed: Int, expected: ModelPreparationCountdown)] = [
            (0, .minutesLeft(4)),
            (56, .minutesLeft(3)),
            (116, .minutesLeft(2)),
            (117, .minutesLeft(2)),
            (176, .underAMinute),
            (236, .underAMinute)
        ]
        for (elapsed, expected) in expectations {
            XCTAssertEqual(
                ModelPreparationCountdown.at(elapsedSeconds: elapsed, measuredSeconds: turbo),
                expected,
                "elapsed \(elapsed)s"
            )
        }
    }

    /// The overrun is the expected case on slower hardware. The floor holds; it never
    /// expires, never reaches zero, never goes negative.
    func testAnOverrunHoldsTheFloor() {
        XCTAssertEqual(
            ModelPreparationCountdown.at(elapsedSeconds: 10_000, measuredSeconds: turbo),
            .underAMinute
        )
    }

    /// A clock that went backwards is the start of the wait, not extra time on top of it.
    func testANegativeElapsedTimeCountsAsTheStart() {
        XCTAssertEqual(
            ModelPreparationCountdown.at(elapsedSeconds: -5, measuredSeconds: turbo),
            .minutesLeft(4)
        )
    }

    // MARK: - When there is nothing to count down from

    /// Unmeasured, a typo, or a brief wait (Medium's 32 s): no countdown at all.
    func testNoCountdownWithoutAMinutesMeasurement() {
        for measured in [nil, 0, -1, 32] as [Int?] {
            XCTAssertNil(
                ModelPreparationCountdown.at(elapsedSeconds: 0, measuredSeconds: measured),
                "measured \(String(describing: measured))"
            )
        }
    }

    // MARK: - Agreement with the notice

    /// At the first second the countdown and the notice under it round up the same
    /// reading, so the line above can never announce more than the line below.
    ///
    /// From 61 s and not 60: see `testAMeasurementOfExactlyOneMinuteStartsAtTheFloor`.
    func testTheFirstFigureIsTheNoticeFigure() {
        for measured in 61...600 {
            guard case .minutes(let noticeMinutes) = ModelPreparationWait.forMeasuredSeconds(measured) else {
                XCTFail("\(measured)s should be announced in minutes")
                return
            }
            XCTAssertEqual(
                ModelPreparationCountdown.at(elapsedSeconds: 0, measuredSeconds: measured),
                .minutesLeft(noticeMinutes),
                "measured \(measured)s"
            )
        }
    }

    /// The one reading where the countdown and the notice cannot agree, pinned so that
    /// changing it is a decision rather than an accident.
    ///
    /// The countdown is a function of the time remaining, and the Turbo walk-through needs
    /// 60 s remaining to read "less than a minute" (elapsed 176 of 236). A measurement of
    /// exactly 60 s is 60 s remaining at the first second, so it starts at the floor, while
    /// the notice lifts the same 60 s to its two-minute minimum. The countdown is the lower
    /// of the two here. No catalogue entry is anywhere near this value (32 s and 236 s).
    func testAMeasurementOfExactlyOneMinuteStartsAtTheFloor() {
        XCTAssertEqual(ModelPreparationWait.forMeasuredSeconds(60), .minutes(2))
        XCTAssertEqual(
            ModelPreparationCountdown.at(elapsedSeconds: 0, measuredSeconds: 60),
            .underAMinute
        )
    }

    /// The copy has no plural rule, so 1 must never reach it, at any second of any wait.
    func testTheCountdownNeverNamesASingleMinute() {
        for measured in [60, 61, 90, 119, 120, turbo, 600] {
            for elapsed in 0...(measured + 120) {
                if case .minutesLeft(let minutes) = ModelPreparationCountdown.at(
                    elapsedSeconds: elapsed, measuredSeconds: measured
                ) {
                    XCTAssertGreaterThanOrEqual(
                        minutes, ModelPreparationWait.minimumNamedMinutes,
                        "measured \(measured)s, elapsed \(elapsed)s"
                    )
                }
            }
        }
    }
}
