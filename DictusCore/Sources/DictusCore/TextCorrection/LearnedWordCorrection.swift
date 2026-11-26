// DictusCore/Sources/DictusCore/TextCorrection/LearnedWordCorrection.swift
// Makes a learned word an autocorrect target, under a narrow rule (#498).
import Foundation

/// Picks the learned word an unknown typed word should be corrected to (ADR 0004,
/// amended by #498).
///
/// WHY a separate rule instead of a place in the trie's ranking: the trie's
/// frequencies are log-normalized (#326) and a learned word has only a usage
/// count, so no number puts the two on one scale. The rule decides instead:
/// a learned word one edit away from what was typed wins, because the user taught
/// it precisely where the dictionary has nothing better to say.
///
/// What keeps it from taking over, each a guard the caller or this function holds:
/// - **The typed word is unknown to the dictionary.** A correctly typed
///   dictionary word is never rewritten into a learned one, however close.
///   `spellCheck` returns before asking for such a word anyway; the check is
///   repeated here so the rule holds wherever it is called from.
/// - **One edit, at least three letters typed.** A shorter word has too many
///   neighbours one edit away, the reason the bigram path uses the same floor.
/// - **Used at least twice.** A word learned by refusing one correction starts at
///   one use, and that one refusal is often the typo itself (#872). It stays
///   immune (L2) but becomes a target only once it is typed again.
public enum LearnedWordCorrection {

    /// Uses a learned word needs before it can be a target. See the type comment.
    public static let minimumUses = 2

    /// Whether a learned word used `uses` times is adopted: typed again since it was
    /// learned, so no longer likely to be the typo one refusal can teach (#872). The one
    /// rule for every path that puts a learned word in without a tap: this correction,
    /// and swipe typing's readings (#1090, `SwipeOwnWords`).
    public static func isAdopted(uses: Int) -> Bool {
        uses >= minimumUses
    }

    /// Shortest typed word a learned word may correct.
    public static let minimumTypedLength = 3

    /// The learned word `typedWord` should become, lowercased, or nil.
    ///
    /// - Parameters:
    ///   - typedWord: the word as typed, without any apostrophe prefix.
    ///   - learnedWords: every learned word mapped to its usage count
    ///     (`UserDictionary.allLearnedWords`).
    ///   - dictionaryKnows: whether the active language's dictionary has a word.
    public static func target(
        for typedWord: String,
        learnedWords: [String: Int],
        dictionaryKnows: (String) -> Bool
    ) -> String? {
        let typed = typedWord.lowercased()
        guard typed.count >= minimumTypedLength, !dictionaryKnows(typed) else { return nil }

        var best: (word: String, uses: Int)?
        for (rawWord, uses) in learnedWords where isAdopted(uses: uses) {
            let word = rawWord.lowercased()
            guard abs(word.count - typed.count) <= 1,
                  SpellingSimilarity.editDistance(typed, word, atMost: 1) == 1
            else { continue }
            // More uses wins; the word itself only makes the order total, so the
            // answer never depends on `Dictionary` iteration order.
            if let current = best, current.uses > uses || (current.uses == uses && current.word < word) {
                continue
            }
            best = (word, uses)
        }
        return best?.word
    }
}
