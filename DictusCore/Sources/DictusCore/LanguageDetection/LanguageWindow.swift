// DictusCore/Sources/DictusCore/LanguageDetection/LanguageWindow.swift
// Folds word votes into the language that autocorrects the next word (#1009).
import Foundation

/// The language a bilingual keyboard is typing in, decided over the last few words.
///
/// Each word's `WordLanguageVote` is folded into a decaying score, and the language
/// changes only when the score crosses a threshold toward the other one. A word both
/// languages have votes near zero and moves nothing. One clearly English word votes
/// about −4, which does not flip a French window: an English insert in a French
/// sentence (`on se fait un call demain`) is still corrected by the French dictionary,
/// and the keep rule (`BilingualKeepRule`) is what leaves it as typed. Two English
/// words in a row from a fresh window do flip it.
///
/// The window carries over from one message to the next, as in a conversation, and a
/// new keyboard process starts it in the primary language.
public struct LanguageWindow: Sendable {

    /// Share of the score kept from one word to the next.
    static let decay = 0.6
    /// How far past zero the score must go, toward the other language, to flip.
    static let threshold = 3.0

    public let pair: KeyboardLanguagePair
    public private(set) var language: SupportedLanguage
    /// Positive leans primary.
    private var score: Double

    public init(pair: KeyboardLanguagePair) {
        self.pair = pair
        language = pair.primary
        score = Self.threshold
    }

    /// Folds in the vote of the word just typed. `language` is then the language that
    /// corrects that word and serves the suggestions for the next one.
    public mutating func push(_ vote: Double) {
        score = Self.decay * score + vote
        if language == pair.primary, score < -Self.threshold {
            language = pair.secondary
        } else if language == pair.secondary, score > Self.threshold {
            language = pair.primary
        }
    }
}
