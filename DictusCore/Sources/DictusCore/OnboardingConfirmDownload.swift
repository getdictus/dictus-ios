// DictusCore/OnboardingConfirmDownload.swift
// What confirming the onboarding's language downloads, once the route is decided (#1057).
import Foundation

/// The download the language step starts, for the route `OnboardingEngineRoute` decided.
///
/// - Today's route: the recommended model, and the user waits for it (unchanged).
/// - Apple's route with Parakeet recommended: Apple dictates at once and Parakeet
///   downloads in the background, to take over later (Pierre, 2026-11-26). The onboarding
///   marks the handoff (`ParakeetHandoff`) and its popup says the user can already dictate.
/// - Apple's route with another recommendation (a 4 GB iPhone 12 gets Whisper Small):
///   nothing downloads, the user stays on Apple (Pierre, 2026-11-26). The handoff is to
///   Parakeet only; no Whisper model takes over from Apple.
public enum OnboardingConfirmDownload: Equatable, Sendable {
    /// Nothing downloads: Apple's route and a recommendation that is not Parakeet.
    case none
    /// Today's route: the recommended model downloads and is what the user dictates with.
    case recommended(String)
    /// Apple's route: Parakeet downloads behind Apple's model, which stays active.
    case parakeetBehindApple(String)

    public static func decide(route: OnboardingEngineRoute, recommendedModel: String) -> OnboardingConfirmDownload {
        guard route.isApple else { return .recommended(recommendedModel) }
        return downloadsBehindApple(recommendedModel: recommendedModel) ? .parakeetBehindApple(recommendedModel) : .none
    }

    /// Whether Apple's route downloads `recommendedModel` behind Apple: only Parakeet.
    /// Also what the language step reads to say so before Confirm.
    public static func downloadsBehindApple(recommendedModel: String) -> Bool {
        ModelInfo.forIdentifier(recommendedModel)?.engine == .parakeet
    }

    /// The model whose download starts, nil when nothing downloads.
    public var model: String? {
        switch self {
        case .none: return nil
        case .recommended(let model), .parakeetBehindApple(let model): return model
        }
    }

    /// Whether the onboarding leaves the Parakeet handoff marker.
    public var marksParakeetHandoff: Bool {
        if case .parakeetBehindApple = self { return true }
        return false
    }
}
