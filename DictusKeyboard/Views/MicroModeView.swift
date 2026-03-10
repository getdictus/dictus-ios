// DictusKeyboard/Views/MicroModeView.swift
// Dictation-only keyboard mode: large centered mic button + bottom key rows.
import SwiftUI
import AudioToolbox
import DictusCore

/// Minimal keyboard layout for dictation-first users.
///
/// Layout (when not in emoji):
/// - Large centered mic button (~120pt wide pill) with "Dicter" label below
/// - Penultimate row: delete key right-aligned (like row 3 of real keyboard)
/// - Bottom row: emoji (left) + space (centered) + return (right)
///
/// Layout (when emoji active):
/// - Full-height EmojiPickerView (same component as full keyboard mode)
///
/// WHY Color.clear background: The native iOS keyboard container provides a
/// blurred background. Using secondarySystemBackground created a visible
/// color mismatch band. Transparent lets the native chrome show through,
/// matching the full keyboard mode's approach (see KeyboardRootView).
struct MicroModeView: View {
    let controller: UIInputViewController
    let dictationStatus: DictationStatus
    let onMicTap: () -> Void
    let totalHeight: CGFloat

    @State private var isEmojiMode = false

    /// Side key width for emoji and return buttons (equal width, centered space).
    /// Uses the same multiplier-based calculation as the full keyboard's row 4.
    /// Proportions: emoji(1.2) + space(4.5) + return(1.2) = 6.9 total.
    private var sideKeyWidth: CGFloat {
        let totalMult: CGFloat = 1.2 + 4.5 + 1.2
        let totalSpacing = 2 * KeyMetrics.keySpacing
        let available = UIScreen.main.bounds.width - (KeyMetrics.rowHorizontalPadding * 2) - totalSpacing
        return available * 1.2 / totalMult
    }

    /// Delete key width matching full keyboard's row 3 delete (1.5x unit).
    private var deleteKeyWidth: CGFloat {
        // Approximate: use same proportions as row 3 (shift 1.5 + 7 letters + accent 1.0 + delete 1.5 = 11.5)
        let totalSpacing = 8 * KeyMetrics.keySpacing // 9 keys = 8 gaps
        let available = UIScreen.main.bounds.width - (KeyMetrics.rowHorizontalPadding * 2) - totalSpacing
        return available * 1.5 / 11.5
    }

    var body: some View {
        if isEmojiMode {
            // Emoji picker replaces the entire micro mode layout.
            // Uses full totalHeight so the picker has the same space as in full mode.
            EmojiPickerView(
                onEmojiInsert: { emoji in
                    controller.textDocumentProxy.insertText(emoji)
                },
                onDelete: {
                    controller.textDocumentProxy.deleteBackward()
                },
                onDismiss: {
                    HapticFeedback.keyTapped()
                    AudioServicesPlaySystemSound(KeySound.modifier)
                    isEmojiMode = false
                }
            )
            .frame(height: totalHeight)
            .clipped()
        } else {
            VStack(spacing: 0) {
                // Top area: centered mic button with label (takes remaining space)
                VStack(spacing: 12) {
                    Spacer()

                    // Large mic button -- pill shape, ~120pt wide.
                    Button(action: onMicTap) {
                        ZStack {
                            Capsule()
                                .fill(micFillColor)
                                .frame(width: 120, height: 56)
                                .dictusGlass(in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(micStrokeColor, lineWidth: 2)
                                        .frame(width: 130, height: 66)
                                )

                            Image(systemName: "mic.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(GlassPressStyle(pressedScale: 0.92))
                    .disabled(dictationStatus == .recording || dictationStatus == .transcribing || dictationStatus == .requested)

                    Text("Dicter")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // Penultimate row: delete key right-aligned.
                // Positioned like row 3 of the real keyboard so muscle memory works.
                HStack(spacing: KeyMetrics.keySpacing) {
                    Spacer()
                    Button {
                        controller.textDocumentProxy.deleteBackward()
                        HapticFeedback.keyTapped()
                        AudioServicesPlaySystemSound(KeySound.delete)
                    } label: {
                        Image(systemName: "delete.backward")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: deleteKeyWidth, height: KeyMetrics.keyHeight)
                            .background(
                                RoundedRectangle(cornerRadius: KeyMetrics.keyCornerRadius)
                                    .fill(KeyMetrics.letterKeyColor)
                                    .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
                            )
                    }
                    .foregroundColor(Color(.label))
                }
                .padding(.horizontal, KeyMetrics.rowHorizontalPadding)

                Spacer().frame(height: KeyMetrics.rowSpacing)

                // Bottom row: emoji (left) + space (centered) + return (right).
                // Emoji and return have equal widths for visual balance.
                // Space bar is centered between them, matching full keyboard proportions.
                HStack(spacing: KeyMetrics.keySpacing) {
                    // Emoji button -- opens our custom EmojiPickerView
                    Button {
                        HapticFeedback.keyTapped()
                        AudioServicesPlaySystemSound(KeySound.modifier)
                        isEmojiMode = true
                    } label: {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: sideKeyWidth, height: KeyMetrics.keyHeight)
                            .background(
                                RoundedRectangle(cornerRadius: KeyMetrics.keyCornerRadius)
                                    .fill(KeyMetrics.letterKeyColor)
                                    .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
                            )
                    }
                    .foregroundColor(Color(.label))

                    // Space bar -- takes remaining width, centered between emoji and return
                    Button {
                        controller.textDocumentProxy.insertText(" ")
                        HapticFeedback.keyTapped()
                        AudioServicesPlaySystemSound(KeySound.modifier)
                    } label: {
                        Text("espace")
                            .font(.system(size: 15))
                            .foregroundColor(Color(.label))
                            .frame(maxWidth: .infinity)
                            .frame(height: KeyMetrics.keyHeight)
                            .background(
                                RoundedRectangle(cornerRadius: KeyMetrics.keyCornerRadius)
                                    .fill(KeyMetrics.letterKeyColor)
                                    .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
                            )
                    }

                    // Return key -- same width as emoji for balance
                    Button {
                        controller.textDocumentProxy.insertText("\n")
                        HapticFeedback.keyTapped()
                        AudioServicesPlaySystemSound(KeySound.modifier)
                    } label: {
                        Image(systemName: "return.left")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: sideKeyWidth, height: KeyMetrics.keyHeight)
                            .background(
                                RoundedRectangle(cornerRadius: KeyMetrics.keyCornerRadius)
                                    .fill(KeyMetrics.letterKeyColor)
                                    .shadow(color: .black.opacity(0.15), radius: 0, x: 0, y: 1)
                            )
                    }
                    .foregroundColor(Color(.label))
                }
                .padding(.horizontal, KeyMetrics.rowHorizontalPadding)
                .padding(.bottom, 4)
            }
            .frame(height: totalHeight)
            .background(Color.clear)
        }
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
