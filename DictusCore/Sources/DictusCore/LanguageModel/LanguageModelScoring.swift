// DictusCore/Sources/DictusCore/LanguageModel/LanguageModelScoring.swift
// What the keyboard asks a local language model, and the text it lets the model read (#996).
import Foundation

/// A causal language model the keyboard asks two questions (#996): how likely each
/// reading of the typed word is after the sentence so far, and which words come next.
///
/// Not thread-safe: `KeyboardLanguageModel` calls it from its own serial queue only.
public protocol LanguageModelScoring: AnyObject {
    /// For each reading, the natural log of the probability that the text after
    /// `context` starts with that reading. nil when the model failed.
    /// - Parameter context: the text before the word, as the document holds it.
    func logProbabilities(of readings: [String], after context: String) -> [Double]?

    /// Up to `limit` words the model expects after `context`, best first, each one
    /// `isWord` accepts.
    func nextWords(after context: String, limit: Int, isWord: (String) -> Bool) -> [String]
}

/// The text a language model may read: the current paragraph before the cursor, at most
/// `maxCharacters` of it, cut at a word, and nothing at all where the host field forbids
/// suggestions (#996).
public enum LanguageModelContext {

    /// About forty words: enough for the sentence, short enough to stay a few ms.
    public static let maxCharacters = 200

    /// The text before the word being typed. `context` ends with `word`.
    public static func text(before word: String, in context: String, policy: HostFieldPolicy) -> String? {
        guard policy.languageModelAllowed, context.hasSuffix(word) else { return nil }
        return paragraphTail(String(context.dropLast(word.count)))
    }

    /// The text before the cursor once a word is committed, for the next-word prediction.
    public static func text(beforeCursor context: String, policy: HostFieldPolicy) -> String? {
        guard policy.languageModelAllowed else { return nil }
        return paragraphTail(context)
    }

    static func paragraphTail(_ text: String) -> String {
        var tail = text.split(separator: "\n", omittingEmptySubsequences: false).last.map(String.init) ?? text
        if tail.count > maxCharacters {
            tail = String(tail.suffix(maxCharacters))
            if let space = tail.firstIndex(of: " ") { tail = String(tail[tail.index(after: space)...]) }
        }
        return tail
    }
}

extension HostFieldPolicy {
    /// Whether the keyboard's language model may read this field (#996): where the
    /// keyboard corrects and suggests, never in a secure, URL, email or one-time-code
    /// field, which turn both off (#200, #1002).
    public var languageModelAllowed: Bool { autocorrectAllowed && suggestionsAllowed }
}
