// DictusApp/Onboarding/FeatureSceneCard.swift
// A feature scene playing in its drawn iPhone: one view for the onboarding and the Pro hub (#686).
import SwiftUI
import DictusCore

/// A scene playing in the drawn iPhone card (#649 decision 12, #686): the player and the
/// phone around it, nothing else.
///
/// WHY ITS OWN VIEW: the onboarding's scene pages (#679, #680) and the Pro hub's feature
/// cards (#216) show the same scene in the same phone. The page adds its title, the
/// download pill and Next; the hub card adds its Settings row under it. Neither carries a
/// copy of the scene's timing or drawing.
struct FeatureSceneCard<Scene: View, Header: View>: View {
    /// The end of the drawn iPhone the scene shows (`OnboardingPhoneCard`).
    var phoneEnd: OnboardingPhoneEnd = .bottom
    let loopSeconds: Double
    /// Where the loop starts when the scene first appears.
    var startSeconds: Double = 0
    let stillSeconds: Double
    /// Drawn in the card above the phone at a moment of the loop: the voice notes scene's
    /// caption and chips (#680), which follow its chapter. Nothing for the other scenes.
    let header: (Double) -> Header
    let scene: (Double) -> Scene

    private typealias Phone = OnboardingPhoneMetrics

    init(phoneEnd: OnboardingPhoneEnd = .bottom,
         loopSeconds: Double,
         startSeconds: Double = 0,
         stillSeconds: Double,
         @ViewBuilder header: @escaping (Double) -> Header,
         @ViewBuilder scene: @escaping (Double) -> Scene) {
        self.phoneEnd = phoneEnd
        self.loopSeconds = loopSeconds
        self.startSeconds = startSeconds
        self.stillSeconds = stillSeconds
        self.header = header
        self.scene = scene
    }

    var body: some View {
        // One player for the whole card, so the header above the phone and the scene
        // inside it read the same clock.
        AnimatedScenePlayer(
            loopSeconds: loopSeconds,
            startSeconds: startSeconds,
            stillSeconds: stillSeconds
        ) { time in
            OnboardingPhoneCard(end: phoneEnd) {
                header(time)
            } content: {
                scene(time)
                    // The phone's screen: inside its outline, rounded like it at the
                    // end the card shows, so the drawing never sits under the frame.
                    .clipShape(Phone.screenShape(end: phoneEnd))
                    .padding(.horizontal, Phone.phoneFrameWidth)
                    .padding(phoneEnd == .bottom ? .bottom : .top, Phone.phoneFrameWidth)
            }
        }
    }
}

extension FeatureSceneCard where Header == EmptyView {
    /// A scene with nothing above its phone, which is every scene but voice notes.
    init(phoneEnd: OnboardingPhoneEnd = .bottom,
         loopSeconds: Double,
         startSeconds: Double = 0,
         stillSeconds: Double,
         @ViewBuilder scene: @escaping (Double) -> Scene) {
        self.init(phoneEnd: phoneEnd, loopSeconds: loopSeconds, startSeconds: startSeconds,
                  stillSeconds: stillSeconds, header: { _ in EmptyView() }, scene: scene)
    }
}

/// The scene of a Pro feature, by feature: what a hub card plays (#686) and what each
/// onboarding scene page shows. Each scene's own card (`SmartModesSceneCard` and the
/// others) holds its timing and its data, next to its drawing.
struct ProFeatureSceneCard: View {
    let feature: ProFeature

    var body: some View {
        switch feature {
        case .smartMode: SmartModesSceneCard()
        case .voiceNotes: VoiceNotesSceneCard()
        case .vocabulary: VocabularySceneCard()
        case .history: HistorySceneCard()
        }
    }
}
