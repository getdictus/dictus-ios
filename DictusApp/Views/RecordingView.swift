// DictusApp/Views/RecordingView.swift
// Immersive full-screen recording UI shared between onboarding and standalone test.
import SwiftUI
import DictusCore

/// Determines the context in which RecordingView is shown.
///
/// WHY a mode enum instead of separate views:
/// The recording experience should feel identical whether the user reaches it
/// from onboarding step 5 or from HomeView's "Tester la dictee" button.
/// The only difference is what happens when the user finishes:
/// - onboarding: calls onComplete to advance onboarding
/// - standalone: offers "Nouvelle dictee" to reset or "Terminer" to dismiss
enum RecordingMode {
    case onboarding
    case standalone
}

/// Immersive Voice Memos-style recording screen with centered mic button,
/// ambient waveform, and fade-to-text transcription result.
///
/// WHY this design:
/// The test recording is the user's first real interaction with dictation.
/// An immersive, focused screen with a large centered mic button and ambient
/// waveform creates a polished, confidence-inspiring experience. The waveform
/// fades out and transcription text fades in — no cards, no chrome — just clean
/// transitions between states.
struct RecordingView: View {
    let mode: RecordingMode
    var onComplete: (() -> Void)?

    @EnvironmentObject var coordinator: DictationCoordinator

    /// Tracks whether the user has seen a transcription result (to show action buttons).
    @State private var transcriptionResult: String?
    /// Controls the fade transition between waveform and transcription text.
    @State private var showResult = false
    @State private var showError = false
    @State private var errorMessage: String?

    init(mode: RecordingMode, onComplete: (() -> Void)? = nil) {
        self.mode = mode
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            // Full-screen dark background for immersive feel
            Color.dictusBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Ambient waveform behind mic button — only visible during recording
                // WHY 30% opacity: The waveform is ambient decoration, not primary UI.
                // It creates atmosphere without competing with the mic button for attention.
                if coordinator.status == .recording {
                    BrandWaveform(
                        energyLevels: coordinator.bufferEnergy,
                        maxHeight: 120
                    )
                    .opacity(0.3)
                    .padding(.horizontal)
                    .transition(.opacity)
                }

                // Transcribing state: sinusoidal waveform maintains visual continuity
                // WHY BrandWaveform instead of ProcessingAnimation:
                // The waveform transitions from audio-driven (recording) to sinusoidal
                // (processing), keeping the same visual element. This feels like the
                // waveform "calms down" into a smooth wave while thinking, rather than
                // abruptly switching to a different animation.
                if coordinator.status == .transcribing {
                    BrandWaveform(maxHeight: 120, isProcessing: true)
                        .opacity(0.3)
                        .padding(.horizontal)
                        .transition(.opacity)

                    Text("Transcription en cours...")
                        .font(.dictusCaption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }

                // Result state: transcription text fades in where waveform was
                if showResult, let result = transcriptionResult {
                    Text(result)
                        .font(.dictusBody)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .transition(.opacity)
                        .padding(.bottom, 16)
                }

                // Error state
                if showError, let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.dictusCaption)
                            .foregroundColor(.dictusRecording)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 16)
                }

                Spacer()

                // Main mic / stop button — large and centered
                micOrStopButton
                    .padding(.bottom, 16)

                // Recording duration display
                if coordinator.status == .recording {
                    Text(formattedTime)
                        .font(.system(size: 20, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }

                // Action buttons after transcription result
                if showResult && transcriptionResult != nil {
                    actionButtons
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }

                // Error retry button
                if showError {
                    Button(action: startRecording) {
                        Text("Reessayer")
                            .font(.dictusSubheading)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.dictusAccent)
                            )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .animation(.easeOut(duration: 0.3), value: showResult)
        .animation(.easeInOut(duration: 0.3), value: coordinator.status)
        .onChange(of: coordinator.status) { newStatus in
            handleStatusChange(newStatus)
        }
        .navigationBarHidden(true)
    }

    // MARK: - Mic / Stop Button

    /// Large centered button that toggles between mic (start) and stop (recording).
    ///
    /// WHY separate from AnimatedMicButton:
    /// In the idle state we use the AnimatedMicButton for its branded pulsing glow.
    /// In the recording state we show a red stop button (circle with white square)
    /// matching the Voice Memos pattern — universally recognized as "stop recording".
    @ViewBuilder
    private var micOrStopButton: some View {
        if coordinator.status == .recording {
            // Stop button: red circle with white square
            Button(action: stopRecording) {
                ZStack {
                    Circle()
                        .fill(Color.dictusRecording)
                        .frame(width: 80, height: 80)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: 28, height: 28)
                }
            }
            .accessibilityLabel("Arreter l'enregistrement")
        } else if coordinator.status == .transcribing {
            // During transcription, show disabled mic
            AnimatedMicButton(status: .transcribing) {}
                .disabled(true)
        } else if showResult || showError {
            // After result or error, hide the mic button (action buttons shown instead)
            EmptyView()
        } else {
            // Idle state: branded animated mic button
            AnimatedMicButton(status: .idle) {
                startRecording()
            }
        }
    }

    // MARK: - Action Buttons

    /// Buttons shown after transcription completes. Content depends on mode.
    @ViewBuilder
    private var actionButtons: some View {
        switch mode {
        case .onboarding:
            // In onboarding, just a "Terminer" button to advance
            Button(action: {
                coordinator.resetStatus()
                onComplete?()
            }) {
                Text("Terminer")
                    .font(.dictusSubheading)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.dictusSuccess)
                    )
            }

        case .standalone:
            // In standalone, offer retry or dismiss
            VStack(spacing: 12) {
                Button(action: resetForNewRecording) {
                    Text("Nouvelle dictee")
                        .font(.dictusSubheading)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.dictusAccent)
                        )
                }

                // WHY no dismiss() call:
                // RecordingView is shown as a ZStack overlay in MainTabView, not via
                // sheet or NavigationLink. Setting status to .idle removes the overlay
                // automatically via the condition (coordinator.status != .idle).
                Button(action: {
                    coordinator.resetStatus()
                }) {
                    Text("Terminer")
                        .font(.dictusSubheading)
                        .foregroundColor(.dictusAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.dictusAccent, lineWidth: 1.5)
                        )
                }
            }
        }
    }

    // MARK: - Actions

    private func startRecording() {
        // Reset state for new recording
        transcriptionResult = nil
        showResult = false
        showError = false
        errorMessage = nil

        // Haptic feedback on mic tap
        HapticFeedback.recordingStarted()

        coordinator.startDictation()
    }

    private func stopRecording() {
        // Haptic feedback on stop tap
        HapticFeedback.recordingStopped()

        coordinator.stopDictation()
    }

    /// Reset local UI state for a new recording WITHOUT dismissing the overlay.
    ///
    /// WHY we don't call coordinator.resetStatus() here:
    /// resetStatus() sets status to .idle, which removes the RecordingView overlay
    /// (MainTabView shows it only when status != .idle). The user wants to stay in
    /// the recording view and start a new dictation — not go back to HomeView.
    /// By only resetting local state, the overlay stays visible and the mic button
    /// reappears. coordinator.status stays at .ready, which startDictation() accepts.
    private func resetForNewRecording() {
        transcriptionResult = nil
        showResult = false
        showError = false
        errorMessage = nil
        coordinator.lastResult = nil
    }

    // MARK: - Status Handling

    private func handleStatusChange(_ newStatus: DictationStatus) {
        switch newStatus {
        case .ready:
            // Transcription complete — fade in result text
            if let result = coordinator.lastResult, !result.isEmpty {
                transcriptionResult = result
                withAnimation(.easeOut(duration: 0.4)) {
                    showResult = true
                }
            }
        case .failed:
            showError = true
            errorMessage = coordinator.lastResult ?? "La transcription a echoue. Verifiez que le modele est telecharge."
        default:
            break
        }
    }

    // MARK: - Helpers

    /// Format elapsed seconds as "M:SS".
    private var formattedTime: String {
        let totalSeconds = Int(coordinator.bufferSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("Recording - Idle") {
    RecordingView(mode: .standalone)
        .environmentObject(DictationCoordinator.shared)
}
