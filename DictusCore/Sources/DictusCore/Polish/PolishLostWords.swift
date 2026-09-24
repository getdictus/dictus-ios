// DictusCore/Sources/DictusCore/Polish/PolishLostWords.swift
// Did a word the speaker dictated disappear from the free polish? (#575)
import Foundation
import NaturalLanguage

/// The dictated words missing from a free-polish output, once every licence the
/// Natural contract grants has been applied. Empty means the output keeps the
/// speaker's meaning, as far as a word count can tell.
///
/// ### The defect, and why no other check sees it
///
/// Apple FM's prior pulls a dictation toward standard written French, and on device it
/// carries the pull past register into meaning: `je suis preneur` → `je suis prêt`,
/// `je te revaudrai ça` → `je te reviendrai ça`, `on se capte` → `on se voit` (#575).
/// Every one of those outputs was `success`. The five checks before this one look at
/// length, language, names, the opening and whole lines, and one replaced word inside
/// an eight-word sentence moves none of them. No prompt removes the prior either:
/// `findings.md` measured a prompt that forbids changing any word damaging *more*.
///
/// ### The bar is meaning, not wording (ADR 0003, 2026-09-24 amendment)
///
/// | change | verdict |
/// |---|---|
/// | a dictated word replaced by a different word | refused |
/// | a meaning-bearing word deleted — a negation, a number, a name, a date | refused |
/// | register lifted: `t'as` → `tu as`, `ne` added, `comment vas-tu`, `checker` → `vérifier` | tolerated |
/// | a politeness formula or sign-off dropped | tolerated |
///
/// So the check counts words, then forgives, in this order: rule 6's repeats collapse
/// in the dictation; grammar words, fillers and single letters are never counted;
/// rule 3's spoken numbers go when the output gained a digit; a politeness formula
/// or sign-off may vanish outright; a register pair's dictated form may vanish when
/// its standard form is in the output; an abbreviation may grow into its full form
/// (`dispo` → `disponible`, and a verb into its future, `déborder` → `débordera`);
/// `essaye` and `essaie` are one word; and `type less` / `TypeLess` are one word
/// written two ways. What is left is lost. The lists are `PolishLostWordsLexicon`.
///
/// ### Short input only
///
/// Bag-of-words is #466's trap: on a long dictation a legitimate rule-8 repair looks
/// exactly like a loss. The research detector refused 21 % of faithful long outputs
/// and 4.3 % of short ones. So the check runs only up to `maximumInputCharacters`,
/// and **a long dictation stays unprotected against a substituted word.**
///
/// ### An off-language clause brought back is rule 8, not a loss
///
/// Parakeet drops English clauses into French dictations, and rule 8 (with ADR 0003's
/// 2026-09-02 amendment) licenses bringing them back into French — which removes
/// every English word. When the lost words include a run of at least three
/// consecutive dictated words that reads confidently as another language, the check
/// stands down for the whole output. That was every false refusal the research
/// detector made on `freepolish.json` (`5-erreur-parakeet`, a short dictation), and
/// the French prompt's own rule-8 example has that shape. **It is a hole**: a French
/// word lost in the same dictation passes too.
///
/// ### French only
///
/// `PolishLostWordsLexicon.lexicon(for:)` has French and nothing else, and every
/// other language passes untested. See that type for why.
public enum PolishLostWords {

    /// Longest pre-passed input, in characters, the check reads. Above it the output
    /// passes untested.
    ///
    /// Measured, not chosen (#575, `docs/research/575-normal-polish-damage/`):
    /// - every dictation #575 was filed from is at most 346 characters — D4, row 2's
    ///   device capture, is exactly 346, so the ~300 the findings *estimated* would
    ///   have left out the one dictation the row exists for;
    /// - the long-input false refusals the findings counted sit at 838, 1,159 and
    ///   1,283 characters, plus four at 353 that are English-clause repairs, which
    ///   the off-language stand-down handles rather than the length;
    /// - no fixture in any of the three corpora lies between 395 and 637 characters,
    ///   so every value in that band sorts them identically. 500 is its middle.
    public static let maximumInputCharacters = 500

    /// Shortest run of consecutive lost dictated words the off-language stand-down
    /// reads. Two words are too few for a recogniser, and a one-word substitution —
    /// the shape this check exists for — can never make a run.
    static let offLanguageRunMinimumWords = 3

    /// One word of a text: what it looked like, and what it compares as.
    struct Token: Equatable {
        let surface: String
        let key: String
    }

    /// Whether the output keeps every dictated word the contract protects.
    ///
    /// `raw` is the text the engine saw — the pipeline passes `preprocessed`, for the
    /// reason every other check does. `languageCode` is the `NLLanguage` code the
    /// dictation is in; without a lexicon for it the answer is `true`.
    public static func accepts(polished: String, raw: String, languageCode: String?) -> Bool {
        lostWords(polished: polished, raw: raw, languageCode: languageCode).isEmpty
    }

    /// The dictated words missing from `polished`, folded, sorted, one per word.
    /// Empty when the output passes, including every case the check does not read.
    ///
    /// `maximumCharacters` exists for the research replay alone, which measures what
    /// the check would refuse on long input it does not ship on. The pipeline never
    /// passes it.
    public static func lostWords(polished: String,
                                 raw: String,
                                 languageCode: String?,
                                 maximumCharacters: Int = maximumInputCharacters) -> [String] {
        guard let lexicon = PolishLostWordsLexicon.lexicon(for: languageCode),
              raw.count <= maximumCharacters else { return [] }
        let comparison = Comparison(input: collapsingRepeats(tokens(in: raw)),
                                    output: tokens(in: polished),
                                    lexicon: lexicon)
        let missing = comparison.missing
        let lost = missing.filter { !comparison.isLicensed($0) }
        guard !lost.isEmpty else { return [] }
        if bringsBackOffLanguageClause(input: comparison.input, missing: missing, lost: lost,
                                       languageCode: languageCode) {
            return []
        }
        return lost.sorted()
    }

    // MARK: - Licences

    /// One dictation against one output: the two word bags, and the licences.
    private struct Comparison {
        let input: [Token]
        let lexicon: PolishLostWordsLexicon
        let inputKeys: [String]
        let outputKeys: [String]
        let inputCounts: [String: Int]
        let outputCounts: [String: Int]
        /// Whether the output carries more numbers than the dictation — rule 3 turned
        /// a spoken number into digits, so its words may go.
        let gainedNumber: Bool

        init(input: [Token], output: [Token], lexicon: PolishLostWordsLexicon) {
            self.input = input
            self.lexicon = lexicon
            inputKeys = input.map(\.key)
            outputKeys = output.map(\.key)
            outputCounts = PolishLostWords.counts(outputKeys)
            var inputCounts = PolishLostWords.counts(inputKeys)
            // Politeness and sign-offs first: they leave the dictation's bag entirely,
            // so nothing below can mistake one of their words for a loss.
            for phrase in lexicon.droppablePhrases {
                let dropped = PolishLostWords.occurrences(of: phrase, in: inputKeys)
                    - PolishLostWords.occurrences(of: phrase, in: outputKeys)
                guard dropped > 0 else { continue }
                for word in phrase { inputCounts[word, default: 0] -= dropped }
            }
            self.inputCounts = inputCounts
            gainedNumber = PolishLostWords.numberCount(outputKeys) > PolishLostWords.numberCount(inputKeys)
        }

        /// Dictated words the output carries fewer of, before any licence.
        var missing: Set<String> {
            Set(inputCounts.keys.filter { (inputCounts[$0] ?? 0) > (outputCounts[$0] ?? 0) })
        }

        /// Whether a word the output has fewer of is one the contract lets go.
        func isLicensed(_ key: String) -> Bool {
            // Elisions (`t'as` → `tu as` loses the `t`) and the ordinary grammar words.
            if key.count == 1 && !key.allSatisfy(\.isNumber) { return true }
            if lexicon.ignoredWords.contains(key) { return true }
            if gainedNumber && lexicon.numberWords.contains(key) { return true }
            // A negation is never forgiven by a pair or a prefix: `plus` → `plusieurs`
            // would otherwise read as an abbreviation growing into its full form.
            guard !lexicon.negations.contains(key) else { return false }
            let pairs = lexicon.registerPairs.filter { $0.dictated.contains(key) }
            if pairs.contains(where: { pair in
                outputKeys.contains { word in pair.standardPrefixes.contains { word.hasPrefix($0) } }
            }) {
                return true
            }
            // An abbreviation grown into its full form (`dispo` → `disponible`), or an
            // infinitive into its future (`déborder` → `débordera`). Four letters at
            // least, and only against a word the output GAINED, so a word that was
            // already in the dictation cannot excuse a loss.
            if key.count >= 4, outputCounts.contains(where: { word, count in
                word != key && word.hasPrefix(key) && count > (inputCounts[word] ?? 0)
            }) {
                return true
            }
            return PolishLostWords.isJoinOrSplit(key, input: inputKeys, output: outputKeys)
        }
    }

    /// Whether `key` is one word written as two or three, or the reverse:
    /// `type less` → `TypeLess`, `ChatGPT` → `Chat GPT`.
    fileprivate static func isJoinOrSplit(_ key: String, input: [String], output: [String]) -> Bool {
        let joinedOutput = adjacentJoins(output)
        if joinedOutput.contains(key) { return true }
        let outputSet = Set(output)
        for (index, word) in input.enumerated() where word == key {
            for width in 2...3 {
                for start in max(0, index - width + 1)...index where start + width <= input.count {
                    if outputSet.contains(input[start..<(start + width)].joined()) { return true }
                }
            }
        }
        return false
    }

    /// Every run of two or three adjacent keys, concatenated.
    private static func adjacentJoins(_ keys: [String]) -> Set<String> {
        var joins: Set<String> = []
        for width in 2...3 where keys.count >= width {
            for start in 0...(keys.count - width) {
                joins.insert(keys[start..<(start + width)].joined())
            }
        }
        return joins
    }

    /// Whether the lost words include a run of consecutive dictated words that reads
    /// as a language other than the dictation's. See the type's doc.
    ///
    /// A run is consecutive dictated words the output has fewer of — `missing`, so a
    /// licensed single letter such as the `I` of `and I think` does not cut it — and
    /// it counts only if at least `offLanguageRunMinimumWords` of them are `lost`.
    /// It is read on its surface, accents and all, at the floor the per-segment
    /// language check uses: only a confident disagreement stands the check down, so a
    /// French run the recogniser cannot place is still a loss.
    private static func bringsBackOffLanguageClause(input: [Token],
                                                    missing: Set<String>,
                                                    lost: Set<String>,
                                                    languageCode: String?) -> Bool {
        let thresholds = PolishLanguageSegmentThresholds.default
        var runs: [[Token]] = [[]]
        for token in input {
            if missing.contains(token.key) {
                runs[runs.count - 1].append(token)
            } else if !(runs.last ?? []).isEmpty {
                runs.append([])
            }
        }
        return runs.contains { run in
            guard run.filter({ lost.contains($0.key) }).count >= offLanguageRunMinimumWords else { return false }
            let text = run.map(\.surface).joined(separator: " ")
            guard text.count >= thresholds.minimumSegmentCharacters else { return false }
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)
            guard let top = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value }),
                  top.value >= thresholds.confidenceFloor else { return false }
            return top.key.rawValue != languageCode
        }
    }

    // MARK: - Tokens

    /// The comparison keys of `text`, in order. Public to the lexicon, which cuts its
    /// own entries with it so a list and a dictation agree on what a word is.
    static func keys(in text: String) -> [String] {
        tokens(in: text).map(\.key)
    }

    /// The words of `text`, in order.
    ///
    /// Cut like `PolishLexicon.words` — a word is a run of letters or digits — with
    /// four differences, each a false loss the research detector counted:
    /// - a run also splits where letters meet digits, so `18h30` and `18 h 30` are
    ///   the same three words;
    /// - `œ` and `æ` fold to two letters (`findings.md`, amendment A1);
    /// - `aye` folds to `aie`, so `essaye` and `essaie`, both correct, compare equal;
    /// - `à` keeps its accent, so the sign-off `à plus` is never the `a plus` of a
    ///   negation.
    ///
    /// No `NLTokenizer` pass: the only lexicon is French, which separates its words.
    static func tokens(in text: String) -> [Token] {
        var tokens: [Token] = []
        for run in text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            for piece in splittingLettersFromDigits(run) {
                tokens.append(Token(surface: piece, key: key(for: piece)))
            }
        }
        return tokens
    }

    private static func key(for surface: String) -> String {
        let lowered = surface.lowercased()
        if lowered == "à" { return lowered }
        return PolishLexicon.fold(lowered)
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "æ", with: "ae")
            .replacingOccurrences(of: "aye", with: "aie")
    }

    private static func splittingLettersFromDigits(_ run: Substring) -> [String] {
        var pieces: [String] = []
        var current = ""
        for character in run {
            if let last = current.last, last.isNumber != character.isNumber {
                pieces.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }

    /// Rule 6, on words and on phrases of up to four: an immediate repeat collapses to
    /// one copy (`dès que dès que dès que` → `dès que`). Applied to the dictation only,
    /// so it can only ever forgive.
    static func collapsingRepeats(_ tokens: [Token]) -> [Token] {
        var kept: [Token] = []
        for token in tokens {
            kept.append(token)
            var collapsed = true
            while collapsed {
                collapsed = false
                for width in 1...4 where kept.count >= 2 * width {
                    let tail = kept.suffix(2 * width).map(\.key)
                    if tail.prefix(width).elementsEqual(tail.suffix(width)) {
                        kept.removeLast(width)
                        collapsed = true
                        break
                    }
                }
            }
        }
        return kept
    }

    fileprivate static func counts(_ keys: [String]) -> [String: Int] {
        keys.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    fileprivate static func numberCount(_ keys: [String]) -> Int {
        keys.filter { $0.allSatisfy(\.isNumber) }.count
    }

    fileprivate static func occurrences(of phrase: [String], in keys: [String]) -> Int {
        guard !phrase.isEmpty, keys.count >= phrase.count else { return 0 }
        return (0...(keys.count - phrase.count)).filter { start in
            keys[start..<(start + phrase.count)].elementsEqual(phrase)
        }.count
    }
}
