import XCTest
@testable import DictusCore

/// Behaviour of a dictation start whose audio session refuses to activate (issue #775).
///
/// WHY a fake session rather than `AVAudioSession`: a refused activation needs the audio
/// server to misbehave, which only a device produces. The fake refuses on demand, posts the
/// reset when told, and moves a clock the run's reset wait is timed on, so the tests drive
/// the same loop and the same log line the app runs.
@MainActor
final class AudioSessionActivationRunTests: XCTestCase {

    /// `AVAudioSessionErrorCodeCannotInterruptOthers`, the code #515's capture carried.
    private static let cannotInterruptOthers = NSError(
        domain: NSOSStatusErrorDomain, code: 560_557_684,
        userInfo: [NSLocalizedDescriptionKey: "Session activation failed"])

    /// An audio session that refuses `failuresLeft` activations, then accepts.
    private final class FakeSession {
        var failuresLeft: Int
        var activations = 0
        var resetCount = 0
        var lost = false
        var clock = Date(timeIntervalSince1970: 0)
        /// Post the reset once the clock has moved this far into a wait, in milliseconds.
        var resetAfterMs: Int?
        var lines: [String] = []

        init(failuresLeft: Int) { self.failuresLeft = failuresLeft }

        func activate() throws {
            activations += 1
            if failuresLeft > 0 {
                failuresLeft -= 1
                try AudioSessionActivationPolicy.perform(.setActive, context: { "lost=\(self.lost)" }, log: {
                    self.lines.append($0.formatted())
                }) { throw AudioSessionActivationRunTests.cannotInterruptOthers }
            }
        }

        /// What `mediaServicesWereReset` does to the engine's state.
        func reset() {
            resetCount += 1
            lost = false
        }

        @MainActor
        func run(_ firstActivation: Result<Void, Error>,
                 dropAfterWait: String? = nil) async throws -> Bool {
            var waitedMs = 0
            return try await AudioSessionActivationRun(
                activate: { try self.activate() },
                mediaServicesLost: { self.lost },
                mediaServicesResetCount: { self.resetCount },
                sleep: { ms in
                    self.clock += Double(ms) / 1000
                    waitedMs += ms
                    if let after = self.resetAfterMs, waitedMs >= after, self.resetCount == 0 { self.reset() }
                    return true
                },
                isStillWanted: { _ in true },
                reasonToDropAfterWait: { dropAfterWait },
                log: { self.lines.append("\($0) \($1)") },
                now: { self.clock }
            ).run(after: firstActivation)
        }

        /// The start's own activation, which `startDictation` makes before the run.
        func firstActivation() -> Result<Void, Error> { Result { try activate() } }
    }

    // MARK: - The log line

    /// A refused activation leaves its own line carrying the error, not a swallowed `try?`.
    func testARefusedActivationLogsItsDomainCodeAndDescription() {
        var events: [LogEvent] = []
        XCTAssertThrowsError(
            try AudioSessionActivationPolicy.perform(.setActive, context: { "route=none" }, log: { events.append($0) }) {
                throw Self.cannotInterruptOthers
            }
        ) { error in
            XCTAssertEqual((error as? AudioSessionActivationFailure)?.step, .setActive)
        }

        XCTAssertEqual(events.count, 1)
        let line = events.first?.formatted() ?? ""
        XCTAssertEqual(events.first?.name, "audioSessionActivationFailed")
        XCTAssertEqual(events.first?.level, .error)
        XCTAssertTrue(line.contains("step=setActive"), line)
        XCTAssertTrue(line.contains("domain=\(NSOSStatusErrorDomain)"), line)
        XCTAssertTrue(line.contains("code=560557684"), line)
        XCTAssertTrue(line.contains("status=560557684 '!int'"), line)
        XCTAssertTrue(line.contains("description=\"Session activation failed\""), line)
        XCTAssertTrue(line.contains("route=none"), line)
    }

    /// An activation that works logs nothing.
    func testAnAcceptedActivationLogsNothing() throws {
        var events: [LogEvent] = []
        try AudioSessionActivationPolicy.perform(.setCategory, context: { "" }, log: { events.append($0) }) {}
        XCTAssertTrue(events.isEmpty)
    }

    /// The line reaches the exported file, the way a device capture would show it.
    func testTheRefusedActivationLineReachesTheLogFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_session_activation_\(UUID().uuidString).log")
        PersistentLog.fileURLOverrideForTesting = url
        defer {
            PersistentLog.fileURLOverrideForTesting = nil
            try? FileManager.default.removeItem(at: url)
        }

        XCTAssertThrowsError(
            try AudioSessionActivationPolicy.perform(.setActive, context: { "mediaServicesLost=false route=none" }) {
                throw Self.cannotInterruptOthers
            }
        )
        PersistentLog.flush()
        let log = PersistentLog.read()
        XCTAssertTrue(log.contains("audioSessionActivationFailed step=setActive"), log)
        XCTAssertTrue(log.contains("code=560557684 status=560557684 '!int'"), log)
    }

    // MARK: - Recovery

    /// The first activation is refused and the retry is accepted: the start records.
    func testARefusedFirstActivationRecoversOnTheRetry() async throws {
        let session = FakeSession(failuresLeft: 1)
        let started = try await session.run(session.firstActivation())

        XCTAssertTrue(started)
        XCTAssertEqual(session.activations, 2)
        XCTAssertTrue(session.lines.contains { $0.contains("audioSessionActivationFailed step=setActive") })
        XCTAssertTrue(session.lines.contains { $0.hasPrefix("sessionActivationRetry failedAttempts=1") })
        XCTAssertTrue(session.lines.contains { $0.hasPrefix("sessionActivationRecovered failedAttempts=1 afterReset=false") })
    }

    /// The 2026-10-22 capture: two refusals, no loss line, the reset one second later. The
    /// start waits for that reset and records, instead of showing "tap again".
    func testAResetAfterTheRetryLetsTheFirstDictationRecord() async throws {
        let session = FakeSession(failuresLeft: 2)
        session.resetAfterMs = 1000
        let started = try await session.run(session.firstActivation())

        XCTAssertTrue(started)
        XCTAssertEqual(session.activations, 3)
        XCTAssertTrue(session.lines.contains { $0.contains("sessionActivationWaitedForReset") && $0.contains("reset=true") },
                      session.lines.joined(separator: "\n"))
        XCTAssertTrue(session.lines.contains { $0.hasPrefix("sessionActivationRecovered failedAttempts=2 afterReset=true") })
    }

    /// A lost audio server: the start waits for its reset before activating again.
    func testALostServerIsWaitedForBeforeTheNextActivation() async throws {
        let session = FakeSession(failuresLeft: 1)
        session.lost = true
        session.resetAfterMs = 500
        let first = session.firstActivation()
        session.failuresLeft = 0
        let started = try await session.run(first)

        XCTAssertTrue(started)
        XCTAssertEqual(session.activations, 2, "no retry spent against the dead server")
        XCTAssertFalse(session.lines.contains { $0.hasPrefix("sessionActivationRetry") })
    }

    /// No reset ever comes and every activation is refused: the start fails with the
    /// activation error, after one wait bounded by the policy's timeout.
    func testNoResetFailsWithTheActivationError() async {
        let session = FakeSession(failuresLeft: 10)
        let begin = session.clock
        do {
            _ = try await session.run(session.firstActivation())
            XCTFail("expected the activation error")
        } catch {
            XCTAssertEqual((error as? AudioSessionActivationFailure)?.code, 560_557_684)
        }
        XCTAssertEqual(session.activations, 3)
        let waitedMs = Int(session.clock.timeIntervalSince(begin) * 1000)
        XCTAssertLessThanOrEqual(
            waitedMs,
            AudioSessionActivationPolicy.retryDelayMilliseconds
                + AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds + 50)
    }

    /// The keyboard stopped waiting during the reset wait: drop the start, no engine.
    func testAStartNobodyWaitsForIsDroppedAfterTheWait() async throws {
        let session = FakeSession(failuresLeft: 2)
        session.resetAfterMs = 1000
        let started = try await session.run(session.firstActivation(), dropAfterWait: "keyboardStatus=failed")

        XCTAssertFalse(started)
        XCTAssertEqual(session.activations, 2)
        XCTAssertTrue(session.lines.contains("sessionActivationDropped keyboardStatus=failed"))
    }
}
