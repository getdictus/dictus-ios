// DictusCore/Sources/DictusCore/Vocabulary/SpellingSimilarity.swift
// When a spelling in History is the engine's attempt at a word the user typed (#512).
import Foundation

/// The comparisons behind the vocabulary suggestions: folding, a phonetic key, and
/// an edit distance that loosens with length.
///
/// ### Why two measures and not one
///
/// The engine's mistakes are acoustic. `airmes` for `Hermes` is two substitutions
/// in six letters, which no edit-distance threshold tight enough to keep ordinary
/// words apart will accept: at two edits for six letters, `maison` and `raison`,
/// `pomme` and `homme` all match. What `airmes` and `hermes` share is how they sound,
/// so the main measure is a **phonetic key** in which French and English spellings
/// of the same sounds meet. The edit distance stays for what sound does not explain:
/// a dropped or doubled letter in a long word (`whisperkitt`).
///
/// ### The phonetic key
///
/// Hand-written rather than Soundex, Metaphone or the French Phonex, because each of
/// those is built for one language and drops information the other needs: Soundex
/// keeps the first letter, which is exactly what `airmes` / `hermes` changes, and
/// erases every vowel, which merges far too much. This key keeps the vowels, folds
/// the spellings both languages use for one sound (`ai` `ei` `è` → `e`, `ee` → `i`,
/// `au` `eau` → `o`, `ph` → `f`, `c`/`q` → `k`), drops `h` (silent in French) and
/// a final `e` (silent in both), and collapses doubled letters.
public enum SpellingSimilarity {

    /// Case and diacritics folded, so `Parakít`, `parakit` and `PARAKIT` compare equal.
    public static func fold(_ word: String) -> String {
        word.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// The folded letters only: `Whisper-Kit`, `whisper kit` and `whisperkit` are one
    /// skeleton. What a word heard as two words is compared on.
    public static func skeleton(_ text: String) -> String {
        String(fold(text).filter { $0.isLetter || $0.isNumber })
    }

    /// Multi-letter spellings first, longest first, so `eau` is read before `au`.
    private static let graphemes: [(String, String)] = [
        ("eau", "o"), ("ou", "u"), ("oo", "u"), ("au", "o"),
        ("ai", "e"), ("ei", "e"), ("ay", "e"), ("ey", "e"),
        ("ee", "i"), ("ea", "i"),
        ("ph", "f"), ("qu", "k"), ("ck", "k"), ("sh", "x"), ("ch", "x"),
        ("th", "t"), ("gn", "n"), ("ce", "se"), ("ci", "si")
    ]

    private static let letters: [Character: String] = [
        "c": "k", "q": "k", "y": "i", "z": "s", "w": "v", "x": "ks", "h": ""
    ]

    /// How a word sounds, approximately, in French or English. See the type's notes.
    public static func phoneticKey(_ text: String) -> String {
        var key = skeleton(text)
        for (spelling, sound) in graphemes {
            key = key.replacingOccurrences(of: spelling, with: sound)
        }
        key = key.reduce(into: "") { result, character in
            result += letters[character] ?? String(character)
        }
        var collapsed = ""
        for character in key where collapsed.last != character {
            collapsed.append(character)
        }
        if collapsed.count > 3, collapsed.hasSuffix("e") { collapsed.removeLast() }
        return collapsed
    }

    /// Edits allowed between two skeletons: a quarter of the shorter, at least one.
    /// One edit for `dictus`, two from eight letters, three from twelve.
    public static func allowedEdits(_ lhs: String, _ rhs: String) -> Int {
        max(1, min(lhs.count, rhs.count) / 4)
    }

    /// Whether `candidate`, a single word the engine wrote, is a spelling of `learned`.
    ///
    /// Equal skeletons (`hermès` for `hermes`), equal phonetic keys (`airmes`), or an
    /// edit distance within `allowedEdits`. The caller has already dropped dictionary
    /// words, which is what keeps `raison` from ever being a spelling of anything.
    /// Returns a score, lower is closer, or nil when the two are not a pair.
    public static func pairScore(candidate: String, learned: String) -> Int? {
        let lhs = skeleton(candidate), rhs = skeleton(learned)
        guard lhs.count >= 3, rhs.count >= 3 else { return nil }
        if lhs == rhs { return 0 }
        let lhsKey = phoneticKey(candidate), rhsKey = phoneticKey(learned)
        if lhsKey == rhsKey, lhsKey.count >= 3 { return 1 }
        let allowed = allowedEdits(lhs, rhs)
        guard abs(lhs.count - rhs.count) <= allowed else { return nil }
        let distance = editDistance(lhs, rhs, atMost: allowed)
        return distance <= allowed ? 1 + distance : nil
    }

    /// Whether `span`, several words the engine wrote, is a spelling of `learned`
    /// heard as more than one word (`her mes`, `whisper kit`).
    ///
    /// Equal skeletons or equal phonetic keys only, never an edit distance: every word
    /// of a span may be an ordinary word, and two ordinary words joined end to end
    /// land within a couple of edits of far too many things.
    public static func spanMatches(_ span: String, learned: String) -> Bool {
        let lhs = skeleton(span), rhs = skeleton(learned)
        // Five letters at least: below that, two short words joined (`de la`) spell
        // too many things to stand for one.
        guard lhs.count >= 5, rhs.count >= 5 else { return false }
        return lhs == rhs || phoneticKey(span) == phoneticKey(learned)
    }

    /// Whether two folded spellings are close enough to be one unknown word misheard
    /// twice. The grouping of the history-only suggestions, which have no learned
    /// word to anchor them; kept as tight as before (one edit up to six characters).
    static func areNearSpellings(_ lhs: String, _ rhs: String) -> Bool {
        let shorter = min(lhs.count, rhs.count)
        let allowed = shorter >= 7 ? 2 : 1
        guard abs(lhs.count - rhs.count) <= allowed else { return false }
        return editDistance(lhs, rhs, atMost: allowed) <= allowed
    }

    /// Levenshtein distance, giving up past `atMost` (the answer is then `atMost + 1`).
    static func editDistance(_ lhs: String, _ rhs: String, atMost limit: Int) -> Int {
        let left = Array(lhs), right = Array(rhs)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }
        var previous = Array(0...right.count)
        for (i, leftChar) in left.enumerated() {
            var current = [i + 1] + Array(repeating: 0, count: right.count)
            var rowMinimum = current[0]
            for (j, rightChar) in right.enumerated() {
                let substitution = previous[j] + (leftChar == rightChar ? 0 : 1)
                current[j + 1] = min(previous[j + 1] + 1, current[j] + 1, substitution)
                rowMinimum = min(rowMinimum, current[j + 1])
            }
            if rowMinimum > limit { return limit + 1 }
            previous = current
        }
        return previous[right.count]
    }
}
