// DictusCore/Sources/DictusCore/TextCorrection/ElisionRepair.swift
// Elisions typed with a wrong prefix, a key in place of the apostrophe, or a space (#1006).
import Foundation

/// Repairs an elision whose apostrophe was missed or whose prefix was mistyped:
/// `v'est` → `c'est`, `qj'on` → `qu'on`, `qunil` → `qu'il`, `ce st` → `c'est` (#1006).
///
/// A glued elision with nothing else wrong (`cest`, `quil`) is `expandContractions`'s
/// job. This type handles the shapes that function cannot see.
///
/// Every answer is lowercase. The caller restores the capital.
public struct ElisionRepair: Sendable {

    /// A prefix typed before an apostrophe, mapped to the prefix it stands for:
    /// `v` → `c` (`v'est`), `qj` → `qu` (`qj'on`). Valid prefixes are not keys.
    public let prefixSlips: [String: String]

    /// The keys next to the apostrophe key, which land in its place: `n` on AZERTY.
    public let apostropheNeighbours: Set<Character>

    /// The elisions repaired from a neighbour key or a space, by prefix without its
    /// apostrophe: `qu` → `il`, `elle`, `on`… A short list, because these two shapes
    /// also occur inside real words and typos: `dnas` is `dans`, never `d'as`.
    public let elidedWords: [String: [String]]

    public init(prefixSlips: [String: String], apostropheNeighbours: Set<Character>, elidedWords: [String: [String]]) {
        self.prefixSlips = prefixSlips
        self.apostropheNeighbours = apostropheNeighbours
        self.elidedWords = elidedWords
    }

    /// `v'est` → `c'est`, `qj'on` → `qu'on`: a mistyped prefix before an apostrophe.
    /// Nil when the prefix is valid or unknown, or when what follows is not a word.
    public func repairPrefix(_ word: String, isWord: (String) -> Bool) -> String? {
        let lowered = word.lowercased()
        guard let apostrophe = lowered.firstIndex(of: "'") else { return nil }
        let rest = String(lowered[lowered.index(after: apostrophe)...])
        guard let prefix = prefixSlips[String(lowered[..<apostrophe])], !rest.isEmpty, isWord(rest) else {
            return nil
        }
        return "\(prefix)'\(rest)"
    }

    /// `qunil` → `qu'il`: the key next to the apostrophe typed in its place.
    public func repairApostropheSlip(_ word: String) -> String? {
        let lowered = word.lowercased()
        for prefix in prefixesLongestFirst where lowered.hasPrefix(prefix) {
            let afterPrefix = lowered.dropFirst(prefix.count)
            guard let key = afterPrefix.first, apostropheNeighbours.contains(key),
                  let elided = elided(String(afterPrefix.dropFirst()), after: prefix) else { continue }
            return "\(prefix)'\(elided)"
        }
        return nil
    }

    /// `qu il` → `qu'il`, `ce st` → `c'est`: a space typed where the apostrophe goes,
    /// wherever it fell inside the elision. Both words are replaced by the answer.
    ///
    /// A word that stands on its own is left alone (`quel le` is not `qu'elle`), unless
    /// the previous word is a bare prefix of two letters, which never stands alone.
    /// A one-letter one does: `le langage C est rapide`.
    /// - Parameter isWord: whether the dictionary knows a lowercase word.
    public func joinAcrossSpace(previousWord: String, word: String, isWord: (String) -> Bool) -> String? {
        let previous = previousWord.lowercased()
        let current = word.lowercased()
        guard !previous.contains("'"), !current.contains("'") else { return nil }
        let joined = previous + current
        for prefix in prefixesLongestFirst where joined.hasPrefix(prefix) {
            guard (previous == prefix && prefix.count > 1) || !isWord(current),
                  let elided = elided(String(joined.dropFirst(prefix.count)), after: prefix) else { continue }
            return "\(prefix)'\(elided)"
        }
        return nil
    }

    /// Longest first, so the answer never depends on the dictionary's hash order.
    private var prefixesLongestFirst: [String] {
        elidedWords.keys.sorted { $0.count != $1.count ? $0.count > $1.count : $0 < $1 }
    }

    /// The listed elided word `typed` spells once accents are ignored: `etait` is `était`.
    private func elided(_ typed: String, after prefix: String) -> String? {
        let folded = typed.folding(options: .diacriticInsensitive, locale: nil)
        return elidedWords[prefix]?.first { $0.folding(options: .diacriticInsensitive, locale: nil) == folded }
    }
}
