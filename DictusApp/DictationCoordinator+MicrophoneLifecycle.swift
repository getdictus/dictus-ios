import Foundation
import UIKit
import DictusCore

// MARK: - Returning from microphone release to warm standby

extension DictationCoordinator {
    /// The ten-minute idle release invalidates a previously verified input too.
    func observeStandbyWarmStateRelease() {
        NotificationCenter.default.addObserver(
            forName: .dictusWarmStateReleased,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.cancelStandbyRestoration() }
        }
    }

    func microphoneLifecyclePreferenceDidChange() {
        cancelStandbyRestoration()
        if microphoneLifecycleMode == .releaseAfterDictation {
            LiveActivityManager.shared.stopIdleStandbyActivity()
            releaseMicrophoneIfPolicyRequires(reason: "preference-enabled")
            return
        }
        guard UIApplication.shared.applicationState == .active, canRestoreMicrophoneStandby else { return }
        // End only terminal UI here, never an active dictation. In particular,
        // an old result's auto-dismiss must not publish standby before input works.
        LiveActivityManager.shared.stopStandbyActivity()
        let request = UUID()
        standbyRestorationID = request
        standbyRestorationState = .preparing
        standbyRestorationTask = Task { await restoreMicrophoneStandby(request: request) }
    }

    private var canRestoreMicrophoneStandby: Bool {
        MicrophoneLifecyclePolicy.canRestoreStandby(
            mode: microphoneLifecycleMode, status: status, awaitingKeyboard: polishHandoffSession != nil)
    }

    func cancelStandbyRestoration() {
        standbyRestorationID = nil
        standbyRestorationTask?.cancel()
        standbyRestorationTask = nil
        standbyRestorationState = .idle
    }

    private func restoreMicrophoneStandby(request: UUID) async {
        defer {
            if standbyRestorationID == request { standbyRestorationTask = nil }
        }
        guard standbyRestorationID == request, !Task.isCancelled else { return }
        guard canRestoreMicrophoneStandby else { return }
        guard UIApplication.shared.applicationState == .active else {
            finishStandbyRestoration(request: request, inputObserved: false)
            return
        }
        do {
            guard defaults.bool(forKey: SharedKeys.modelReady) else {
                finishStandbyRestoration(request: request, inputObserved: false)
                return
            }
            let permission = try await ensureStandbyMicrophonePermission()
            guard standbyRestorationID == request, !Task.isCancelled else { return }
            guard permission, canRestoreMicrophoneStandby, UIApplication.shared.applicationState == .active else {
                finishStandbyRestoration(request: request, inputObserved: false)
                return
            }
            await warmUpEngineOnForeground()
            guard standbyRestorationID == request, !Task.isCancelled else { return }
            guard canRestoreMicrophoneStandby else { return }
            let inputObserved = try await waitForStandbyInputFlow()
            finishStandbyRestoration(request: request, inputObserved: inputObserved)
        } catch {
            guard !Task.isCancelled else { return }
            finishStandbyRestoration(request: request, inputObserved: false)
        }
    }

    private func finishStandbyRestoration(request: UUID, inputObserved: Bool) {
        guard standbyRestorationID == request, canRestoreMicrophoneStandby else { return }
        standbyRestorationState = inputObserved ? .verified : .unavailable
        if inputObserved {
            if UIApplication.shared.applicationState == .active {
                LiveActivityManager.shared.ensureActivityAlive()
            }
        } else {
            // A failed restoration must not leave an activated but unusable session.
            deactivateStandbyMicrophone()
            LiveActivityManager.shared.stopIdleStandbyActivity()
        }
        PersistentLog.log(.diagnosticProbe(
            component: "MicrophoneLifecycle", instanceID: "shared",
            action: inputObserved ? "standbyInputVerified" : "standbyInputUnavailable",
            details: "preference-restoration"
        ))
    }
}
