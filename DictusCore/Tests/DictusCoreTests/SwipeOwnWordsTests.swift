// DictusCore/Tests/DictusCoreTests/SwipeOwnWordsTests.swift
// Swipe typing reads the user's own words (#1090): learned words under ADR 0004's adoption
// rule, contacts and text replacements, written in the user's casing.
import CoreGraphics
import XCTest
@testable import DictusCore

final class SwipeOwnWordsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDictionary.shared.resetAll()
    }

    override func tearDown() {
        UserDictionary.shared.resetAll()
        super.tearDown()
    }

    private static func modelPath(_ language: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusKeyboard/Resources/\(language).hextm").path
    }

    // MARK: - The guardrail (ADR 0004)

    /// The swipe as the keyboard reads it: the model, the language's extra words, and the
    /// own words the bridge hands the controller, from the real store.
    private func decoder(_ language: String, lexicon: SupplementaryLexicon = .empty) throws -> SwipeDecoder {
        let model = try XCTUnwrap(SpatialDecoderModel(path: Self.modelPath(language)))
        var decoder = SwipeDecoder(model: model)
        var extra = decoder.extraWords
        SwipeOwnWords.add(
            SwipeOwnWords.words(learnedUses: UserDictionary.shared.allLearnedWords, lexiconWords: lexicon.lowercasedWords),
            to: &extra, model: model
        )
        decoder.extraWords = extra
        return decoder
    }

    /// What a swipe through `word`'s keys types mid-sentence, after `previous`, written as
    /// the bridge writes it (`SwipeOwnWords.written`, then no sentence capital).
    private func swiped(_ word: String, after previous: String, _ language: String, lexicon: SupplementaryLexicon = .empty) throws -> [String] {
        let keys = SwipeKeys.letterPage(language)
        let readings = try decoder(language, lexicon: lexicon)
            .decode(SwipePath.through(word, keys: keys), keys: keys, previous: previous, limit: 4).map(\.text)
        let store = UserDictionary.shared
        return readings.map { reading in
            let written = SwipeOwnWords.written(
                reading,
                lexiconDecision: { lexicon.decision(for: $0, isDictionaryWord: false) },
                learned: { word in store.allLearnedWords[word].map { .init(uses: $0, casing: store.casing(of: word)) } }
            )
            return SwipeTypingText.cased(written, capital: false, capsLock: false)
        }
    }

    /// A word learned on one refusal is often the typo itself (#872): it never comes out of a
    /// swipe, even one drawn exactly through its keys. Typed again, it is adopted, and the
    /// same swipe types it.
    func testATypoLearnedOnceNeverWinsASwipeAndAnAdoptedWordDoes() throws {
        // « bonjoru »: « bonjour » with its last two letters swapped, which a refusal learns.
        XCTAssertTrue(UserDictionary.shared.learn("bonjoru"))
        XCTAssertEqual(UserDictionary.shared.allLearnedWords["bonjoru"], 1)
        let once = try swiped("bonjoru", after: "dis", "fr")
        XCTAssertFalse(once.contains("bonjoru"), "learned once, never read by a swipe: \(once)")

        UserDictionary.shared.recordUsage("bonjoru")
        let adopted = try swiped("bonjoru", after: "dis", "fr")
        XCTAssertEqual(adopted.first, "bonjoru", "typed again, it is the user's word: \(adopted)")
    }

    /// Pierre's case: « Apple » mid-sentence in French, a word the French model lacks.
    func testAnAdoptedLearnedWordComesOutMidSentenceWithItsCapital() throws {
        let model = try XCTUnwrap(SpatialDecoderModel(path: Self.modelPath("fr")))
        XCTAssertFalse(model.contains("apple"), "the French model alone cannot read it")
        XCTAssertFalse(try swiped("apple", after: "chez", "fr").contains { $0.lowercased() == "apple" })

        // Typed twice mid-sentence with its capital, as the keyboard learns an unknown word.
        UserDictionary.shared.recordUsage("Apple")
        XCTAssertFalse(try swiped("apple", after: "chez", "fr").contains { $0.lowercased() == "apple" },
                       "typed once, not learned yet")
        UserDictionary.shared.recordUsage("Apple")
        XCTAssertEqual(try swiped("apple", after: "chez", "fr").first, "Apple")
    }

    func testAWordWithInnerCapitalsKeepsThemAtTheStartOfASentence() throws {
        UserDictionary.shared.recordUsage("WisprFlow")
        UserDictionary.shared.recordUsage("WisprFlow")
        let readings = try swiped("wisprflow", after: "avec", "fr")
        XCTAssertEqual(readings.first, "WisprFlow", "\(readings)")
        XCTAssertEqual(SwipeTypingText.cased("WisprFlow", capital: true, capsLock: false), "WisprFlow")
        XCTAssertEqual(SwipeTypingText.cased("iPhone", capital: true, capsLock: false), "iPhone")
        XCTAssertEqual(SwipeTypingText.cased("Apple", capital: true, capsLock: false), "Apple")
        XCTAssertEqual(SwipeTypingText.cased("apple", capital: true, capsLock: false), "Apple")
        XCTAssertEqual(SwipeTypingText.cased("WisprFlow", capital: false, capsLock: true), "WISPRFLOW")
    }

    /// A contact the model lacks swipes in its casing at its first use, as a tapped one is
    /// kept and recased: the lexicon is the user's own writing, not something learned.
    func testAContactNameSwipesInItsCasing() throws {
        let lexicon = SupplementaryLexicon(entries: [(userInput: "Zofiak", documentText: "Zofiak")])
        XCTAssertEqual(try swiped("zofiak", after: "avec", "fr", lexicon: lexicon).first, "Zofiak")
        XCTAssertFalse(try swiped("zofiak", after: "avec", "fr").contains { $0.lowercased() == "zofiak" },
                       "without the contact, no such word")
    }

    func testAnAppNameSwipesInItsCasing() throws {
        XCTAssertEqual(try swiped("whatsapp", after: "sur", "fr").first, "WhatsApp")
        XCTAssertEqual(try swiped("dictus", after: "avec", "fr").first, "Dictus")
    }

    // MARK: - The list of own words

    func testOnlyAdoptedLearnedWordsAreRead() {
        let words = SwipeOwnWords.words(
            learnedUses: ["bonjoru": 1, "apple": 2, "wisprflow": 7, "x": 9],
            lexiconWords: ["zofiak"]
        )
        XCTAssertFalse(words.contains("bonjoru"))
        XCTAssertTrue(words.contains("apple"))
        XCTAssertTrue(words.contains("wisprflow"))
        XCTAssertFalse(words.contains("x"), "one letter is tapped, never swiped")
        XCTAssertTrue(words.contains("zofiak"))
        XCTAssertTrue(words.contains("whatsapp"), "the curated names, as tap typing keeps them")
        XCTAssertEqual(words, words.sorted(), "sorted, so the keyboard can tell when they changed")
        XCTAssertEqual(LearnedWordCorrection.minimumUses, 2, "the one rule, tap typing's (#498)")
    }

    func testTheModelsOwnWordsAreNotReadTwice() throws {
        let model = try XCTUnwrap(SpatialDecoderModel(path: Self.modelPath("fr")))
        var extra = SwipeDecoder.ExtraWords()
        SwipeOwnWords.add(["bonjour", "zofiak"], to: &extra, model: model)
        XCTAssertEqual(extra.texts, ["zofiak"], "a model word keeps the model's own cost")
        XCTAssertEqual(extra.costs, [SwipeDecoder.ownWordCost])
    }

    /// With no own word the decoder reads exactly what it read before #1090.
    func testWithNoOwnWordTheReadingsAreUnchanged() throws {
        let model = try XCTUnwrap(SpatialDecoderModel(path: Self.modelPath("fr")))
        let plain = SwipeDecoder(model: model)
        var extra = plain.extraWords
        SwipeOwnWords.add([], to: &extra, model: model)
        var synced = plain
        synced.extraWords = extra
        let keys = SwipeKeys.letterPage("fr")
        for word in ["bonjour", "merci", "maison", "pour"] {
            let path = SwipePath.through(word, keys: keys)
            XCTAssertEqual(plain.decode(path, keys: keys, limit: 8), synced.decode(path, keys: keys, limit: 8), word)
        }
    }

    // MARK: - Writing a reading

    func testWritingFollowsTheLexiconThenTheAdoptedLearnedWord() {
        let lexicon = SupplementaryLexicon(entries: [
            (userInput: "Pierre", documentText: "Pierre"), (userInput: "qqc", documentText: "quelque chose")
        ])
        func written(_ reading: String, dictionary: Set<String> = [], learned: [String: SwipeOwnWords.Learned] = [:]) -> String {
            SwipeOwnWords.written(
                reading,
                lexiconDecision: { lexicon.decision(for: $0, isDictionaryWord: dictionary.contains($0)) },
                learned: { learned[$0] }
            )
        }
        XCTAssertEqual(written("pierre"), "Pierre", "a contact the dictionary lacks takes its casing")
        XCTAssertEqual(written("pierre", dictionary: ["pierre"]), "pierre", "« une pierre » stays, as when tapped")
        XCTAssertEqual(written("qqc"), "qqc", "a shortcut is not expanded by a swipe")
        XCTAssertEqual(written("iphone"), "iPhone")
        XCTAssertEqual(written("apple", learned: ["apple": .init(uses: 2, casing: "Apple")]), "Apple")
        XCTAssertEqual(written("apple", learned: ["apple": .init(uses: 1, casing: "Apple")]), "apple",
                       "a casing learned once is not a swipe's to apply")
        XCTAssertEqual(written("apple", learned: ["apple": .init(uses: 3, casing: nil)]), "apple",
                       "learned before casings were kept")
        XCTAssertEqual(written("I'm"), "I'm", "already written")
    }

    // MARK: - The casing a learned word keeps

    func testTheCasingRule() {
        XCTAssertEqual(LearnedWordCasing.merged(kept: nil, typed: "Apple"), "Apple")
        XCTAssertEqual(LearnedWordCasing.merged(kept: "apple", typed: "Apple"), "apple",
                       "a capital first letter may be the sentence's: a lowercase form outweighs it")
        XCTAssertEqual(LearnedWordCasing.merged(kept: "Apple", typed: "apple"), "apple")
        XCTAssertEqual(LearnedWordCasing.merged(kept: "Wisprflow", typed: "WisprFlow"), "WisprFlow")
        XCTAssertEqual(LearnedWordCasing.merged(kept: "WisprFlow", typed: "Wisprflow"), "WisprFlow",
                       "inner capitals are never the keyboard's")
        XCTAssertEqual(LearnedWordCasing.merged(kept: "SNCF", typed: "sncf"), "sncf")
        XCTAssertEqual(LearnedWordCasing.merged(kept: "Other", typed: "Apple"), "Apple", "another word's form is ignored")
        XCTAssertEqual(LearnedWordCasing.merged(kept: "apple", typed: ""), "apple")
    }

    func testTheStoreKeepsTheCasingOfLearnedWordsOnly() {
        let store = UserDictionary.shared
        store.recordUsage("Apple")
        XCTAssertNil(store.casing(of: "apple"), "pending, not learned")
        store.recordUsage("Apple")
        XCTAssertEqual(store.casing(of: "apple"), "Apple")
        store.recordUsage("apple")
        XCTAssertEqual(store.casing(of: "APPLE"), "apple", "typed lowercase mid-sentence")
        store.recordUsage("Apple")
        XCTAssertEqual(store.casing(of: "apple"), "apple", "a sentence-start capital does not undo it")

        store.learn("WisprFlow")
        XCTAssertEqual(store.casing(of: "wisprflow"), "WisprFlow")
        store.reload()
        XCTAssertEqual(store.casing(of: "wisprflow"), "WisprFlow", "kept in the App Group")

        store.forget("wisprflow")
        XCTAssertNil(store.casing(of: "wisprflow"))
        store.resetAll()
        XCTAssertNil(store.casing(of: "apple"))
        XCTAssertEqual(AppGroup.defaults.dictionary(forKey: UserDictionary.casingKey) as? [String: String], [:])
    }

    func testLoadingDropsTheCasingOfAWordNoLongerLearned() {
        UserDictionary.shared.learn("Zorglub")
        // An older build of the other process forgot the word without knowing about casings.
        AppGroup.defaults.set([String: Int](), forKey: UserDictionary.storageKey)
        UserDictionary.shared.reload()
        XCTAssertNil(UserDictionary.shared.casing(of: "zorglub"))
        XCTAssertEqual(AppGroup.defaults.dictionary(forKey: UserDictionary.casingKey) as? [String: String], [:])
    }
}
