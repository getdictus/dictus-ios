// DictusCore/Tests/DictusCoreTests/SilentDownloadTaskWatchdogTests.swift
// The three clauses that let a silent background-session transfer be moved without bringing #449 back (#690, #707).
import XCTest
@testable import DictusCore

final class SilentDownloadTaskWatchdogTests: XCTestCase {

    private let epoch = Date(timeIntervalSince1970: 1_760_000_000)

    private func at(_ seconds: TimeInterval) -> Date {
        epoch.addingTimeInterval(seconds)
    }

    // MARK: - The case the issue is about

    /// A background-session task, the user looking, and nothing arrives: at thirty seconds
    /// it is cancelled so its chunk can move to the foreground session.
    func testFiresAtThirtySecondsWithoutAByteOnABackgroundTaskInTheForeground() {
        XCTAssertTrue(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(30),
            session: .background,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    func testFiresWellPastTheLimit() {
        XCTAssertTrue(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(90),
            session: .background,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    func testSilentJustBeforeTheLimit() {
        XCTAssertFalse(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(29.9),
            session: .background,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    /// #690's ten seconds no longer fire: a new task's legitimate start can take longer.
    func testTenSecondsNoLongerFire() {
        XCTAssertFalse(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(10),
            session: .background,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    func testTheLimitIsThirtySeconds() {
        XCTAssertEqual(SilentDownloadTaskWatchdog.silenceLimit, 30)
    }

    // MARK: - The case #449 removed, which must not come back

    /// Backgrounded: iOS throttles the transfer and long silences are normal. However long
    /// it lasts, nothing is cancelled.
    func testNeverFiresInTheBackground() {
        XCTAssertFalse(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(3_600),
            session: .background,
            lastByteAt: at(0),
            foregroundSince: nil
        ))
    }

    /// Time spent in another app does not count: the silence has to be observed in full
    /// with the app in front. Back from Settings at 60 s, the clock starts at 60 s.
    func testTimeSpentInTheBackgroundDoesNotCount() {
        XCTAssertFalse(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(85),
            session: .background,
            lastByteAt: at(0),
            foregroundSince: at(60)
        ))
        XCTAssertTrue(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(90),
            session: .background,
            lastByteAt: at(0),
            foregroundSince: at(60)
        ))
    }

    // MARK: - The loop it must never start

    /// A foreground-session task — which is where every chunk the watchdog moves goes — is
    /// never cancelled, whatever its silence. That is what rules out cancel-and-move
    /// forever; a stall there is the foreground session's own idle timeout's to report.
    func testNeverFiresOnAForegroundSessionTask() {
        XCTAssertFalse(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(3_600),
            session: .foreground,
            lastByteAt: at(0),
            foregroundSince: at(0)
        ))
    }

    // MARK: - A task that is moving

    /// Bytes arriving reset the clock: a background task that is transferring is left alone.
    func testABytePushesTheDeadlineBack() {
        XCTAssertFalse(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(35),
            session: .background,
            lastByteAt: at(8),
            foregroundSince: at(0)
        ))
        XCTAssertTrue(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(38),
            session: .background,
            lastByteAt: at(8),
            foregroundSince: at(0)
        ))
    }

    /// A negative limit is a programming error, read as zero rather than as a deadline in
    /// the past that fires before the silence began.
    func testNegativeLimitIsClampedToZero() {
        XCTAssertFalse(SilentDownloadTaskWatchdog.shouldCancel(
            now: at(-1),
            session: .background,
            lastByteAt: at(0),
            foregroundSince: at(0),
            limit: -5
        ))
    }

    // MARK: - Origin, logged but not decided on

    /// The log prints the origin with these exact words; the device captures on #690 and
    /// #707 are read with them.
    func testOriginRawValuesMatchTheLog() {
        XCTAssertEqual(DownloadTaskOrigin.adoptedFromPreviousProcess.rawValue, "adopted")
        XCTAssertEqual(DownloadTaskOrigin.createdByThisProcess.rawValue, "new")
    }
}
