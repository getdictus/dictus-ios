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
/// Rows 2 and 5 need the downloaded model WARM (`ModelWarmth`): its Core ML cache compiled
/// on this install. A cold one (a fresh install, an iOS update) costs minutes to compile on
/// an iPhone, and a keyboard dictation stopped meanwhile would wait behind the note at the
/// engine gate. So a cold model leaves the note on Apple's model (rows 3 and 6, the card
/// says so under automatic detection) and asks for the compile, which runs later with the
/// app in front and idle (`VoiceNoteModelCompileGate`). Notes after it use the model.
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
        /// The downloaded model would read it but is not compiled yet on this install.
        case coldCache
    }

    /// What `decide` answers.
    public struct Decision: Equatable, Sendable {
        public let choice: VoiceNoteEngineChoice
        public let reason: Reason
        /// Compile the downloaded model once the app is in front and idle, so later notes
        /// get it. True only with `reason == .coldCache`.
        public let compilesDownloadedModel: Bool
        /// The downloaded model whose readiness and warmth this decision read, when it loads
        /// or compiles it; nil otherwise. The note keeps THIS identity for every chunk, never
        /// a fresh read of `activeModel`: a model selected mid-note was never checked warm,
        /// and a cold one must not load under `EngineAccessGate` (PR #1095 review).
        public let downloadedModel: String?

        init(_ choice: VoiceNoteEngineChoice, _ reason: Reason, model: String?) {
            self.choice = choice
            self.reason = reason
            self.compilesDownloadedModel = reason == .coldCache
            self.downloadedModel = choice == .downloadedModel || reason == .coldCache ? model : nil
        }

        /// The model each chunk of the note loads, nil for the dictation's engine.
        public var modelToLoad: String? {
            choice == .downloadedModel ? downloadedModel : nil
        }
    }

    /// - Parameters:
    ///   - language: the voice-note language setting.
    ///   - dictationEngine: what a dictation would run now (`AppleEngineAssets.effectiveEngine`).
    ///   - downloadedModel: `SharedKeys.activeModel`, read once for the note, when a downloaded
    ///     model is on the device (`SharedKeys.modelReady`); nil when there is none.
    ///   - downloadedModelWarm: its Core ML cache is compiled on this install (`ModelWarmth`).
    ///   - appleCoversFixedLanguage: Apple's model lists the fixed language and is installed
    ///     for it. Only read for a fixed language.
    public static func decide(language: VoiceNoteLanguage, dictationEngine: EffectiveSpeechEngine,
                              downloadedModel: String?, downloadedModelWarm: Bool,
                              appleCoversFixedLanguage: Bool) -> Decision {
        func decision(_ choice: VoiceNoteEngineChoice, _ reason: Reason) -> Decision {
            Decision(choice, reason, model: downloadedModel)
        }
        guard case .apple = dictationEngine else { return decision(.dictationEngine, .dictationRunsDownloadedModel) }
        let wanted: Reason
        switch language {
        case .autoDetect:
            guard downloadedModel != nil else { return decision(.dictationEngine, .autoDetectWithoutDownloadedModel) }
            wanted = .autoDetectUsesDownloadedModel
        case .fixed:
            if appleCoversFixedLanguage { return decision(.dictationEngine, .fixedLanguageCoveredByApple) }
            guard downloadedModel != nil else {
                return decision(.dictationEngine, .fixedLanguageNotCoveredWithoutDownloadedModel)
            }
            wanted = .fixedLanguageNotCoveredUsesDownloadedModel
        }
        return downloadedModelWarm ? decision(.downloadedModel, wanted) : decision(.dictationEngine, .coldCache)
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
    ///
    /// `detected` says the code came from that measure: the History shows it, but the
    /// note's Smart Mode stays on the automatic policy (`smartModeLanguageMode`).
    public static func recordedLanguage(policy: TranscriptionLanguagePolicy,
                                        transcript: String) -> (code: String, detected: Bool) {
        let fromPolicy = TranscriptionRecord.languageCode(for: policy)
        guard policy.mode == .autoDetect, !policy.languageIsAssumed,
              let detected = detectedLanguageCode(in: transcript) else { return (fromPolicy, false) }
        return (detected, true)
    }

    /// The language mode a voice note's Smart Mode runs under, from its record.
    ///
    /// A detected language is shown, never a target (PR #1095 review): the note was in
    /// automatic detection, so the mode keeps the language-agnostic automatic prompt and
    /// does not rewrite foreign passages into the dominant language. A language the user
    /// fixed, or one Apple's model was given (`languageWasAssumed`), stays explicit, as
    /// before; `auto` and an unknown code stay automatic.
    public static func smartModeLanguageMode(recordedLanguage: String,
                                             languageWasDetected: Bool) -> TranscriptionLanguageMode {
        guard !languageWasDetected, let language = SupportedLanguage(rawValue: recordedLanguage) else {
            return .autoDetect
        }
        return .explicit(language)
    }
}
