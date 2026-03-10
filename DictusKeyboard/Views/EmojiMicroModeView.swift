// DictusKeyboard/Views/EmojiMicroModeView.swift
// Emoji + Mic keyboard mode: emoji picker with mic pill in a compact toolbar.
import SwiftUI
import DictusCore

/// Keyboard layout combining emoji picker with dictation mic.
///
/// Layout (top to bottom):
/// - Compact toolbar (40pt): gear icon (left, opens Dictus app) + mic pill (right).
/// - EmojiPickerView: horizontal LazyHGrid with category bar and search.
///
/// WHY no height expansion (previous totalHeight + 56 caused overflow):
/// EmojiPickerView was designed to fill the full keyboard height. In full mode,
/// the toolbar and spacer are hidden when emoji is active, giving it all 266pt.
/// Here the toolbar stays visible, so the picker gets totalHeight - 40pt.
/// This is slightly less space, but the picker handles it gracefully with its
/// ScrollView. The category bar and grid fit within the available height.
struct EmojiMicroModeView: View {
    let controller: UIInputViewController
    let hasFullAccess: Bool
    let dictationStatus: DictationStatus
    let onMicTap: () -> Void
    let totalHeight: CGFloat

    /// Compact toolbar height — smaller than full mode's 48pt to give
    /// more vertical space to the emoji picker.
    private let toolbarHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            // Compact toolbar: gear left, mic pill right.
            HStack {
                // Gear icon -- opens Dictus app for settings.
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
            .frame(height: toolbarHeight)

            // Emoji picker with explicit size constraints to prevent overflow.
            // The picker fills remaining height after toolbar.
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
            .frame(maxWidth: .infinity)
            .frame(height: totalHeight - toolbarHeight)
            .clipped()
        }
        .frame(width: UIScreen.main.bounds.width, height: totalHeight)
        .clipped()
    }
}
