// DictusCore/Tests/DictusCoreTests/FrenchAdaptiveKeyTests.swift
// The AZERTY row-3 adaptive key: its French behaviour, and the language guard that keeps
// it from surfacing French accents to the other languages now reachable on AZERTY (#272).
import XCTest
@testable import DictusCore

final class FrenchAdaptiveKeyTests: XCTestCase {

    // MARK: - French behaviour (unchanged by #272)

    func testLabelShowsTheDefaultAccentAfterAVowel() {
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "e", language: .french), "\u{00E9}")
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "a", language: .french), "\u{00E0}")
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "u", language: .french), "\u{00F9}")
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "i", language: .french), "\u{00EE}")
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "o", language: .french), "\u{00F4}")
    }

    func testLabelShowsApostropheAfterAConsonant() {
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "l", language: .french), "'")
    }

    func testLabelShowsApostropheAfterTheQuBigram() {
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "u", precedingChar: "q", language: .french), "'")
        XCTAssertFalse(FrenchAdaptiveKey.shouldReplace(afterTyping: "u", precedingChar: "q", language: .french))
        XCTAssertNil(FrenchAdaptiveKey.vowel(afterTyping: "u", precedingChar: "q", language: .french))
    }

    func testLabelPreservesTheCaseOfTheTypedVowel() {
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "E", language: .french), "\u{00C9}")
    }

    func testShouldReplaceOnlyAfterAVowel() {
        XCTAssertTrue(FrenchAdaptiveKey.shouldReplace(afterTyping: "e", language: .french))
        XCTAssertFalse(FrenchAdaptiveKey.shouldReplace(afterTyping: "l", language: .french))
        XCTAssertFalse(FrenchAdaptiveKey.shouldReplace(afterTyping: nil, language: .french))
    }

    func testVowelReportsTheBaseVowel() {
        XCTAssertEqual(FrenchAdaptiveKey.vowel(afterTyping: "E", language: .french), "e")
        XCTAssertNil(FrenchAdaptiveKey.vowel(afterTyping: "l", language: .french))
    }

    // MARK: - Language guard (#272)

    /// Decoupling the layout from the dictionary language makes English/Spanish/German on
    /// AZERTY reachable. On those keyboards the key is what it is labelled: an apostrophe.
    func testTheKeyIsAPlainApostropheOutsideFrench() {
        for language in SupportedLanguage.allCases where language != .french {
            for typed in ["e", "a", "u", "i", "o", "E", "l", nil] {
                XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: typed, language: language), "'",
                               "\(language.rawValue) must not get a French accent after \(typed ?? "nil")")
                XCTAssertFalse(FrenchAdaptiveKey.shouldReplace(afterTyping: typed, language: language),
                               "\(language.rawValue) must never replace the character it just typed")
                XCTAssertNil(FrenchAdaptiveKey.vowel(afterTyping: typed, language: language))
            }
        }
    }

    /// The guard reads the active language by default, which is how the keyboard bridge
    /// calls it — one language switch is enough to change the key's behaviour.
    func testTheGuardFollowsTheActiveLanguageByDefault() {
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        // Restore rather than clear: the suite is shared with every other test class,
        // and clearing would hand them a different language than they started with.
        let previousLanguage = defaults?.string(forKey: SharedKeys.language)
        defer {
            if let previousLanguage {
                defaults?.set(previousLanguage, forKey: SharedKeys.language)
            } else {
                defaults?.removeObject(forKey: SharedKeys.language)
            }
        }

        defaults?.set(SupportedLanguage.french.rawValue, forKey: SharedKeys.language)
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "e"), "\u{00E9}")

        defaults?.set(SupportedLanguage.english.rawValue, forKey: SharedKeys.language)
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "e"), "'")
    }

    // MARK: - Unchanged by the per-language long-press lists (#1042)

    /// #1042 gave each language its own long-press lists, and French's held o now opens on
    /// ö, not ô. The adaptive key must not follow: it keeps its own table, and every
    /// keystroke gives what it gave before. The expected values are spelled out here, not
    /// read from `FrenchAdaptiveKey.defaults`, so a change to that table fails too.
    func testTheAdaptiveKeyIsUnchangedByThePerLanguageLongPressLists() {
        XCTAssertEqual(FrenchAdaptiveKey.defaults, [
            "e": "\u{00E9}", "a": "\u{00E0}", "u": "\u{00F9}", "i": "\u{00EE}", "o": "\u{00F4}"
        ])

        let accentAfter: [String: String] = [
            "e": "\u{00E9}", "a": "\u{00E0}", "u": "\u{00F9}", "i": "\u{00EE}", "o": "\u{00F4}"
        ]
        let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)
        for layout in LayoutType.allCases {
            // The French long-press lists exist on every layout; the key must ignore them.
            XCTAssertNotNil(AccentedCharacters.accents(for: "o", language: .french, layout: layout))
            for letter in letters + letters.map { $0.uppercased() } {
                let lower = letter.lowercased()
                let expected = accentAfter[lower].map { letter == lower ? $0 : $0.uppercased() } ?? "'"
                XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: letter, language: .french), expected, letter)
                XCTAssertEqual(FrenchAdaptiveKey.shouldReplace(afterTyping: letter, language: .french),
                               accentAfter[lower] != nil, letter)
                XCTAssertEqual(FrenchAdaptiveKey.vowel(afterTyping: letter, language: .french),
                               accentAfter[lower] != nil ? lower : nil, letter)
            }
        }
        // Not œ after o, not æ after a: those are held, never on the key.
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "o", language: .french), "\u{00F4}")
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "a", language: .french), "\u{00E0}")
        // qu still gives the apostrophe, and the apostrophe key itself still holds nothing.
        XCTAssertEqual(FrenchAdaptiveKey.label(afterTyping: "u", precedingChar: "q", language: .french), "'")
        XCTAssertNil(AccentedCharacters.accents(for: "'", language: .french, layout: .azerty))
    }
}
