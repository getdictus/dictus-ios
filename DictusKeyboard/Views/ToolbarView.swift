// DictusKeyboard/Views/ToolbarView.swift
import SwiftUI
import DictusCore

/// Toolbar displayed above the keyboard with app shortcut and mic button.
/// Inspired by Wispr Flow — the mic button is the primary dictation trigger.
///
/// WHY onMicTap callback:
/// The mic button calls back to KeyboardState.startRecording(), which sets local
/// state to .requested (triggering the recording overlay) and then opens DictusApp
/// via URL scheme to begin the actual recording. This replaces the Phase 2 Link
/// approach that opened the app without showing any in-keyboard UI.
struct ToolbarView: View {
    let hasFullAccess: Bool
    let dictationStatus: DictationStatus
    var onMicTap: () -> Void

    var body: some View {
        HStack {
            // Left: gear icon to open DictusApp settings
            if hasFullAccess {
                // Safe to force-unwrap: compile-time literal, always valid URL
                Link(destination: URL(string: "dictus://")!) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                        .frame(width: 32, height: 32)
                }
            }

            Spacer()

            // Right: mic button with state-dependent appearance
            micButton
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color(.separator).opacity(0.3))
                    .frame(height: 0.5)
            }
        )
    }

    @ViewBuilder
    private var micButton: some View {
        if !hasFullAccess {
            // Disabled state: gray mic icon, not tappable
            micIcon(color: Color(.systemGray3), background: Color(.systemGray5))
        } else {
            switch dictationStatus {
            case .idle, .ready, .failed:
                // Idle: subtle mic icon triggers in-keyboard recording flow
                Button(action: onMicTap) {
                    micIcon(color: Color(.systemGray), background: Color(.systemGray5))
                }

            case .requested:
                // Requested: pulsing to indicate app is opening
                micIcon(color: .blue, background: Color.blue.opacity(0.15))
                    .opacity(0.7)

            case .recording:
                // Recording: animated pulsing mic — NOT a link (stop is in overlay)
                micIcon(color: .red, background: Color.red.opacity(0.15))
                    .opacity(pulsingOpacity)
                    .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        pulsingOpacity = 0.4
                    }}

            case .transcribing:
                // Transcribing: spinner appearance
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 32, height: 32)
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
    }

    @State private var pulsingOpacity: Double = 1.0

    private func micIcon(color: Color, background: Color) -> some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(background)
            )
    }
}
