// DictusCore/Sources/DictusCore/TextCorrection/ContextualContraction.swift
// Restores a contraction typed without its apostrophe when the typed form is
// also a word (`ill` for `I'll`), from the words before it (#995).
import Foundation

/// A contraction whose apostrophe-less spelling is a word of its own: `ill` and
/// `I'll`, `its` and `it's`, `were` and `we're`. A language's override map cannot
/// hold these (`I'll be ill` needs both), so each one says where the contraction
/// is meant.
///
/// The space bar decides before the next word exists, so the context is the
/// sentence position and the previous word. A rule may also name the words that,
/// typed next, call for the contraction (`before`): the space after that word then
/// writes both (`contextualContraction(profile:word:before:)`).
public struct ContextualContraction: Sendable, Equatable {
    /// Which previous words call for the contraction.
    public enum PreviousWords: Sendable, Equatable {
        /// Any previous word except these, after which the typed word is meant.
        case anyExcept(Set<String>)
        /// Only these previous words.
        case only(Set<String>)
    }

    /// The typed form, lowercase, without apostrophe.
    public let word: String
    /// The contraction, with the casing it takes mid-sentence (`I'll`, `it's`).
    public let contraction: String
    /// Whether the contraction is meant when the word starts a sentence.
    public let atSentenceStart: Bool
    /// Where the contraction is meant mid-sentence.
    public let after: PreviousWords
    /// The next words, lowercase, after which the typed word was the contraction: words
    /// the typed word is never followed by when it is meant (`its` is never followed by
    /// `a`: "its a good idea" is "it's a good idea").
    public let before: Set<String>

    public init(
        word: String, contraction: String, atSentenceStart: Bool, after: PreviousWords, before: Set<String> = []
    ) {
        self.word = word
        self.contraction = contraction
        self.atSentenceStart = atSentenceStart
        self.after = after
        self.before = before
    }
}

/// The contraction `word` stands for in this context, or `nil` when the typed
/// word is meant or the language has no such contraction.
///
/// - Parameters:
///   - profile: The active language's profile.
///   - word: The word as typed (any case).
///   - previousWord: The word before it, across punctuation, as the space bar reads it.
///   - isAtSentenceStart: Whether `word` starts a sentence. Takes precedence over
///     `previousWord`, which is then the last word of the previous sentence.
public func contextualContraction(
    profile: LanguageProfile,
    word: String,
    previousWord: String?,
    isAtSentenceStart: Bool
) -> String? {
    let lowered = word.lowercased()
    guard let rule = profile.contextualContractions.first(where: { $0.word == lowered }) else { return nil }

    let isMeant: Bool
    if isAtSentenceStart {
        isMeant = rule.atSentenceStart
    } else if let previous = previousWord?.lowercased().replacingOccurrences(of: "\u{2019}", with: "'") {
        switch rule.after {
        case .anyExcept(let kept): isMeant = !kept.contains(previous)
        case .only(let callers): isMeant = callers.contains(previous)
        }
    } else {
        isMeant = false
    }
    guard isMeant else { return nil }

    guard word.first?.isUppercase == true, let first = rule.contraction.first else { return rule.contraction }
    return first.uppercased() + rule.contraction.dropFirst()
}

/// The contraction `word` stood for, now that `nextWord` follows it, or `nil` when
/// the next word leaves the typed word meant. Both as typed, any case; the contraction
/// takes the case of `word`'s first letter ("Its raining" -> "It's").
///
/// WHY from the next word: `its` is possessive mid-sentence far more often than not
/// ("the dog wagged its tail"), so the space bar keeps it (#995), but the word after it
/// tells: no possessive is followed by an article, a pronoun, a preposition, a negation
/// or a verb in -ing. Apple's keyboard makes the same revision once that word is typed.
public func contextualContraction(profile: LanguageProfile, word: String, before nextWord: String) -> String? {
    let lowered = word.lowercased()
    guard let rule = profile.contextualContractions.first(where: { $0.word == lowered }),
          rule.before.contains(nextWord.lowercased()) else { return nil }
    guard word.first?.isUppercase == true, let first = rule.contraction.first else { return rule.contraction }
    return first.uppercased() + rule.contraction.dropFirst()
}
