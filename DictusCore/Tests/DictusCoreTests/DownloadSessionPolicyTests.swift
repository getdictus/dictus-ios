// DictusCore/Tests/DictusCoreTests/DownloadSessionPolicyTests.swift
// Which session a model download chunk goes to, and which go back on backgrounding (#707).
import XCTest
@testable import DictusCore

final class DownloadSessionPolicyTests: XCTestCase {

    // MARK: - Routing a new chunk

    /// The normal case: no stall seen, the background session carries the download.
    func testForegroundWithoutFallbackUsesTheBackgroundSession() {
        XCTAssertEqual(
            DownloadSessionPolicy.session(appInForeground: true, fallbackEngaged: false),
            .background
        )
    }

    /// The watchdog has moved a chunk during this foreground stay: the next chunks follow
    /// it rather than each waiting out the silence limit on a session known to be silent.
    func testForegroundWithFallbackUsesTheForegroundSession() {
        XCTAssertEqual(
            DownloadSessionPolicy.session(appInForeground: true, fallbackEngaged: true),
            .foreground
        )
    }

    /// A process about to be suspended cannot carry a default-session transfer: whatever
    /// the fallback says, a chunk requested in the background goes to the background
    /// session. This is the retry that a backoff schedules and that fires after the user
    /// left, and the re-issue of a hand-off.
    func testBackgroundAlwaysUsesTheBackgroundSession() {
        XCTAssertEqual(
            DownloadSessionPolicy.session(appInForeground: false, fallbackEngaged: true),
            .background
        )
        XCTAssertEqual(
            DownloadSessionPolicy.session(appInForeground: false, fallbackEngaged: false),
            .background
        )
    }

    // MARK: - Handing back on backgrounding

    func testForegroundSessionTasksAreHandedBack() {
        XCTAssertTrue(DownloadSessionPolicy.shouldHandBack(taskOn: .foreground))
    }

    /// A background-session task is where a backgrounded download belongs: cancelling it
    /// would only re-pay its bytes.
    func testBackgroundSessionTasksStay() {
        XCTAssertFalse(DownloadSessionPolicy.shouldHandBack(taskOn: .background))
    }

    // MARK: - The two policies together

    /// Whatever the watchdog moves goes to a session it never cancels on: one move per
    /// chunk per foreground stay, never a loop.
    func testAMovedChunkLandsWhereTheWatchdogNeverLooks() {
        let destination = DownloadSessionPolicy.session(appInForeground: true, fallbackEngaged: true)
        let epoch = Date(timeIntervalSince1970: 0)
        XCTAssertFalse(SilentDownloadTaskWatchdog.shouldCancel(
            now: epoch.addingTimeInterval(10_000),
            session: destination,
            lastByteAt: epoch,
            foregroundSince: epoch
        ))
    }

    /// The log prints these exact words in `session=`.
    func testRawValuesMatchTheLog() {
        XCTAssertEqual(DownloadSessionKind.background.rawValue, "bg")
        XCTAssertEqual(DownloadSessionKind.foreground.rawValue, "fg")
    }
}
