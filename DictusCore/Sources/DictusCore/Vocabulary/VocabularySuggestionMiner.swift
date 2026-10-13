// DictusCore/Sources/DictusCore/Vocabulary/VocabularySuggestionMiner.swift
// Words in the History that Dictus may be getting wrong, ranked for review (#512 trial).
import Foundation

/// One word the History suggests adding to the vocabulary (#512).
///
/// The forms are the evidence: what the engine actually wrote. They become the
/// variants of the entry the user creates on **Accept**, and the user types the
/// correct spelling, exactly as with a selection in History (#723). The miner never
/// proposes a canonical spelling: it has no way of knowing it.
public struct VocabularySuggestion: Identifiable, Equatable, Sendable {

    /// The folded form of the group's leading spelling. Stable across two runs over
    /// the same History, which is what SwiftUI's list identity needs.
    public let id: String

    /// The spellings seen, distinct ignoring case, most frequent first.
    public let forms: [String]

    /// How many times any of the forms appears, across all dictations.
    public let occurrences: Int

    /// How many dictations contain at least one of the forms. The ranking key.
    public let dictationCount: Int

    /// When the newest dictation containing a form was made.
    public let lastSeen: Date

    /// Every occurrence reads as a correctly written name: capitalised mid-sentence,
    /// or an acronym, and never in lowercase. Such a group is ranked after the others
    /// (the known risk of this trial: a name the engine spells right is not a
    /// mistake).
    public let looksLikeName: Bool

    /// The forms as the add sheet's variants line.
    public var variantsLine: String {
        forms.joined(separator: ", ")
    }
}

/// The deterministic miner behind **Suggestions from History** (#512, 2.0.0 trial).
///
/// ### What the trial is, and is not
///
/// The slice decided on 2026-10-12: History only, no model, no recognition biasing.
/// A word is a candidate when it is **not a dictionary word**, not part of a URL or an
/// e-mail address, carries no digit, is not already in the vocabulary, and was not
/// ignored. Near spellings are grouped, the groups counted, and the ones seen in at
/// least two dictations ranked. Everything else on #512's body waits for 2.1.
///
/// ### Why the dictionary is injected
///
/// The only dictionary the app process can ask is `UITextChecker`, which is UIKit and
/// unavailable to `swift test`. The predicate keeps this type pure, and lets the
/// tests say exactly which words count as known.
///
/// ### Why History text works at all
///
/// A record holds the text after the vocabulary pass, so a variant the user already
/// taught Dictus never shows up, and its term does. That is why the exclusion below
/// covers terms as well as variants.
public struct VocabularySuggestionMiner {

    /// A word seen in only one dictation is not a pattern: a vocabulary entry fixes
    /// a mistake that comes back, and a one-off is far more often a name said once.
    public static let minimumDictations = 2

    /// Shorter tokens are interjections, initials and elided articles far more often
    /// than technical terms, and edit distance means nothing at that length.
    public static let minimumLength = 3

    /// The trial's go/no-go reads the top ten (#512, 2026-10-12): the sheet shows
    /// that many, and refills as the user accepts or ignores.
    public static let defaultLimit = 10

    /// French elided articles and pronouns: `l'parakit` is the word `parakit`.
    static let elisionPrefixes: Set<String> = [
        "l", "d", "j", "m", "n", "s", "t", "c", "qu", "jusqu", "lorsqu", "puisqu"
    ]

    private let isKnownWord: (String) -> Bool

    /// - Parameter isKnownWord: whether a word is in a dictionary the user's
    ///   languages use. Called once per distinct spelling, after every cheaper
    ///   filter, so its cost scales with the unusual words and not with the text.
    public init(isKnownWord: @escaping (String) -> Bool) {
        self.isKnownWord = isKnownWord
    }

    /// The ranked suggestions for this History.
    ///
    /// - Parameters:
    ///   - records: the History, any order.
    ///   - vocabulary: every stored entry, switched on or off: a term the user
    ///     already wrote down is not a suggestion, whatever its switch says.
    ///   - ignored: folded spellings the user dismissed (`VocabularySuggestionIgnoreList`).
    ///   - limit: how many to return.
    public func suggestions(from records: [TranscriptionRecord],
                            vocabulary: [VocabularyEntry],
                            ignored: Set<String>,
                            limit: Int = VocabularySuggestionMiner.defaultLimit) -> [VocabularySuggestion] {
        let excluded = Self.vocabularyKeys(vocabulary).union(ignored)
        var knownCache: [String: Bool] = [:]
        var tallies: [String: Tally] = [:]

        for record in records {
            for token in Self.tokens(in: record.text) {
                guard let word = candidateWord(token.text, cache: &knownCache) else { continue }
                let key = Self.fold(word)
                guard !excluded.contains(key) else { continue }
                tallies[key, default: Tally(key: key)].add(
                    form: word,
                    record: record.id,
                    date: record.createdAt,
                    isSentenceInitial: token.isSentenceInitial
                )
            }
        }

        let groups = Self.group(Array(tallies.values))
            .filter { $0.records.count >= Self.minimumDictations }
            .map { $0.suggestion }
        return Array(groups.sorted(by: Self.ranksBefore).prefix(max(0, limit)))
    }

    // MARK: - Filtering one token

    /// The word a token stands for, or nil when it is not a candidate.
    ///
    /// The order matters only for cost: the dictionary is asked last.
    private func candidateWord(_ raw: String, cache: inout [String: Bool]) -> String? {
        guard !raw.contains(where: { $0.isNumber }) else { return nil }
        guard let word = strippedWord(raw, cache: &cache) else { return nil }
        guard word.count >= Self.minimumLength else { return nil }
        guard !known(word, cache: &cache) else { return nil }
        // A compound whose every part is a word (`peut-être`, `Jean-Pierre`) is
        // ordinary text, even when the checker does not list the compound itself.
        let parts = word.split(whereSeparator: { $0 == "-" }).map(String.init)
        if parts.count > 1, parts.allSatisfy({ known($0, cache: &cache) }) { return nil }
        return word
    }

    /// The token without an elided article in front or a possessive behind, when the
    /// whole of it is not itself a word (`aujourd'hui`, `don't`).
    private func strippedWord(_ raw: String, cache: inout [String: Bool]) -> String? {
        let apostrophes: Set<Character> = ["'", "\u{2019}"]
        guard let index = raw.firstIndex(where: { apostrophes.contains($0) }) else { return raw }
        if known(raw, cache: &cache) { return nil }
        let head = String(raw[..<index])
        let tail = String(raw[raw.index(after: index)...])
        if Self.elisionPrefixes.contains(head.lowercased()), !tail.isEmpty { return tail }
        if tail.lowercased() == "s", !head.isEmpty { return head }
        return raw
    }

    private func known(_ word: String, cache: inout [String: Bool]) -> Bool {
        if let hit = cache[word] { return hit }
        let answer = isKnownWord(word)
        cache[word] = answer
        return answer
    }

    // MARK: - Tokenising

    /// A word as it stands in a transcript.
    struct Token: Equatable {
        let text: String
        /// At the start of the text, of a line, or after `.`, `!`, `?` or `…`: a
        /// capital there is the keyboard's or the engine's, not a name's.
        let isSentenceInitial: Bool
    }

    /// The words of a transcript, URLs and e-mail addresses removed.
    ///
    /// A word is a run of letters, digits and combining marks, with an apostrophe or
    /// a hyphen kept when it joins two of them (`aujourd'hui`, `peut-être`). The text
    /// is put in composed form first, so a decomposed `é` from a paste or another
    /// engine counts as the same word.
    static func tokens(in text: String) -> [Token] {
        let clean = removingLinks(from: text.precomposedStringWithCanonicalMapping)
        var tokens: [Token] = []
        var current = ""
        var sentenceInitial = true
        var nextIsSentenceInitial = true
        let joiners: Set<Character> = ["'", "\u{2019}", "-"]

        func flush() {
            while let last = current.last, joiners.contains(last) { current.removeLast() }
            if !current.isEmpty {
                tokens.append(Token(text: current, isSentenceInitial: sentenceInitial))
                nextIsSentenceInitial = false
            }
            current = ""
        }

        for character in clean {
            if character.isLetter || character.isNumber || character.unicodeScalars.allSatisfy({ $0.properties.isGraphemeExtend }) {
                if current.isEmpty { sentenceInitial = nextIsSentenceInitial }
                current.append(character)
            } else if joiners.contains(character), !current.isEmpty {
                current.append(character)
            } else {
                flush()
                if character.isNewline || ".!?…".contains(character) { nextIsSentenceInitial = true }
            }
        }
        flush()
        return tokens
    }

    /// The text with every link and e-mail address replaced by a space.
    ///
    /// `NSDataDetector` rather than a pattern: it knows the top-level domains, so
    /// `dictus.app` goes and `etc.` stays. A detected link is replaced by a space and
    /// not by nothing, so the words on either side stay apart.
    static func removingLinks(from text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return text
        }
        let mutable = NSMutableString(string: text)
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: mutable.length))
        for match in matches.reversed() {
            mutable.replaceCharacters(in: match.range, with: " ")
        }
        return mutable as String
    }

    // MARK: - Keys

    /// The comparison form: case and diacritics folded, so `Parakít`, `parakit` and
    /// `PARAKIT` are one spelling for grouping, exclusion and ignoring.
    public static func fold(_ word: String) -> String {
        word.precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Every word of every term and variant, folded, plus each whole field.
    ///
    /// Word by word because History holds `Parakeet v3` after the replacement pass,
    /// and its token `Parakeet` must not come back as a suggestion.
    static func vocabularyKeys(_ vocabulary: [VocabularyEntry]) -> Set<String> {
        var keys = Set<String>()
        for entry in vocabulary {
            for field in [entry.term] + entry.variants {
                keys.insert(fold(field))
                for token in tokens(in: field) { keys.insert(fold(token.text)) }
            }
        }
        return keys
    }

    // MARK: - Grouping

    /// Whether two folded spellings are close enough to be one word misheard twice.
    ///
    /// One edit up to six characters, two from seven: `parakit` / `parakeet` is two
    /// edits apart, and at that length two edits still leave most of the word.
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

    /// Near spellings joined behind the most frequent one.
    ///
    /// Leader-based rather than transitive on purpose: with chaining, `abcd` - `abce`
    /// - `abfe` would pull two unrelated words into one group through the middle one.
    /// Each spelling joins the first leader it is near, in rank order, or leads its own
    /// group. The order is fully determined, so two runs give the same groups.
    static func group(_ tallies: [Tally]) -> [Tally] {
        let ordered = tallies.sorted { lhs, rhs in
            if lhs.records.count != rhs.records.count { return lhs.records.count > rhs.records.count }
            if lhs.occurrences != rhs.occurrences { return lhs.occurrences > rhs.occurrences }
            return lhs.key < rhs.key
        }
        var leaders: [Tally] = []
        for tally in ordered {
            if let index = leaders.firstIndex(where: { areNearSpellings($0.key, tally.key) }) {
                leaders[index].absorb(tally)
            } else {
                leaders.append(tally)
            }
        }
        return leaders
    }

    // MARK: - Ranking

    /// Words that do not look like names first; then more dictations, more spellings,
    /// more occurrences, more recent, and the spelling itself as the last tie-break.
    static func ranksBefore(_ lhs: VocabularySuggestion, _ rhs: VocabularySuggestion) -> Bool {
        if lhs.looksLikeName != rhs.looksLikeName { return !lhs.looksLikeName }
        if lhs.dictationCount != rhs.dictationCount { return lhs.dictationCount > rhs.dictationCount }
        if lhs.forms.count != rhs.forms.count { return lhs.forms.count > rhs.forms.count }
        if lhs.occurrences != rhs.occurrences { return lhs.occurrences > rhs.occurrences }
        if lhs.lastSeen != rhs.lastSeen { return lhs.lastSeen > rhs.lastSeen }
        return lhs.id < rhs.id
    }

    // MARK: - Counting

    /// What the History says about one folded spelling, then about one group.
    struct Tally {
        let key: String
        /// Count per surface spelling, keyed by its lowercased form so `Parakit` at
        /// the start of a sentence and `parakit` in the middle are one form.
        private(set) var formCounts: [String: (spelling: String, count: Int)] = [:]
        private(set) var records: Set<UUID> = []
        private(set) var occurrences = 0
        private(set) var lastSeen = Date.distantPast
        private(set) var hasLowercase = false
        private(set) var hasNameLikeCapital = false

        init(key: String) {
            self.key = key
        }

        mutating func add(form: String, record: UUID, date: Date, isSentenceInitial: Bool) {
            let lower = form.lowercased()
            let existing = formCounts[lower]
            formCounts[lower] = (Self.preferredSpelling(existing?.spelling, form), (existing?.count ?? 0) + 1)
            records.insert(record)
            occurrences += 1
            lastSeen = max(lastSeen, date)
            if form == lower {
                hasLowercase = true
            } else if ProperNounGuard.isLikelyProperNoun(word: form, isAtSentenceStart: isSentenceInitial) {
                hasNameLikeCapital = true
            }
        }

        mutating func absorb(_ other: Tally) {
            for (lower, entry) in other.formCounts {
                let existing = formCounts[lower]
                formCounts[lower] = (Self.preferredSpelling(existing?.spelling, entry.spelling), (existing?.count ?? 0) + entry.count)
            }
            records.formUnion(other.records)
            occurrences += other.occurrences
            lastSeen = max(lastSeen, other.lastSeen)
            hasLowercase = hasLowercase || other.hasLowercase
            hasNameLikeCapital = hasNameLikeCapital || other.hasNameLikeCapital
        }

        /// Which of two spellings that differ only by case a form is shown as: the
        /// lowercase one when there is one, since a capital is often only the start of
        /// a sentence, and the first seen otherwise.
        static func preferredSpelling(_ existing: String?, _ candidate: String) -> String {
            guard let existing else { return candidate }
            if existing != existing.lowercased(), candidate == candidate.lowercased() { return candidate }
            return existing
        }

        var suggestion: VocabularySuggestion {
            let forms = formCounts.values
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.spelling < $1.spelling }
                .map(\.spelling)
            return VocabularySuggestion(
                id: key,
                forms: forms,
                occurrences: occurrences,
                dictationCount: records.count,
                lastSeen: lastSeen,
                looksLikeName: hasNameLikeCapital && !hasLowercase
            )
        }
    }
}
