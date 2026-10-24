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
    /// One diagnostic line: an action and its details.
    let log: (_ action: String, _ details: String) -> Void
    /// The clock the reset wait is timed on. A test moves it with its own `sleep`.
    let now: () -> Date

    public init(
        activate: @escaping () throws -> Void,
        mediaServicesLost: @escaping () -> Bool,
        mediaServicesResetCount: @escaping () -> Int,
        sleep: @escaping (_ milliseconds: Int) async -> Bool,
        isStillWanted: @escaping (_ label: String) -> Bool,
        reasonToDropAfterWait: @escaping () -> String?,
        log: @escaping (_ action: String, _ details: String) -> Void,
        now: @escaping () -> Date = Date.init
    ) {
        self.activate = activate
        self.mediaServicesLost = mediaServicesLost
        self.mediaServicesResetCount = mediaServicesResetCount
        self.sleep = sleep
        self.isStillWanted = isStillWanted
        self.reasonToDropAfterWait = reasonToDropAfterWait
        self.log = log
        self.now = now
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

        while true {
            let decision = AudioSessionActivationPolicy.decide(
                activated: lastError == nil,
                failedAttempts: failedAttempts,
                mediaServicesLost: mediaServicesLost(),
                hasWaitedForReset: hasWaitedForReset
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
                let started = now()
                while mediaServicesResetCount() == resetCountAtStart
                        && now().timeIntervalSince(started) * 1000 < Double(timeoutMs) {
                    guard await sleep(50) else { return false }
                }
                hasWaitedForReset = true
                let waitedMs = Int(now().timeIntervalSince(started) * 1000)
                log("sessionActivationWaitedForReset",
                    "waitedMs=\(waitedMs) timeoutMs=\(timeoutMs) "
                        + "reset=\(mediaServicesResetCount() != resetCountAtStart) lost=\(mediaServicesLost())")

                // Starting now would record for a dictation nobody is looking at.
                if let reason = reasonToDropAfterWait() {
                    log("sessionActivationDropped", reason)
                    return false
                }
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
