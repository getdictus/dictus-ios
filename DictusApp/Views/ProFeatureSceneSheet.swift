// DictusApp/Views/ProFeatureSceneSheet.swift
// "See the demo" on each Pro feature screen: the onboarding's scene, in a sheet (#686).
import SwiftUI
import DictusCore

/// The "How it works" section of each Pro feature screen, right under the feature's
/// switch (#686, amended on the issue on 2026-10-17): a short paragraph, then the
/// "See the demo" link inside the same card. One component, so the four screens carry
/// the same header, sizes, colours and sheet.
///
/// WHY A SECTION AND NOT A FOOTER LINK (Pierre's device test of `e45d29f6`): Voice notes
/// already had this card and its link read right; on the three other screens a lone
/// footnote link under the switch was too small and looked orphaned.
///
/// WHY NOT A FIRST ROW (device test of `7a8274fa`): a row with a play icon read as a
/// media player and pushed the switch off first place (#216 decision 4).
///
/// Off, the paragraph dims with the rest of the locked content
/// (`proFeatureContent(isAvailable:)`), but the link stays live: the demo is how someone
/// decides to turn the feature on.
struct ProFeatureHowItWorksSection: View {
    let feature: ProFeature

    /// The paragraph above the link.
    let explanation: Text

    /// `FeatureGate.isAvailable(feature)`, the one predicate, read by the screen.
    let isAvailable: Bool

    /// The paragraph defaults to the line under the feature's onboarding title
    /// (`ProFeatureSceneCard.line(for:)`): the sentence the demo itself opens with, so no
    /// copy of its own.
    init(feature: ProFeature, explanation: Text? = nil, isAvailable: Bool) {
        self.feature = feature
        self.explanation = explanation ?? ProFeatureSceneCard.line(for: feature)
        self.isAvailable = isAvailable
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                explanation
                    .foregroundColor(.secondary)
                    .proFeatureContent(isAvailable: isAvailable)

                ProFeatureDemoLink(feature: feature)
            }
            .font(.dictusCaption)
        } header: {
            Text("How it works")
        }
    }
}

/// The plain text link, "See the demo", that plays the feature's onboarding scene in a
/// sheet (#686). Lives at the end of `ProFeatureHowItWorksSection`; the font is the
/// section's.
struct ProFeatureDemoLink: View {
    let feature: ProFeature

    @State private var showsScene = false

    var body: some View {
        Button {
            showsScene = true
        } label: {
            Text("See the demo",
                 comment: "Text link at the end of the \"How it works\" card of each Dictus Pro feature screen (Smart Modes, History, Vocabulary, Voice notes); opens the feature's animated demo from the onboarding (#686).")
                .foregroundStyle(Color.dictusAccent)
        }
        // Borderless, so only the link's own words take the tap, not the whole row.
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
