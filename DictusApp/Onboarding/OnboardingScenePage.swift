// DictusApp/Onboarding/OnboardingScenePage.swift
// The onboarding page that plays one feature scene, with Next and the shell's Skip (#679).
import SwiftUI
import DictusCore

/// A page of the onboarding's scene sequence (#649 decisions 8 and 9, #679): the title
/// and its line, the scene in a drawn iPhone, the download pill, and **Next**.
///
/// WHY NEXT IS NEVER DISABLED: decision 8, a scene never blocks the flow; only the model
/// does, and only on the preparation step. The shell's **Skip** (top right) jumps the
/// whole sequence (`OnboardingStep.stepAfterSceneSequence`); `OnboardingView` owns it.
///
/// Every scene of the sequence (Smart Modes, voice notes, vocabulary, history, #680) is
/// this page with another title, line and scene.
///
/// WHY NOT `OnboardingPage` (#680, device test of 18dc4e99): that page scrolls, so when the
/// download pill took its row the drawn iPhone ran under the page's edge. Here the card
/// takes the height left between the header and the buttons, and shrinks to fit it
/// (`OnboardingFitToHeight`), so the phone is always seen whole.
struct OnboardingScenePage<Scene: View, CardHeader: View>: View {
    /// A small label above the title, nil for none: "Also in Pro" on the scenes after the
    /// Smart Mode pick (#680), which leave Smart Modes for the other Pro features.
    var eyebrow: Text?
    let title: Text
    let line: Text
    /// The end of the drawn iPhone the scene shows (`OnboardingPhoneCard`).
    var phoneEnd: OnboardingPhoneEnd = .bottom
    /// Drawn in the card above the phone (`OnboardingPhoneCard.header`) at a moment of the
    /// loop, nothing for most scenes. The voice notes scene's caption and chips change
    /// with its chapter (#680), so they follow the scene's clock.
    let cardHeader: (Double) -> CardHeader
    let loopSeconds: Double
    /// Where the loop starts when the page appears.
    var startSeconds: Double = 0
    let stillSeconds: Double
    /// The flow's model manager, read for the download pill.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onNext: () -> Void
    let scene: (Double) -> Scene

    private typealias Phone = OnboardingPhoneMetrics

    init(eyebrow: Text? = nil,
         title: Text,
         line: Text,
         phoneEnd: OnboardingPhoneEnd = .bottom,
         loopSeconds: Double,
         startSeconds: Double = 0,
         stillSeconds: Double,
         modelManager: ModelManager,
         modelIdentifier: String,
         onNext: @escaping () -> Void,
         @ViewBuilder cardHeader: @escaping (Double) -> CardHeader,
         @ViewBuilder scene: @escaping (Double) -> Scene) {
        self.eyebrow = eyebrow
        self.title = title
        self.line = line
        self.phoneEnd = phoneEnd
        self.cardHeader = cardHeader
        self.loopSeconds = loopSeconds
        self.startSeconds = startSeconds
        self.stillSeconds = stillSeconds
        self.modelManager = modelManager
        self.modelIdentifier = modelIdentifier
        self.onNext = onNext
        self.scene = scene
    }

    var body: some View {
        VStack(spacing: 0) {
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

            OnboardingFitToHeight {
                card
            }
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, 16)

            VStack(spacing: 12) {
                OnboardingDownloadPill(modelManager: modelManager, modelIdentifier: modelIdentifier)
                OnboardingPrimaryButton(Text("Next"), action: onNext)
                    .accessibilityIdentifier("onboarding.primary")
            }
            .padding(.horizontal, OnboardingMetrics.horizontalPadding)
            .padding(.bottom, OnboardingMetrics.buttonBottomPadding)
        }
    }

    /// The drawn iPhone in its card, with the header above it.
    private var card: some View {
        // One player for the whole card, so the header above the phone and the scene
        // inside it read the same clock.
        AnimatedScenePlayer(
            loopSeconds: loopSeconds,
            startSeconds: startSeconds,
            stillSeconds: stillSeconds
        ) { time in
            OnboardingPhoneCard(end: phoneEnd) {
                cardHeader(time)
            } content: {
                scene(time)
                    // The phone's screen: inside its outline, rounded like it at the
                    // end the card shows, so the drawing never sits under the frame.
                    .clipShape(screenShape)
                    .padding(.horizontal, Phone.phoneFrameWidth)
                    .padding(phoneEnd == .bottom ? .bottom : .top, Phone.phoneFrameWidth)
            }
        }
    }

    /// The phone's screen: the outline's inner curve at the end the card shows.
    private var screenShape: UnevenRoundedRectangle {
        let radius = Phone.phoneCornerRadius - Phone.phoneFrameWidth
        let showsBottom = phoneEnd == .bottom
        return UnevenRoundedRectangle(
            topLeadingRadius: showsBottom ? 0 : radius,
            bottomLeadingRadius: showsBottom ? radius : 0,
            bottomTrailingRadius: showsBottom ? radius : 0,
            topTrailingRadius: showsBottom ? 0 : radius,
            style: .continuous
        )
    }
}

extension OnboardingScenePage where CardHeader == EmptyView {
    /// A scene with nothing above its phone, which is every scene but voice notes.
    init(eyebrow: Text? = nil,
         title: Text,
         line: Text,
         phoneEnd: OnboardingPhoneEnd = .bottom,
         loopSeconds: Double,
         startSeconds: Double = 0,
         stillSeconds: Double,
         modelManager: ModelManager,
         modelIdentifier: String,
         onNext: @escaping () -> Void,
         @ViewBuilder scene: @escaping (Double) -> Scene) {
        self.init(eyebrow: eyebrow, title: title, line: line, phoneEnd: phoneEnd, loopSeconds: loopSeconds,
                  startSeconds: startSeconds, stillSeconds: stillSeconds, modelManager: modelManager,
                  modelIdentifier: modelIdentifier, onNext: onNext, cardHeader: { _ in EmptyView() }, scene: scene)
    }
}
