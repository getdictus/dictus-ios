// DictusCore/Tests/DictusCoreTests/AdoptedDownloadWatchdogTests.swift
// The three clauses that let a wedged adopted transfer be replaced without bringing #449 back (#690).
import XCTest
@testable import DictusCore

final class AdoptedDownloadWatchdogTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_760_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        epoch.addingTimeInterval(seconds)
    }

    // MARK: - The case the issue is about

    /// Relaunch after the Full Access kill: the task is adopted, the user is looking, and
    /// nothing arrives. At ten seconds it is cancelled.
    func testFiresAtTenSecondsWithoutAByteOnAnAdoptedTaskInTheForeground() {
        XCTAssertTrue(AdoptedDownloadWatchdog.shouldCancel(
            now: at(10),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    func testFiresWellPastTheLimit() {
        XCTAssertTrue(AdoptedDownloadWatchdog.shouldCancel(
            now: at(90),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    func testSilentJustBeforeTheLimit() {
        XCTAssertFalse(AdoptedDownloadWatchdog.shouldCancel(
            now: at(9.9),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    func testTheLimitIsTenSeconds() {
        XCTAssertEqual(AdoptedDownloadWatchdog.silenceLimit, 10)
    }

    // MARK: - The case #449 removed, which must not come back

    /// Backgrounded: iOS throttles the transfer and long silences are normal. However long
    /// it lasts, nothing is cancelled.
    func testNeverFiresInTheBackground() {
        XCTAssertFalse(AdoptedDownloadWatchdog.shouldCancel(
            now: at(3_600),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(0),
            foregroundSince: nil
        ))
    }

    /// Time spent in another app does not count: the silence has to be observed in full
    /// with the app in front. Back from Settings at 60 s, the clock starts at 60 s.
    func testTimeSpentInTheBackgroundDoesNotCount() {
        XCTAssertFalse(AdoptedDownloadWatchdog.shouldCancel(
            now: at(65),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(0),
            foregroundSince: at(60)
        ))
        XCTAssertTrue(AdoptedDownloadWatchdog.shouldCancel(
            now: at(70),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(0),
            foregroundSince: at(60)
        ))
    }

    // MARK: - The loop it must never start

    /// A task this process created — including the one the watchdog re-issues — is never
    /// cancelled, whatever its silence. That is what rules out cancel-and-reissue forever.
    func testNeverFiresOnATaskThisProcessCreated() {
        XCTAssertFalse(AdoptedDownloadWatchdog.shouldCancel(
            now: at(3_600),
            origin: .createdByThisProcess,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    // MARK: - A task that is moving

    /// Bytes arriving reset the clock: an adopted task that is transferring is left alone.
    func testABytePushesTheDeadlineBack() {
        XCTAssertFalse(AdoptedDownloadWatchdog.shouldCancel(
            now: at(15),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(8),
            foregroundSince: at(0)
        ))
        XCTAssertTrue(AdoptedDownloadWatchdog.shouldCancel(
            now: at(18),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(8),
            foregroundSince: at(0)
        ))
    }

    /// A negative limit is a programming error, read as zero rather than as a deadline in
    /// the past that fires before the silence began.
    func testNegativeLimitIsClampedToZero() {
        XCTAssertFalse(AdoptedDownloadWatchdog.shouldCancel(
            now: at(-1),
            origin: .adoptedFromPreviousProcess,
            lastByteAt: at(0),
            foregroundSince: at(0),
            limit: -5
        ))
    }
}
