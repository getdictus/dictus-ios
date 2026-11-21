// DictusCore/Sources/DictusCore/TextCorrection/ContextualHomograph.swift
// A typed word with two correct spellings, where the words before it decide (#501).
import Foundation

/// A word typed without its accent where both spellings are correct words, so only
/// the sentence can choose: French `a` (the verb *avoir*) and `à` (the preposition).
///
/// WHY not the spell checker: neither spelling is a typo, so there is no edit
/// distance for the accent-cost table to weigh (#222, #321, #327).
///
/// WHY a table of words and not the n-grams: the bundled French bigrams prefer `à`
/// after most nouns (`le chien a`), because in books a noun is followed by `à`
/// more often than by `a`. Choosing by bigram score accented 11% of the verb `a`
/// in Tatoeba's French sentences; this table accents 0.07%, and 33 of those 45
/// are sentences Tatoeba itself spells wrong (#501, `tools/a-grave-eval`).
///
/// One instance is one pair. Each set matches a word whole, by the elision it
/// starts with (`m'aider` matches `m'`) or by what follows the elision (`n'y`
/// matches `y`). The rules run in a fixed order and leave the typed word as it is
/// when none fires, so a context the table does not know costs a missed accent,
/// not a broken verb.
public struct ContextualHomograph: Sendable {
    /// The spelling the user types, e.g. `a`.
    public let typed: String
    /// The spelling the context can call for, e.g. `à`.
    public let accented: String
    /// The word right before proves the typed spelling (`il a`, `y a`).
    public let typedAfter: Set<String>
    /// The word right before, or the two words before joined by a space, proves the
    /// accented spelling (`vais à`, `du mal à`).
    public let accentedAfter: Set<String>
    /// The word two back proves that the word right before is a verb, so the typed
    /// word cannot be one (`je pense à`, `est arrivé à`).
    public let accentedTwoAfter: Set<String>
    /// Opens a relative clause. Within the three words before the word right
    /// before, nothing is accented: in `ce que tu as fait a été`, `fait a` is a verb.
    public let clauseOpeners: Set<String>
    /// The first word of a sentence takes the accented spelling (#979): `à demain`,
    /// `À deux on ira plus vite`. In Tatoeba's French sentences a sentence starts
    /// with `À` 4300 times and with a plain `A` 106 times, and all but about ten of
    /// those 106 are `À` written without its accent; the rest are `A voté`,
    /// `A demandé`, the letter (`A et B`) and initials (`E. T. A. Hoffmann`).
    public let accentedAtSentenceStart: Bool

    public init(
        typed: String,
        accented: String,
        typedAfter: Set<String>,
        accentedAfter: Set<String>,
        accentedTwoAfter: Set<String>,
        clauseOpeners: Set<String>,
        accentedAtSentenceStart: Bool = false
    ) {
        self.typed = typed
        self.accented = accented
        self.typedAfter = typedAfter
        self.accentedAfter = accentedAfter
        self.accentedTwoAfter = accentedTwoAfter
        self.clauseOpeners = clauseOpeners
        self.accentedAtSentenceStart = accentedAtSentenceStart
    }

    /// The accented spelling when the text before the cursor calls for it, else nil.
    ///
    /// `context` is the text before the cursor and ends with `word`, as the keyboard
    /// reads it when the word is committed or previewed.
    public func accentedForm(of word: String, context: String) -> String? {
        guard word.lowercased() == typed, context.hasSuffix(word) else { return nil }
        let words = Self.clauseWords(before: context.dropLast(word.count))
        guard let previous = words.last else {
            // Nothing before it in the clause: only the start of a sentence decides,
            // not a comma (`ce qu'il dit, a choqué`). The keyboard capitalises the
            // first word, so `A` is read as `a` here and keeps its capital.
            guard accentedAtSentenceStart,
                  ProperNounGuard.isAtSentenceStart(context: context, word: word) else { return nil }
            return word == typed ? accented : accented.uppercased()
        }
        // Inside a sentence, a capital `A` is left as typed, as before.
        guard word == typed else { return nil }

        // A capital inside a clause is a name, and a name can be the subject (`Marie a`).
        if words.count > 1, previous.first?.isUppercase == true { return nil }

        let lowered = words.map { $0.lowercased() }
        let previousLowered = lowered[lowered.count - 1]
        if Self.matches(previousLowered, typedAfter) { return nil }
        if lowered.dropLast().suffix(3).contains(where: { Self.matches($0, clauseOpeners) }) { return nil }

        let twoBack = lowered.count > 1 ? lowered[lowered.count - 2] : nil
        if Self.matches(previousLowered, accentedAfter) { return accented }
        if let twoBack {
            if accentedAfter.contains(twoBack + " " + previousLowered) { return accented }
            if Self.matches(twoBack, accentedTwoAfter) { return accented }
        }
        return nil
    }

    /// The words of the clause `text` ends in: everything after its last
    /// punctuation mark, split on spaces so that `elle-même` stays one word.
    private static func clauseWords(before text: Substring) -> [String] {
        let clauseStart = text.lastIndex(where: { clauseBreaks.contains($0) })
            .map { text.index(after: $0) } ?? text.startIndex
        return text[clauseStart...]
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private static let clauseBreaks: Set<Character> = [
        ".", ",", ";", ":", "!", "?", "\u{2026}", "(", ")", "\"", "\u{00AB}", "\u{00BB}", "\n"
    ]

    private static func matches(_ word: String, _ set: Set<String>) -> Bool {
        if set.contains(word) { return true }
        guard let apostrophe = word.firstIndex(of: "'") else { return false }
        let elision = String(word[...apostrophe])
        let rest = String(word[word.index(after: apostrophe)...])
        return set.contains(elision) || set.contains(rest)
    }
}
