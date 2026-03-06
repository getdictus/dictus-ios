// DictusApp/Views/TestDictationView.swift
// In-app test screen for end-to-end dictation testing without leaving the app.
import SwiftUI

/// Test dictation screen allowing the user to record and transcribe speech directly in-app.
///
/// WHY this exists separately from the keyboard's dictation flow:
/// The keyboard triggers dictation via URL scheme (dictus://dictate), which opens the app
/// and starts recording. This test screen provides a simpler flow: tap the mic button directly
/// in the app, no URL scheme needed. Useful for testing the WhisperKit pipeline without
/// switching between apps. This is the ONLY place where dictation is triggered directly
/// (not via URL scheme).
struct TestDictationView: View {
    @EnvironmentObject var coordinator: DictationCoordinator

    /// Accumulated transcription text from all recording sessions.
    @State private var transcriptionText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Transcription result area
            transcriptionArea
                .frame(maxHeight: .infinity)

            Divider()

            // Mic button area
            micButtonArea
                .padding(.vertical, 24)
        }
        .navigationTitle("Test Dictation")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Effacer") {
                    transcriptionText = ""
                }
                .disabled(transcriptionText.isEmpty)
            }
        }
        // Watch for status changes to capture transcription results.
        //
        // WHY .onChange instead of direct binding:
        // DictationCoordinator sets lastResult when transcription completes, then
        // transitions through .ready -> .idle. We watch the status transition to
        // .idle to know when a transcription cycle is done, then read lastResult.
        .onChange(of: coordinator.status) { newStatus in
            if newStatus == .idle,
               let result = coordinator.lastResult,
               !result.isEmpty {
                if transcriptionText.isEmpty {
                    transcriptionText = result
                } else {
                    transcriptionText += "\n" + result
                }
            }
        }
    }

    // MARK: - Subviews

    /// Scrollable text area showing transcription results or placeholder.
    private var transcriptionArea: some View {
        ScrollView {
            if transcriptionText.isEmpty {
                Text("Appuyez sur le micro pour tester la dictee")
                    .font(.body)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(transcriptionText)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    /// Mic button with three visual states: idle (blue), recording (red + pulse), transcribing (gray + spinner).
    ///
    /// WHY three distinct states:
    /// Clear visual feedback is critical for speech input. The user needs to know:
    /// (1) when the app is ready to listen (blue mic),
    /// (2) when it's actively recording (red pulse = "I'm listening"),
    /// (3) when it's processing their speech (gray spinner = "please wait").
    private var micButtonArea: some View {
        VStack(spacing: 12) {
            Button {
                switch coordinator.status {
                case .idle, .failed:
                    coordinator.startDictation()
                case .recording:
                    coordinator.stopDictation()
                default:
                    break // Transcribing — disabled, do nothing
                }
            } label: {
                micButtonLabel
            }
            .disabled(coordinator.status == .requested || coordinator.status == .transcribing || coordinator.status == .ready)

            // Status label below mic button
            statusLabel
        }
    }

    /// The visual appearance of the mic button changes based on dictation status.
    @ViewBuilder
    private var micButtonLabel: some View {
        ZStack {
            Circle()
                .fill(micButtonColor)
                .frame(width: 72, height: 72)

            if coordinator.status == .transcribing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        // Pulse animation during recording.
        //
        // WHY scaleEffect animation:
        // A subtle pulsing circle is a universal "recording" indicator (like iOS
        // Voice Memos). It provides continuous feedback that the mic is active
        // without being distracting. The animation repeats forever while recording
        // and resets when recording stops.
        .overlay(
            Circle()
                .stroke(Color.red.opacity(0.5), lineWidth: 3)
                .scaleEffect(coordinator.status == .recording ? 1.3 : 1.0)
                .opacity(coordinator.status == .recording ? 0 : 1)
                .animation(
                    coordinator.status == .recording
                        ? .easeInOut(duration: 1.0).repeatForever(autoreverses: false)
                        : .default,
                    value: coordinator.status
                )
        )
    }

    /// Color of the mic button circle based on current status.
    private var micButtonColor: Color {
        switch coordinator.status {
        case .idle, .failed:
            return .blue
        case .recording:
            return .red
        case .requested, .transcribing, .ready:
            return Color(.systemGray3)
        }
    }

    /// Text label shown below the mic button indicating current status.
    @ViewBuilder
    private var statusLabel: some View {
        switch coordinator.status {
        case .idle:
            Text("Appuyez pour enregistrer")
                .font(.caption)
                .foregroundColor(.secondary)
        case .requested:
            Text("Demarrage...")
                .font(.caption)
                .foregroundColor(.secondary)
        case .recording:
            Text("Enregistrement...")
                .font(.caption)
                .foregroundColor(.red)
        case .transcribing:
            Text("Transcription...")
                .font(.caption)
                .foregroundColor(.secondary)
        case .ready:
            Text("Termine")
                .font(.caption)
                .foregroundColor(.green)
        case .failed:
            Text("Erreur - reessayez")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}
