// DictusKeyboard/Views/LanguageSwitcherView.swift
import SwiftUI
import DictusCore

/// Compact language code label in the keyboard toolbar.
///
/// - Tap: cycles through FR → EN → ES → FR and triggers keyboard reload.
/// - Long-press: opens the Dictus app (replaces the old gear icon behavior).
///
/// WHY plain text instead of a pill button:
/// The mic button on the right is a large pill with glow effects. Adding a second,
/// smaller pill on the left creates visual imbalance. Plain text keeps the toolbar
/// clean and lets the mic button remain the single focal point. The haptic feedback
/// + text animation provide sufficient interaction feedback.
struct LanguageSwitcherView: View {
    @State private var language: SupportedLanguage = .active
    var onLanguageChanged: ((SupportedLanguage) -> Void)?

    @Environment(\.openURL) private var openURL

    var body: some View {
        Text(language.shortCode)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(Color(.systemGray))
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .onTapGesture {
                cycleLanguage()
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                HapticFeedback.keyTapped()
                if let url = URL(string: "dictus://") {
                    openURL(url)
                }
            }
    }

    private func cycleLanguage() {
        let next = language.next()

        // Write to App Group so both app and keyboard stay in sync
        AppGroup.defaults.set(next.rawValue, forKey: SharedKeys.language)
        // Also switch keyboard layout to the language's default
        AppGroup.defaults.set(next.defaultLayout.rawValue, forKey: SharedKeys.keyboardLayout)

        // Haptic feedback on language change
        HapticFeedback.keyTapped()

        // Update state with animation
        withAnimation(.easeInOut(duration: 0.15)) {
            language = next
        }

        onLanguageChanged?(next)
    }
}
