// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularyPairSuggestionsTests.swift
// What the app offers from the pair generator: thresholds, ranking, cap (#512, step 2 UI).
import XCTest
@testable import DictusCore

/// Synthetic texts only, as for the generator's own tests.
final class VocabularyPairSuggestionsTests: XCTestCase {

    private static let dictionary: Set<String> = [
        "cloud", "code", "est", "lent", "le", "encore", "on", "parle", "de", "avec", "et"
    ]

    private let generator = VocabularyPairGenerator { word in
        dictionary.contains(word.lowercased())
    }

    private func entry(_ term: String, _ variants: [String] = ["placeholder-variant"]) throws -> VocabularyEntry {
        try XCTUnwrap(VocabularyEntry(term: term, variants: variants))
    }

    private func suggestions(_ texts: [String],
                             terms: [VocabularyEntry],
                             ignored: Set<String> = []) -> [VocabularyPair] {
        let records = texts.enumerated().map { index, text in
            TranscriptionRecord(
                text: text,
                language: "fr",
                durationSeconds: 5,
                createdAt: Date(timeIntervalSince1970: 1_000_000 - Double(index) * 60),
                sttProvider: "PK"
            )
        }
        return generator.suggestions(from: records, vocabulary: terms, ignored: ignored)
    }

    // MARK: - Thresholds

    func testTheMotivatingCaseIsOfferedOnceSeenTwice() throws {
        let result = suggestions(["cloud code est lent", "on parle de cloud code"], terms: [try entry("Claude Code")])
        let pair = try XCTUnwrap(result.first)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(pair.canonical, "Claude Code")
        XCTAssertEqual(pair.observed, "cloud code")
        XCTAssertEqual(pair.score, VocabularyPairGenerator.suggestionMaxScore, "two edits: the loosest score offered")
        XCTAssertEqual(pair.dictationCount, 2)
    }

    func testASpanSeenInOneDictationIsNotOffered() throws {
        let terms = [try entry("Claude Code")]
        XCTAssertEqual(suggestions(["cloud code est lent, cloud code encore"], terms: terms), [],
                       "two occurrences in one dictation are still one dictation")
        XCTAssertEqual(
            generator.pairs(from: [TranscriptionRecord(text: "cloud code est lent", language: "fr",
                                                      durationSeconds: 5, sttProvider: "PK")],
                            vocabulary: terms, ignored: []).count,
            1, "the generator itself still finds it"
        )
    }

    func testAPairThreeEditsAwayIsNotOffered() throws {
        // Twelve letters allow three edits in `spanScore`, which the app does not offer.
        XCTAssertEqual(SpellingSimilarity.spanScore("kentrabolixumrtv", canonical: "Kentrabolixum", wordCount: 1), 4)
        let result = suggestions(["kentrabolixumrtv est lent", "kentrabolixumrtv encore"],
                                 terms: [try entry("Kentrabolixum")])
        XCTAssertEqual(result, [])
    }

    func testLearnedWordsAreNotCanonicalsHere() throws {
        let records = ["l'airmes est lent", "airmes encore"].map {
            TranscriptionRecord(text: $0, language: "fr", durationSeconds: 5, sttProvider: "PK")
        }
        XCTAssertEqual(generator.pairs(from: records, vocabulary: [], learnedWords: ["hermes"], ignored: []).count, 1)
        XCTAssertEqual(generator.suggestions(from: records, vocabulary: [], ignored: []), [],
                       "learned words stay with step 1's paired section")
    }

    // MARK: - Ranking and cap

    func testClosestFirstThenMoreDictations() throws {
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

    func testTheListIsCappedAtFive() throws {
        let names = ["Zorvalix", "Kentrabo", "Plimdora", "Quastemi", "Brunzeta", "Vothrami", "Dashkelo"]
        let terms = try names.map { try entry($0) }
        // Each name misheard with its last letter doubled: one edit, an unknown word.
        let texts = names.flatMap { name in
            let heard = name.lowercased() + String(name.last ?? "a")
            return ["\(heard) est lent", "\(heard) encore"]
        }
        let result = suggestions(texts, terms: terms)
        XCTAssertEqual(result.count, VocabularyPairGenerator.suggestionLimit)
        XCTAssertEqual(result, Array(generator.pairs(
            from: texts.enumerated().map { index, text in
                TranscriptionRecord(text: text, language: "fr", durationSeconds: 5,
                                    createdAt: Date(timeIntervalSince1970: 1_000_000 - Double(index) * 60),
                                    sttProvider: "PK")
            },
            vocabulary: terms, ignored: []
        ).prefix(5)), "the first five of the generator's own order")
    }

    // MARK: - After Accept and Ignore

    func testAnAcceptedVariantIsNotOfferedAgain() throws {
        let texts = ["cloud code est lent", "cloud code encore"]
        let term = try entry("Claude Code", ["clode code"])
        let pair = try XCTUnwrap(suggestions(texts, terms: [term]).first)
        let accepted = term.addingVariants([pair.observed])
        XCTAssertEqual(accepted.variants, ["clode code", "cloud code"])
        XCTAssertEqual(suggestions(texts, terms: [accepted]), [])
    }

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
