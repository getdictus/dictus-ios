// DictusApp/Onboarding/OnboardingScenePage.swift
// The onboarding page that plays one feature scene, with Next and the shell's Skip (#679).
import SwiftUI
import DictusCore

/// A page of the onboarding's scene sequence (#649 decisions 8 and 9, #679): the title
/// and its line, the scene in a drawn iPhone, the download pill, and **Next**.
///
/// WHY NEXT IS NEVER DISABLED: decision 8, a scene never blocks the flow; only the model
/// does, and only on the preparation step. The shell's **Skip** (under **Next**) jumps the
/// whole sequence (`OnboardingStep.stepAfterSceneSequence`); `OnboardingView` owns it.
///
/// The scenes after this one (voice notes, vocabulary, history) are the same page with
/// another title, line and scene.
struct OnboardingScenePage<Scene: View>: View {
    let title: Text
    let line: Text
    /// The end of the drawn iPhone the scene shows (`OnboardingPhoneCard`).
    var phoneEnd: OnboardingPhoneEnd = .bottom
    /// The scene's width over its height, which sizes the drawn iPhone to the room it has.
    let sceneAspectRatio: CGFloat
    let loopSeconds: Double
    /// Where the loop starts when the page appears.
    var startSeconds: Double = 0
    let stillSeconds: Double
    /// The flow's model manager, read for the download pill.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onNext: () -> Void
    @ViewBuilder let scene: (Double) -> Scene

    private typealias Phone = OnboardingPhoneMetrics

    var body: some View {
        // WHY THE PAGE DOES NOT SCROLL (#700): the scene's subject can be its last row (the
        // mic of the Smart Modes scene). On a short screen a scroll view put it under the
        // fold; the drawn iPhone now narrows, keeping its proportions, until the whole
        // scene fits above the button (`OnboardingPhoneFit`). Where there is room, the card
        // keeps the page's width, as before.
        OnboardingPage(title: title, subtitle: line, scrolls: false) {
            GeometryReader { geometry in
                OnboardingPhoneCard(end: phoneEnd) {
                    AnimatedScenePlayer(
                        loopSeconds: loopSeconds,
                        startSeconds: startSeconds,
                        stillSeconds: stillSeconds,
                        content: scene
                    )
                        // The phone's screen: inside its outline, rounded like it at the end
                        // the card shows, so the drawing never sits under the frame.
                        .clipShape(screenShape)
                        .padding(.horizontal, Phone.phoneFrameWidth)
                        .padding(phoneEnd == .bottom ? .bottom : .top, Phone.phoneFrameWidth)
                }
                .frame(width: cardWidth(in: geometry.size))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        } bottom: {
            OnboardingDownloadPill(modelManager: modelManager, modelIdentifier: modelIdentifier)
            OnboardingPrimaryButton(Text("Next"), action: onNext)
                .accessibilityIdentifier("onboarding.primary")
        }
    }

    /// The card's width in `size`: the page's width, or less on a screen too short for it.
    private func cardWidth(in size: CGSize) -> CGFloat {
        let horizontalChrome = (Phone.phoneInset + Phone.phoneFrameWidth) * 2
        let verticalChrome = Phone.phoneInset + Phone.phoneFrameWidth
        return CGFloat(OnboardingPhoneFit.cardWidth(
            availableWidth: Double(size.width),
            availableHeight: Double(size.height),
            sceneAspectRatio: Double(sceneAspectRatio),
            horizontalChrome: Double(horizontalChrome),
            verticalChrome: Double(verticalChrome)
        ))
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
