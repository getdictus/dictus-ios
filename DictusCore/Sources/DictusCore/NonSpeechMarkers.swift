// DictusCore/Sources/DictusCore/NonSpeechMarkers.swift
// Drops the non-speech markers a speech engine writes instead of an empty result (#766).
//
// On a clip with no words, Whisper can return "(musique)", "[Musique].", "[Music]",
// "[BLANK_AUDIO]" or "..." rather than nothing, and that marker was inserted as if it
// were a transcription. The rule is engine-agnostic so the one call site that receives
// every engine's text can apply it.
//
// THE RULE (#766):
// 1. A result made only of bracketed or parenthesized spans, whatever they hold, and/or
//    punctuation and whitespace is no speech: it comes back empty.
// 2. When real words remain, only the known markers below are removed. Any other
//    bracketed text stays, since "(salle 212)" may be what the user said.
// 3. An unclosed marker ("[Musique") is not one, and stays.

import Foundation

public enum NonSpeechMarkers {

    /// Any bracketed or parenthesized span.
    private static let anyMarker = #"(?:\[[^\[\]]*\]|\([^()]*\))"#

    /// The markers removed from text that also holds words. Matched case-insensitively,
    /// with whitespace and punctuation allowed around the word inside the brackets.
    private static let knownWords = [
        "musique", "rires", "applaudissements", "silence", "bruit", "inaudible",
        "music", "laughter", "applause", "noise", "blank_audio",
        "musik", "lachen", "applaus", "stille", "geräusch",
        "música", "risas", "aplausos", "silencio", "ruido"
    ].joined(separator: "|")

    private static let knownMarker: String = {
        let inner = #"[\s.,;:!?…-]*(?:"# + knownWords + #")[\s.,;:!?…-]*"#
        return #"(?:\["# + inner + #"\]|\("# + inner + #"\))"#
    }()

    private static let options: String.CompareOptions = [.regularExpression, .caseInsensitive]

    /// The spoken words in `text`, or an empty string when there are none.
    ///
    /// Text with no known marker is returned trimmed and otherwise untouched.
    public static func spokenText(in text: String) -> String {
        let withoutAnyMarker = text.replacingOccurrences(of: anyMarker, with: "", options: .regularExpression)
        guard withoutAnyMarker.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains) else {
            return ""
        }
        // A marker glued between two words ("Bonjour[Music]monde") becomes a space, so the
        // words stay apart. Every other marker goes with the whitespace before it, so one
        // in mid-sentence leaves one space and not two.
        let separated = text.replacingOccurrences(
            of: #"(?<=[\p{L}\p{N}])"# + knownMarker + #"(?=[\p{L}\p{N}])"#, with: " ", options: options)
        let stripped = separated.replacingOccurrences(of: #"\s*"# + knownMarker, with: "", options: options)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        // A marker that opened the text can leave the punctuation that followed it, as in
        // "[Musique]. Bonjour": the sentence must not start with ". ". Only then: the
        // leading "..." of "...et voilà [Music]" is the speaker's. An opening quote is
        // kept, since it belongs to the words after it.
        guard text.range(of: #"^\s*"# + knownMarker, options: options) != nil else { return trimmed }
        return String(trimmed.drop { ".,;:!?…".contains($0) || $0.isWhitespace })
    }
}
