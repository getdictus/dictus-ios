// DictusCore/Sources/DictusCore/NonSpeechMarkers.swift
// Drops the non-speech markers a speech engine writes instead of an empty result (#766).
//
// On a clip with no words, Whisper can return "(musique)", "[Musique].", "[Music]",
// "[BLANK_AUDIO]" or "..." rather than nothing, and that marker was inserted as if it
// were a transcription. The rule is engine-agnostic so the one call site that receives
// every engine's text can apply it.

import Foundation

public enum NonSpeechMarkers {

    /// A bracketed or parenthesized span, with the whitespace before it, so removing it
    /// from the middle of a sentence leaves one space and not two.
    private static let marker = #"\s*(?:\[[^\[\]]*\]|\([^()]*\))"#

    /// The spoken words in `text`, or an empty string when there are none.
    ///
    /// Every `[...]` and `(...)` span is dropped. What remains counts as speech only if it
    /// holds a letter or a digit, so a result of punctuation, ellipsis or whitespace alone
    /// comes back empty. Text with no marker is returned trimmed and otherwise untouched.
    public static func spokenText(in text: String) -> String {
        let stripped = text.replacingOccurrences(of: marker, with: "", options: .regularExpression)
        guard stripped.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains) else {
            return ""
        }
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped != text else { return trimmed }
        // A marker that opened the text can leave the punctuation that followed it, as in
        // "[Musique]. Bonjour": the sentence must not start with ". ". An opening quote
        // is kept, since it belongs to the words after it.
        return String(trimmed.drop { ".,;:!?…".contains($0) || $0.isWhitespace })
    }
}
