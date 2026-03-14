// DictusApp/LiveActivityManager.swift
// Manages the Dictus Live Activity lifecycle (Dynamic Island + Lock Screen).
import ActivityKit
import Foundation
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

    /// Current Live Activity instance. nil if no activity is running.
    private var currentActivity: Activity<DictusLiveActivityAttributes>?

    /// Timestamp of last waveform update. Used to throttle to 1Hz.
    private var lastWaveformUpdate = Date.distantPast

    /// Task for auto-dismiss after result/failure display.
    private var autoDismissTask: Task<Void, Never>?

    private init() {}

    // MARK: - Standby Mode

    /// Start a Live Activity in standby mode.
    /// Called when the app enters background — gives the user a persistent
    /// Dynamic Island indicator that Dictus is ready to record.
    ///
    /// WHY check areActivitiesEnabled:
    /// The user can disable Live Activities in Settings. Attempting to create
    /// one when disabled throws an error. Checking first avoids log noise.
    func startStandbyActivity() {
        // Don't create duplicate activities
        guard currentActivity == nil else {
            DictusLogger.app.info("Live Activity already running — skipping startStandby")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            DictusLogger.app.info("Live Activities disabled by user — skipping")
            return
        }

        let attributes = DictusLiveActivityAttributes()
        let state = DictusLiveActivityAttributes.ContentState(phase: .standby)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            DictusLogger.app.info("Live Activity started in standby mode (id: \(activity.id))")
        } catch {
            DictusLogger.app.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Stop the standby Live Activity entirely.
    /// Called when user taps Power button in expanded Dynamic Island view.
    func stopStandbyActivity() {
        guard let activity = currentActivity else { return }

        autoDismissTask?.cancel()
        autoDismissTask = nil

        Task {
            let finalState = DictusLiveActivityAttributes.ContentState(phase: .standby)
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            currentActivity = nil
            DictusLogger.app.info("Live Activity stopped by user (Power button)")
        }
    }

    // MARK: - Recording Mode

    /// Transition from standby to recording.
    /// Called when DictationCoordinator starts recording.
    func transitionToRecording() {
        guard let activity = currentActivity else {
            // If no activity exists (e.g., app was in foreground), create one
            startStandbyActivity()
            // Small delay to let the activity initialize, then update
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await updateToRecording()
            }
            return
        }

        Task {
            let state = DictusLiveActivityAttributes.ContentState(
                phase: .recording,
                recordingStartDate: Date(),
                waveformLevels: [0.3, 0.5, 0.7, 0.5, 0.3]
            )
            await activity.update(.init(state: state, staleDate: nil))
            DictusLogger.app.info("Live Activity → recording")
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
        DictusLogger.app.info("Live Activity → recording (delayed)")
    }

    /// Update waveform levels during recording.
    /// Throttled to 1Hz to stay within ActivityKit update budget.
    ///
    /// WHY 1Hz (not 5Hz like App Group writes):
    /// ActivityKit has a stricter update budget than UserDefaults.
    /// Apple recommends no more than ~1 update/second for Live Activities.
    /// The timer auto-updates independently via Text(date, style: .timer).
    ///
    /// WHY downsample 30→5:
    /// DictationCoordinator's bufferEnergy has up to 30 values (one per waveform bar
    /// in the in-app RecordingView). Dynamic Island only shows 5 bars. Averaging
    /// groups of 6 produces smooth, representative levels.
    func updateWaveform(levels: [Float]) {
        guard currentActivity != nil else { return }

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
        guard let activity = currentActivity else { return }

        Task {
            let state = DictusLiveActivityAttributes.ContentState(
                phase: .transcribing,
                waveformLevels: [0.3, 0.5, 0.4, 0.5, 0.3]
            )
            await activity.update(.init(state: state, staleDate: nil))
            DictusLogger.app.info("Live Activity → transcribing")
        }
    }

    /// Show transcription result, then return to standby after 5 seconds.
    ///
    /// WHY return to standby instead of ending:
    /// The user expects the Dynamic Island to persist as long as the app is alive.
    /// After showing the result briefly, we go back to the "On" standby state
    /// so they can start another recording from the Dynamic Island.
    func endWithResult(preview: String?) {
        guard let activity = currentActivity else { return }

        autoDismissTask?.cancel()

        Task {
            let truncatedPreview = preview.map { String($0.prefix(100)) }
            let state = DictusLiveActivityAttributes.ContentState(
                phase: .ready,
                transcriptionPreview: truncatedPreview
            )
            await activity.update(.init(state: state, staleDate: nil))
            DictusLogger.app.info("Live Activity → ready")
        }

        // Return to standby after 5 seconds
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
            guard !Task.isCancelled else { return }
            await returnToStandby()
        }
    }

    /// Show failure state, then return to standby after 3 seconds.
    func endWithFailure() {
        guard let activity = currentActivity else { return }

        autoDismissTask?.cancel()

        Task {
            let state = DictusLiveActivityAttributes.ContentState(phase: .failed)
            await activity.update(.init(state: state, staleDate: nil))
            DictusLogger.app.info("Live Activity → failed")
        }

        // Return to standby after 3 seconds
        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s
            guard !Task.isCancelled else { return }
            await returnToStandby()
        }
    }

    // MARK: - Utilities

    /// Return to standby state (used after result/failure display).
    private func returnToStandby() async {
        guard let activity = currentActivity else { return }

        let state = DictusLiveActivityAttributes.ContentState(phase: .standby)
        await activity.update(.init(state: state, staleDate: nil))
        DictusLogger.app.info("Live Activity → standby (auto-return)")
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
        Task {
            for activity in Activity<DictusLiveActivityAttributes>.activities {
                await activity.end(
                    .init(
                        state: DictusLiveActivityAttributes.ContentState(phase: .standby),
                        staleDate: nil
                    ),
                    dismissalPolicy: .immediate
                )
                DictusLogger.app.info("Cleaned up stale Live Activity: \(activity.id)")
            }
            currentActivity = nil
        }
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
