// DictusCore/Sources/DictusCore/Vocabulary/VocabularyPairGenerator.swift
// Spans of History that may be the engine's attempt at a term the user wrote down (#512, step 2).
import Foundation

/// One candidate correction: a span the engine wrote, and the spelling it may stand for.
///
/// A pair is **global**, not per dictation: if it is confirmed, it becomes the variant
/// of a normal vocabulary entry (step 2 brief, decision 1), and that entry rewrites the
/// span everywhere. The sentence is the evidence a reader (Pierre labelling, or the
/// judge) needs to decide; it is the most recent one the span was found in.
public struct VocabularyPair: Identifiable, Equatable, Sendable {

    /// Where the canonical spelling came from (step 2 brief, decision 2).
    public enum CanonicalSource: String, Sendable {
        /// A term of the Personal Vocabulary: certain, and may be several words.
        case vocabulary
        /// A word the keyboard learned from typing (#288): lowercase, one word.
        case learned
    }

    /// `pair:` plus the folded canonical and the folded span. Stable across two runs
    /// over the same History, and what an ignore list stores to dismiss this pair.
    public let id: String

    /// The spelling the user wants. Exactly as the vocabulary stores it, or the
    /// learned word in lowercase, which is how the keyboard stores it.
    public let canonical: String

    public let source: CanonicalSource

    /// The span as the engine wrote it, the most frequent spelling ignoring case. One
    /// to three words. What would become the entry's variant.
    public let observed: String

    /// The sentence of the most recent occurrence, cut to a window around the span
    /// when it is long (`VocabularyPairGenerator.contextWords`), on one line.
    public let sentence: String

    /// `SpellingSimilarity.spanScore`, the closest occurrence's. Lower is closer, and
    /// the first ranking key (decision 5: "ranked by similarity").
    public let score: Int

    /// How many dictations contain the span, and how many times it appears overall.
    public let dictationCount: Int
    public let occurrences: Int

    /// When the newest dictation containing the span was made.
    public let lastSeen: Date
}

/// The step 2 pair generator (#512): for each spelling the user wrote down, the History
/// spans that sound or spell like it.
///
/// ### What it is for (step 2 brief, 2026-10-19)
///
/// Step 1 pairs a keyboard-learned word with its misspellings, but only misspellings
/// that are not dictionary words, and only one word or a span whose letters or sounds
/// are *equal* to it. The case it cannot reach is the commonest Parakeet mistake:
/// `cloud code` for `Claude Code`, real words two edits away from a term the keyboard
/// never learns because it is two words. This generator reaches it, and accepts that it
/// proposes pairs it is unsure of: its output is measured first, labelled by hand, and
/// if fewer than 17 of its first 20 pairs are true, Apple Foundation Models is tried as
/// a judge of each pair. The app offers a cautious subset of them, with no judge
/// (`suggestions(from:vocabulary:ignored:)`).
///
/// ### The rules, each from the brief
///
/// - **Canonicals**: Personal Vocabulary terms first, every entry whatever its switch;
///   keyboard-learned words second, a learned word already a term dropped (decision 2).
/// - **Spans**: one to three words, inside one sentence (decision 3), with no digit.
/// - **A single dictionary word is never a variant** (decision 1): storing `cloud` →
///   `Claude` would rewrite every cloud. A span of several dictionary words is allowed,
///   which is the whole point (`cloud code`). Decided by `VocabularySuggestionMiner`'s
///   `candidateWord`, so "dictionary word" means the same thing in steps 1 and 2.
/// - **Not already known**: a span that is any stored term or variant (lowercase,
///   accents kept) is skipped; so is the canonical written right, ignoring case only.
///   Case only, because the replacement pass is case-insensitive (a lowercase variant
///   of a term changes nothing it would not), and because the keyboard stores learned
///   words lowercase, so their case is unknowable. Accents are kept: `stephane` for
///   `Stéphane` is a real mistake and the pass is accent-sensitive.
/// - **The ignore list is honoured** (`VocabularySuggestionIgnoreList`): a folded form
///   the user dismissed, a learned word dismissed as `learned:<word>`, and a pair id.
///
/// ### Why it reads History records
///
/// So it can ship in the app unchanged once the measurement says go (decision 3). The
/// harness builds records from the polish journal export, which is what the Mac sees.
///
/// ### Why greedy and non-overlapping per sentence
///
/// `cloud code`, `cloud code tous` and `j'utilise cloud code` can all be near
/// `Claude Code`; only one reading of those words is the engine's attempt. Within a
/// sentence the closest span wins, then the longer one, then the earlier, and no token
/// serves two pairs. Without that, one occurrence would surface as several pairs and
/// fill the twenty lines Pierre labels with the same mistake.
public struct VocabularyPairGenerator {

    /// Decision 3: a term is heard as one, two or three words, never four.
    public static let longestSpan = 3

    /// Decision 5: the labelling file holds the first twenty pairs.
    public static let defaultLimit = 20

    /// How many words of context each side of the span a long sentence keeps. The
    /// judge is given short inputs (decision 6); a dictation can be one long sentence.
    public static let contextWords = 12

    static let idPrefix = "pair:"

    private let miner: VocabularySuggestionMiner

    /// - Parameter isKnownWord: whether a word is in a dictionary the user's languages
    ///   use, the same predicate `VocabularySuggestionMiner` takes.
    public init(isKnownWord: @escaping (String) -> Bool) {
        self.miner = VocabularySuggestionMiner(isKnownWord: isKnownWord)
    }

    /// The candidate pairs for this History, closest first.
    ///
    /// - Parameters:
    ///   - records: the History, any order.
    ///   - vocabulary: every stored entry. Its terms are canonicals, its terms and
    ///     variants are spans already known.
    ///   - learnedWords: the keyboard's learned words (`UserDictionary`), any case.
    ///   - ignored: what `VocabularySuggestionIgnoreList.keys` returns.
    ///   - limit: how many to return.
    public func pairs(from records: [TranscriptionRecord],
                      vocabulary: [VocabularyEntry],
                      learnedWords: [String] = [],
                      ignored: Set<String>,
                      limit: Int = VocabularyPairGenerator.defaultLimit) -> [VocabularyPair] {
        let canonicals = Self.canonicals(vocabulary: vocabulary, learnedWords: learnedWords, ignored: ignored)
        guard !canonicals.isEmpty else { return [] }
        let knownSpellings = vocabulary.flatMap { [$0.term] + $0.variants }
        let scan = Scan(
            canonicals: canonicals,
            known: Set(knownSpellings.map(Self.lowered)),
            knownWords: knownSpellings.map(Self.words(of:)).filter { !$0.isEmpty },
            ignored: ignored
        )
        var cache = Cache()
        var tallies: [String: PairTally] = [:]

        for record in records {
            let clean = VocabularySuggestionMiner.cleaned(record.text)
            let ranged = VocabularySuggestionMiner.rangedTokens(inClean: clean)
            for sentence in Self.sentences(ranged) {
                let matches = candidates(in: sentence, ranged: ranged, clean: clean, scan: scan, cache: &cache)
                for match in Self.nonOverlapping(matches) {
                    let canonical = canonicals[match.canonical]
                    let key = Self.idPrefix + VocabularySuggestionMiner.fold(canonical.text)
                        + "|" + VocabularySuggestionMiner.fold(match.surface)
                    let excerpt = Self.excerpt(of: match, in: sentence, ranged: ranged, clean: clean)
                    tallies[key, default: PairTally(id: key, canonical: canonical)]
                        .add(match.surface, score: match.score, record: record, sentence: excerpt)
                }
            }
        }

        return tallies.values
            .filter { !ignored.contains($0.id) }
            .map(\.pair)
            .sorted(by: Self.ranksBefore)
            .prefix(max(0, limit))
            .map { $0 }
    }

    // MARK: - Canonicals

    /// A spelling to look for, with what the scan compares it on.
    struct Canonical {
        let text: String
        let source: VocabularyPair.CanonicalSource
        /// Its words, lowercase, elision stripped: what "written right" is tested on.
        let words: [String]
        /// What `spanScore` compares, computed once per run.
        let keys: SpellingSimilarity.Keys
    }

    /// Vocabulary terms in alphabetical order, then learned words not already a term.
    /// Sorted, so two runs see them in the same order and break ties the same way.
    static func canonicals(vocabulary: [VocabularyEntry],
                           learnedWords: [String],
                           ignored: Set<String>) -> [Canonical] {
        var seen = Set<String>()
        var result: [Canonical] = []
        let terms = vocabulary.map(\.term).sorted { lowered($0) < lowered($1) }
        for term in terms where seen.insert(VocabularySuggestionMiner.fold(term)).inserted {
            let words = Self.words(of: term)
            guard !words.isEmpty else { continue }
            result.append(Canonical(text: term, source: .vocabulary, words: words, keys: .init(term)))
        }
        for word in VocabularySuggestionMiner.usableLearnedWords(learnedWords, ignored: ignored)
        where seen.insert(VocabularySuggestionMiner.fold(word)).inserted {
            result.append(Canonical(text: word, source: .learned, words: [word], keys: .init(word)))
        }
        return result
    }

    // MARK: - Scanning one sentence

    /// One span near one canonical, in token indices of the whole record.
    struct Match {
        let canonical: Int
        let start: Int
        let length: Int
        let score: Int
        let surface: String
    }

    /// What one run remembers between sentences: dictionary verdicts, and the keys
    /// of every span already seen (most spans recur across a History).
    struct Cache {
        var known: [String: Bool] = [:]
        private var spanKeys: [String: SpellingSimilarity.Keys] = [:]

        mutating func keys(of surface: String) -> SpellingSimilarity.Keys {
            if let keys = spanKeys[surface] { return keys }
            let keys = SpellingSimilarity.Keys(surface)
            spanKeys[surface] = keys
            return keys
        }
    }

    /// What every sentence of one run is compared against.
    struct Scan {
        let canonicals: [Canonical]
        /// Every stored term and variant, `lowered`: spans already known.
        let known: Set<String>
        /// The same spellings as words (`words(of:)`): a span touching one of them
        /// where it stands in a sentence is not a mistake either.
        let knownWords: [[String]]
        let ignored: Set<String>
    }

    /// Every span of the sentence near a canonical, before overlaps are resolved.
    ///
    /// `sentence` holds indices into `ranged`. "Written right" and "already known" are
    /// found on the sentence's words lowercased with elision stripped, position for
    /// position.
    ///
    /// ### Where a span may start and stop (#512, device feedback 2026-10-25)
    ///
    /// A variant is replaced wherever it appears, so a span carrying one extra word
    /// would eat that word: `super whisper je` stored for `superwhisper` turns every
    /// "super whisper je crois" into "superwhisper crois". So a span:
    /// - never touches a stored term or variant where it stands in the sentence: the
    ///   known part is already handled, the rest is a neighbour;
    /// - never crosses punctuation (a comma ends it as a full stop does);
    /// - never starts or ends with a function word (`edgeWords`).
    private func candidates(in sentence: [Int],
                            ranged: [(token: VocabularySuggestionMiner.Token, range: Range<String.Index>)],
                            clean: String,
                            scan: Scan,
                            cache: inout Cache) -> [Match] {
        let words = sentence.map { Self.lowered(Self.strippingElision(ranged[$0].token.text)) }
        let canonicals = scan.canonicals
        let writtenRight = canonicals.map { Self.occurrences(of: $0.words, in: words) }
        let knownHere = scan.knownWords.flatMap { Self.occurrences(of: $0, in: words) }
        // Whether only blanks stand between a word and the next one.
        let joinedToNext = sentence.indices.map { position in
            position + 1 < sentence.count && clean[ranged[sentence[position]].range.upperBound
                ..< ranged[sentence[position + 1]].range.lowerBound].allSatisfy(\.isWhitespace)
        }
        var matches: [Match] = []
        for offset in sentence.indices {
            for length in 1...Self.longestSpan where offset + length <= sentence.count {
                if length > 1, !joinedToNext[offset + length - 2] { break }
                let parts = sentence[offset..<offset + length].map { ranged[$0].token.text }
                if parts.contains(where: { $0.contains(where: \.isNumber) }) { break }
                let covered = offset..<offset + length
                guard !knownHere.contains(where: { $0.overlaps(covered) }) else { continue }
                guard !Self.edgeWords.contains(words[offset]),
                      !Self.edgeWords.contains(words[offset + length - 1]) else { continue }
                guard let surface = spanSurface(parts, cache: &cache.known) else { continue }
                guard !scan.known.contains(Self.lowered(surface)),
                      !scan.ignored.contains(VocabularySuggestionMiner.fold(surface)) else { continue }
                let keys = cache.keys(of: surface)
                for (index, canonical) in canonicals.enumerated() {
                    // Score first: it refuses most canonicals on two lengths alone.
                    guard let score = SpellingSimilarity.spanScore(
                        keys, canonical: canonical.keys, wordCount: length
                    ) else { continue }
                    // The term written right, or a span reaching into it, is not a mistake.
                    guard !writtenRight[index].contains(where: { $0.overlaps(covered) }) else { continue }
                    matches.append(Match(canonical: index, start: sentence[offset], length: length,
                                         score: score, surface: surface))
                }
            }
        }
        return matches
    }

    /// What a run of tokens is written as, or nil when it cannot be a variant.
    ///
    /// One word goes through `candidateWord`, which refuses a dictionary word, a short
    /// one and a compound of dictionary words, and strips an elided article. Several
    /// words only lose an elided article in front (`d'cloud code` is `cloud code`).
    private func spanSurface(_ parts: [String], cache: inout [String: Bool]) -> String? {
        guard parts.count > 1 else { return parts.first.flatMap { miner.candidateWord($0, cache: &cache) } }
        var words = parts
        words[0] = Self.strippingElision(words[0])
        return words.joined(separator: " ")
    }

    /// Words a span may not start or end with, French and English: pronouns,
    /// articles, conjunctions, prepositions. Inside a span they are fine
    /// (`chat de gpt`), at its edge they are a neighbour the span swallowed.
    static let edgeWords: Set<String> = [
        "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles", "et", "ou", "de", "du",
        "des", "le", "la", "les", "un", "une", "à", "au", "aux", "en", "que", "qui", "ce", "se",
        "i", "you", "it", "he", "she", "we", "they", "and", "or", "of", "the", "a", "an", "to",
        "in", "at", "for", "is"
    ]

    /// A spelling as the words a sentence is compared on: lowercase, elision stripped.
    static func words(of text: String) -> [String] {
        VocabularySuggestionMiner.tokens(in: text).map { lowered(strippingElision($0.text)) }
    }

    /// Where `needle` stands in `haystack`, as ranges of positions.
    static func occurrences(of needle: [String], in haystack: [String]) -> [Range<Int>] {
        guard !needle.isEmpty, needle.count <= haystack.count else { return [] }
        return (0...(haystack.count - needle.count)).compactMap { start in
            Array(haystack[start..<start + needle.count]) == needle ? start..<start + needle.count : nil
        }
    }

    /// The closest match first, then the longer, then the earlier; each token used once.
    static func nonOverlapping(_ matches: [Match]) -> [Match] {
        let ordered = matches.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            if lhs.length != rhs.length { return lhs.length > rhs.length }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            return lhs.canonical < rhs.canonical
        }
        var used = IndexSet()
        var kept: [Match] = []
        for match in ordered {
            let range = match.start..<match.start + match.length
            guard !used.intersects(integersIn: range) else { continue }
            used.insert(integersIn: range)
            kept.append(match)
        }
        return kept
    }

    // MARK: - Sentences and excerpts

    /// The record's tokens grouped by sentence, as indices into `ranged`. A sentence
    /// starts at every sentence-initial token, the tokenizer's own boundary rule.
    static func sentences(_ ranged: [(token: VocabularySuggestionMiner.Token, range: Range<String.Index>)]) -> [[Int]] {
        var sentences: [[Int]] = []
        for index in ranged.indices {
            if ranged[index].token.isSentenceInitial || sentences.isEmpty {
                sentences.append([index])
            } else {
                sentences[sentences.count - 1].append(index)
            }
        }
        return sentences
    }

    /// The sentence around a match, on one line: whole when short, otherwise
    /// `contextWords` words each side with `…` where it was cut. A sentence that runs
    /// to its end keeps its closing punctuation.
    static func excerpt(of match: Match,
                        in sentence: [Int],
                        ranged: [(token: VocabularySuggestionMiner.Token, range: Range<String.Index>)],
                        clean: String) -> String {
        guard let first = sentence.first, let last = sentence.last else { return match.surface }
        let low = max(first, match.start - contextWords)
        let high = min(last, match.start + match.length - 1 + contextWords)
        let start = ranged[low].range.lowerBound
        let end = high == last
            ? (high + 1 < ranged.count ? ranged[high + 1].range.lowerBound : clean.endIndex)
            : ranged[high].range.upperBound
        let body = clean[start..<end]
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
        return (low > first ? "… " : "") + body + (high < last ? " …" : "")
    }

    // MARK: - Keys

    /// Composed and lowercased, accents kept: the comparison "already known" and
    /// "written right" use. Folding accents here would hide `stephane` for `Stéphane`.
    static func lowered(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping.lowercased()
    }

    /// The word without an elided article in front: `l'airmes` is `airmes`.
    static func strippingElision(_ word: String) -> String {
        let apostrophes: Set<Character> = ["'", "\u{2019}"]
        guard let index = word.firstIndex(where: { apostrophes.contains($0) }),
              VocabularySuggestionMiner.elisionPrefixes.contains(word[..<index].lowercased()) else { return word }
        let tail = String(word[word.index(after: index)...])
        return tail.isEmpty ? word : tail
    }

    // MARK: - Ranking

    /// Closest first (decision 5), then more dictations, more occurrences, more recent,
    /// and the id as the last tie-break so the order is fully determined.
    static func ranksBefore(_ lhs: VocabularyPair, _ rhs: VocabularyPair) -> Bool {
        if lhs.score != rhs.score { return lhs.score < rhs.score }
        if lhs.dictationCount != rhs.dictationCount { return lhs.dictationCount > rhs.dictationCount }
        if lhs.occurrences != rhs.occurrences { return lhs.occurrences > rhs.occurrences }
        if lhs.lastSeen != rhs.lastSeen { return lhs.lastSeen > rhs.lastSeen }
        return lhs.id < rhs.id
    }

    // MARK: - Counting

    /// What History says about one (canonical, span) pair.
    struct PairTally {
        let id: String
        let canonical: Canonical
        private var spellings: [String: (spelling: String, count: Int)] = [:]
        private var records: Set<UUID> = []
        private var occurrences = 0
        private var score = Int.max
        private var lastSeen = Date.distantPast
        private var sentence = ""

        init(id: String, canonical: Canonical) {
            self.id = id
            self.canonical = canonical
        }

        mutating func add(_ surface: String, score: Int, record: TranscriptionRecord, sentence excerpt: String) {
            let lower = surface.lowercased()
            let existing = spellings[lower]
            spellings[lower] = (
                VocabularySuggestionMiner.Tally.preferredSpelling(existing?.spelling, surface),
                (existing?.count ?? 0) + 1
            )
            records.insert(record.id)
            occurrences += 1
            self.score = min(self.score, score)
            // The newest dictation's sentence; within one, the first occurrence's.
            if record.createdAt > lastSeen {
                sentence = excerpt
                lastSeen = record.createdAt
            } else if sentence.isEmpty {
                sentence = excerpt
            }
        }

        var pair: VocabularyPair {
            // Most frequent, then alphabetical: `min` under "ranks before".
            let observed = spellings.values
                .min { $0.count != $1.count ? $0.count > $1.count : $0.spelling < $1.spelling }?
                .spelling ?? ""
            return VocabularyPair(
                id: id,
                canonical: canonical.text,
                source: canonical.source,
                observed: observed,
                sentence: sentence,
                score: score,
                dictationCount: records.count,
                occurrences: occurrences,
                lastSeen: lastSeen
            )
        }
    }
}
