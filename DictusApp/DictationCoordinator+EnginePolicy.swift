// DictusApp/DictationCoordinator+EnginePolicy.swift
// Apple's engine as picked on the Models screen, and the language policy named after the
// engine that is actually loaded (#1036, #1083).
//
// WHY a file of its own: DictationCoordinator.swift sits at the `file_length` budget, and
// this extension reaches the coordinator only through `ensureEngineReady`, `defaults` and
// the read side of `currentModelName`. Moved as is, no behaviour change.
import Foundation
import DictusCore

extension DictationCoordinator {
    /// Load Apple's engine right after the user picks it, so the next dictation does not
    /// have to. Unlike `preloadActiveModel` it leaves `modelLoadState` alone: there is no
    /// model preparation to show, and a `.loading` state would put the downloaded model's
    /// preparation screen over the Models screen for a load that is not happening.
    func adoptAppleEngine() {
        Task {
            do {
                try await ensureEngineReady()
                AppleEngineAssets.log("adopted", "engine=\(self.currentModelName ?? "none")")
            } catch {
                AppleEngineAssets.log("adoptFailed", "error=\(DictationFailureMessage.diagnostic(for: error))")
            }
        }
    }

    /// The dictation's language policy with the engine that will actually transcribe it.
    ///
    /// The policy names `ActiveSpeechEngine`, read from Apple's last recorded readiness
    /// (#1083), and `ensureEngineReady` reads it fresh: the two disagree when Apple stopped
    /// being ready in between, and the loaded engine is the one that transcribes. Apple is
    /// told the chosen language and is polished as a forced-language engine, so its
    /// dictations carry `.apple`.
    func languagePolicyForLoadedEngine(_ policy: TranscriptionLanguagePolicy) -> TranscriptionLanguagePolicy {
        let appleLoaded = currentModelName == AppleSpeechEngineIdentity.identifier
        guard appleLoaded != (policy.engine == .apple) else { return policy }
        let loaded = appleLoaded
            ? ActiveSpeechEngine.apple
            : ActiveSpeechEngine.resolve(choice: .downloadedModel, appleAvailability: .needsAsset(.unknown),
                                         downloadedModel: currentModelName ?? defaults.string(forKey: SharedKeys.activeModel))
        guard let loaded else { return policy }
        return TranscriptionLanguagePolicy(mode: policy.mode, keyboardLanguage: policy.keyboardLanguage,
                                           engine: loaded.engine, modelIdentifier: loaded.identifier)
    }
}
