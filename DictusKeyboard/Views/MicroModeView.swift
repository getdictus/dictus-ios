// DictusKeyboard/Views/MicroModeView.swift
// Dictation-only keyboard mode: large centered mic button + globe for input switching.
import SwiftUI
import DictusCore

/// Minimal keyboard layout for dictation-first users.
///
/// WHY a separate view instead of conditionals in KeyboardRootView:
/// Each keyboard mode has distinct layout logic. Extracting into separate views
/// keeps KeyboardRootView as a thin router and makes each mode independently
/// maintainable. Single Responsibility Principle.
///
/// Layout:
/// - Large centered mic button (~120pt wide pill) with "Dicter" label below
/// - Globe button in bottom-left for switching to next input method
/// - No other controls (no backspace, no space, no suggestions)
/// - Uses totalHeight parameter to match other modes' height (no layout jump)
struct MicroModeView: View {
    let controller: UIInputViewController
    let dictationStatus: DictationStatus
    let onMicTap: () -> Void
    let totalHeight: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Centered mic button with label
            VStack(spacing: 12) {
                Spacer()

                // Large mic button -- pill shape, ~120pt wide.
                // WHY not using scaleEffect on AnimatedMicButton:
                // scaleEffect causes blur on retina displays because it rasterizes
                // the view at its original size then scales the bitmap. Instead we
                // build a custom large pill button with the same visual language.
                Button(action: onMicTap) {
                    ZStack {
                        // Glass background pill
                        Capsule()
                            .fill(micFillColor)
                            .frame(width: 120, height: 56)
                            .dictusGlass(in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(micStrokeColor, lineWidth: 2)
                                    .frame(width: 130, height: 66)
                            )

                        // Mic icon
                        Image(systemName: "mic.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(GlassPressStyle(pressedScale: 0.92))
                .disabled(dictationStatus == .recording || dictationStatus == .transcribing)

                Text("Dicter")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Globe button -- bottom-left corner for input method switching.
            // WHY advanceToNextInputMode:
            // This is the standard iOS API for keyboard extensions to switch
            // to the next keyboard in the user's keyboard list. Apple requires
            // all custom keyboards to provide this capability.
            Button {
                controller.advanceToNextInputMode()
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
            }
            .padding(.leading, 8)
            .padding(.bottom, 4)
        }
        .frame(height: totalHeight)
    }

    // MARK: - Helpers

    private var micFillColor: Color {
        switch dictationStatus {
        case .recording:
            return .dictusRecording
        case .transcribing:
            return .dictusAccentHighlight.opacity(0.5)
        default:
            return .dictusAccent
        }
    }

    private var micStrokeColor: Color {
        switch dictationStatus {
        case .recording:
            return Color.dictusRecording.opacity(0.5)
        default:
            return Color.dictusAccent.opacity(0.4)
        }
    }
}
