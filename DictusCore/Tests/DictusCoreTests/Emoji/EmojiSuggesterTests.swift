// Ported from Hex (github.com/anomalyco/hex, branch dev @ 492d8c2,
// ios/HEXMobileTests/EmojiSuggesterTests.swift), MIT, Copyright (c) 2026 Christopher Langton.
// Dictus's changes (#1027): the index read from DictusCore's bundle; French instead of
// Norwegian; French search ("coeur" and "cœur"); the old recents' import. The drawing and panel
// tests moved to EmojiPanelTests (UIKit only), and Hex's routed-target test went with the type.
import QuartzCore
import XCTest
@testable import DictusCore

/// The emoji panel's ranking: the index, context suggestions, search, the strip's emoji for a
/// finished word, your history, and the 60 hand-written sentences behind Hex's numbers.
@MainActor
final class EmojiSuggesterTests: XCTestCase {
    private static var libraries: [String: EmojiLibrary] = [:]

    private func library(_ language: String = "en") throws -> EmojiLibrary {
        if let cached = Self.libraries[language] { return cached }
        let loaded = try XCTUnwrap(EmojiLibrary.load(language: language))
        Self.libraries[language] = loaded
        return loaded
    }

    private func suggest(_ text: String, usage: [Int: Float] = [:], limit: Int = 5, language: String = "en") throws -> [String] {
        let library = try library(language)
        let context = EmojiContext(before: text, stopwords: library.stopwords)
        return EmojiSuggester.suggestions(context: context, library: library, usage: usage, limit: limit, fill: false)
            .map { library.entries[$0].emoji }
    }

    private func search(_ query: String, language: String = "en", limit: Int = 10) throws -> [String] {
        let library = try library(language)
        return EmojiSuggester.search(query, library: library, limit: limit).map { library.entries[$0].emoji }
    }

    // MARK: - Index

    /// Hex #2352: an index built per keyboard presentation leaked about 0.8 MB each time.
    func testBundledCacheReusesInstanceAcrossPresentationsAndEvictsOnMemoryWarning() throws {
        EmojiLibrary.evictCached()
        let first = try XCTUnwrap(EmojiLibrary.bundled(language: "en"))
        let second = try XCTUnwrap(EmojiLibrary.bundled(language: "en"))
        XCTAssertTrue(first === second, "presentations in the same language share one EmojiLibrary")
        let fallback = try XCTUnwrap(EmojiLibrary.bundled(language: "it"))
        XCTAssertTrue(first === fallback, "languages without an index share the cached English instance")
        let french = try XCTUnwrap(EmojiLibrary.bundled(language: "fr"))
        XCTAssertFalse(first === french, "French has its own index")
        XCTAssertEqual(french.language, "fr")
        EmojiLibrary.evictCached()
        let afterWarning = try XCTUnwrap(EmojiLibrary.bundled(language: "fr"))
        XCTAssertFalse(french === afterWarning, "a memory warning releases the cached library")
        EmojiLibrary.evictCached()
    }

    func testEveryDictusLanguageHasItsIndex() throws {
        for language in ["fr", "en", "es", "de"] {
            let library = try library(language)
            XCTAssertEqual(library.language, language)
            XCTAssertGreaterThan(library.entries.count, 1_850, language)
        }
    }

    func testLoadsEveryCategoryAndOnlyEmojiTheFontDraws() throws {
        let library = try library()
        XCTAssertGreaterThan(library.entries.count, 1_850)
        for category in EmojiCategory.allCases {
            XCTAssertTrue(library.entries.contains { $0.category == category }, "\(category)")
        }
        // Smileys and People are two categories in Dictus (one in Hex).
        XCTAssertEqual(library.entries[try XCTUnwrap(library.entryByEmoji["😀"])].category, .smileys)
        XCTAssertEqual(library.entries[try XCTUnwrap(library.entryByEmoji["👋"])].category, .people)
        XCTAssertTrue(EmojiLibrary.fontDraws("🍕"))
        XCTAssertTrue(EmojiLibrary.fontDraws("🧑🏽‍🚀"))
        XCTAssertFalse(EmojiLibrary.fontDraws("\u{E000}"))
        XCTAssertFalse(EmojiLibrary.fontDraws("🍕🍕"))
        let wave = try XCTUnwrap(library.entryByEmoji["👋"])
        XCTAssertEqual(library.entries[wave].tones.count, 5)
        XCTAssertEqual(library.entryByEmoji["👋🏽"], wave)
        XCTAssertEqual(library.name(of: wave), "waving hand")
    }

    func testLooksUpWordsAndPhrases() throws {
        let library = try library()
        let pizza = try XCTUnwrap(library.hits(forWord: "pizza"))
        XCTAssertEqual(library.entries[Int(pizza[0].entry)].emoji, "🍕")
        XCTAssertNil(library.hits(forWord: "qqqzzz"))
        let newYear = try XCTUnwrap(library.hits(forPhrase: "new year"))
        XCTAssertEqual(library.entries[Int(newYear[0].entry)].emoji, "🎆")
    }

    func testFoldsLikeTheIndex() {
        XCTAssertEqual(EmojiText.fold("Café Ñandú"), "cafe nandu")
        XCTAssertEqual(EmojiText.words(in: "That’s SO good!!"), ["that", "so", "good"])
        XCTAssertEqual(EmojiText.collapsingRepeats("soooo"), ["soo", "so"])
        XCTAssertEqual(EmojiText.collapsingRepeats("good"), [])
    }

    /// NFD leaves ligatures whole; French types "coeur" for "cœur" (#1027).
    func testFoldingOpensTheLigatures() {
        XCTAssertEqual(EmojiText.fold("cœur"), "coeur")
        XCTAssertEqual(EmojiText.fold("Cœur"), "coeur")
        XCTAssertEqual(EmojiText.fold("ŒUF"), "oeuf")
        XCTAssertEqual(EmojiText.fold("ex æquo"), "ex aequo")
        XCTAssertEqual(EmojiText.words(in: "Mon cœur bat"), ["mon", "coeur", "bat"])
    }

    // MARK: - French

    /// The brief's own check: "coeur" and "cœur" both find ❤️.
    func testFrenchSearchFindsTheHeartWithAndWithoutTheLigature() throws {
        let plain = try search("coeur", language: "fr")
        let ligature = try search("cœur", language: "fr")
        XCTAssertTrue(plain.prefix(3).contains("❤️"), "\(plain)")
        XCTAssertEqual(plain, ligature, "the ligature folds to the same search")
        XCTAssertEqual(try search("Cœur rouge", language: "fr").first, "❤️")
        XCTAssertTrue(try search("heart", language: "fr").prefix(3).contains("❤️"), "English words work under French too")
    }

    func testFrenchSearchReadsCLDRNamesAndKeywords() throws {
        XCTAssertEqual(try search("pizza", language: "fr").first, "🍕")
        let cat = try search("chat", language: "fr")
        XCTAssertEqual(cat.first, "🐈", "CLDR fr names 🐈 \"chat\" outright: \(cat)")
        XCTAssertTrue(cat.prefix(10).contains("🐱"), "\(cat)")
        let cake = try search("gateau", language: "fr")
        XCTAssertTrue(cake.prefix(5).contains("🎂"), "\(cake)")
        XCTAssertEqual(try search("drapeau fra", language: "fr").first, "🇫🇷")
        XCTAssertEqual(try search("zzzzqq", language: "fr"), [])
    }

    func testFrenchContextSuggestsTheWordsEmoji() throws {
        let birthday = try suggest("joyeux anniversaire ", language: "fr")
        XCTAssertTrue(birthday.contains("🎂"), "\(birthday)")
        let coffee = try suggest("un café ce matin ", language: "fr")
        XCTAssertTrue(coffee.contains("☕"), "\(coffee)")
        let cakes = try suggest("deux gâteaux ", language: "fr")
        XCTAssertTrue(cakes.contains("🎂") || cakes.contains("🍰"), "\(cakes)")
    }

    // MARK: - Context

    func testSuggestsTheWordsOwnEmoji() throws {
        XCTAssertEqual(try suggest("pizza tonight? ").prefix(3).contains("🍕"), true)
        let launch = try suggest("congrats on the launch ")
        XCTAssertTrue(launch.contains("🎉"), "\(launch)")
        XCTAssertTrue(launch.contains("🚀"), "\(launch)")
        XCTAssertTrue(try suggest("happy new year ").contains("🎆"))
    }

    func testTheNewestWordCountsMost() throws {
        let tail = try suggest("pizza was great, now coffee ")
        XCTAssertLessThan(try XCTUnwrap(tail.firstIndex(of: "☕")), try XCTUnwrap(tail.firstIndex(of: "🍕")))
    }

    func testShowsOneEmojiPerFamily() throws {
        let run = try suggest("going for a run ", limit: 8)
        XCTAssertEqual(run.filter { $0.hasPrefix("🏃") }.count, 1, "\(run)")
    }

    func testReadsHeldDownLettersAndEndings() throws {
        XCTAssertTrue(try suggest("lmaooo ").contains { $0 == "🤣" || $0 == "😂" })
        XCTAssertTrue(try suggest("two dogs ").contains { $0 == "🐶" || $0 == "🐕" })
    }

    func testWordStillBeingTypedFindsWhatItStarts() throws {
        XCTAssertTrue(try suggest("piz").contains("🍕"))
    }

    func testYourEmojiBreakTiesAndFillTheRow() throws {
        let library = try library()
        let fire = try XCTUnwrap(library.entryByEmoji["🔥"])
        let filled = EmojiSuggester.suggestions(
            context: EmojiContext(before: "", stopwords: library.stopwords),
            library: library,
            usage: [fire: 1],
            limit: 4
        ).map { library.entries[$0].emoji }
        XCTAssertEqual(filled.first, "🔥")
        XCTAssertEqual(filled.count, 4)
    }

    func testOtherLanguagesReadTheirWordsAndEnglish() throws {
        XCTAssertTrue(try suggest("un café ", language: "fr").contains("☕"))
        XCTAssertTrue(try suggest("feliz cumpleaños ", language: "es").contains("🎂"))
        XCTAssertTrue(try suggest("pizza heute ", language: "de").contains("🍕"))
    }

    // MARK: - Strip and search

    func testStripOffersEmojiForAFinishedWordOnly() throws {
        let library = try library()
        func strip(_ text: String) -> [String] {
            EmojiSuggester.forFinishedWord(text, library: library).map { library.entries[$0].emoji }
        }
        XCTAssertEqual(strip("pizza "), ["🍕"])
        XCTAssertEqual(strip("Happy birthday "), ["🎂", "🎉", "🥳"])
        XCTAssertEqual(strip("pizza"), [])
        XCTAssertEqual(strip("pizza  "), [])
        XCTAssertEqual(strip("on the "), [])
        XCTAssertEqual(strip("at 7 "), [])
        // A word several emoji only describe offers none.
        XCTAssertEqual(strip("face "), [])
    }

    func testSearchMatchesNamesBeforeKeywords() throws {
        XCTAssertEqual(try search("piz").first, "🍕")
        let heart = try search("heart")
        XCTAssertTrue(heart.prefix(3).contains("❤️"), "\(heart)")
        XCTAssertEqual(try search("flag jap").first, "🇯🇵")
        XCTAssertEqual(try search("zzzzqq"), [])
    }

    // MARK: - History

    func testHistoryFadesByHalfEveryTenDaysAndKeepsTones() throws {
        let suite = "dictus.tests.emoji.history"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        var now = Date(timeIntervalSince1970: 1_000_000)
        let store = EmojiUsageStore(defaults: defaults, now: { now })
        store.record("🍕")
        store.record("🍕")
        now += 20 * 86_400
        store.record("☕")
        // 🍕: 2 halved twice = 0.5; ☕: 1.
        XCTAssertEqual(store.ranked().map(\.emoji), ["☕", "🍕"])
        XCTAssertEqual(store.ranked().last?.score ?? 0, 0.5, accuracy: 0.001)
        store.setTone(3, for: "👍")
        XCTAssertEqual(EmojiUsageStore(defaults: defaults).tone(for: "👍"), 3)
        store.clear()
        XCTAssertTrue(EmojiUsageStore(defaults: defaults).isEmpty)
        defaults.removePersistentDomain(forName: suite)
    }

    /// The old picker's 30 recents (newest first) become the new store's first emoji, once.
    func testImportsTheOldPickersRecentsOnce() throws {
        let suite = "dictus.tests.emoji.legacy"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defaults.set(["🔥", "😂", "❤️"], forKey: "recentEmojis")
        let store = EmojiUsageStore(defaults: defaults)
        XCTAssertEqual(store.ranked().map(\.emoji), ["🔥", "😂", "❤️"])
        XCTAssertNil(defaults.stringArray(forKey: "recentEmojis"), "the old list is read once")
        store.record("🍕")
        XCTAssertEqual(EmojiUsageStore(defaults: defaults).ranked().map(\.emoji).first, "🔥")
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - Quality

    private struct Sentence: Decodable {
        let text: String
        let accept: [String]
    }

    private struct Fixture: Decodable {
        let dev: [Sentence]
        let heldOut: [Sentence]
        let blind: [Sentence]
    }

    private static func plain(_ emoji: String) -> String {
        String(String.UnicodeScalarView(emoji.unicodeScalars.filter {
            $0.value != 0xFE0F && !(0x1F3FB...0x1F3FF).contains($0.value)
        }))
    }

    /// How many of Hex's English sentences get a sensible emoji in the top five, with the
    /// words' own emoji and then with Apple's word embedding added. Hex's floors, kept: Dictus's
    /// index adds French stopwords to the shared list, and this catches it costing English.
    func testSentencesGetASensibleEmojiInTheTopFive() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "emoji-context-sentences", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let library = try library()

        let start = CACurrentMediaTime()
        let semantic = EmojiSemanticIndex(language: "en", vocabulary: library.vocabulary)
        let built = CACurrentMediaTime() - start
        let neighbors: EmojiSuggester.Neighbors? = semantic.map { index in { index.neighbors(of: $0) } }

        func score(_ sentences: [Sentence], _ neighbors: EmojiSuggester.Neighbors?) -> (hits: Int, top1: Int) {
            var hits = 0
            var top1 = 0
            for sentence in sentences {
                let context = EmojiContext(before: sentence.text + " ", stopwords: library.stopwords)
                let top = EmojiSuggester.suggestions(context: context, library: library, neighbors: neighbors, limit: 5, fill: false)
                    .map { Self.plain(library.entries[$0].emoji) }
                let accepted = Set(sentence.accept.map(Self.plain))
                if top.contains(where: accepted.contains) { hits += 1 }
                if let first = top.first, accepted.contains(first) { top1 += 1 }
            }
            return (hits, top1)
        }
        let devWords = score(fixture.dev, nil)
        let heldWords = score(fixture.heldOut, nil)
        let blindWords = score(fixture.blind, nil)
        let blindSemantic = score(fixture.blind, neighbors)
        print("EMOJI_QUALITY words: dev \(devWords.hits)/30 (top-1 \(devWords.top1)), held-out \(heldWords.hits)/30 (top-1 \(heldWords.top1)), blind \(blindWords.hits)/\(fixture.blind.count) (top-1 \(blindWords.top1))")
        print("EMOJI_QUALITY words + embeddings: blind \(blindSemantic.hits)/\(fixture.blind.count), index built in \(String(format: "%.0f", built * 1000)) ms (\(semantic?.vocabularySize ?? 0) words)")
        XCTAssertGreaterThanOrEqual(devWords.hits, 28)
        XCTAssertGreaterThanOrEqual(heldWords.hits, 27)
        XCTAssertGreaterThanOrEqual(blindWords.hits, 35)
    }
}
