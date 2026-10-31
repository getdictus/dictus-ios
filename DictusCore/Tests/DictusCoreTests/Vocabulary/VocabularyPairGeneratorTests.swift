// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularyPairGeneratorTests.swift
// The step 2 pair generator: History spans near a term the user wrote down (#512).
import XCTest
@testable import DictusCore

/// Synthetic texts only: the real pairs come off the maintainer's device and never
/// enter the repository (step 2 brief, decision 5).
final class VocabularyPairGeneratorTests: XCTestCase {

    /// A small stand-in for the dictionaries, compared ignoring case like the app's.
    private static let dictionary: Set<String> = [
        "je", "j'utilise", "utilise", "cloud", "code", "tous", "les", "jours", "le", "est",
        "lent", "il", "a", "dit", "prêt", "on", "en", "parle", "avec", "ai", "appelé",
        "hier", "et", "puis", "ce", "matin", "de", "la", "sur", "mon", "projet", "un",
        "mot", "encore", "une", "fois", "pour", "voir", "si", "ça", "marche", "bien"
    ]

    private let generator = VocabularyPairGenerator { word in
        dictionary.contains(word.lowercased())
    }

    private func record(_ text: String, minutesAgo: Double = 0) -> TranscriptionRecord {
        TranscriptionRecord(
            text: text,
            language: "fr",
            durationSeconds: 5,
            createdAt: Date(timeIntervalSince1970: 1_000_000 - minutesAgo * 60),
            sttProvider: "PK"
        )
    }

    private func entry(_ term: String, _ variants: [String] = ["placeholder-variant"]) throws -> VocabularyEntry {
        try XCTUnwrap(VocabularyEntry(term: term, variants: variants))
    }

    private func pairs(_ texts: [String],
                       terms: [VocabularyEntry] = [],
                       learned: [String] = [],
                       ignored: Set<String> = [],
                       limit: Int = 20) -> [VocabularyPair] {
        generator.pairs(
            from: texts.enumerated().map { record($0.element, minutesAgo: Double($0.offset)) },
            vocabulary: terms,
            learnedWords: learned,
            ignored: ignored,
            limit: limit
        )
    }

    // MARK: - Multi-word canonicals

    func testTwoDictionaryWordsPairWithAMultiWordTerm() throws {
        let result = pairs(["J'utilise cloud code tous les jours."], terms: [try entry("Claude Code")])
        let pair = try XCTUnwrap(result.first)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(pair.canonical, "Claude Code")
        XCTAssertEqual(pair.observed, "cloud code")
        XCTAssertEqual(pair.source, .vocabulary)
        XCTAssertEqual(pair.sentence, "J'utilise cloud code tous les jours.",
                       "the pair carries the sentence it was found in")
    }

    func testATermHeardAsOneWordPairsAndRanksBeforeAnApproximateSpan() throws {
        let result = pairs(
            ["on en parle avec cloud code", "le claudecode est lent"],
            terms: [try entry("Claude Code")]
        )
        XCTAssertEqual(result.map(\.observed), ["claudecode", "cloud code"],
                       "equal letters score 0; two edits score 3, and similarity is the first key")
        XCTAssertEqual(result.map(\.score), [0, 3])
    }

    func testOneOccurrenceGivesOnePairNotOnePerOverlappingSpan() throws {
        let result = pairs(["J'utilise cloud code tous les jours"], terms: [try entry("Claude Code")])
        XCTAssertEqual(result.count, 1, "`cloud code`, `utilise cloud code`, `cloud code tous` are one reading")
        XCTAssertEqual(result.first?.occurrences, 1)
    }

    func testASpanStopsAtTheEndOfASentence() throws {
        XCTAssertEqual(pairs(["Il a dit cloud. Code est prêt"], terms: [try entry("Claude Code")]), [])
    }

    func testASpanStopsAtADigit() throws {
        XCTAssertEqual(pairs(["cloud 3 code"], terms: [try entry("Claude Code")]), [])
    }

    // MARK: - French diacritics

    func testAMissingAccentIsAPair() throws {
        let result = pairs(["J'ai appelé stephane hier"], terms: [try entry("Stéphane")])
        let pair = try XCTUnwrap(result.first)
        XCTAssertEqual(pair.observed, "stephane")
        XCTAssertEqual(pair.score, 0)
    }

    func testTheTermWrittenRightIsNotAPairWhateverItsCaseOrComposition() throws {
        let terms = [try entry("Stéphane"), try entry("Claude Code")]
        XCTAssertEqual(pairs(["J'ai appelé Stéphane hier", "ste\u{0301}phane et claude code"], terms: terms), [],
                       "case only, or a decomposed accent, is the term written right")
    }

    func testAnAccentedVariantOfAnAccentedTermPairs() throws {
        let result = pairs(["on parle de mélanchon ce matin"], terms: [try entry("Mélenchon")])
        XCTAssertEqual(result.map(\.observed), ["mélanchon"])
    }

    // MARK: - Single dictionary words refused

    func testASingleDictionaryWordIsNeverAVariant() throws {
        XCTAssertEqual(pairs(["le cloud est lent"], terms: [try entry("Claude")]), [],
                       "`cloud` → `Claude` would rewrite every cloud")
    }

    func testASingleUnknownWordIsAVariant() throws {
        let result = pairs(["le clode est lent"], terms: [try entry("Claude")])
        XCTAssertEqual(result.map(\.observed), ["clode"])
    }

    func testAnElidedArticleIsStrippedFromTheSpan() throws {
        let result = pairs(["l'airmes est prêt", "d'cloud code"], terms: [try entry("Hermes"), try entry("Claude Code")])
        XCTAssertEqual(Set(result.map(\.observed)), ["airmes", "cloud code"])
    }

    // MARK: - Already-known variants

    func testAVariantAlreadyStoredIsSkippedAndAnotherIsNot() throws {
        let terms = [try entry("Claude Code", ["cloud code"])]
        let result = pairs(["cloud code est lent", "clode code est lent"], terms: terms)
        XCTAssertEqual(result.map(\.observed), ["clode code"])
    }

    func testAVariantOfAnotherEntryIsSkippedToo() throws {
        let terms = [try entry("Claude Code"), try entry("Claude Coda", ["clode code"])]
        let result = pairs(["clode code est lent"], terms: terms)
        XCTAssertEqual(result, [], "a span the user already mapped to a term is not a new pair")
    }

    // MARK: - Ignore list

    func testAnIgnoredFormIsSkippedWhateverItsCaseOrAccents() throws {
        let ignored: Set<String> = [VocabularySuggestionMiner.fold("Cloud Code")]
        XCTAssertEqual(pairs(["cloud code est lent"], terms: [try entry("Claude Code")], ignored: ignored), [])
    }

    func testAnIgnoredLearnedWordIsNotACanonical() {
        let ignored: Set<String> = [VocabularySuggestionMiner.pairedIDPrefix + "hermes"]
        XCTAssertEqual(pairs(["l'airmes est prêt"], learned: ["hermes"], ignored: ignored), [])
    }

    func testAnIgnoredPairIdIsSkipped() throws {
        let terms = [try entry("Claude Code")]
        let pair = try XCTUnwrap(pairs(["cloud code est lent"], terms: terms).first)
        XCTAssertEqual(pairs(["cloud code est lent"], terms: terms, ignored: [pair.id]), [])
    }

    func testTheIgnoreListAsStoredIsHonoured() throws {
        let suiteName = "VocabularyPairGeneratorTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let list = VocabularySuggestionIgnoreList(defaults: defaults)
        let suggestion = VocabularySuggestion(
            id: "learned:hermes", term: "hermes", forms: ["airmes"], occurrences: 1,
            dictationCount: 1, lastSeen: Date(), looksLikeName: false
        )
        list.ignore(suggestion)
        XCTAssertEqual(pairs(["l'airmes est prêt"], terms: [try entry("Hermès")], ignored: list.keys), [],
                       "a form ignored in step 1's sheet stays ignored here")
    }

    // MARK: - Canonical sources

    func testLearnedWordsAreCanonicalsToo() throws {
        let pair = try XCTUnwrap(pairs(["l'airmes est prêt"], learned: ["Hermes"]).first)
        XCTAssertEqual(pair.canonical, "hermes", "the keyboard stores learned words lowercase")
        XCTAssertEqual(pair.source, .learned)
    }

    func testAVocabularyTermWinsOverTheSameLearnedWord() throws {
        let result = pairs(["l'airmes est prêt"], terms: [try entry("Hermès")], learned: ["hermes"])
        XCTAssertEqual(result.map(\.canonical), ["Hermès"])
        XCTAssertEqual(result.map(\.source), [.vocabulary])
    }

    func testNoCanonicalMeansNoPair() {
        XCTAssertEqual(pairs(["cloud code et clode"]), [])
    }

    // MARK: - Counting, ranking, excerpts

    func testCountsDictationsAndKeepsTheNewestSentence() throws {
        let result = pairs(
            ["cloud code puis cloud code", "voir si cloud code marche bien"],
            terms: [try entry("Claude Code")]
        )
        let pair = try XCTUnwrap(result.first)
        XCTAssertEqual(pair.occurrences, 3)
        XCTAssertEqual(pair.dictationCount, 2)
        XCTAssertEqual(pair.sentence, "cloud code puis cloud code", "the first text is the newest record")
    }

    func testMoreDictationsBreakASimilarityTie() throws {
        let result = pairs(["ermes et puis", "l'airmes est prêt", "l'airmes est lent"], terms: [try entry("Hermes")])
        XCTAssertEqual(result.map(\.score), [1, 1], "both sound like the term")
        XCTAssertEqual(result.map(\.observed), ["airmes", "ermes"], "two dictations before one")
    }

    func testALongSentenceIsCutAroundTheSpan() throws {
        let filler = Array(repeating: "mot", count: 20).joined(separator: " ")
        let result = pairs(["\(filler) cloud code \(filler)."], terms: [try entry("Claude Code")])
        let sentence = try XCTUnwrap(result.first?.sentence)
        let twelve = Array(repeating: "mot", count: 12).joined(separator: " ")
        XCTAssertEqual(sentence, "… \(twelve) cloud code \(twelve) …")
    }

    func testTheExcerptIsOneLine() throws {
        let result = pairs(["cloud code   est\tlent"], terms: [try entry("Claude Code")])
        XCTAssertEqual(result.first?.sentence, "cloud code est lent")
    }

    func testTheLimitCapsTheList() throws {
        let texts = ["clode", "claudy", "klode", "clodo"]
        XCTAssertEqual(pairs(texts, terms: [try entry("Claude")], limit: 2).count, 2)
    }

    func testTheResultIsDeterministic() throws {
        let terms = [try entry("Claude Code"), try entry("Hermes")]
        let texts = ["l'airmes est prêt", "her mes et cloud code", "clode code"]
        XCTAssertEqual(pairs(texts, terms: terms), pairs(texts, terms: terms))
    }

    // MARK: - The score

    func testSpanScoreRefusesTwoShortWordsJoined() {
        XCTAssertNil(SpellingSimilarity.spanScore("de la", canonical: "Dela", wordCount: 2))
    }

    func testSpanScoreOfTheMotivatingCase() {
        XCTAssertEqual(SpellingSimilarity.spanScore("cloud code", canonical: "Claude Code", wordCount: 2), 3)
        XCTAssertNil(SpellingSimilarity.spanScore("cloud", canonical: "Claude Code", wordCount: 1))
    }
}
