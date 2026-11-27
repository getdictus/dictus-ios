// DictusCore/Tests/DictusCoreTests/SwipeBrandsTests.swift
// Swipe typing reads well-known brand names in their casing (#1090): the list each
// language ships (Wikidata, filtered offline by rule v3) and what a swipe types with it.
import CoreGraphics
import XCTest
@testable import DictusCore

final class SwipeBrandsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDictionary.shared.resetAll()
    }

    override func tearDown() {
        UserDictionary.shared.resetAll()
        super.tearDown()
    }

    private static let languages = ["fr", "en", "es", "de"]

    private static func model(_ language: String) throws -> SpatialDecoderModel {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusKeyboard/Resources/\(language).hextm").path
        return try XCTUnwrap(SpatialDecoderModel(path: path))
    }

    // MARK: - The list

    /// The counts rule v3 leaves (`SwipeBrandList.swift`'s header): a change to the list is
    /// a regenerated list, and its PR says why.
    func testEachLanguageShipsTheListRuleV3Kept() {
        XCTAssertEqual(SwipeBrands.names(for: "fr").count, 74)
        XCTAssertEqual(SwipeBrands.names(for: "en").count, 61)
        XCTAssertEqual(SwipeBrands.names(for: "es").count, 77)
        XCTAssertEqual(SwipeBrands.names(for: "de").count, 65)
        XCTAssertEqual(SwipeBrands.names(for: "it"), [], "a language with no list reads no brand")
    }

    /// Pierre's names, where each model lacks them; and what rule v3 dropped stays out.
    func testTheAskedNamesAreInAndTheDroppedOnesOut() {
        let french = SwipeBrands.names(for: "fr")
        for name in ["Apple", "Google", "Samsung", "Microsoft", "Amazon"] {
            XCTAssertTrue(french.contains(name), name)
        }
        XCTAssertFalse(french.contains("Android"), "rule v3: Android takes « androïde »'s swipes in French")
        XCTAssertFalse(SwipeBrands.names(for: "es").contains("Android"), "and « androide »'s in Spanish")
        for name in ["Ford", "Intel", "PayPal", "Barbie", "Reuters", "Kia"] {
            XCTAssertFalse(french.contains(name), name)
        }
        XCTAssertFalse(SwipeBrands.names(for: "de").contains("Nike"))
        XCTAssertFalse(SwipeBrands.names(for: "en").contains("Sony"))
        XCTAssertTrue(SwipeBrands.names(for: "en").contains("Samsung"))
    }

    /// Every name is one the language's model lacks, with letters on its keys, once, and not
    /// one `CuratedNames` already spells: the list adds words, it never re-ranks one.
    func testEveryNameIsAWordTheModelLacks() throws {
        let curated = Set(CuratedNames.recased.map { $0.lowercased() })
        for language in Self.languages {
            let model = try Self.model(language)
            let names = SwipeBrands.names(for: language)
            XCTAssertEqual(Set(names.map { $0.lowercased() }).count, names.count, "\(language): once each")
            var extra = SwipeDecoder.ExtraWords()
            SwipeOwnWords.add(names, to: &extra, model: model)
            XCTAssertEqual(extra.texts, names, "\(language): every name is read, in its casing")
            for name in names {
                XCTAssertFalse(model.contains(name.lowercased()), "\(language): the model has \(name)")
                XCTAssertFalse(curated.contains(name.lowercased()), "\(language): \(name) is a curated name")
                XCTAssertNotEqual(name, name.lowercased(), "\(language): \(name) has a capital")
            }
        }
    }

    // MARK: - The own words

    func testABrandGoesInInItsCasingUnlessTheUserHasTheWord() {
        let words = SwipeOwnWords.words(learnedUses: [:], lexiconWords: [], brands: ["Apple", "GitHub"])
        XCTAssertTrue(words.contains("Apple"))
        XCTAssertTrue(words.contains("GitHub"))
        XCTAssertFalse(words.contains("apple"))

        let learned = SwipeOwnWords.words(learnedUses: ["apple": 2], lexiconWords: ["github"], brands: ["Apple", "GitHub"])
        XCTAssertTrue(learned.contains("apple"), "the user's own word, written as the user types it")
        XCTAssertTrue(learned.contains("github"))
        XCTAssertFalse(learned.contains("Apple"))
        XCTAssertFalse(learned.contains("GitHub"))
        XCTAssertEqual(learned, learned.sorted())
    }

    /// A model word in a brand's casing is still the model's: « Google » stays out in English.
    func testAModelWordInCapitalsIsNotReadTwice() throws {
        let model = try Self.model("en")
        XCTAssertTrue(model.contains("google"))
        var extra = SwipeDecoder.ExtraWords()
        SwipeOwnWords.add(["Google", "Zofiak"], to: &extra, model: model)
        XCTAssertEqual(extra.texts, ["Zofiak"])
    }

    // MARK: - A swipe

    /// What a swipe through `word`'s keys types mid-sentence after `previous`, as the
    /// keyboard reads it for a user with no learned word and no contact.
    private func swiped(_ word: String, after previous: String, _ language: String) throws -> [String] {
        let model = try Self.model(language)
        var decoder = SwipeDecoder(model: model)
        var extra = decoder.extraWords
        SwipeOwnWords.add(
            SwipeOwnWords.words(learnedUses: [:], lexiconWords: [], brands: SwipeBrands.names(for: language)),
            to: &extra, model: model
        )
        decoder.extraWords = extra
        let keys = SwipeKeys.letterPage(language)
        return decoder.decode(SwipePath.through(word, keys: keys), keys: keys, previous: previous, limit: 4).map { reading in
            let written = SwipeOwnWords.written(
                reading.text, lexiconDecision: { _ in nil }, learned: { _ in nil }
            )
            return SwipeTypingText.cased(written, capital: false, capsLock: false)
        }
    }

    /// The fr: line of #1094's TestFlight note: Apple, Google, Samsung swiped mid-sentence come
    /// out with their capital, nothing learned.
    func testAppleGoogleAndSamsungSwipeWithTheirCapitalInFrench() throws {
        XCTAssertEqual(try swiped("apple", after: "chez", "fr").first, "Apple")
        XCTAssertEqual(try swiped("google", after: "sur", "fr").first, "Google")
        XCTAssertEqual(try swiped("samsung", after: "un", "fr").first, "Samsung")
    }

    /// Where the model has the word, the model decides: English's « apple » stays a fruit.
    func testAModelWordSwipesAsBefore() throws {
        XCTAssertEqual(try swiped("apple", after: "an", "en").first, "apple")
        XCTAssertEqual(try swiped("samsung", after: "a", "en").first, "Samsung")
    }

    /// A dictionary word on a kept brand's path still reads as the dictionary word.
    func testADictionaryWordKeepsItsSwipe() throws {
        XCTAssertEqual(try swiped("androïde", after: "un", "fr").first, "androïde")
        XCTAssertEqual(try swiped("général", after: "le", "fr").first, "général")
    }
}
