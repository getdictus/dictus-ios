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
/// The scenes after this one (voice notes, vocabulary, history) are the same page with
/// another title, line and scene.
struct OnboardingScenePage<Scene: View>: View {
    let title: Text
    let line: Text
    /// The end of the drawn iPhone the scene shows (`OnboardingPhoneCard`).
    var phoneEnd: OnboardingPhoneEnd = .bottom
    let loopSeconds: Double
    let stillSeconds: Double
    /// The flow's model manager, read for the download pill.
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding installs.
    let modelIdentifier: String
    let onNext: () -> Void
    @ViewBuilder let scene: (Double) -> Scene

    private typealias Phone = OnboardingPhoneMetrics

    var body: some View {
        OnboardingPage(title: title, subtitle: line) {
            OnboardingPhoneCard(end: phoneEnd) {
                AnimatedScenePlayer(loopSeconds: loopSeconds, stillSeconds: stillSeconds, content: scene)
                    // The phone's screen: inside its outline, rounded like it at the end
                    // the card shows, so the drawing never sits under the frame.
                    .clipShape(screenShape)
                    .padding(.horizontal, Phone.phoneFrameWidth)
                    .padding(phoneEnd == .bottom ? .bottom : .top, Phone.phoneFrameWidth)
            }
        } bottom: {
            OnboardingDownloadPill(modelManager: modelManager, modelIdentifier: modelIdentifier)
            OnboardingPrimaryButton(Text("Next"), action: onNext)
                .accessibilityIdentifier("onboarding.primary")
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
