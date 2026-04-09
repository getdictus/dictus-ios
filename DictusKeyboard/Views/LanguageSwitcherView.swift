// DictusKeyboard/Views/LanguageSwitcherView.swift
import SwiftUI
import DictusCore

/// Compact language code label in the keyboard toolbar.
///
/// - Tap (touchDown): cycles through FR → EN → ES → FR and triggers keyboard reload.
///
/// WHY plain text instead of a pill button:
/// The mic button on the right is a large pill with glow effects. Adding a second,
/// smaller pill on the left creates visual imbalance. Plain text keeps the toolbar
/// clean and lets the mic button remain the single focal point. The haptic feedback
/// + text animation provide sufficient interaction feedback.
struct LanguageSwitcherView: View {
    @State private var language: SupportedLanguage = .active
    var onLanguageChanged: ((SupportedLanguage) -> Void)?

    /// Prevents double-fire from rapid taps while the keyboard rebuilds.
    @State private var isSwitching = false

    var body: some View {
        Text(language.shortCode)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(Color(.systemGray))
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            // Fire on touchDown for immediate response (better UX than onTapGesture
            // which waits for touchUp). DragGesture(minimumDistance: 0) fires .onChanged
            // as soon as the finger touches the view.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isSwitching else { return }
                        isSwitching = true
                        cycleLanguage()
                    }
                    .onEnded { _ in
                        isSwitching = false
                    }
            )
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
