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
/// - Simplified toolbar: gear icon (left, opens Dictus app) + mic pill (right).
/// - EmojiPickerView: horizontal LazyHGrid with category bar and search.
/// - Uses totalHeight + 56 to compensate for toolbar stealing vertical space
///   (matching full mode's expansion when emoji is active).
struct EmojiMicroModeView: View {
    let controller: UIInputViewController
    let hasFullAccess: Bool
    let dictationStatus: DictationStatus
    let onMicTap: () -> Void
    let totalHeight: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // Simplified toolbar: gear left, mic pill right.
            HStack {
                // Gear icon -- opens Dictus app for settings.
                // WHY gear instead of globe: iOS already provides a globe icon
                // via the system keyboard switcher. The gear matches ToolbarView's
                // pattern and gives users quick access to settings.
                Link(destination: URL(string: "dictus://")!) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                        .frame(width: 32, height: 32)
                }

                Spacer()

                // Mic pill for dictation
                AnimatedMicButton(status: dictationStatus, isPill: true, onTap: onMicTap)
            }
            .padding(.horizontal, 12)
            .frame(height: 48)

            // Emoji picker -- reuses the existing EmojiPickerView component.
            // WHY reuse: Same horizontal grid, category bar, search functionality.
            // onDismiss wired to advanceToNextInputMode so the ABC button in
            // EmojiCategoryBar acts as keyboard switcher (replaces removed globe).
            EmojiPickerView(
                onEmojiInsert: { emoji in
                    controller.textDocumentProxy.insertText(emoji)
                },
                onDelete: {
                    controller.textDocumentProxy.deleteBackward()
                },
                onDismiss: {
                    // ABC button switches to next input method.
                    controller.advanceToNextInputMode()
                }
            )
            .clipped()
        }
        // WHY totalHeight + 56: EmojiPickerView was designed to use the full
        // keyboard height. In full mode, the toolbar (48pt) and spacer (8pt) are
        // hidden when emoji is active, giving emoji the full space. Here the toolbar
        // stays visible, so we add 56pt to compensate.
        .frame(height: totalHeight + 56)
        .clipped()
    }
}
