// DictusCore/Sources/DictusCore/SpeechEngine.swift
import Foundation

/// Identifies which speech-to-text engine a model uses.
///
/// WHY an enum with raw values:
/// Each model belongs to a specific engine (WhisperKit, Parakeet or Nemotron). Storing
/// as a Codable rawValue ("WK"/"PK"/"NM") allows persistence in UserDefaults and
/// easy serialization. Parakeet and Nemotron both run through FluidAudio.
///
/// WHY NEMOTRON IS ITS OWN CASE and not a second Parakeet model (#558): the two
/// answer the language question in opposite ways. Parakeet TDT v3 has no decoder
/// prompt and infers the language from the audio, so the "Transcription language"
/// setting cannot reach it. Nemotron 3.5 takes the language as a prompt and is forced
/// to it, like Whisper. Every rule keyed on the engine — whether the setting is
/// effective, which polish mode runs, whether the output is inserted as-is — has a
/// different answer for it, and a shared case would have given it Parakeet's.
///
/// `Sendable` is stated rather than inferred: a public frozen-by-default enum in a
/// library gets no implicit conformance across module boundaries, so every
/// `Sendable` type holding one — `TranscriptionLanguagePolicy` is the first, and it
/// crosses the App Group into the keyboard — warns without it. A `String`-backed
/// enum with no associated values carries no mutable state, so the conformance is
/// a statement of fact and needs no `@unchecked`.
public enum SpeechEngine: String, Codable, Sendable {
    case whisperKit = "WK"
    case parakeet = "PK"
    case nemotron = "NM"

    /// Human-readable name for UI display.
    public var displayName: String {
        switch self {
        case .whisperKit: return "WhisperKit"
        case .parakeet: return "Parakeet"
        case .nemotron: return "Nemotron"
        }
    }
}
