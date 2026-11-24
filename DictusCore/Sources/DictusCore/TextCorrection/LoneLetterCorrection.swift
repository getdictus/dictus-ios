// DictusCore/Sources/DictusCore/TextCorrection/LoneLetterCorrection.swift
// A single letter that is not a word on its own, corrected to the neighbouring key that is one (#977).
import Foundation

/// French `problème z` → `problème a`: a lone letter typed in place of `a` (#977).
///
/// WHY a rule of its own: the French dictionary holds every letter but `h`, `p` and `r`
/// (the letter as a noun, an initial), so the valid-word guard of `spellCheck` kept `z`
/// as "already valid" and the trie never saw it, while the three missing ones went to the
/// trie, which wrote `p` and `r` as `à`. In French only `a`, `à` and `y` are words on
/// their own; any other lone letter is either a slip next to one of them or meant as a
/// letter.
///
/// WHY by key proximity and not by the trie: the trie ranks by frequency, and for one
/// typed letter its nearest candidates are two-letter words (`le`, `de`, `la`) as much
/// as `a`. Only the key next to the one pressed says what was meant: `z` and `q` sit
/// next to `a`, `t`, `u`, `g` and `h` next to `y` on AZERTY. A letter with no such
/// neighbour (`b`, `c`, `l`...) is kept as typed, as before: nothing says which word it
/// stands for.
///
/// A capital letter is kept everywhere (`plan B`, `vitamine C`, `H. Dupont`). At the
/// start of a sentence the capital may be the keyboard's, but the engine does not know
/// which key committed the word, and a full stop after it reads as an initial as often
/// as a space after it reads as a slip.
///
/// A letter after an apostrophe is kept (`l'h muet`): the trie used to read the `h`, which
/// the French dictionary does not hold, and wrote `l'y`. So is a letter the user taught
/// the keyboard (`isLearned`). The other cases the issue keeps never reach the rule as a
/// lone letter: a list marker (`a)`) or an address (`t.martin@`) is not corrected as a
/// word (`AutocorrectRejectionMemory.wordAtCursor`, `AddressLikeToken`,
/// `AddressCorrectionRevert`).
public enum LoneLetterCorrection {

    /// What the rule decides for a lone letter. Nil from `decision` means the word is not
    /// the rule's: the usual path decides.
    public enum Decision: Equatable, Sendable {
        /// Replace the letter with this word.
        case correct(String)
        /// Keep the letter as typed, without asking the trie.
        case keep
    }

    /// Two keys are neighbours when their centres sit this close, in key widths. On the
    /// staggered letter rows the keys around a key sit 1.0 to 1.25 key widths from its
    /// centre, and the next ring 1.6 or more (`KeyboardProximity.keyPositions`).
    static let neighbourDistance = 1.3

    /// The decision for `word`, or nil when it is not a lone letter the rule covers.
    ///
    /// - Parameters:
    ///   - words: the lowercase one-letter words of the language (French `a`, `à`, `y`),
    ///     or nil when nobody has written them down for it: the rule is then off.
    ///   - layout: the letter layout the word was typed on, which decides the neighbours.
    ///   - context: the text before the cursor, ending with `word`. With it, a homograph
    ///     rule may choose the accented spelling of the correction (`je vais z` → `à`).
    ///   - homographs: the language's contextual homographs (#501).
    ///   - isLearned: whether the user dictionary holds a lowercase word.
    public static func decision(
        for word: String,
        words: Set<String>?,
        layout: LayoutType,
        context: String? = nil,
        homographs: [ContextualHomograph] = [],
        isLearned: (String) -> Bool
    ) -> Decision? {
        guard let words else { return nil }
        if let apostrophe = word.lastIndex(where: { $0 == "'" || $0 == "\u{2019}" }) {
            let elided = word[word.index(after: apostrophe)...]
            guard elided.count == 1, elided.first?.isLetter == true, !words.contains(elided.lowercased()) else {
                return nil
            }
            return .keep
        }
        guard word.count == 1, let letter = word.first, letter.isLetter,
              !words.contains(word.lowercased()) else { return nil }
        guard !letter.isUppercase, !isLearned(word.lowercased()), let neighbour = nearestWord(to: letter, among: words, on: layout) else {
            return .keep
        }
        guard let context, context.hasSuffix(word) else { return .correct(neighbour) }
        let corrected = String(context.dropLast(word.count)) + neighbour
        let spelling = homographs.lazy.compactMap { $0.accentedForm(of: neighbour, context: corrected) }.first
        return .correct(spelling ?? neighbour)
    }

    /// The one-letter word whose key is nearest `letter`'s, among those within
    /// `neighbourDistance`. Ties go to the word itself, so the answer never depends on
    /// the set's order. A word with no key of its own (`à`) is never a neighbour.
    static func nearestWord(to letter: Character, among words: Set<String>, on layout: LayoutType) -> String? {
        let positions = KeyboardProximity.keyPositions(for: layout)
        guard let typed = positions.first(where: { $0.character == letter }) else { return nil }
        var best: (word: String, distance: Double)?
        for key in positions where words.contains(String(key.character)) {
            let distance = hypot(key.x - typed.x, key.y - typed.y)
            guard distance <= neighbourDistance else { continue }
            let word = String(key.character)
            if let current = best, current.distance < distance || (current.distance == distance && current.word < word) {
                continue
            }
            best = (word, distance)
        }
        return best?.word
    }
}
