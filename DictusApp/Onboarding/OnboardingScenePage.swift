// DictusApp/Onboarding/OnboardingScenePage.swift
// The onboarding page that plays one feature scene, with Next and the shell's Skip (#679).
import SwiftUI
import DictusCore

/// A page of the onboarding's scene sequence (#649 decisions 8 and 9, #679): the title
/// and its line, the scene in a drawn iPhone, the download pill, and **Next**.
///
/// WHY NEXT IS NEVER DISABLED: decision 8, a scene never blocks the flow; only the model
/// does, and only on the preparation step. The shell's **Skip** (under **Next**, #700) jumps the
/// whole sequence (`OnboardingStep.stepAfterSceneSequence`); `OnboardingView` owns it.
///
/// Every scene of the sequence (Smart Modes, voice notes, vocabulary, history, #680) is
/// this page with another title, line and scene.
///
/// WHY NOT `OnboardingPage` (#680, device test of 18dc4e99): that page scrolls, so when the
/// download pill took its row the drawn iPhone ran under the page's edge. Here the card
/// takes the height left between the header and the buttons, and shrinks to fit it
/// (`OnboardingFitToHeight`), so the phone is always seen whole. It scrolls only when the
/// text alone leaves no room for a readable card.
struct OnboardingScenePage<Card: View>: View {
    /// A small label above the title, nil for none: "Also in Pro" on the scenes after the
    /// Smart Mode pick (#680), which leave Smart Modes for the other Pro features.
    var eyebrow: Text?
    let title: Text
    let line: Text
    /// The flow's model manager, read for the download pill.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onNext: () -> Void
    /// The scene in its drawn iPhone (`FeatureSceneCard`), the same view the Pro hub's
    /// cards play (#686).
    let card: Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Whether the download pill is on screen: the model is still downloading.
    private var isDownloading: Bool {
        modelManager.modelStates[modelIdentifier] == .downloading
    }

    /// How the page moves when the pill comes or goes (#680, device test of 039aa622): the
    /// pill fades while the card grows or shrinks to its new scale, in one movement,
    /// instead of the phone jumping to its new size when the download ends. With Reduce
    /// Motion on, the change is immediate.
    ///
    /// The scene's loop is not disturbed: its clock lives in the player's state, and a
    /// resize keeps the player's identity.
    private var pillAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.45)
    }

    init(eyebrow: Text? = nil,
         title: Text,
         line: Text,
         modelManager: ModelManager,
         modelIdentifier: String,
         onNext: @escaping () -> Void,
         @ViewBuilder card: () -> Card) {
        self.eyebrow = eyebrow
        self.title = title
        self.line = line
        self.modelManager = modelManager
        self.modelIdentifier = modelIdentifier
        self.onNext = onNext
        self.card = card()
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingSceneLayout(eyebrow: eyebrow, title: title, line: line) {
                card
            }

            VStack(spacing: 12) {
                OnboardingDownloadPill(modelManager: modelManager, modelIdentifier: modelIdentifier)
                OnboardingPrimaryButton(Text("Next"), action: onNext)
                    .accessibilityIdentifier("onboarding.primary")
                // The shell's Skip row (#700): reserved on every step, so Next sits at the
                // same height as every other step's button.
                OnboardingSkipRow()
            }
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
        .animation(pillAnimation, value: isDownloading)
    }
}

/// The top of a scene page: the eyebrow, the title and its line, then the scene's card in
/// the height that is left. The onboarding's scene pages and the "See how it works" sheet
/// of the Pro feature screens (#686) both use it, each with its own buttons under it.
struct OnboardingSceneLayout<Card: View>: View {
    /// A small label above the title, nil for none.
    var eyebrow: Text?
    let title: Text
    let line: Text
    let card: Card

    init(eyebrow: Text? = nil, title: Text, line: Text, @ViewBuilder card: () -> Card) {
        self.eyebrow = eyebrow
        self.title = title
        self.line = line
        self.card = card()
    }

    /// The least height the card is drawn at. Under it the phone would be too small to
    /// read, so the page scrolls instead (`body`).
    ///
    /// WHY 160: it must stay under what the smallest supported iPhone leaves at the
    /// default text size with the download pill showing (about 230 pt on an iPhone SE,
    /// measured on #680's captures), or that ordinary case would scroll and the phone would
    /// run under the pill again. 260 did exactly that.
    private static var minimumCardHeight: CGFloat { 160 }

    var body: some View {
        // WHY TWO LAYOUTS (CodeRabbit on PR #722): the fitted one does not scroll, so
        // a title and line taller than the screen (the accessibility text sizes, a
        // small iPhone) used to push everything below them off the page. When the
        // header and a card of at least `minimumCardHeight` fit, the card takes the
        // rest of the height, as before. When they do not, the same content scrolls,
        // with the card at that minimum height. The buttons under this view are
        // outside both, pinned, so they are always reachable.
        ViewThatFits(in: .vertical) {
            VStack(spacing: 0) {
                header
                OnboardingFitToHeight {
                    card
                }
                .frame(minHeight: Self.minimumCardHeight)
                .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                .padding(.bottom, 16)
            }

            ScrollView {
                VStack(spacing: 0) {
                    header
                    OnboardingFitToHeight {
                        card
                    }
                    .frame(height: Self.minimumCardHeight)
                    .padding(.horizontal, OnboardingMetrics.horizontalPadding)
                    .padding(.bottom, 16)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// The eyebrow, the title and the line.
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                eyebrow
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dictusAccent)
            }
            OnboardingHeader(title: title, subtitle: line)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, OnboardingMetrics.titleTopPadding)
        .padding(.bottom, 24)
        .padding(.horizontal, OnboardingMetrics.horizontalPadding)
    }
}
