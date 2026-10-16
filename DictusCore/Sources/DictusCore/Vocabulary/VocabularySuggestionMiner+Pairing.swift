// DictusCore/Sources/DictusCore/Vocabulary/VocabularySuggestionMiner+Pairing.swift
// Keyboard-learned words as the correct spelling, History as the evidence (#512, step 1).
import Foundation

extension VocabularySuggestionMiner {

    /// The longest run of words a learned word can be heard as: `whisper kit`, `her mes`,
    /// `chat j p t` stops being one word long before four.
    static let longestSpan = 3

    /// The id prefix of a paired suggestion. Ignoring it stores the id, so the same
    /// learned word is not offered again with the same evidence.
    static let pairedIDPrefix = "learned:"

    /// One suggestion per learned word the engine got wrong at least once.
    ///
    /// ### What counts as the engine getting it wrong
    ///
    /// - **One word** that is not a dictionary word and is a spelling of the learned
    ///   word (`SpellingSimilarity.pairScore`). A dictionary word never pairs: the
    ///   replacement would rewrite that word everywhere it is meant.
    /// - **Two or three words in a row**, inside one sentence, whose letters together
    ///   are the learned word or sound like it (`SpellingSimilarity.spanMatches`). Each
    ///   of them may be an ordinary word: `her mes` is how `hermes` gets split.
    ///
    /// ### What does not count (decided 2026-10-16)
    ///
    /// The learned word itself, written right. That is the `dictus` case from the
    /// device trial: a word the engine already spells correctly needs no entry. Those
    /// occurrences are read for one thing only, the capitalisation of the term.
    func pairedSuggestions(_ tokenized: [(record: TranscriptionRecord, tokens: [Token])],
                           learnedWords: [String],
                           excluded: Set<String>,
                           ignored: Set<String>,
                           cache knownCache: inout [String: Bool]) -> [VocabularySuggestion] {
        let learned = Self.usableLearnedWords(learnedWords, ignored: ignored)
        guard !learned.isEmpty else { return [] }
        let learnedSet = Set(learned)
        var bySkeleton: [String: String] = [:]
        var byKey: [String: String] = [:]
        // Sorted input, first writer wins: two learned words sharing a key resolve the
        // same way on every run.
        for word in learned {
            if bySkeleton[SpellingSimilarity.skeleton(word)] == nil { bySkeleton[SpellingSimilarity.skeleton(word)] = word }
            if byKey[SpellingSimilarity.phoneticKey(word)] == nil { byKey[SpellingSimilarity.phoneticKey(word)] = word }
        }

        var tallies: [String: PairTally] = [:]
        var singleMatches: [String: String?] = [:]

        for (record, tokens) in tokenized {
            for (index, token) in tokens.enumerated() {
                if let exact = Self.learnedWord(writtenBy: token.text, in: learnedSet) {
                    tallies[exact, default: PairTally(learned: exact)]
                        .recordExact(token.text, isSentenceInitial: token.isSentenceInitial)
                    continue
                }

                if let word = candidateWord(token.text, cache: &knownCache),
                   !excluded.contains(Self.fold(word)),
                   !learnedSet.contains(word.lowercased()) {
                    if singleMatches[word] == nil {
                        singleMatches[word] = Self.closestLearnedWord(to: word, in: learned)
                    }
                    // Flattened: the cache holds "no match" as a stored nil.
                    if let target = singleMatches[word].flatMap({ $0 }) {
                        tallies[target, default: PairTally(learned: target)]
                            .add(variant: word, record: record.id, date: record.createdAt)
                    }
                }

                for length in 2...Self.longestSpan where index + length <= tokens.count {
                    let parts = tokens[index..<index + length]
                    // A span stops at a sentence boundary, at a digit, and at the learned
                    // word itself: `hermes mes` is the word written right, then a word.
                    if parts.dropFirst().contains(where: \.isSentenceInitial) { break }
                    if parts.contains(where: { $0.text.contains(where: \.isNumber) }) { break }
                    if parts.contains(where: { Self.learnedWord(writtenBy: $0.text, in: learnedSet) != nil }) { break }
                    let surface = parts.map(\.text).joined(separator: " ")
                    guard !excluded.contains(Self.fold(surface)) else { continue }
                    let target = bySkeleton[SpellingSimilarity.skeleton(surface)]
                        ?? byKey[SpellingSimilarity.phoneticKey(surface)]
                    guard let target, SpellingSimilarity.spanMatches(surface, learned: target) else { continue }
                    tallies[target, default: PairTally(learned: target)]
                        .add(variant: surface, record: record.id, date: record.createdAt)
                }
            }
        }

        return tallies.values
            .filter { !$0.records.isEmpty }
            .map(\.suggestion)
            .sorted(by: Self.ranksBefore)
    }

    /// The learned words worth pairing: composed, lowercase, at least three letters,
    /// no digit, not ignored. Sorted, so every run reads them in the same order.
    static func usableLearnedWords(_ words: [String], ignored: Set<String>) -> [String] {
        let usable = words.map { $0.precomposedStringWithCanonicalMapping.lowercased() }
            .filter { word in
                SpellingSimilarity.skeleton(word).count >= minimumLength
                    && !word.contains(where: \.isNumber)
                    && !ignored.contains(pairedIDPrefix + word)
            }
        return Array(Set(usable)).sorted()
    }

    /// The learned word a token writes exactly, ignoring case, with or without an
    /// elided article in front (`l'hermes`).
    static func learnedWord(writtenBy text: String, in learned: Set<String>) -> String? {
        let lower = text.lowercased()
        if learned.contains(lower) { return lower }
        let apostrophes: Set<Character> = ["'", "\u{2019}"]
        guard let index = lower.firstIndex(where: { apostrophes.contains($0) }),
              elisionPrefixes.contains(String(lower[..<index])) else { return nil }
        let tail = String(lower[lower.index(after: index)...])
        return learned.contains(tail) ? tail : nil
    }

    /// The learned word `candidate` is a spelling of, closest first, or nil.
    static func closestLearnedWord(to candidate: String, in learned: [String]) -> String? {
        var best: (word: String, score: Int)?
        for word in learned {
            guard let score = SpellingSimilarity.pairScore(candidate: candidate, learned: word) else { continue }
            if best == nil || score < (best?.score ?? .max) { best = (word, score) }
        }
        return best?.word
    }

    /// What History says about one learned word.
    struct PairTally {
        let learned: String
        private(set) var variantCounts: [String: (spelling: String, count: Int)] = [:]
        private(set) var records: Set<UUID> = []
        private(set) var occurrences = 0
        private(set) var lastSeen = Date.distantPast
        /// The learned word written right, by surface form, mid-sentence only: a capital
        /// at the start of a sentence says nothing about the word.
        private(set) var exactSurfaces: [String: Int] = [:]

        init(learned: String) {
            self.learned = learned
        }

        mutating func add(variant: String, record: UUID, date: Date) {
            let lower = variant.lowercased()
            let existing = variantCounts[lower]
            variantCounts[lower] = (
                Tally.preferredSpelling(existing?.spelling, variant), (existing?.count ?? 0) + 1
            )
            records.insert(record)
            occurrences += 1
            lastSeen = max(lastSeen, date)
        }

        mutating func recordExact(_ surface: String, isSentenceInitial: Bool) {
            guard !isSentenceInitial else { return }
            exactSurfaces[surface, default: 0] += 1
        }

        /// The term to prefill: the user's own capitalisation when History has it
        /// mid-sentence (most frequent, then alphabetical), the lowercase learned word
        /// otherwise (decided 2026-10-16).
        var term: String {
            let ranked = exactSurfaces.sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            guard let surface = ranked.first?.key, surface.lowercased() == learned else { return learned }
            return surface
        }

        var suggestion: VocabularySuggestion {
            let forms = variantCounts.values
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.spelling < $1.spelling }
                .map(\.spelling)
            return VocabularySuggestion(
                id: VocabularySuggestionMiner.pairedIDPrefix + learned,
                term: term,
                forms: forms,
                occurrences: occurrences,
                dictationCount: records.count,
                lastSeen: lastSeen,
                looksLikeName: false
            )
        }
    }
}
