// DictusApp/Onboarding/ModeSelectionPage.swift
// Onboarding step 3: keyboard mode selection with blocking "Continuer" button.
import SwiftUI
import DictusCore

/// Onboarding page where the user selects their preferred keyboard mode.
///
/// WHY this is a blocking step:
/// The keyboard mode determines which layout the keyboard extension renders.
/// If no mode is selected, the extension wouldn't know what to show. We default
/// the @AppStorage to an empty string here (not .full) so the user must make
/// an explicit choice — the "Continuer" button is disabled until they pick.
///
/// WHY reuse KeyboardModePicker:
/// Same component as in SettingsView. The user sees the same miniature previews
/// during onboarding and can later change their choice in Settings.
struct ModeSelectionPage: View {
    let onNext: () -> Void

    /// WHY empty string default (not .full):
    /// During onboarding, we want to force the user to actively choose.
    /// An empty string means "no selection yet" — the Continuer button stays disabled.
    /// Once they tap a segment, the picker writes the rawValue and the button enables.
    @AppStorage(SharedKeys.keyboardMode, store: UserDefaults(suiteName: AppGroup.identifier))
    private var keyboardMode = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("Choisissez votre clavier")
                .font(.title2.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Subtitle explaining the choice
            Text("Vous pourrez changer a tout moment dans les reglages.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            // Reusable mode picker with previews
            KeyboardModePicker(selectedMode: $keyboardMode)
                .padding(.horizontal, 16)

            Spacer()

            // Continue button — disabled until a mode is selected
            Button(action: onNext) {
                Text("Continuer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.dictusAccent)
            .disabled(keyboardMode.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color.dictusBackground.ignoresSafeArea())
    }
}
