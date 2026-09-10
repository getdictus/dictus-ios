// DictusCore/Sources/DictusCore/Vocabulary/DictationTranscript.swift
// The two texts one dictation produces, since #80 made them two.
import Foundation

/// What a dictation produced: the text everything downstream uses, and — only when
/// they differ — the engine's own words.
///
/// ### Why this is a type and not two parameters
///
/// The same reason `PolishService.Request` is one: threading a second text through
/// `finishInApp` and `handOffToKeyboard` put both over the parameter-count limit,
/// and a pair that must always travel together is a pair that should be one value.
/// It also makes the invariant unforgeable — `engineRaw` is *computed*, so no call
/// site can set it to something that is not the text the engine returned, and none
/// can forget to set it to nil when nothing changed.
///
/// ### Which one is which
///
/// `text` is what the keyboard types, what the polish runs on, and what the
/// deterministic floor falls back to. It is the **corrected** text: the user asked
/// for their spelling and must get it even when the model refuses.
///
/// `engineRaw` is carried to be **recorded and nothing else**. The polish debug
/// export's `raw` field has to keep meaning "what the engine produced" — #80's own
/// corpus is mined from those exports, and a feature that rewrote them would erase
/// the evidence its validation depends on. Nil is the ordinary case and reads as
/// "the two are the same", so nothing extra is carried, written to the App Group, or
/// recorded for a user who has stored no terms.
public struct DictationTranscript: Equatable, Sendable {

    /// The text every stage after transcription works on.
    public let text: String

    /// The engine's own output when the vocabulary pass rewrote it, else nil.
    public let engineRaw: String?

    /// Build the pair from the engine's output, running the custom-vocabulary pass
    /// on it (#80 decision 5).
    ///
    /// This is the seam the issue names: the consumer of
    /// `TranscriptionService.transcribe()`, never inside it — that function returns
    /// from more than one branch depending on the active engine, so a pass added to
    /// one would be silently skipped by the other.
    public static func corrected(_ engineText: String) -> DictationTranscript {
        DictationTranscript(engine: engineText, corrected: CustomVocabulary.corrected(engineText))
    }

    /// - Parameters:
    ///   - engine: what the speech engine returned.
    ///   - corrected: what the vocabulary pass made of it.
    public init(engine: String, corrected: String) {
        self.text = corrected
        self.engineRaw = corrected == engine ? nil : engine
    }
}
