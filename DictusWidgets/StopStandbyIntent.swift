// DictusWidgets/StopStandbyIntent.swift
// LiveActivityIntent to stop the Dictus standby Dynamic Island.
//
// WHY LiveActivityIntent (not AppIntent):
// Button(intent:) inside a Live Activity requires a LiveActivityIntent.
// Regular AppIntents open the app; LiveActivityIntents execute in-process
// without bringing the app to the foreground.
//
// WHY in both DictusApp AND DictusWidgets targets:
// LiveActivityIntent.perform() executes in the HOST APP process, not the
// widget extension. If the type is only compiled into DictusWidgets,
// iOS can't find it at runtime → silent failure. Both targets must include
// this file so the intent is available wherever iOS needs to run it.
import AppIntents
import ActivityKit
import Foundation
import DictusCore

struct StopStandbyIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Standby"
    static var description = IntentDescription("Turn off Dictus standby mode")

    func perform() async throws -> some IntentResult {
        // End all Live Activities
        for activity in Activity<DictusLiveActivityAttributes>.activities {
            await activity.end(
                .init(state: .init(phase: .standby), staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        // Notify the app process to stop the audio engine (kills the orange mic indicator).
        // WHY NotificationCenter (not calling DictationCoordinator directly):
        // This file is compiled into both DictusApp and DictusWidgets targets.
        // DictationCoordinator only exists in DictusApp — referencing it here
        // would break the DictusWidgets build. NotificationCenter is available
        // in both, and the notification only reaches the coordinator when running
        // in the app process (which is exactly when we need it).
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("DictusStopStandbyRequested"),
                object: nil
            )
        }

        return .result()
    }
}
