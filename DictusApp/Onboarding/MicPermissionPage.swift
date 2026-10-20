// DictusApp/Onboarding/MicPermissionPage.swift
// Onboarding step: say why Dictus needs the microphone, then let iOS ask for it.
import SwiftUI
import AVFoundation
import DictusCore

/// The pre-permission screen for the microphone, right before the first dictation.
///
/// WHY HERE (#649 decision 17, #675): no step before the first dictation uses the
/// microphone, and this is the moment the reason is obvious. Asking on this screen, with
/// the reason written out, also keeps the system popup from landing in the middle of the
/// first recording. `OnboardingView` passes over this step when the microphone is already
/// granted.
///
/// WHY we don't block on denial:
/// Apple's HIG and research best practices recommend against blocking progress
/// on a denied permission. The user can still try the keyboard by typing — they just
/// won't be able to record until they grant mic access later.
struct MicPermissionPage: View {
    let onNext: () -> Void

    /// nil = not yet requested, true = granted, false = denied
    @State private var permissionGranted: Bool?
    @State private var isRequesting = false

    var body: some View {
        OnboardingCenteredPage(
            title: Text("Dictus needs the microphone"),
            message: Text("To hear you while you dictate. The sound is transcribed on your iPhone and never leaves it.")
        ) {
            VStack(spacing: 24) {
                MicHalo()

                // Permission result feedback
                if let granted = permissionGranted {
                    if granted {
                        Label("Microphone authorized", systemImage: "checkmark.circle.fill")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.dictusSuccess)
                    } else {
                        Text("You can enable the microphone later in Settings")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        } bottom: {
            // WHY neutral wording ("Continue", not "Allow microphone"):
            // App Review guideline 5.1.1(iv) forbids priming buttons that direct
            // the user toward granting a system permission. The button only advances
            // to the OS prompt — iOS owns the actual allow/deny choice. The #675 mock-up
            // draws "Autoriser le micro" here; the guideline wins.
            OnboardingPrimaryButton(
                Text("Continue"),
                isEnabled: !isRequesting,
                action: permissionGranted == nil ? requestPermission : onNext
            )
            .accessibilityIdentifier("onboarding.primary")
        }
    }

    // MARK: - Private

    private func requestPermission() {
        isRequesting = true

        // Check current status first — if already determined, don't re-prompt
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            permissionGranted = true
            autoAdvance()
        case .denied:
            permissionGranted = false
            isRequesting = false
        case .undetermined:
            // Bridge the completion-handler API to async-friendly code.
            //
            // WHY not async/await wrapper here:
            // requestRecordPermission uses a completion handler callback (pre-async API).
            // We could use withCheckedContinuation, but since we're updating @State
            // on main thread anyway, a simple DispatchQueue.main.async in the callback
            // is simpler and avoids the continuation overhead.
            session.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    permissionGranted = allowed
                    isRequesting = false
                    if allowed {
                        autoAdvance()
                    }
                }
            }
        @unknown default:
            permissionGranted = false
            isRequesting = false
        }
    }

    private func autoAdvance() {
        // Auto-advance after brief delay to show the checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onNext()
        }
    }
}

/// The microphone in a blue disc, inside three pale rings (#675 mock-up `09-micro`).
private struct MicHalo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.dictusAccent.opacity(0.08))
                .frame(width: 220, height: 220)
            Circle()
                .fill(Color.dictusAccent.opacity(0.10))
                .frame(width: 170, height: 170)
            Circle()
                .fill(Color.dictusAccent.opacity(0.14))
                .frame(width: 124, height: 124)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.dictusAccentHighlight, .dictusGradientEnd],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 96, height: 96)
                .shadow(color: .dictusAccent.opacity(0.35), radius: 16, y: 6)
            Image(systemName: "mic")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}
