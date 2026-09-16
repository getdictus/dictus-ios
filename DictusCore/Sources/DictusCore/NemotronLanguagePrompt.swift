// DictusCore/Sources/DictusCore/NemotronLanguagePrompt.swift
// The language code a Nemotron dictation is forced to (#558).
import Foundation

/// The language prompt a Nemotron dictation is forced to (#558).
///
/// WHY A TYPE FOR ONE LINE: the line is the difference between forcing French and silently
/// running auto-detect. `TranscriptionLanguagePolicy.sttLanguageCode` spells auto-detection
/// `nil`, which is what WhisperKit wants. Nemotron wants a string, and FluidAudio resolves an
/// unknown or missing one to the model's default prompt without saying so. Naming the mapping
/// here keeps it testable, and keeps `"auto"` a deliberate value rather than a fallback.
public enum NemotronLanguagePrompt {

    /// The model's own auto-detection prompt, `prompt_dictionary["auto"]` in `metadata.json`.
    public static let autoDetect = "auto"

    /// The code handed to `StreamingNemotronMultilingualAsrManager.setLanguage(_:)`.
    ///
    /// - Parameter sttLanguageCode: `TranscriptionLanguagePolicy.sttLanguageCode`, `nil` for
    ///   auto-detection. Short codes pass through unchanged: `fr`, `en`, `es` and `de` are
    ///   all keys of the multilingual ship's prompt dictionary (`fr` is `fr-FR`'s prompt; `es`
    ///   is `es-US`'s, not `es-ES`'s). The engine logs the prompt id FluidAudio resolved, which
    ///   is how a code that is not a key would show up.
    public static func code(forSTTLanguageCode sttLanguageCode: String?) -> String {
        guard let sttLanguageCode, !sttLanguageCode.isEmpty else { return autoDetect }
        return sttLanguageCode
    }
}
