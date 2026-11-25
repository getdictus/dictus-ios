// DictusCore/Sources/DictusCore/TextCorrection/CuratedNameCorrection.swift
// Makes a curated app or brand name an autocorrect target, under a narrow rule
// (Titus, 2026-11-25): `iphon` -> "iPhone", `youtub` -> "YouTube".
import Foundation

/// Picks the curated name (`CuratedNames.recased`) an unknown typed word should be
/// corrected to.
///
/// WHY a rule and not trie entries: the dictionaries hold no `iphone` (fr, en) and
/// no `whatsapp` or `youtube` (en), and adding them would make every brand a target
/// of the whole fuzzy search, at the weight of a common word. Measured before this
/// rule (sweep of every one-edit typo of the 30,000 most frequent fr and en words):
/// "one edit from a brand" alone sends `ihone` to iPhone instead of `phone`,
/// `airpors` to AirPods instead of `airport`, `youture` to YouTube instead of
/// `couture`. So a name wins only on a close typo of the name itself:
///
/// - **The typed word is unknown to the dictionary**, has at least five letters
///   and only letters. A correctly typed word (`upon`, `siphon`, `youth`, `whats`,
///   `foutu`) is never rewritten, and a short word has too many neighbours.
/// - **The name minus its last letter** wins outright: `iphon`, `youtub`,
///   `whatsap`. The typist stopped one letter short of the name; `siphon`, one edit
///   away too, needs a letter added in front, which is the less likely slip.
/// - **One other edit** (`iphine`, `youtubr`) wins only when no dictionary word is
///   one edit away, the name's first letter is right, and the name has six letters
///   or more. `ihone` stays the trie's (`phone`), and `iphones` is not cut to iPhone.
/// - **`CuratedNames.keptAsTyped` are never targets**: `discorf` is the trie's.
public enum CuratedNameCorrection {

    /// Shortest typed word a curated name may correct.
    public static let minimumTypedLength = 5

    /// Shortest name the one-edit branch may reach. `gmail` and `ipad` are only
    /// reached from their missing-last-letter form.
    static let minimumOneEditNameLength = 6

    /// Letters tried for a dictionary word one edit from the typed word: the
    /// Latin letters and the accented ones of the Dictus languages.
    static let neighbourLetters = Array("abcdefghijklmnopqrstuvwxyzàâäçéèêëîïôöùûüÿñæœß")

    private static let names = CuratedNames.recased.map { (key: $0.lowercased(), casing: $0) }
    private static let nameKeys = Set(names.map(\.key))

    /// The curated name `typedWord` should become, in the name's casing, or nil.
    ///
    /// - Parameters:
    ///   - typedWord: the word as typed, without any apostrophe prefix. Its case is
    ///     ignored: `Iphon` at a sentence start gives "iPhone", as a typed `Iphone` does.
    ///   - dictionaryKnows: whether the active language's dictionary has a lowercase word.
    public static func target(for typedWord: String, dictionaryKnows: (String) -> Bool) -> String? {
        let typed = typedWord.lowercased()
        guard typed.count >= minimumTypedLength, typed.allSatisfy(\.isLetter), !dictionaryKnows(typed) else {
            return nil
        }
        if let name = names.first(where: { $0.key.count == typed.count + 1 && $0.key.hasPrefix(typed) }) {
            return name.casing
        }
        let oneEdit = names.first { name in
            name.key.count >= minimumOneEditNameLength
                && name.key.first == typed.first
                && !typed.hasPrefix(name.key)
                && abs(name.key.count - typed.count) <= 1
                && SpellingSimilarity.editDistance(typed, name.key, atMost: 1) == 1
        }
        guard let oneEdit, !hasDictionaryWordOneEditAway(typed, dictionaryKnows: dictionaryKnows) else {
            return nil
        }
        return oneEdit.casing
    }

    /// Whether a dictionary word other than a curated name is one deletion,
    /// substitution or insertion from `typed`. Only asked once a name matched, so
    /// the few hundred lookups run on a handful of typed words.
    static func hasDictionaryWordOneEditAway(_ typed: String, dictionaryKnows: (String) -> Bool) -> Bool {
        let letters = Array(typed)
        func isWord(_ candidate: [Character]) -> Bool {
            let word = String(candidate)
            return !nameKeys.contains(word) && dictionaryKnows(word)
        }
        for index in 0...letters.count {
            if index < letters.count {
                var deleted = letters
                deleted.remove(at: index)
                if isWord(deleted) { return true }
            }
            for letter in neighbourLetters {
                var inserted = letters
                inserted.insert(letter, at: index)
                if isWord(inserted) { return true }
                if index < letters.count, letters[index] != letter {
                    var substituted = letters
                    substituted[index] = letter
                    if isWord(substituted) { return true }
                }
            }
        }
        return false
    }
}
