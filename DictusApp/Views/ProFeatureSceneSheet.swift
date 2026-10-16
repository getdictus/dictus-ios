// DictusApp/Views/ProFeatureSceneSheet.swift
// "See how it works" on each Pro feature screen: the onboarding's scene, in a sheet (#686).
import SwiftUI
import DictusCore

/// The first section of each Pro feature screen the hub opens (#686, decided on the issue
/// on 2026-10-16): one row that plays the feature's onboarding scene in a sheet.
///
/// WHY HERE AND NOT ON THE HUB CARDS (Pierre's device test of PR #743): scenes inside the
/// hub's cards turned the hub into a sales page for someone who already pays, made the
/// Settings row the smallest thing on each card, cropped each scene differently, and lost
/// the title and sentence that explain them. On the feature's own screen, the scene is
/// asked for, shown whole, and keeps its words.
struct ProFeatureHowItWorksSection: View {
    let feature: ProFeature

    @State private var showsScene = false

    var body: some View {
        Section {
            Button {
                showsScene = true
            } label: {
                Label {
                    Text("See how it works",
                         comment: "Row at the top of each Dictus Pro feature screen (Smart Modes, History, Vocabulary, Voice notes); opens the feature's animated demo from the onboarding (#686).")
                        .foregroundStyle(Color.dictusAccent)
                } icon: {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(Color.dictusAccent)
                }
            }
            .sheet(isPresented: $showsScene) {
                ProFeatureSceneSheet(feature: feature)
            }
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
