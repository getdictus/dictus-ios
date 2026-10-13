// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularySuggestionMinerTests.swift
// The deterministic miner behind the vocabulary suggestions (#512 trial).
import XCTest
@testable import DictusCore

final class VocabularySuggestionMinerTests: XCTestCase {

    /// A small stand-in for the dictionaries, compared ignoring case like the app's.
    private static let dictionary: Set<String> = [
        "je", "teste", "avec", "le", "modèle", "on", "a", "parlé", "de", "aujourd'hui",
        "peut-être", "et", "sur", "voir", "écrit", "the", "meeting", "about", "is", "en",
        "pierre", "jean", "café", "réunion", "demain", "nouveau", "projet", "chez", "pour"
    ]

    private let miner = VocabularySuggestionMiner { word in
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

    private func mine(_ texts: [String],
                      vocabulary: [VocabularyEntry] = [],
                      ignored: Set<String> = [],
                      limit: Int = 10) -> [VocabularySuggestion] {
        miner.suggestions(
            from: texts.enumerated().map { record($0.element, minutesAgo: Double($0.offset)) },
            vocabulary: vocabulary,
            ignored: ignored,
            limit: limit
        )
    }

    // MARK: - What is dropped

    func testDictionaryWordsAreDropped() {
        let result = mine(["Je teste avec le modèle parakit", "On a parlé de parakit"])
        XCTAssertEqual(result.map(\.forms), [["parakit"]])
    }

    func testUrlsAndEmailAddressesAreDropped() {
        let result = mine([
            "voir https://zorgblat.example.com/page et zorgblat@mail.fr",
            "voir www.zorgblat.io et dictus.app"
        ])
        XCTAssertEqual(result, [], "a word that only ever appears inside a link is not a suggestion")
    }

    func testTokensWithDigitsAreDropped() {
        XCTAssertEqual(mine(["le gpt4 et 2026 et v3", "le gpt4 et 2026 et v3"]), [])
    }

    func testShortTokensAreDropped() {
        XCTAssertEqual(mine(["hm zz", "hm zz"]), [])
    }

    func testOrdinaryWordsWithApostrophesAndHyphensAreDropped() {
        XCTAssertEqual(mine(["aujourd'hui peut-être", "aujourd’hui Jean-Pierre"]), [])
    }

    func testAnElidedArticleIsStrippedBeforeChecking() {
        let result = mine(["le modèle d'parakit", "l’parakit écrit"])
        XCTAssertEqual(result.map(\.forms), [["parakit"]])
        XCTAssertEqual(result.first?.dictationCount, 2)
    }

    // MARK: - Existing vocabulary and ignored spellings

    func testTermsAndVariantsAlreadyStoredAreExcluded() throws {
        let entry = try XCTUnwrap(VocabularyEntry(term: "Parakeet v3", variants: ["parakit"]))
        let result = mine(
            ["Parakeet est écrit parakit et zorgblat", "Parakeet et parakit et zorgblat"],
            vocabulary: [entry]
        )
        XCTAssertEqual(result.map(\.forms), [["zorgblat"]],
                       "each word of a multi-word term, and every variant, is already the user's")
    }

    func testASwitchedOffEntryIsExcludedToo() throws {
        let entry = try XCTUnwrap(VocabularyEntry(term: "Zorgblat", isEnabled: false))
        XCTAssertEqual(mine(["zorgblat", "zorgblat"], vocabulary: [entry]), [])
    }

    func testIgnoredSpellingsAreExcludedWhateverTheirCaseOrAccents() {
        let ignored: Set<String> = [VocabularySuggestionMiner.fold("parakit")]
        let result = mine(["Parakít zorgblat", "parakit zorgblat"], ignored: ignored)
        XCTAssertEqual(result.map(\.forms), [["zorgblat"]])
    }

    func testIgnoreListRemembersEveryFormOfASuggestion() throws {
        let suiteName = "VocabularySuggestionIgnoreListTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let list = VocabularySuggestionIgnoreList(defaults: defaults)

        let suggestion = try XCTUnwrap(mine(["parakit", "Parakeat", "parakit"]).first)
        list.ignore(suggestion)

        let reread = VocabularySuggestionIgnoreList(defaults: defaults)
        XCTAssertTrue(reread.keys.isSuperset(of: ["parakit", "parakeat"]))
        XCTAssertEqual(mine(["parakit", "parakeat", "Parakit"], ignored: reread.keys), [])
    }

    // MARK: - Grouping and counting

    func testNearSpellingsAreGroupedBehindTheMostFrequent() throws {
        let result = mine(["parakit", "parakit", "parakeet", "Parakit"])
        let group = try XCTUnwrap(result.first)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(group.forms, ["parakit", "parakeet"])
        XCTAssertEqual(group.occurrences, 4)
        XCTAssertEqual(group.dictationCount, 4)
    }

    func testDistantSpellingsAreNotGrouped() {
        let result = mine(["zorgblat kwimbo", "zorgblat kwimbo"])
        XCTAssertEqual(Set(result.map(\.forms)), [["zorgblat"], ["kwimbo"]])
    }

    func testGroupingDoesNotChainThroughAMiddleSpelling() {
        // `kwab` is one edit from `kwob` and from `kwac`, which is two from `kwob`.
        // `kwab` joins the leader `kwob`; `kwac` must not follow it in through `kwab`.
        let result = mine(["kwob kwab kwac", "kwob kwab kwac", "kwob"])
        XCTAssertEqual(result.map(\.forms), [["kwob", "kwab"], ["kwac"]])
    }

    func testCountsDictationsAndOccurrencesSeparately() throws {
        let result = mine(["zorgblat zorgblat zorgblat", "zorgblat"])
        let group = try XCTUnwrap(result.first)
        XCTAssertEqual(group.occurrences, 4)
        XCTAssertEqual(group.dictationCount, 2)
    }

    func testAWordFromASingleDictationIsNotSuggested() {
        XCTAssertEqual(mine(["zorgblat zorgblat zorgblat", "rien"]), [])
    }

    // MARK: - French diacritics

    func testDiacriticsAreKeptInTheFormsAndFoldedForGrouping() throws {
        let result = mine(["Airmès est là", "airmes demain", "airmès encore"])
        let group = try XCTUnwrap(result.first)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(Set(group.forms), ["airmès", "airmes"])
        XCTAssertEqual(group.dictationCount, 3)
    }

    func testDecomposedAccentsCountAsTheSameWord() throws {
        let decomposed = "airme\u{0300}s"
        let result = mine(["airmès", decomposed])
        let group = try XCTUnwrap(result.first)
        XCTAssertEqual(group.forms, ["airmès"])
        XCTAssertEqual(group.dictationCount, 2)
    }

    func testAnAccentedDictionaryWordIsDroppedWhateverItsForm() {
        XCTAssertEqual(mine(["réunion café", "re\u{0301}union cafe\u{0301}"]), [])
    }

    // MARK: - Ranking

    func testMoreDictationsRankFirst() {
        let result = mine(["zorgblat kwimbo", "zorgblat kwimbo", "zorgblat"])
        XCTAssertEqual(result.map(\.forms.first), ["zorgblat", "kwimbo"])
    }

    func testWordsThatLookLikeCorrectNamesRankLast() throws {
        // `Zorgblat` is only ever capitalised mid-sentence: a name the engine likely
        // spells right. `kwimbo` is lowercase, which a name almost never is.
        let result = mine([
            "avec Zorgblat et kwimbo", "pour Zorgblat", "chez Zorgblat et kwimbo"
        ])
        XCTAssertEqual(result.map(\.forms.first), ["kwimbo", "Zorgblat"])
        XCTAssertEqual(result.last?.looksLikeName, true)
        XCTAssertEqual(result.first?.looksLikeName, false)
    }

    func testACapitalAtTheStartOfASentenceDoesNotMakeAName() throws {
        let result = mine(["Zorgblat est là", "Bien. Zorgblat encore"])
        XCTAssertEqual(result.first?.looksLikeName, false)
    }

    func testTheLimitCapsTheList() {
        let words = ["zorgblat", "kwimbo", "flurtax", "brompel"]
        let texts = Array(repeating: words.joined(separator: " "), count: 2)
        XCTAssertEqual(mine(texts, limit: 3).count, 3)
        XCTAssertEqual(mine(texts).count, 4)
    }

    func testTheResultIsDeterministic() {
        let texts = ["zorgblat kwimbo flurtax", "kwimbo flurtax zorgblat", "flurtax"]
        XCTAssertEqual(mine(texts), mine(texts))
    }

    // MARK: - Tokenising

    func testTokensMarkTheStartOfEachSentence() {
        let tokens = VocabularySuggestionMiner.tokens(in: "Un deux. Trois\nquatre")
        XCTAssertEqual(tokens.map(\.isSentenceInitial), [true, false, true, true])
    }

    func testTheDictionaryIsAskedOncePerSpelling() {
        var calls = 0
        let counting = VocabularySuggestionMiner { word in
            calls += 1
            return Self.dictionary.contains(word.lowercased())
        }
        _ = counting.suggestions(
            from: Array(repeating: record("zorgblat teste zorgblat teste"), count: 5),
            vocabulary: [],
            ignored: []
        )
        XCTAssertEqual(calls, 2, "one call for `zorgblat`, one for `teste`")
    }
}
