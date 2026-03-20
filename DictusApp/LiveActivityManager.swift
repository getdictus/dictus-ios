// DictusApp/LiveActivityManager.swift
// Manages the Dictus Live Activity lifecycle (Dynamic Island + Lock Screen).
import ActivityKit
import Foundation
import UIKit
import DictusCore

/// Manages Live Activity lifecycle for Dynamic Island and Lock Screen display.
///
/// WHY singleton (@MainActor + static let shared):
/// Only one Live Activity should exist at a time. DictationCoordinator and DictusApp
/// both need to call methods on the same instance. @MainActor ensures thread safety
/// for ActivityKit calls which must happen on the main thread.
///
/// WHY the standby pattern:
/// Unlike typical Live Activities that start/end with a task, Dictus keeps a persistent
/// "standby" Live Activity while the app runs in background. This gives the user
/// permanent access to the Dynamic Island for quick recording. The activity transitions
/// between phases (.standby -> .recording -> .transcribing -> .ready -> .standby)
/// without being destroyed. Only the Power button or app termination ends it.
@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    // MARK: - State Machine

    /// Internal state machine for Live Activity lifecycle.
    /// WHY separate from ContentState.Phase: This tracks the manager's own state,
    /// including .idle (no activity exists). ContentState.Phase is the ActivityKit
    /// display state sent to the widget. The state machine prevents Dynamic Island
    /// desync after chaining multiple recordings (#42).
    private enum LiveActivityPhase: String {
        case idle       // No activity exists
        case standby    // Activity exists, waiting for user
        case recording  // Active recording
        case transcribing // Processing audio
        case ready      // Showing result (auto-dismiss pending)
        case failed     // Showing error (auto-dismiss pending)
    }

    /// Returns true if transitioning from the current phase to `target` is valid.
    /// Invalid transitions are logged and rejected -- callers check the return value.
    /// WHY: Without validation, concurrent Activity.update() calls arrive out of order
    /// and autoDismissTask from previous recordings can fire mid-recording (#42).
    private func validateTransition(to target: LiveActivityPhase) -> Bool {
        let valid: [LiveActivityPhase: Set<LiveActivityPhase>] = [
            .idle: [.standby],
            .standby: [.recording, .idle],
            .recording: [.transcribing, .standby],  // standby = cancel
            .transcribing: [.ready, .failed],
            .ready: [.standby, .recording],  // recording = quick chain before auto-dismiss
            // WHY .recording and .idle: If autoDismissTask is killed by iOS
            // (cold start, app switching), .failed becomes permanent. Allow recovery
            // to .recording (new dictation) and .idle (activity teardown).
            .failed: [.standby, .recording, .idle]
        ]
        let allowed = valid[currentPhase] ?? []
        if allowed.contains(target) {
            return true
        } else {
            DictusLogger.app.warning("LiveActivity: rejected transition \(self.currentPhase.rawValue, privacy: .public) -> \(target.rawValue, privacy: .public)")
            PersistentLog.log(.statusChanged(from: currentPhase.rawValue, to: "REJECTED-\(target.rawValue)", source: "LiveActivityManager"))
            return false
        }
    }

    /// Maps ContentState.Phase (ActivityKit display) to LiveActivityPhase (internal state machine).
    private func mapContentPhase(_ phase: DictusLiveActivityAttributes.ContentState.Phase) -> LiveActivityPhase {
        switch phase {
        case .standby: return .standby
        case .recording: return .recording
        case .transcribing: return .transcribing
        case .ready: return .ready
        case .failed: return .failed
        }
    }

    /// Current Live Activity instance. nil if no activity is running.
    private var currentActivity: Activity<DictusLiveActivityAttributes>?

    /// Tracks the current phase via a formal state machine with validated transitions.
    /// WHY: Even if DictationCoordinator guards its sinks, this provides a second
    /// barrier -- updateWaveform() is a no-op unless we're actually recording.
    /// WHY LiveActivityPhase (not ContentState.Phase): Adds .idle state and transition
    /// validation to prevent DI desync after chaining recordings (#42).
    private var currentPhase: LiveActivityPhase = .idle

    /// Timestamp of last waveform update. Used to throttle to 1Hz.
    private var lastWaveformUpdate = Date.distantPast

    /// Task for auto-dismiss after result/failure display.
    private var autoDismissTask: Task<Void, Never>?

    private init() {
        // End all Live Activities when the app is terminated (force-quit from app switcher).
        // WHY: Without this, the DI stays visible for up to 8 hours after a force-quit.
        // willTerminate fires reliably when the user swipes up in the app switcher.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.endAllActivitiesSync()
        }
    }

    // MARK: - Standby Mode

    /// Start a Live Activity in standby mode.
    /// Called when the app enters background -- gives the user a persistent
    /// Dynamic Island indicator that Dictus is ready to record.
    ///
    /// WHY check areActivitiesEnabled:
    /// The user can disable Live Activities in Settings. Attempting to create
    /// one when disabled throws an error. Checking first avoids log noise.
    /// WHY synchronous (not async):
    /// Called from onChange(scenePhase: .background). If wrapped in Task { await },
    /// the Task is deferred -- by the time it runs, iOS considers the app fully
    /// backgrounded and Activity.request() fails with "Target is not foreground".
    /// Synchronous execution ensures the activity is created during the transition.
    /// Zombie cleanup is handled separately by cleanupStaleActivities() at app init.
    func startStandbyActivity() {
        // Allow transition from idle->standby or if already standby (no-op)
        // WHY: Prevents creating duplicate activities when app re-enters background
        if currentPhase == .standby && currentActivity != nil {
            DictusLogger.app.info("Live Activity already in standby -- skipping")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            DictusLogger.app.info("Live Activities disabled by user -- skipping")
            return
        }

        // Sync currentActivity reference (may be stale after intent or force-quit)
        if let current = currentActivity,
           !Activity<DictusLiveActivityAttributes>.activities.contains(where: { $0.id == current.id }) {
            DictusLogger.app.info("currentActivity stale (killed by intent or force-quit) -- clearing")
            currentActivity = nil
            currentPhase = .idle
        }

        // Guard against duplicates at the system level, not just our in-memory reference.
        // WHY: After crash/force-quit, currentActivity is nil but old activities persist
        // in ActivityKit. cleanupStaleActivities() runs async in init() and may not have
        // finished yet. Checking the system list prevents creating a second activity.
        let systemActivities = Activity<DictusLiveActivityAttributes>.activities
        if currentActivity == nil && !systemActivities.isEmpty {
            // Recover orphaned activity instead of creating a new one
            if let existing = systemActivities.first {
                currentActivity = existing
                currentPhase = mapContentPhase(existing.content.state.phase)
                DictusLogger.app.info("Recovered orphaned Live Activity: \(existing.id, privacy: .public)")
            }
            // End any extras beyond the first (shouldn't happen, but defense in depth)
            for activity in systemActivities.dropFirst() {
                Task {
                    await activity.end(
                        .init(state: .init(phase: .standby), staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                    DictusLogger.app.info("Ended duplicate Live Activity: \(activity.id, privacy: .public)")
                }
            }
        }

        // Don't create duplicate activities
        guard currentActivity == nil else {
            DictusLogger.app.info("Live Activity already running -- skipping startStandby")
            return
        }

        let attributes = DictusLiveActivityAttributes()
        let state = DictusLiveActivityAttributes.ContentState(phase: .standby)
        // staleDate: if app is killed without willTerminate firing, iOS dims the DI
        // after 15 minutes and the user knows something is wrong.
        let staleDate = Date().addingTimeInterval(15 * 60)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: staleDate),
                pushType: nil
            )
            currentActivity = activity
            currentPhase = .standby
            DictusLogger.app.info("Live Activity started in standby (id: \(activity.id, privacy: .public))")
        } catch {
            DictusLogger.app.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Stop the standby Live Activity entirely.
    /// Called when user taps Power button in expanded Dynamic Island view.
    func stopStandbyActivity() {
        guard let activity = currentActivity else { return }

        autoDismissTask?.cancel()
        autoDismissTask = nil

        currentActivity = nil
        currentPhase = .idle  // Update BEFORE async work to prevent races (#49)
        Task {
            let finalState = DictusLiveActivityAttributes.ContentState(phase: .standby)
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            DictusLogger.app.info("Live Activity stopped by user (Power button)")
        }
    }

    // MARK: - Recording Mode

    /// Transition from standby to recording.
    /// Called when DictationCoordinator starts recording.
    func transitionToRecording() {
        // Auto-bootstrap: if no activity exists, create standby first.
        // WHY BEFORE validateTransition: idle→recording is invalid, but idle→standby→recording
        // is the valid path. Without this, the guard rejects and the fallback at line 228
        // (which also calls startStandbyActivity) is UNREACHABLE after the guard returns.
        if currentPhase == .idle {
            startStandbyActivity()
        }

        // WHY: State machine guard prevents DI desync from concurrent transitions (#42)
        guard validateTransition(to: .recording) else { return }

        // Cancel any pending auto-return from a previous dictation's ready/failed state.
        // WHY AFTER validation (not before): If state is .failed and validation rejects,
        // we must NOT cancel the autoDismissTask — it's the only path back to .standby.
        // Cancelling before validation destroyed the recovery path (#15.2).
        autoDismissTask?.cancel()
        autoDismissTask = nil

        guard let activity = currentActivity else {
            // If no activity exists (e.g., app was in foreground), create one then transition.
            // WHY only delayed path: startStandbyActivity() is synchronous but the activity
            // needs a moment before it can accept updates. The delayed updateToRecording()
            // is the ONLY update path — no duplicate immediate Task (#49).
            startStandbyActivity()
            currentPhase = .recording  // Lock state immediately to prevent races (#49)
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await updateToRecording()
            }
            return
        }

        currentPhase = .recording  // Update BEFORE async work to prevent races (#49)
        Task {
            let state = DictusLiveActivityAttributes.ContentState(
                phase: .recording,
                recordingStartDate: Date(),
                waveformLevels: [0.3, 0.5, 0.7, 0.5, 0.3]
            )
            await activity.update(.init(state: state, staleDate: nil))
            DictusLogger.app.info("Live Activity -> recording")
        }
    }

    /// Internal helper to update existing activity to recording after creation.
    private func updateToRecording() async {
        guard let activity = currentActivity else { return }
        let state = DictusLiveActivityAttributes.ContentState(
            phase: .recording,
            recordingStartDate: Date(),
            waveformLevels: [0.3, 0.5, 0.7, 0.5, 0.3]
        )
        await activity.update(.init(state: state, staleDate: nil))
        // currentPhase already set to .recording by caller before Task (#49)
        DictusLogger.app.info("Live Activity -> recording (delayed)")
    }

    /// Update waveform levels during recording.
    /// Throttled to 1Hz to stay within ActivityKit update budget.
    ///
    /// WHY 1Hz (not 5Hz like App Group writes):
    /// ActivityKit has a stricter update budget than UserDefaults.
    /// Apple recommends no more than ~1 update/second for Live Activities.
    /// The timer auto-updates independently via Text(date, style: .timer).
    ///
    /// WHY downsample 30->5:
    /// DictationCoordinator's bufferEnergy has up to 30 values (one per waveform bar
    /// in the in-app RecordingView). Dynamic Island only shows 5 bars. Averaging
    /// groups of 6 produces smooth, representative levels.
    func updateWaveform(levels: [Float]) {
        guard currentActivity != nil else { return }
        // Defense in depth: only update waveform during active recording
        guard currentPhase == .recording else { return }

        // Throttle to 1Hz
        let now = Date()
        guard now.timeIntervalSince(lastWaveformUpdate) >= 1.0 else { return }
        lastWaveformUpdate = now

        // Downsample to 5 bars
        let downsampled = downsample(levels, to: 5)

        guard let activity = currentActivity else { return }
        Task {
            let state = DictusLiveActivityAttributes.ContentState(
                phase: .recording,
                recordingStartDate: activity.content.state.recordingStartDate,
                waveformLevels: downsampled
            )
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    // MARK: - Transcription Mode

    /// Transition from recording to transcribing.
    func transitionToTranscribing() {
        // WHY: State machine guard prevents DI desync from concurrent transitions (#42)
        guard validateTransition(to: .transcribing) else { return }

        guard let activity = currentActivity else { return }

        currentPhase = .transcribing  // Update BEFORE async work to prevent races (#49)
        Task {
            let state = DictusLiveActivityAttributes.ContentState(
                phase: .transcribing,
                waveformLevels: [0.3, 0.5, 0.4, 0.5, 0.3]
            )
            await activity.update(.init(state: state, staleDate: nil))
            DictusLogger.app.info("Live Activity -> transcribing")
        }
    }

    /// Show transcription result, then return to standby after 1 second.
    ///
    /// WHY return to standby instead of ending:
    /// The user expects the Dynamic Island to persist as long as the app is alive.
    /// After showing the result briefly, we go back to the "On" standby state
    /// so they can start another recording from the Dynamic Island.
    func endWithResult(preview: String?) {
        // WHY: State machine guard prevents DI desync from concurrent transitions (#42)
        guard validateTransition(to: .ready) else { return }

        guard let activity = currentActivity else { return }

        autoDismissTask?.cancel()

        currentPhase = .ready  // Update BEFORE async work to prevent races (#49)
        Task {
            let truncatedPreview = preview.map { String($0.prefix(100)) }
            let state = DictusLiveActivityAttributes.ContentState(
                phase: .ready,
                transcriptionPreview: truncatedPreview
            )
            await activity.update(.init(state: state, staleDate: nil))
            DictusLogger.app.info("Live Activity -> ready")
        }

        // Return to standby after 1 second (fast turnaround for chaining dictations)
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            guard !Task.isCancelled else { return }
            // WHY phase check after sleep: If user started a new recording during the 1s
            // delay, the auto-dismiss must NOT fire -- it would flash DI back to standby
            // mid-recording, causing desync (#42).
            guard currentPhase == .ready else {
                DictusLogger.app.info("Auto-dismiss skipped -- phase changed to \(self.currentPhase.rawValue, privacy: .public)")
                return
            }
            await returnToStandby()
        }
    }

    /// Show failure state, then return to standby after 3 seconds.
    func endWithFailure() {
        // WHY: State machine guard prevents DI desync from concurrent transitions (#42)
        guard validateTransition(to: .failed) else { return }

        guard let activity = currentActivity else { return }

        autoDismissTask?.cancel()

        currentPhase = .failed  // Update BEFORE async work to prevent races (#49)
        Task {
            let state = DictusLiveActivityAttributes.ContentState(phase: .failed)
            await activity.update(.init(state: state, staleDate: nil))
            DictusLogger.app.info("Live Activity -> failed")
        }

        // Return to standby after 3 seconds
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
            guard !Task.isCancelled else { return }
            // WHY phase check after sleep: If the phase changed during the 3s delay
            // (e.g., user retried), the auto-dismiss must NOT fire (#42).
            guard currentPhase == .failed else {
                DictusLogger.app.info("Auto-dismiss skipped -- phase changed to \(self.currentPhase.rawValue, privacy: .public)")
                return
            }
            await returnToStandby()
        }
    }

    // MARK: - Utilities

    /// Return to standby state. Called after result/failure auto-dismiss,
    /// and also when a recording is cancelled from the keyboard.
    func returnToStandby() async {
        // WHY: Only return to standby from states that logically precede it.
        // Prevents stale auto-dismiss tasks from overwriting an active recording (#42).
        guard currentPhase == .ready || currentPhase == .failed || currentPhase == .recording else {
            DictusLogger.app.info("returnToStandby skipped -- already \(self.currentPhase.rawValue, privacy: .public)")
            return
        }

        guard let activity = currentActivity else { return }

        currentPhase = .standby  // Update BEFORE async work to prevent races (#49)
        let state = DictusLiveActivityAttributes.ContentState(phase: .standby)
        // Refresh staleDate on each return to standby (15 min from now)
        let staleDate = Date().addingTimeInterval(15 * 60)
        await activity.update(.init(state: state, staleDate: staleDate))
        DictusLogger.app.info("Live Activity -> standby (auto-return)")
    }

    /// Clean up stale Live Activities from previous app launches.
    /// Called at app startup to prevent zombie activities from persisting
    /// after a crash or force-quit.
    ///
    /// WHY this is needed:
    /// If the app crashes or is force-quit, the Live Activity stays visible
    /// on the Dynamic Island until iOS times it out (up to 8 hours).
    /// Cleaning up on launch ensures a fresh state.
    func cleanupStaleActivities() {
        // Capture current session ID BEFORE entering the async Task.
        // WHY: On cold start, transitionToRecording() may create a new Live Activity
        // before this cleanup Task runs. Without this guard, the cleanup would end
        // the freshly created recording activity (race condition).
        let currentSessionActivityID = currentActivity?.id

        Task {
            for activity in Activity<DictusLiveActivityAttributes>.activities {
                if activity.id == currentSessionActivityID { continue }

                await activity.end(
                    .init(
                        state: DictusLiveActivityAttributes.ContentState(phase: .standby),
                        staleDate: nil
                    ),
                    dismissalPolicy: .immediate
                )
                DictusLogger.app.info("Cleaned up stale Live Activity: \(activity.id, privacy: .public)")
            }
            if currentSessionActivityID == nil {
                currentActivity = nil
                currentPhase = .idle
            }
        }
    }

    /// Synchronously end all Live Activities. Called from willTerminate which has
    /// very limited time -- cannot use async/await reliably.
    private func endAllActivitiesSync() {
        for activity in Activity<DictusLiveActivityAttributes>.activities {
            let state = DictusLiveActivityAttributes.ContentState(phase: .standby)
            Task {
                await activity.end(
                    .init(state: state, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
        }
        currentActivity = nil
        currentPhase = .idle
        DictusLogger.app.info("Ended all Live Activities (app terminating)")
    }

    /// Downsample an array of Float values to the target count by averaging groups.
    private func downsample(_ values: [Float], to count: Int) -> [Float] {
        guard !values.isEmpty else {
            return Array(repeating: 0.3, count: count)
        }

        if values.count <= count {
            // Pad with last value if needed
            var result = values
            let pad = values.last ?? 0.3
            while result.count < count {
                result.append(pad)
            }
            return result
        }

        // Average groups
        let groupSize = values.count / count
        return (0..<count).map { i in
            let start = i * groupSize
            let end = min(start + groupSize, values.count)
            let slice = values[start..<end]
            return slice.reduce(0, +) / Float(slice.count)
        }
    }
}
