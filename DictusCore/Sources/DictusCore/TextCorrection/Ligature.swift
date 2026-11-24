// DictusCore/Sources/DictusCore/TextCorrection/Ligature.swift
// The ligatures œ and æ, typed as one letter and stored by the dictionaries as two (#1042).
import Foundation

/// The ligatures œ and æ, which a user types as one letter and the dictionaries store as two.
///
/// Every word list Dictus ships spells them out: the French one comes from Lexique 3.83,
/// which writes "coeur", "soeur", "oeuvre", and holds no ligature at all; neither do the
/// English, Spanish or German lists. Since #1042 the long-press popups offer œ and æ, so
/// "cœur" typed by hand reached a trie that only knows "coeur", counted as unknown, and the
/// space bar corrected it to its nearest neighbour, "cour".
///
/// The dictionary is not wrong to spell them out: "coeur" is how French is typed without the
/// ligature, and it stays a valid word. What was missing is the lookup in the dictionary's own
/// spelling, which `FrequencyProvider.hasWord(_:)` adds.
///
/// WHY not Unicode normalization: neither NFD nor NFKD decomposes œ (U+0153) or æ (U+00E6).
/// They are letters in their own right, not a base letter plus a mark, so the accent folding
/// that turns "é" into "e" leaves them as they are.
public enum Ligature {

    /// Each ligature and the two letters the dictionaries write it with, both cases.
    private static let spellings: [Character: String] = [
        "\u{0153}": "oe", "\u{0152}": "OE",   // œ Œ
        "\u{00E6}": "ae", "\u{00C6}": "AE"    // æ Æ
    ]

    /// Whether `word` holds a ligature.
    public static func contains(_ word: String) -> Bool {
        word.contains { spellings[$0] != nil }
    }

    /// `word` with each ligature written as its two letters: "cœur" → "coeur", "Æ" → "AE".
    /// A word without one comes back unchanged.
    public static func spelledOut(_ word: String) -> String {
        guard contains(word) else { return word }
        return word.reduce(into: "") { result, character in
            result += spellings[character] ?? String(character)
        }
    }
}
