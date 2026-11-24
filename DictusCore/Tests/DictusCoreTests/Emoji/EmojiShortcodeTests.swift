// Ported from Hex (github.com/anomalyco/hex, branch dev @ 492d8c2,
// ios/HEXMobileTests/EmojiShortcodeTests.swift), MIT, Copyright (c) 2026 Christopher Langton.
// Dictus's changes (#1027): the index read from DictusCore's bundle. Hex's two tests of its
// keyboard engine and settings are left out with the code they test; the matching is all here.
import Foundation
import XCTest
@testable import DictusCore

/// Emoji shortcodes (Settings › Experiments): the ":name" before the cursor, the emoji the
/// bundled index names, the closing ":" of an exact name, and the cases that must not fire.
@MainActor
final class EmojiShortcodeTests: XCTestCase {
    private static var libraries: [String: EmojiLibrary] = [:]

    private func library(_ language: String = "en") throws -> EmojiLibrary {
        if let cached = Self.libraries[language] { return cached }
        let loaded = try XCTUnwrap(EmojiLibrary.load(language: language))
        Self.libraries[language] = loaded
        return loaded
    }

    private func matches(_ text: String?, enabled: Bool = true, limit: Int = 3) throws -> [String] {
        let library = try library()
        return EmojiShortcode.matches(before: text, enabled: enabled, library: library, usage: [:], limit: limit)
            .map { library.entries[$0].emoji }
    }

    // MARK: - Off, and no token

    func testOffFindsNothing() throws {
        XCTAssertEqual(try matches(":pizza", enabled: false), [])
        XCTAssertEqual(try matches("hello :pizza", enabled: false), [])
    }

    func testOneCharacterIsNotATokenAndTwoAre() throws {
        XCTAssertNil(EmojiShortcode.token(before: ":p"))
        XCTAssertEqual(try matches(":p"), [], "a colon and one letter is not a token yet")
        XCTAssertFalse(try matches(":pi").isEmpty, "two characters may match")
        XCTAssertEqual(try matches(":piz").first ?? "", "🍕")
    }

    func testChatEmoticonShapesAreNotTokens() throws {
        let library = try library()
        for text in [":-D", ":-p", ":+1", ":-1"] {
            XCTAssertNil(EmojiShortcode.token(before: text), text)
            XCTAssertNil(EmojiShortcode.completion(before: text, library: library), text)
            XCTAssertEqual(try matches(text), [], text)
        }
    }

    func testColonInsideAWordIsNotAToken() throws {
        XCTAssertNil(EmojiShortcode.token(before: "abc:pizza"))
        XCTAssertEqual(try matches("abc:pizza"), [])
        XCTAssertEqual(try matches("abc:p"), [])
    }

    func testTokenAfterWhitespaceOrAtTheStart() throws {
        XCTAssertEqual(try matches(":pizza").first ?? "", "🍕")
        XCTAssertEqual(try matches("I want :pizza").first ?? "", "🍕")
        XCTAssertEqual(try matches("I want\n:pizza").first ?? "", "🍕")
        XCTAssertEqual(try matches("I want:pizza"), [])
    }

    func testPizzaFindsPizzaAndCaseDoesNotMatter() throws {
        XCTAssertTrue(try matches(":pizza").contains("🍕"))
        XCTAssertTrue(try matches(":PIZZA").contains("🍕"))
    }

    func testUnknownNameFindsNothing() throws {
        XCTAssertEqual(try matches(":zzzzzz"), [])
        XCTAssertEqual(try matches(":notanemoji"), [])
    }

    func testTheTokenCoversTheWholeName() throws {
        let token = try XCTUnwrap(EmojiShortcode.token(before: "I want :pizza"))
        XCTAssertEqual(token.name, "pizza")
        XCTAssertEqual(token.text, ":pizza")
        XCTAssertEqual(token.text.count, 6)
    }

    // MARK: - Closing colon

    func testClosingColonCompletesAnExactName() throws {
        let library = try library()
        let completion = try XCTUnwrap(EmojiShortcode.completion(before: ":pizza", library: library))
        XCTAssertEqual(completion.token.text, ":pizza")
        XCTAssertEqual(library.entries[completion.entry].emoji, "🍕")
        XCTAssertEqual(EmojiShortcode.completion(before: "I want :pizza", library: library)?.token.text ?? "", ":pizza")
    }

    func testClosingColonNeedsTheWholeName() throws {
        let library = try library()
        XCTAssertNil(EmojiShortcode.completion(before: ":piz", library: library))
        XCTAssertNil(EmojiShortcode.completion(before: "abc:pizza", library: library))
        XCTAssertNil(EmojiShortcode.completion(before: ":zzzzzz", library: library))
    }

    func testCompletionIsExactEvenWhenPrefixMatchesExist() throws {
        let library = try library()
        let completion = try XCTUnwrap(EmojiShortcode.completion(before: ":thumbs", library: library))
        XCTAssertEqual(library.entries[completion.entry].emoji, "👍")
    }

    /// Dictus's French index answers English shortcodes too, as Hex's other layouts do.
    func testFrenchIndexKnowsEnglishShortcodes() throws {
        let library = try XCTUnwrap(EmojiLibrary.load(language: "fr"))
        let found = EmojiShortcode.matches(before: ":pizza", enabled: true, library: library).map { library.entries[$0].emoji }
        XCTAssertEqual(found.first, "🍕")
        let coeur = EmojiShortcode.matches(before: ":coeur", enabled: true, library: library).map { library.entries[$0].emoji }
        XCTAssertFalse(coeur.isEmpty)
    }
}
