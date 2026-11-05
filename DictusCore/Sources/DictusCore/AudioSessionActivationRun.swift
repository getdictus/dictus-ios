// DictusCore/Sources/DictusCore/AudioSessionActivationRun.swift
// Runs AudioSessionActivationPolicy for one dictation start, and logs a refused activation (#775).
//
// WHY in DictusCore and not next to `UnifiedAudioEngine`: the loop and the log line are the
// two things #775 asks to be proven, and `swift test` here is the only suite the repo runs.
// The `AVAudioSession` calls, the engine and the keyboard's status reach it as closures, so a
// test can refuse an activation, post a reset and read the real log line.
import Foundation

/// A refused `setCategory` or `setActive(true)`, with the parts of the error the log carries.
public struct AudioSessionActivationFailure: Error, Equatable, Sendable {
    public let step: AudioSessionActivationStep
    public let domain: String
    public let code: Int
    public let errorDescription: String

    public init(step: AudioSessionActivationStep, error: Error) {
        let nsError = error as NSError
        self.step = step
        domain = nsError.domain
        code = nsError.code
        errorDescription = nsError.localizedDescription
    }

    /// `code` as the log shows it: `560557684 '!int'`.
    public var status: String { AudioSessionActivationPolicy.statusDescription(code) }
}

extension AudioSessionActivationPolicy {

    /// Run one `AVAudioSession` call. On a throw, log `audioSessionActivationFailed` with the
    /// error's domain, code and description, then throw it as `AudioSessionActivationFailure`.
    ///
    /// - Parameter context: the session state at the throw, read only when the call throws.
    public static func perform(
        _ step: AudioSessionActivationStep,
        context: () -> String,
        log: (LogEvent) -> Void = { PersistentLog.log($0) },
        _ call: () throws -> Void
    ) throws {
        do {
            try call()
        } catch {
            let failure = AudioSessionActivationFailure(step: step, error: error)
            log(.audioSessionActivationFailed(
                step: step.rawValue,
                domain: failure.domain,
                code: failure.code,
                status: failure.status,
                errorDescription: failure.errorDescription,
                context: context()
            ))
            throw failure
        }
    }
}

/// One dictation start's way through `AudioSessionActivationPolicy`: activate, retry, wait
/// for the audio server, or give up.
///
/// `@MainActor` because every closure reads the audio engine, which lives there.
@MainActor
public struct AudioSessionActivationRun {
    /// Activate the session. Throws when `setCategory` or `setActive(true)` refuses.
    let activate: () throws -> Void
    /// Whether `mediaServicesWereLost` is raised with no reset after it.
    let mediaServicesLost: () -> Bool
    /// How many `mediaServicesWereReset` the process has seen. A change is a reset.
    let mediaServicesResetCount: () -> Int
    /// Pause; `false` when the start's task was cancelled during it.
    let sleep: (_ milliseconds: Int) async -> Bool
    /// Whether the start is still wanted: not abandoned, not cancelled. `label` names the
    /// point it is asked at, for the caller's own log.
    let isStillWanted: (_ label: String) -> Bool
    /// After a wait, whether anyone is still waiting for this start (the keyboard may have
    /// given up). `nil` to go on; otherwise the reason to drop it, for the log.
    let reasonToDropAfterWait: () -> String?
    /// Whether the keyboard still shows this start as `requested`, with DictusApp in front
    /// (#899). Read before and during the late-reset wait; `false` for any other start.
    let keyboardStillWaiting: () -> Bool
    /// One diagnostic line: an action and its details.
    let log: (_ action: String, _ details: String) -> Void
    /// A `LogEvent` of its own: the late-reset retry (#899).
    let logEvent: (LogEvent) -> Void
    /// The clock the reset wait is timed on. A test moves it with its own `sleep`.
    let now: () -> Date

    public init(
        activate: @escaping () throws -> Void,
        mediaServicesLost: @escaping () -> Bool,
        mediaServicesResetCount: @escaping () -> Int,
        sleep: @escaping (_ milliseconds: Int) async -> Bool,
        isStillWanted: @escaping (_ label: String) -> Bool,
        reasonToDropAfterWait: @escaping () -> String?,
        keyboardStillWaiting: @escaping () -> Bool = { false },
        log: @escaping (_ action: String, _ details: String) -> Void,
        logEvent: @escaping (LogEvent) -> Void = { PersistentLog.log($0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.activate = activate
        self.mediaServicesLost = mediaServicesLost
        self.mediaServicesResetCount = mediaServicesResetCount
        self.sleep = sleep
        self.isStillWanted = isStillWanted
        self.reasonToDropAfterWait = reasonToDropAfterWait
        self.keyboardStillWaiting = keyboardStillWaiting
        self.log = log
        self.logEvent = logEvent
        self.now = now
    }

    /// Whole milliseconds since `start`, rounded so a clock that adds 0.05 s sixty times
    /// reads 3000, not 2999.
    private func milliseconds(since start: Date) -> Int {
        Int((now().timeIntervalSince(start) * 1000).rounded())
    }

    /// Pause until a reset lands after `resetCountAtStart`, `keepWaiting` turns false, or
    /// `timeoutMs` has passed. Each pause is capped at what is left, so the wait never asks for
    /// more than `timeoutMs` in total: a full 50 ms poll after 2990 ms used to overrun it.
    /// - Returns: the milliseconds waited, or `nil` when the task was cancelled.
    private func waitForReset(after resetCountAtStart: Int, timeoutMs: Int,
                              while keepWaiting: () -> Bool = { true }) async -> Int? {
        let started = now()
        while mediaServicesResetCount() == resetCountAtStart && keepWaiting() {
            let remainingMs = timeoutMs - milliseconds(since: started)
            guard remainingMs > 0 else { break }
            guard await sleep(min(50, remainingMs)) else { return nil }
        }
        return milliseconds(since: started)
    }

    /// - Parameter firstActivation: how the start's own activation went.
    /// - Returns: `true` to start the engine, `false` to drop the start silently.
    /// - Throws: the last activation error when the policy gives up.
    public func run(after firstActivation: Result<Void, Error>) async throws -> Bool {
        // A reset seen before this start began says nothing about this start's failures.
        let resetCountAtStart = mediaServicesResetCount()
        var lastError: Error?
        if case .failure(let error) = firstActivation { lastError = error }
        var failedAttempts = lastError == nil ? 0 : 1
        var hasWaitedForReset = false
        var hasAwaitedLateReset = false

        while true {
            let decision = AudioSessionActivationPolicy.decide(
                activated: lastError == nil,
                failedAttempts: failedAttempts,
                mediaServicesLost: mediaServicesLost(),
                hasWaitedForReset: hasWaitedForReset,
                resetSeen: mediaServicesResetCount() != resetCountAtStart,
                keyboardStillWaiting: keyboardStillWaiting(),
                hasAwaitedLateReset: hasAwaitedLateReset
            )

            switch decision {
            case .startRecording:
                if failedAttempts > 0 {
                    log("sessionActivationRecovered",
                        "failedAttempts=\(failedAttempts) afterReset=\(hasWaitedForReset)")
                }
                return true

            case .fail:
                // `.fail` is only decided for a failed activation, so `lastError` is set.
                throw lastError ?? AudioSessionActivationFailure(
                    step: .setActive, error: NSError(domain: "DictusAudioSession", code: 0))

            case .retryActivation(let delayMs):
                log("sessionActivationRetry", "failedAttempts=\(failedAttempts) delayMs=\(delayMs)")
                guard await sleep(delayMs) else { return false }

            case .waitForMediaServicesReset(let timeoutMs):
                // Ends on a reset during this start. A loss flag still raised after one is
                // a loss that reset cleared and a later one raised: the timeout bounds it.
                guard let waitedMs = await waitForReset(after: resetCountAtStart, timeoutMs: timeoutMs) else {
                    return false
                }
                hasWaitedForReset = true
                log("sessionActivationWaitedForReset",
                    "waitedMs=\(waitedMs) timeoutMs=\(timeoutMs) "
                        + "reset=\(mediaServicesResetCount() != resetCountAtStart) lost=\(mediaServicesLost())")

                // Starting now would record for a dictation nobody is looking at.
                if let reason = reasonToDropAfterWait() {
                    log("sessionActivationDropped", reason)
                    return false
                }
            case .awaitLateMediaServicesReset(let timeoutMs):
                // #899: stops as soon as the keyboard gives up or DictusApp leaves the
                // foreground, where the engine could not start anyway (#853).
                hasAwaitedLateReset = true
                guard let waitedMs = await waitForReset(
                    after: resetCountAtStart, timeoutMs: timeoutMs, while: keyboardStillWaiting) else {
                    return false
                }
                let reset = mediaServicesResetCount() != resetCountAtStart
                log("sessionActivationAwaitedLateReset",
                    "waitedMs=\(waitedMs) timeoutMs=\(timeoutMs) reset=\(reset) keyboardWaiting=\(keyboardStillWaiting())")
                guard reset else {
                    if let reason = reasonToDropAfterWait() {
                        log("sessionActivationDropped", reason)
                        return false
                    }
                    // No reset: the refusal that sent the start here is the one to report.
                    throw lastError ?? AudioSessionActivationFailure(
                        step: .setActive, error: NSError(domain: "DictusAudioSession", code: 0))
                }
                logEvent(.coldStartRetryAfterMediaServicesReset(waitedMs: waitedMs, failedAttempts: failedAttempts))
            }

            guard isStillWanted("session activation retry") else { return false }
            do {
                try activate()
                lastError = nil
            } catch {
                lastError = error
                failedAttempts += 1
            }
        }
    }
}
