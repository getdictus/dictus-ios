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
        /// `LogEvent`s the run logged of its own (#899).
        var events: [LogEvent] = []
        /// Whether the keyboard still waits, read at a given point of the clock (#899).
        var keyboardWaiting: (_ waitedMs: Int) -> Bool = { _ in false }
        /// Why the start is dropped after a wait, at a given point of the clock; `nil` to go on.
        var dropReason: ((_ waitedMs: Int) -> String?)?

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
                reasonToDropAfterWait: { self.dropReason?(waitedMs) ?? dropAfterWait },
                keyboardStillWaiting: { self.keyboardWaiting(waitedMs) },
                log: { self.lines.append("\($0) \($1)") },
                logEvent: { self.events.append($0) },
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
        let waitedMs = Int((session.clock.timeIntervalSince(begin) * 1000).rounded())
        XCTAssertLessThanOrEqual(
            waitedMs,
            AudioSessionActivationPolicy.retryDelayMilliseconds
                + AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds)
    }

    /// The trade-off PR #801 makes, pinned: a `'!int'` refusal (`cannotInterruptOthers`) with
    /// no reset ever posted costs the one retry and the one reset wait, never more, then
    /// fails with the activation error. That error is the "tap again" path: the app's
    /// `activationStep` rethrows it as `AudioEngineError.sessionActivationFailed`, whose
    /// sentence is "Dictation could not start. Tap the microphone again."
    ///
    /// WHY `'!int'` still waits rather than failing at once: #515's capture shows `'!int'`
    /// refusing the activation right after an interruption, and the next attempt working.
    /// It is a transient refusal, so it does not tell another app holding the session apart
    /// from an audio stack still coming back, and #775's own code was never logged.
    func testACannotInterruptOthersRefusalWithNoResetFailsWithinTheBound() async {
        let session = FakeSession(failuresLeft: .max)
        let begin = session.clock
        var thrown: Error?
        do {
            let started = try await session.run(session.firstActivation())
            XCTFail("expected the activation error, got started=\(started)")
        } catch {
            thrown = error
        }

        let failure = thrown as? AudioSessionActivationFailure
        XCTAssertEqual(failure?.step, .setActive)
        XCTAssertEqual(failure?.code, 560_557_684)
        XCTAssertEqual(failure?.status, "560557684 '!int'")
        XCTAssertEqual(session.activations, 3, "first, retry, after the wait")
        XCTAssertEqual(session.resetCount, 0)

        let elapsedMs = Int((session.clock.timeIntervalSince(begin) * 1000).rounded())
        XCTAssertLessThanOrEqual(
            elapsedMs,
            AudioSessionActivationPolicy.retryDelayMilliseconds
                + AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds)
        XCTAssertLessThanOrEqual(elapsedMs, 3250)
        XCTAssertTrue(session.lines.contains { $0.hasPrefix("sessionActivationWaitedForReset") && $0.contains("reset=false") },
                      session.lines.joined(separator: "\n"))
        XCTAssertFalse(session.lines.contains { $0.hasPrefix("sessionActivationRecovered") })
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

    // MARK: - A reset that outlasts the wait (#899)

    /// The 2026-11-04 capture: `'msrv'`, a loss, and a reset that lands after the 3 s wait.
    /// While the keyboard still waits, the start keeps waiting, logs the retry and records,
    /// instead of leaving the keyboard on `requested`.
    func testALateResetStartsTheDictationTheKeyboardStillWaitsFor() async throws {
        let session = FakeSession(failuresLeft: 2)
        session.lost = true
        session.resetAfterMs = 4500
        session.keyboardWaiting = { _ in true }
        let first = session.firstActivation()
        let started = try await session.run(first)

        XCTAssertTrue(started, session.lines.joined(separator: "\n"))
        XCTAssertEqual(session.activations, 3, "first, after the wait, after the late reset")
        XCTAssertEqual(session.events.map(\.name), ["coldStartRetryAfterMediaServicesReset"])
        XCTAssertEqual(session.events.first?.formatted().contains("waitedMs=1500 failedAttempts=2"), true,
                       session.events.first?.formatted() ?? "")
        XCTAssertTrue(session.lines.contains { $0.hasPrefix("sessionActivationAwaitedLateReset") && $0.contains("reset=true") })
        XCTAssertTrue(session.lines.contains { $0.hasPrefix("sessionActivationRecovered failedAttempts=2 afterReset=true") })
    }

    /// Nobody waits (an in-app start, or DictusApp no longer in front): the same late reset
    /// changes nothing, the start fails after the 3 s wait as before.
    func testALateResetIsNotWaitedForWhenNobodyWaits() async {
        let session = FakeSession(failuresLeft: 3)
        session.lost = true
        session.resetAfterMs = 4500
        do {
            _ = try await session.run(session.firstActivation())
            XCTFail("expected the activation error")
        } catch {
            XCTAssertEqual((error as? AudioSessionActivationFailure)?.code, 560_557_684)
        }
        XCTAssertEqual(session.activations, 2)
        XCTAssertTrue(session.events.isEmpty)
    }

    /// No reset ever comes: one late wait, bounded, then the activation error ("tap again").
    func testNoLateResetFailsWithinBothWaits() async {
        let session = FakeSession(failuresLeft: .max)
        session.keyboardWaiting = { _ in true }
        let begin = session.clock
        do {
            _ = try await session.run(session.firstActivation())
            XCTFail("expected the activation error")
        } catch {
            XCTAssertEqual((error as? AudioSessionActivationFailure)?.code, 560_557_684)
        }
        let elapsedMs = Int((session.clock.timeIntervalSince(begin) * 1000).rounded())
        XCTAssertEqual(elapsedMs, AudioSessionActivationPolicy.retryDelayMilliseconds
            + AudioSessionActivationPolicy.mediaServicesResetTimeoutMilliseconds
            + AudioSessionActivationPolicy.lateMediaServicesResetTimeoutMilliseconds)
        XCTAssertEqual(session.activations, 3, "no activation without a reset during the late wait")
        XCTAssertTrue(session.events.isEmpty)
        XCTAssertTrue(session.lines.contains { $0.hasPrefix("sessionActivationAwaitedLateReset") && $0.contains("reset=false") })
    }

    /// The keyboard gives up during the late wait: the wait stops and the start is dropped
    /// silently, with no activation and no engine.
    func testTheLateWaitStopsWhenTheKeyboardGivesUp() async throws {
        let session = FakeSession(failuresLeft: .max)
        session.lost = true
        session.keyboardWaiting = { $0 < 4000 }
        session.dropReason = { $0 < 4000 ? nil : "keyboardStatus=idle" }
        let begin = session.clock
        let started = try await session.run(session.firstActivation())

        XCTAssertFalse(started)
        XCTAssertEqual(session.activations, 2, "no activation after the keyboard gave up")
        XCTAssertTrue(session.events.isEmpty)
        XCTAssertTrue(session.lines.contains("sessionActivationDropped keyboardStatus=idle"))
        let elapsedMs = Int((session.clock.timeIntervalSince(begin) * 1000).rounded())
        XCTAssertEqual(elapsedMs, 4000, "the wait stops at the first poll after the keyboard gave up")
    }

    /// DictusApp leaves the foreground during the late wait (a swipe back, the keyboard still on
    /// `requested`): the wait stops and the start fails with "tap again", because the engine
    /// could not start from the background anyway (#853).
    func testTheLateWaitStopsWhenDictusAppLeavesTheForeground() async {
        let session = FakeSession(failuresLeft: .max)
        session.lost = true
        session.keyboardWaiting = { $0 < 4000 }
        do {
            _ = try await session.run(session.firstActivation())
            XCTFail("expected the activation error")
        } catch {
            XCTAssertEqual((error as? AudioSessionActivationFailure)?.code, 560_557_684)
        }
        XCTAssertEqual(session.activations, 2)
        XCTAssertTrue(session.events.isEmpty)
        XCTAssertTrue(session.lines.contains { $0.hasPrefix("sessionActivationAwaitedLateReset waitedMs=1000") })
    }

    /// The reset comes during the late wait but the session still refuses: one retry, then
    /// "tap again", never a second wait.
    func testARefusalAfterTheLateResetFailsWithoutASecondWait() async {
        let session = FakeSession(failuresLeft: .max)
        session.lost = true
        session.resetAfterMs = 4500
        session.keyboardWaiting = { _ in true }
        do {
            _ = try await session.run(session.firstActivation())
            XCTFail("expected the activation error")
        } catch {
            XCTAssertEqual((error as? AudioSessionActivationFailure)?.code, 560_557_684)
        }
        XCTAssertEqual(session.activations, 3)
        XCTAssertEqual(session.events.count, 1)
        XCTAssertEqual(session.lines.filter { $0.hasPrefix("sessionActivationAwaitedLateReset") }.count, 1)
    }
}
