// DictusApp/Onboarding/FeatureSceneCard.swift
// A feature scene playing in its drawn iPhone: one view for the onboarding and the feature screens (#686).
import SwiftUI
import DictusCore

/// A scene playing in the drawn iPhone card (#649 decision 12, #686): the player and the
/// phone around it, nothing else.
///
/// WHY ITS OWN VIEW: the onboarding's scene pages (#679, #680) and the "See how it works"
/// sheet of each Pro feature screen (#686) show the same scene in the same phone, and What's
/// new (#685) will too. The page adds the download pill, Next and Skip; the sheet adds OK.
/// Neither carries a copy of the scene's timing or drawing.
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

/// The scene of a Pro feature, by feature: what each onboarding scene page shows and what
/// the feature screen's "See how it works" sheet plays (#686). Each scene's own card
/// (`SmartModesSceneCard` and the others) holds its timing, its data and its title, next
/// to its drawing.
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

extension ProFeatureSceneCard {
    /// The scene's title: its onboarding step's, so the sheet and the step say the same.
    static func title(for feature: ProFeature) -> Text {
        switch feature {
        case .smartMode: return SmartModesSceneCard.title
        case .voiceNotes: return VoiceNotesSceneCard.title
        case .vocabulary: return VocabularySceneCard.title
        case .history: return HistorySceneCard.title
        }
    }

    /// The line under the title, from the same step.
    static func line(for feature: ProFeature) -> Text {
        switch feature {
        case .smartMode: return SmartModesSceneCard.line
        case .voiceNotes: return VoiceNotesSceneCard.line
        case .vocabulary: return VocabularySceneCard.line
        case .history: return HistorySceneCard.line
        }
    }
}
