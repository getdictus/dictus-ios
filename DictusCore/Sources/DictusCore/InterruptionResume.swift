// DictusCore/Sources/DictusCore/InterruptionResume.swift
// Bringing the warm engine back when an audio interruption ends with `.shouldResume` (#353).
// The decision and its order of operations live here so they run under `swift test`;
// `UnifiedAudioEngine` supplies the AVFoundation and ActivityKit halves.

import Foundation

/// What the engine was doing at the moment an interruption began, read before the
/// `.began` teardown erases it.
public enum InterruptedEngineState: Equatable, Sendable {
    /// Nothing of ours left the engine warm (no idle release armed): nothing to bring back.
    /// Not read from `AVAudioEngine.isRunning`, which a call can clear before `.began`
    /// is delivered (#353, device 2026-10-25).
    case cold
    /// A dictation was capturing. The interruption fails it, as before #353, and a
    /// resume must never restart a recording behind the user's back.
    case recording
    /// Warm and idle, with the idle release armed: the standby state of #106 / #430.
    /// `idleSince` and `interval` are the window that release was measuring.
    case standby(idleSince: Date, interval: TimeInterval)
}

/// Whether an interruption that just ended may bring the warm engine back.
public enum InterruptionResumePlan: Equatable, Sendable {
    /// Restart, and re-arm the release so it fires at the deadline the interrupted
    /// window already had, `remaining` seconds from now.
    case resume(idleSince: Date, interval: TimeInterval, remaining: TimeInterval)
    case skip(InterruptionResumeSkip)
}

/// Why an ended interruption left the engine cold. The raw value is the log token.
public enum InterruptionResumeSkip: String, Equatable, Sendable {
    /// iOS did not say the app may resume. Behavior before #353, unchanged.
    case noShouldResume
    /// No `.began` was seen, or the engine was not running when it came.
    case wasCold
    case wasRecording
    /// The idle window ran out during the interruption: the release would have
    /// happened anyway, so there is nothing to restore.
    case standbyExpired
    /// Something already started the engine during the interruption (the app came
    /// to the foreground and warmed up). It owns the warm state and its timer.
    case alreadyRunning
}

public enum InterruptionResumePolicy {

    /// The plan for an interruption that ended.
    ///
    /// WHY the remaining time and not a fresh window: the window bounds how long the
    /// engine sits warm after the user last used Dictus (#106, #256). A call is not a
    /// use. Restarting it from the resume would let a run of calls keep the engine warm
    /// indefinitely with nobody dictating, which is the unbounded state #256 removed.
    public static func plan(
        shouldResume: Bool,
        interrupted: InterruptedEngineState?,
        engineAlreadyRunning: Bool,
        now: Date
    ) -> InterruptionResumePlan {
        guard shouldResume else { return .skip(.noShouldResume) }
        switch interrupted ?? .cold {
        case .cold:
            return .skip(.wasCold)
        case .recording:
            return .skip(.wasRecording)
        case let .standby(idleSince, interval):
            guard !engineAlreadyRunning else { return .skip(.alreadyRunning) }
            let remaining = interval - now.timeIntervalSince(idleSince)
            guard remaining > 0 else { return .skip(.standbyExpired) }
            return .resume(idleSince: idleSince, interval: interval, remaining: remaining)
        }
    }
}

/// The operations a resume needs from the app. `UnifiedAudioEngine` is the real one;
/// tests pass a fake.
@MainActor
public protocol InterruptionResumeTarget: AnyObject {
    /// The state our code left the engine in, read at `.began` before any teardown.
    var engineStateForInterruption: InterruptedEngineState { get }
    var isEngineRunning: Bool { get }
    /// The `.began` teardown: stop the engine, drop the idle release, tell the Live
    /// Activity and the dictation pipeline. Unchanged by #353.
    func tearDownForInterruption()
    /// `setCategory` + `setActive(true)`.
    func reactivateSession() throws
    /// Start the engine and mute its input, the at-rest state of #430. Returns whether
    /// the input is muted afterwards.
    func startEngineAtRest() throws -> Bool
    /// Undo a resume that did not reach the at-rest state: engine stopped, input
    /// unmuted, session released. Leaves the state a failed resume found, so the next
    /// tap takes the cold-start path it took before #353.
    func abandonResume()
    /// Arm the idle release for the window `idleSince` + `interval`.
    func armIdleRelease(idleSince: Date, interval: TimeInterval)
    /// Ask for the standby Live Activity. Returns the outcome's log token.
    func restartStandbyLiveActivity() -> String
}

/// Owns what has to survive between `.began` and `.ended`: the engine state the
/// interruption found.
@MainActor
public final class AudioInterruptionRecovery {

    /// The standby the last `.began` interrupted, consumed by the next `.ended`.
    public private(set) var interrupted: InterruptedEngineState?

    private let now: () -> Date
    private let log: (LogEvent) -> Void
    private let describe: (Error) -> String

    public init(
        now: @escaping () -> Date = Date.init,
        log: @escaping (LogEvent) -> Void = { PersistentLog.log($0) },
        describe: @escaping (Error) -> String = { $0.localizedDescription }
    ) {
        self.now = now
        self.log = log
        self.describe = describe
    }

    /// `.began`: remember the engine state, then tear down as before #353.
    ///
    /// WHY the read comes first: the teardown cancels the idle release, and with it the
    /// anchor that says the engine was in standby and since when.
    public func began(target: InterruptionResumeTarget) {
        interrupted = target.engineStateForInterruption
        target.tearDownForInterruption()
    }

    /// Something ended the warm state for its own reason during the interruption (the
    /// user stopped standby, the idle release ran, media services reset). A later
    /// `.ended` must not bring back what was deliberately released.
    public func forget() {
        interrupted = nil
    }

    /// `.ended`: resume when the plan allows it, and log what happened.
    ///
    /// One attempt, no retry: a start iOS refuses from the background (`kAUStartIO`,
    /// measured for #430) is not one a second try fixes, and the next keyboard tap
    /// still has the cold-start path through the app.
    ///
    /// - Parameters:
    ///   - appIsActive: the standby Live Activity is a background affordance, started
    ///     when the app leaves the foreground. In the foreground it is left to that path.
    ///   - appState: `UIApplication.State.rawValue`, for the log.
    /// - Returns: whether the warm state is back, the `restored` of `audioInterruptionEnded`.
    @discardableResult
    public func ended(
        shouldResume: Bool,
        appIsActive: Bool,
        appState: String,
        target: InterruptionResumeTarget
    ) -> Bool {
        let plan = InterruptionResumePolicy.plan(
            shouldResume: shouldResume,
            interrupted: interrupted,
            engineAlreadyRunning: target.isEngineRunning,
            now: now()
        )
        interrupted = nil

        let restored = perform(plan, appIsActive: appIsActive, appState: appState, target: target)
        log(.audioInterruptionEnded(shouldResume: shouldResume, restored: restored))
        return restored
    }

    private func perform(
        _ plan: InterruptionResumePlan,
        appIsActive: Bool,
        appState: String,
        target: InterruptionResumeTarget
    ) -> Bool {
        guard case let .resume(idleSince, interval, remaining) = plan else {
            if case let .skip(reason) = plan {
                log(.engineWarmUpSkipped(context: "interruptionResume", reason: reason.rawValue))
            }
            return false
        }

        do {
            try target.reactivateSession()
        } catch {
            fail(step: "reactivateSession", error: describe(error), appState: appState, target: target)
            return false
        }

        let inputMuted: Bool
        do {
            inputMuted = try target.startEngineAtRest()
        } catch {
            fail(step: "startEngine", error: describe(error), appState: appState, target: target)
            return false
        }
        // A running engine with an open input is the orange indicator for the rest of
        // the window (#430): worse than staying cold, so it counts as a failed resume.
        guard inputMuted else {
            fail(step: "muteInput", error: "input still open after start", appState: appState, target: target)
            return false
        }

        target.armIdleRelease(idleSince: idleSince, interval: interval)
        let liveActivity = appIsActive ? "skippedForeground" : target.restartStandbyLiveActivity()

        log(.warmStateRestored(context: "interruptionResume engineRestarted=true inputMuted=true "
            + "liveActivity=\(liveActivity) remainingSeconds=\(Int(remaining.rounded())) appState=\(appState)"))
        return true
    }

    private func fail(step: String, error: String, appState: String, target: InterruptionResumeTarget) {
        target.abandonResume()
        log(.engineWarmUpFailed(context: "interruptionResume-\(step)", error: "\(error) appState=\(appState)"))
    }
}
