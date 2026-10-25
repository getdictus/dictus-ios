// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularyPairSuggestionsTests.swift
// What the app offers from the pair generator: sources, thresholds, ranking, cap,
// the one-word-one-rule exclusion, and what Accept stores (#512, step 2 UI).
import XCTest
@testable import DictusCore

/// Synthetic texts only, as for the generator's own tests.
final class VocabularyPairSuggestionsTests: XCTestCase {

    private static let dictionary: Set<String> = [
        "cloud", "code", "est", "lent", "le", "encore", "on", "parle", "de", "avec", "et",
        "grok", "boat", "dick", "thus", "whisper", "kid",
        "je", "me", "demande", "si", "ça", "marche", "crois", "super", "teste", "fall", "the", "is", "slow"
    ]

    private static let isKnown: (String) -> Bool = { dictionary.contains($0.lowercased()) }

    private let generator = VocabularyPairGenerator(isKnownWord: VocabularyPairSuggestionsTests.isKnown)

    private func entry(_ term: String, _ variants: [String] = ["placeholder-variant"]) throws -> VocabularyEntry {
        try XCTUnwrap(VocabularyEntry(term: term, variants: variants))
    }

    /// One record per text, the first the newest.
    private func records(_ texts: [String]) -> [TranscriptionRecord] {
        texts.enumerated().map { index, text in
            TranscriptionRecord(
                text: text,
                language: "fr",
                durationSeconds: 5,
                createdAt: Date(timeIntervalSince1970: 1_000_000 - Double(index) * 60),
                sttProvider: "PK"
            )
        }
    }

    private func suggestions(_ texts: [String],
                             terms: [VocabularyEntry] = [],
                             learned: [String] = [],
                             stepOne: [VocabularySuggestion] = [],
                             ignored: Set<String> = []) -> [VocabularyPair] {
        generator.suggestions(from: records(texts), vocabulary: terms, learnedWords: learned,
                              stepOne: stepOne, ignored: ignored)
    }

    // MARK: - Thresholds

    func testTheMotivatingCaseIsOfferedOnceSeenTwice() throws {
        let result = suggestions(["cloud code est lent", "on parle de cloud code"], terms: [try entry("Claude Code")])
        let pair = try XCTUnwrap(result.first)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(pair.canonical, "Claude Code")
        XCTAssertEqual(pair.observed, "cloud code")
        XCTAssertEqual(pair.source, .vocabulary)
        XCTAssertEqual(pair.score, VocabularyPairGenerator.suggestionMaxScore, "two edits: the loosest score offered")
        XCTAssertEqual(pair.dictationCount, 2)
    }

    func testASpanSeenInOneDictationIsNotOffered() throws {
        let terms = [try entry("Claude Code")]
        XCTAssertEqual(suggestions(["cloud code est lent, cloud code encore"], terms: terms), [],
                       "two occurrences in one dictation are still one dictation")
        XCTAssertEqual(generator.pairs(from: records(["cloud code est lent"]), vocabulary: terms, ignored: []).count,
                       1, "the generator itself still finds it")
    }

    func testAPairThreeEditsAwayIsNotOffered() throws {
        // Twelve letters allow three edits in `spanScore`, which the app does not offer.
        XCTAssertEqual(SpellingSimilarity.spanScore("kentrabolixumrtv", canonical: "Kentrabolixum", wordCount: 1), 4)
        let result = suggestions(["kentrabolixumrtv est lent", "kentrabolixumrtv encore"],
                                 terms: [try entry("Kentrabolixum")])
        XCTAssertEqual(result, [])
    }

    // MARK: - Where a span starts and stops (device feedback, 2026-10-25)

    func testTheDeviceCaseYieldsNoPair() throws {
        // `superwhisper` was accepted from step 1 with the variant `super whisper`.
        // Step 2 then offered `super whisper je` and `Super Whisper et`, which would
        // have eaten the `je` and the `et` of every later dictation.
        let terms = [try entry("superwhisper", ["super whisper"])]
        let texts = [
            "Je teste super whisper, je me demande si ça marche.",
            "super whisper je crois",
            "Super Whisper et WhisperFlow",
            "Dictus, Super Whisper et Whisper Fall"
        ]
        XCTAssertEqual(suggestions(texts, terms: terms), [])
        let raw = generator.pairs(from: records(texts), vocabulary: terms, ignored: [])
        XCTAssertFalse(raw.contains { $0.observed.lowercased().contains("super whisper") },
                       "no span reaches into a stored variant: \(raw.map(\.observed))")
    }

    func testTheLegitCaseStillPairsAfterTheNewRules() throws {
        let result = suggestions(["cloud code est lent", "on parle de cloud code"], terms: [try entry("Claude Code")])
        XCTAssertEqual(result.map(\.observed), ["cloud code"])
    }

    func testASpanNeverCrossesAComma() throws {
        let terms = [try entry("Claude Code")]
        XCTAssertEqual(suggestions(["cloud, code est lent", "on parle de cloud, code"], terms: terms), [])
        XCTAssertEqual(suggestions(["cloud code, est lent", "cloud code, encore"], terms: terms).map(\.observed),
                       ["cloud code"], "a comma after the span is fine")
    }

    func testASpanNeverStartsOrEndsWithAFunctionWord() throws {
        XCTAssertTrue(VocabularyPairGenerator.edgeWords.isSuperset(of: ["je", "et", "le", "the", "and", "a"]))
        // `le grokbot` and `grokbot the` would score as close as `grokbot` itself.
        let pairs = generator.pairs(from: records(["le grokbott est lent", "grokbott the slow"]), vocabulary: [],
                                    learnedWords: ["grokbot"], ignored: [])
        XCTAssertEqual(pairs.map(\.observed), ["grokbott"])
    }

    func testOneRowPerCanonicalTheBestPair() throws {
        let terms = [try entry("Claude Code")]
        let texts = ["claudecode est lent", "claudecode encore", "cloud code est lent", "cloud code encore"]
        XCTAssertEqual(generator.pairs(from: records(texts), vocabulary: terms, ignored: []).count, 2)
        let result = suggestions(texts, terms: terms)
        XCTAssertEqual(result.map(\.observed), ["claudecode"], "same letters (0) beats two edits (3)")
    }

    // MARK: - Sources

    func testALearnedWordIsASourceForAPairStepOneDoesNotMake() throws {
        let texts = ["grok boat est lent", "on parle de grok boat"]
        let stepOne = VocabularySuggestionMiner(isKnownWord: Self.isKnown)
            .suggestions(from: records(texts), learnedWords: ["grokbot"], vocabulary: [], ignored: [])
        XCTAssertFalse(stepOne.contains(where: \.isPaired), "two dictionary words one edit away: beyond step 1")

        let pair = try XCTUnwrap(suggestions(texts, learned: ["GrokBot"], stepOne: stepOne).first)
        XCTAssertEqual(pair.canonical, "grokbot", "the learned word as the keyboard stores it, lowercase")
        XCTAssertEqual(pair.observed, "grok boat")
        XCTAssertEqual(pair.source, .learned)
    }

    func testHistoryIsNeverASourceOfTheCorrectSpelling() {
        // An unknown word repeated in History, close to another one: no term, no
        // learned word, so nothing to pair it with.
        XCTAssertEqual(suggestions(["zorvalix est lent", "zorvalyx encore", "zorvalix et le reste"]), [])
    }

    // MARK: - One word, one rule

    func testALearnedWordStepOneSuggestsIsNotAPairSource() throws {
        let texts = ["dick thus est lent", "on parle de dick thus"]
        let stepOne = VocabularySuggestionMiner(isKnownWord: Self.isKnown)
            .suggestions(from: records(texts), learnedWords: ["dictus"], vocabulary: [], ignored: [])
        XCTAssertEqual(stepOne.filter(\.isPaired).map(\.id), ["learned:dictus"], "step 1 pairs it itself")

        XCTAssertEqual(suggestions(texts, learned: ["dictus"]).map(\.canonical), ["dictus"],
                       "without the rule, the same word would show twice")
        XCTAssertEqual(suggestions(texts, learned: ["dictus"], stepOne: stepOne), [],
                       "step 1 keeps the word: it is not offered again as a pair")
    }

    func testTheRuleDropsTheWholeWordNotOneSpelling() throws {
        // Step 1 suggests `dictus` from one spelling; the pair list would have found it
        // under another. The word is gone from the pairs either way.
        let stepOne = [VocabularySuggestion(id: "learned:dictus", term: "dictus", forms: ["dictüs"], occurrences: 2,
                                            dictationCount: 2, lastSeen: Date(), looksLikeName: false)]
        XCTAssertEqual(suggestions(["dick thus est lent", "dick thus encore"], learned: ["dictus"], stepOne: stepOne), [])
    }

    func testOnlyStepOnePairedRowsExcludeAWord() throws {
        let historyOnly = VocabularySuggestion(id: "grokbot", term: nil, forms: ["grokbot"], occurrences: 2,
                                               dictationCount: 2, lastSeen: Date(), looksLikeName: false)
        XCTAssertFalse(historyOnly.isPaired)
        let result = suggestions(["grok boat est lent", "grok boat encore"], learned: ["grokbot"], stepOne: [historyOnly])
        XCTAssertEqual(result.map(\.canonical), ["grokbot"])
    }

    // MARK: - Ranking and cap

    func testVocabularyPairsRankBeforeLearnedWordPairsWhateverTheirScore() throws {
        let result = suggestions(
            ["cloud code est lent", "cloud code encore", "whisper kid est lent", "whisper kid encore",
             "whisper kid et le reste"],
            terms: [try entry("Claude Code")],
            learned: ["whisperkit"]
        )
        XCTAssertEqual(result.map(\.observed), ["cloud code", "whisper kid"])
        XCTAssertEqual(result.map(\.source), [.vocabulary, .learned])
        XCTAssertGreaterThan(result[0].score, result[1].score, "the vocabulary pair is the further one, and still first")
    }

    func testWithinASourceClosestFirst() throws {
        let terms = [try entry("Claude Code"), try entry("WhisperKit"), try entry("Hermes")]
        let result = suggestions(
            [
                "cloud code est lent", "cloud code encore", "cloud code et le reste",
                "whisper kit est lent", "whisper kit encore",
                "airmes est lent", "airmes encore"
            ],
            terms: terms
        )
        XCTAssertEqual(result.map(\.observed), ["whisper kit", "airmes", "cloud code"],
                       "equal letters (0), equal sounds (1), then two edits (3), whatever the counts")
        XCTAssertEqual(result.map(\.score), [0, 1, 3])
    }

    func testTheListIsCappedAtTen() throws {
        let names = ["Zorvalix", "Kentrabo", "Plimdora", "Quastemi", "Brunzeta", "Vothrami",
                     "Dashkelo", "Fennobar", "Gristalu", "Holmavek", "Juntrepo", "Lorvessa"]
        let terms = try names.map { try entry($0) }
        // Each name misheard with its last letter doubled: one edit, an unknown word.
        let texts = names.flatMap { name in
            let heard = name.lowercased() + String(name.last ?? "a")
            return ["\(heard) est lent", "\(heard) encore"]
        }
        let result = suggestions(texts, terms: terms)
        XCTAssertEqual(VocabularyPairGenerator.suggestionLimit, 10)
        XCTAssertEqual(result.count, 10)
        XCTAssertEqual(result, Array(generator.pairs(from: records(texts), vocabulary: terms, ignored: []).prefix(10)),
                       "the first ten of the generator's own order")
    }

    // MARK: - Accept

    func testAcceptOnAVocabularyPairAddsTheVariant() throws {
        let texts = ["cloud code est lent", "cloud code encore"]
        let term = try entry("Claude Code", ["clode code"])
        let pair = try XCTUnwrap(suggestions(texts, terms: [term]).first)

        let acceptance = try XCTUnwrap(VocabularyPairAcceptance(pair, vocabulary: [term]))
        XCTAssertEqual(acceptance, .addVariant(term.addingVariants(["cloud code"])))
        XCTAssertEqual(acceptance.entry.id, term.id, "the same entry, not a second one")
        XCTAssertEqual(acceptance.entry.variants, ["clode code", "cloud code"])
        XCTAssertEqual(suggestions(texts, terms: [acceptance.entry]), [], "not offered again once stored")
    }

    func testAcceptOnALearnedWordPairCreatesTheTerm() throws {
        let texts = ["grok boat est lent", "grok boat encore"]
        let pair = try XCTUnwrap(suggestions(texts, learned: ["grokbot"]).first)

        let acceptance = try XCTUnwrap(VocabularyPairAcceptance(pair, vocabulary: []))
        guard case .newTerm(let created) = acceptance else { return XCTFail("expected a new term, got \(acceptance)") }
        XCTAssertEqual(created.term, "grokbot")
        XCTAssertEqual(created.variants, ["grok boat"])
        XCTAssertTrue(created.isEnabled)
        XCTAssertEqual(suggestions(texts, terms: [created], learned: ["grokbot"]), [],
                       "once a term, its variant is known and the word is a vocabulary canonical")
    }

    func testAcceptOnALearnedWordAlreadyATermAddsTheVariant() throws {
        let pair = try XCTUnwrap(suggestions(["grok boat est lent", "grok boat encore"], learned: ["grokbot"]).first)
        let term = try entry("GrokBot", ["grokbott"])
        XCTAssertEqual(VocabularyPairAcceptance(pair, vocabulary: [term]), .addVariant(term.addingVariants(["grok boat"])))
    }

    func testAcceptOnAVocabularyPairWhoseTermWasDeletedStoresNothing() throws {
        let pair = try XCTUnwrap(suggestions(["cloud code est lent", "cloud code encore"],
                                             terms: [try entry("Claude Code")]).first)
        XCTAssertNil(VocabularyPairAcceptance(pair, vocabulary: []))
    }

    // MARK: - Accept with the review sheet's fields edited

    func testEditedFieldsMakeANewTerm() throws {
        let acceptance = try XCTUnwrap(VocabularyPairAcceptance(term: " GrokBot ", variant: "grok bot", vocabulary: []))
        guard case .newTerm(let created) = acceptance else { return XCTFail("expected a new term, got \(acceptance)") }
        XCTAssertEqual(created.term, "GrokBot", "the user's capitals, trimmed")
        XCTAssertEqual(created.variants, ["grok bot"])
    }

    func testAnEditedTermWithOtherCapitalsMergesIntoTheStoredOne() throws {
        let stored = try entry("Claude Code", ["clode code"])
        let acceptance = try XCTUnwrap(VocabularyPairAcceptance(term: "claude CODE", variant: "cloud coat", vocabulary: [stored]))
        XCTAssertEqual(acceptance, .addVariant(stored.addingVariants(["cloud coat"])))
        XCTAssertEqual(acceptance.entry.id, stored.id)
        XCTAssertEqual(acceptance.entry.term, "Claude Code", "the stored spelling is kept")
    }

    func testAnEditWithNoEffectIsRefused() throws {
        let stored = try entry("Claude Code", ["clode code"])
        XCTAssertNil(VocabularyPairAcceptance(term: "Claude Code", variant: "clode code", vocabulary: [stored]),
                     "variant already there")
        XCTAssertNil(VocabularyPairAcceptance(term: "Claude Code", variant: "CLODE CODE", vocabulary: [stored]),
                     "variant already there, other case")
        XCTAssertNil(VocabularyPairAcceptance(term: "Claude Code", variant: "  ", vocabulary: [stored]), "empty variant")
        XCTAssertNil(VocabularyPairAcceptance(term: "grokbot", variant: "grokbot", vocabulary: []), "variant equal to the term")
        XCTAssertNil(VocabularyPairAcceptance(term: "", variant: "grok bot", vocabulary: []), "empty term")
        XCTAssertNil(VocabularyPairAcceptance(term: "grokbot", variant: "", vocabulary: []), "new term with no variant")
    }

    // MARK: - Ignore

    func testAnIgnoredPairStaysIgnored() throws {
        let suiteName = "VocabularyPairSuggestionsTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let list = VocabularySuggestionIgnoreList(defaults: defaults)
        let texts = ["cloud code est lent", "cloud code encore"]
        let terms = [try entry("Claude Code")]

        list.ignore(try XCTUnwrap(suggestions(texts, terms: terms).first))

        let reread = VocabularySuggestionIgnoreList(defaults: defaults)
        XCTAssertEqual(suggestions(texts, terms: terms, ignored: reread.keys), [])
        XCTAssertFalse(reread.keys.contains(VocabularySuggestionMiner.fold("cloud code")),
                       "the span itself is not ignored, only its pairing with this term")
    }
}
