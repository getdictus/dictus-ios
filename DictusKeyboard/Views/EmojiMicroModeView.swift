// DictusKeyboard/Views/EmojiMicroModeView.swift
// Emoji + Mic keyboard mode: emoji picker with mic pill in a simplified toolbar.
import SwiftUI
import DictusCore

/// Keyboard layout combining emoji picker with dictation mic.
///
/// WHY a dedicated view instead of reusing full keyboard with emoji toggle:
/// The full keyboard's emoji mode is a toggle state (isEmojiMode) that replaces
/// the AZERTY keys. In emojiMicro mode, the emoji picker IS the permanent layout
/// -- there's no keyboard to toggle back to. Different mental model = different view.
///
/// Layout (top to bottom):
/// - Simplified toolbar: globe (left) + mic pill (right). No suggestions, no gear.
/// - EmojiPickerView: horizontal LazyHGrid with category bar and search.
/// - Uses totalHeight parameter to match other modes' height.
struct EmojiMicroModeView: View {
    let controller: UIInputViewController
    let hasFullAccess: Bool
    let dictationStatus: DictationStatus
    let onMicTap: () -> Void
    let totalHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Simplified toolbar: globe left, mic pill right.
            // WHY no suggestions or gear:
            // This mode is for emoji + dictation users. Text suggestions don't apply
            // (no typing happening), and settings are accessible from the main app.
            HStack {
                // Globe for input method switching
                Button {
                    controller.advanceToNextInputMode()
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Mic pill for dictation
                AnimatedMicButton(status: dictationStatus, isPill: true, onTap: onMicTap)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)

            // Emoji picker -- reuses the existing EmojiPickerView component.
            // WHY reuse: Same horizontal grid, category bar, search functionality.
            // The onDismiss closure is a no-op because in this mode there's no
            // keyboard to "dismiss back to" -- emoji IS the mode.
            EmojiPickerView(
                onEmojiInsert: { emoji in
                    controller.textDocumentProxy.insertText(emoji)
                },
                onDelete: {
                    controller.textDocumentProxy.deleteBackward()
                },
                onDismiss: {
                    // No-op: emoji picker is always visible in this mode.
                    // In full keyboard mode, this would toggle back to AZERTY.
                }
            )
        }
        .frame(height: totalHeight)
    }
}
