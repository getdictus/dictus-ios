// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteEngineChoice.swift
// Which engine transcribes a voice note in the app, when Apple's model dictates (#1084).
import Foundation

/// The engine DictusApp transcribes one shared voice note with.
///
/// WHY a choice of its own and not the dictation's engine: Apple's model takes one
/// language and cannot detect one, so a note in automatic detection read by it comes out
/// in the dictation language, whatever was spoken (#1084). A downloaded model (Parakeet,
/// Whisper) detects. The rule, Pierre's (2026-11-26):
///
/// 1. the dictation does not run Apple's model → the downloaded model, as before;
/// 2. automatic detection and a downloaded model ready → the downloaded model;
/// 3. automatic detection and no downloaded model → Apple's model, in the dictation
///    language, said on the card (`TranscriptionLanguagePolicy.languageIsAssumed`);
/// 4. a fixed language Apple's model can read on this device → Apple's model (faster);
/// 5. a fixed language it cannot read and a downloaded model ready → the downloaded model;
/// 6. a fixed language it cannot read and no downloaded model → Apple's model, as before.
///
/// Voice notes only: the keyboard and the app's own dictation keep their engine. The
/// share extension, which cannot load a downloaded model, does not read this either.
public enum VoiceNoteEngineChoice: Equatable, Sendable {
    /// The engine the dictation runs now (`EffectiveSpeechEngine`): Apple's or the downloaded model.
    case dictationEngine
    /// The downloaded model in `SharedKeys.activeModel`, even though Apple's model dictates.
    case downloadedModel

    /// Why, for the log.
    public enum Reason: String, Equatable, Sendable {
        case dictationRunsDownloadedModel
        case autoDetectUsesDownloadedModel
        case autoDetectWithoutDownloadedModel
        case fixedLanguageCoveredByApple
        case fixedLanguageNotCoveredUsesDownloadedModel
        case fixedLanguageNotCoveredWithoutDownloadedModel
    }

    /// - Parameters:
    ///   - language: the voice-note language setting.
    ///   - dictationEngine: what a dictation would run now (`AppleEngineAssets.effectiveEngine`).
    ///   - downloadedModelReady: a downloaded model is on the device (`SharedKeys.modelReady`).
    ///   - appleCoversFixedLanguage: Apple's model lists the fixed language and is installed
    ///     for it. Only read for a fixed language.
    public static func decide(language: VoiceNoteLanguage, dictationEngine: EffectiveSpeechEngine,
                              downloadedModelReady: Bool,
                              appleCoversFixedLanguage: Bool) -> (choice: VoiceNoteEngineChoice, reason: Reason) {
        guard case .apple = dictationEngine else { return (.dictationEngine, .dictationRunsDownloadedModel) }
        switch language {
        case .autoDetect:
            return downloadedModelReady
                ? (.downloadedModel, .autoDetectUsesDownloadedModel)
                : (.dictationEngine, .autoDetectWithoutDownloadedModel)
        case .fixed:
            if appleCoversFixedLanguage { return (.dictationEngine, .fixedLanguageCoveredByApple) }
            return downloadedModelReady
                ? (.downloadedModel, .fixedLanguageNotCoveredUsesDownloadedModel)
                : (.dictationEngine, .fixedLanguageNotCoveredWithoutDownloadedModel)
        }
    }

    /// The language a voice note in automatic detection is recorded under, once a model
    /// that detects has read it (#1084): the language holding most of the transcript
    /// (`PolishLanguageMix`, the measure polish already trusts, #456), when Dictus knows it.
    /// Nil keeps today's `auto`: nothing was measured, or the language is not one Dictus ships.
    public static func detectedLanguageCode(in transcript: String) -> String? {
        guard let code = PolishLanguageMix.measure(transcript).dominantCode,
              let language = SupportedLanguage(rawValue: code) else { return nil }
        return language.rawValue
    }

    /// What a voice note's record says its language is, once read under `policy`:
    /// `TranscriptionRecord.languageCode(for:)`, except that a note in automatic detection
    /// read by a model that detects gets the language measured in its transcript.
    public static func recordedLanguageCode(policy: TranscriptionLanguagePolicy, transcript: String) -> String {
        let fromPolicy = TranscriptionRecord.languageCode(for: policy)
        guard policy.mode == .autoDetect, !policy.languageIsAssumed else { return fromPolicy }
        return detectedLanguageCode(in: transcript) ?? fromPolicy
    }
}
