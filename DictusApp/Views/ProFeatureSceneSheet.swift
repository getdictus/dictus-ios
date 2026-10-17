// DictusApp/Views/ProFeatureSceneSheet.swift
// "See the demo" on each Pro feature screen: the onboarding's scene, in a sheet (#686).
import SwiftUI
import DictusCore

/// A plain text link, "See the demo", that plays the feature's onboarding scene in a
/// sheet (#686, decided on the issue on 2026-10-17). One component, so the four Pro
/// feature screens carry the same words, colour and sheet.
///
/// WHERE IT SITS: at the end of the screen's own "How it works" explanation, or, on a
/// screen without one, at the end of the footer under the feature's switch
/// (`ProFeatureSwitchSection`). That is Apple's "Learn more…" footer link: the switch
/// stays the first row (#216 decision 4), and nothing reads as a media player.
///
/// WHY NOT A ROW OF ITS OWN (Pierre's device test of `7a8274fa`): a first row with a play
/// icon read as a media player, repeated the "How it works" header below it, and pushed
/// the switch off first place.
///
/// Always live, switched off included: the demo is how someone decides to turn the
/// feature on. Callers keep it out of `proFeatureContent(isAvailable:)`.
///
/// The font is the caller's: a footer's footnote, or the explanation's caption.
struct ProFeatureDemoLink: View {
    let feature: ProFeature

    @State private var showsScene = false

    var body: some View {
        Button {
            showsScene = true
        } label: {
            Text("See the demo",
                 comment: "Text link at the end of each Dictus Pro feature screen's explanation or switch footer (Smart Modes, History, Vocabulary, Voice notes); opens the feature's animated demo from the onboarding (#686).")
                .foregroundStyle(Color.dictusAccent)
        }
        // Borderless, so only the link's own words take the tap, not the whole row or
        // footer it ends.
        .buttonStyle(.borderless)
        .accessibilityIdentifier("proFeatureDemoLink")
        .sheet(isPresented: $showsScene) {
            ProFeatureSceneSheet(feature: feature)
        }
    }
}

/// The feature's scene, full size, with its onboarding step's title and sentence, and one
/// OK where the onboarding has Next and Skip (#686).
///
/// The layout is the onboarding page's own (`OnboardingSceneLayout`) and the scene is the
/// shared card (`ProFeatureSceneCard`), so the sheet carries no scene code and no copy of
/// its own. Reduce Motion shows the scene's still moment, as in the onboarding: the player
/// decides that (`AnimatedScenePlayer`).
struct ProFeatureSceneSheet: View {
    let feature: ProFeature

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            OnboardingSceneLayout(
                title: ProFeatureSceneCard.title(for: feature),
                line: ProFeatureSceneCard.line(for: feature)
            ) {
                ProFeatureSceneCard(feature: feature)
            }

            OnboardingPrimaryButton(Text("OK")) {
                dismiss()
            }
            .accessibilityIdentifier("proFeatureScene.ok")
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
        // The onboarding's background, so the card reads the same here and there.
        .background(Color.dictusBackground.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}
