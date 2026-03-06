// DictusKeyboard/Views/ToolbarView.swift
import SwiftUI
import DictusCore

/// Toolbar displayed above the keyboard with app shortcut and mic button.
/// Inspired by Wispr Flow — the mic button is the primary dictation trigger.
///
/// WHY Link instead of Button:
/// Keyboard extensions cannot access UIApplication.shared, so opening a URL scheme
/// requires using SwiftUI's Link(destination:) which bypasses UIApplication entirely.
/// This is the only way to open DictusApp from within the keyboard extension.
struct ToolbarView: View {
    let hasFullAccess: Bool
    let dictationStatus: DictationStatus

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
                // Idle: subtle mic icon that opens DictusApp via URL scheme
                Link(destination: URL(string: "dictus://dictate")!) {
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
