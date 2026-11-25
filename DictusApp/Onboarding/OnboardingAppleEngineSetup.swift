// DictusApp/Onboarding/OnboardingAppleEngineSetup.swift
// The onboarding's Apple route: decide it, install Apple's model, fall back (#1057).
import DictusCore
import Foundation

/// The engine the onboarding sets up, and Apple's install when it is Apple's model.
///
/// WHY AN OBJECT OWNED BY `OnboardingView`: the install starts when the language step is
/// confirmed and is watched four to ten steps later by the preparation step, like the
/// Dictus download it replaces (`OnboardingView.modelManager`). A page would be released
/// with its state long before.
///
/// WHAT SURVIVES A KILL: the route is stored as the engine choice
/// (`SharedKeys.speechEngineChoice`), written when the language is confirmed. iOS kills the
/// app when Full Access is turned on; on the next launch `resume` reads Apple again and
/// starts the install over if it had not finished (iOS's request is idempotent: an
/// installed model answers "nothing to install").
@MainActor
final class OnboardingAppleEngineSetup: ObservableObject {
    enum Phase: Equatable {
        /// Nothing running: today's route, or the Apple route before its first reading.
        case idle
        /// iOS is installing Apple's model; nil while the size is not known yet.
        case installing(fraction: Double?)
        /// Apple's model is installed and picked: nothing to wait for.
        case ready
    }

    /// The route the language step decided, nil before it or on today's route.
    @Published private(set) var route: OnboardingEngineRoute?
    @Published private(set) var phase: Phase = .idle

    /// The running install, so a second start joins it instead of racing it.
    private var installTask: Task<Void, Never>?

    var isAppleRoute: Bool { route?.isApple ?? false }

    /// Decides the route for the setup the language step just applied, and stores it.
    ///
    /// The availability is read fresh (`AppleEngineAssets.availability()`) after
    /// `LanguageSetup.apply()`, so it is about the language just confirmed. Apple's route
    /// writes the Apple choice at once; today's route writes the downloaded model's choice,
    /// so confirming again after a relaunch with another language cannot keep a stale
    /// Apple choice.
    func decide(for setup: LanguageSetup, recommendedModelReady: Bool,
                modelManager: ModelManager) async -> OnboardingEngineRoute {
        let device = DeviceCapabilities.current()
        let availability = await AppleEngineAssets.availability()
        let decided = OnboardingEngineRoute.decide(
            spokenLanguageHasDictusKeyboard: setup.spokenLanguageHasDictusKeyboard,
            keyboardDictatesWithApple: !device.isPreA14,
            recommendedModelReady: recommendedModelReady,
            appleAvailability: availability
        )
        AppleEngineAssets.log("onboardingRoute", "route=\(decided) spoken=\(setup.spokenLanguage) "
            + "hasKeyboard=\(setup.spokenLanguageHasDictusKeyboard) preA14=\(device.isPreA14) "
            + "modelReady=\(recommendedModelReady) availability=\(availability)")
        route = decided
        if decided.isApple {
            modelManager.chooseEngineDuringOnboarding(.apple)
        } else if modelManager.speechEngineChoice == .apple {
            modelManager.chooseEngineDuringOnboarding(.downloadedModel)
        }
        return decided
    }

    /// Picks the stored route back up after a relaunch mid-onboarding.
    ///
    /// Only for a run past the language step whose stored choice is Apple and that has no
    /// ready downloaded model. Apple read ready: picked, nothing to wait for. Otherwise the
    /// install starts again, with the same fallback.
    func resume(modelManager: ModelManager, onFallback: @escaping @MainActor () -> Void) {
        guard route == nil, modelManager.speechEngineChoice == .apple, !modelManager.isModelReady,
              let code = AppleSpeechLanguage.activeDictationLanguageCode() else { return }
        route = .apple(languageCode: code, needsInstall: true)
        AppleEngineAssets.log("onboardingRoute", "resumed lang=\(code)")
        start(languageCode: code, modelManager: modelManager, onFallback: onFallback)
    }

    /// Installs Apple's model for `languageCode`, then picks it, or falls back.
    ///
    /// Runs in the background of the next steps: nothing on screen waits for it until the
    /// preparation step. On a failure, or a model iOS reports installed but Apple still
    /// does not read as ready, the route becomes today's (`afterAppleInstall`):
    /// `onFallback` starts the recommended model's download, and the preparation step
    /// shows that download with its own retry. Nothing blocks the user.
    func start(languageCode: String, modelManager: ModelManager, onFallback: @escaping @MainActor () -> Void) {
        guard installTask == nil else { return }
        phase = .installing(fraction: nil)
        let startedAt = Date()
        installTask = Task {
            var succeeded = true
            if route != .apple(languageCode: languageCode, needsInstall: false) {
                do {
                    try await AppleEngineAssets.install(languageCode: languageCode) { [weak self] fraction in
                        self?.phase = .installing(fraction: fraction)
                    }
                } catch {
                    succeeded = false
                    AppleEngineAssets.log("installFailed", "lang=\(languageCode) context=onboarding "
                        + "error=\(LoggedError.domainAndCode(error))")
                }
            }
            let after = OnboardingEngineRoute.afterAppleInstall(
                succeeded: succeeded, appleAvailability: await AppleEngineAssets.availability()
            )
            let seconds = String(format: "%.1f", Date().timeIntervalSince(startedAt))
            AppleEngineAssets.log("onboardingInstall", "lang=\(languageCode) result=\(after) seconds=\(seconds)")
            route = after
            installTask = nil
            if after.isApple {
                modelManager.selectAppleEngine()
                phase = .ready
            } else {
                modelManager.chooseEngineDuringOnboarding(.downloadedModel)
                phase = .idle
                onFallback()
            }
        }
    }
}
