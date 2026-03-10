// DictusApp/Onboarding/ModeSelectionPage.swift
// Onboarding step: default keyboard layer selection.
import SwiftUI
import DictusCore

/// Onboarding page where the user selects their preferred default keyboard layer.
///
/// WHY no @AppStorage here:
/// DefaultLayerPicker owns its own @AppStorage for the defaultKeyboardLayer key.
/// This avoids @Binding propagation issues inside the onboarding flow
/// (which uses .id(currentPage) + transitions that can break binding chains).
struct ModeSelectionPage: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Choisissez votre clavier")
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text("ABC est selectionne par defaut. Changez si vous preferez ouvrir sur les chiffres.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            DefaultLayerPicker()
                .padding(.horizontal, 16)

            Spacer()

            Button(action: onNext) {
                Text("Continuer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.dictusAccent)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}
