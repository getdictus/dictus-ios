// DictusCore/Tests/DictusCoreTests/SupplementaryLexiconTests.swift
// Tests for the contacts + text replacements lexicon (issue #873): lexicon
// words are never autocorrected, a lowercase match takes the lexicon casing,
// and a shortcut is replaced by its phrase.

import XCTest
@testable import DictusCore

final class SupplementaryLexiconTests: XCTestCase {

    /// Mirrors the simulator setup of #873: contact "Zofiak", replacement
    /// `qqc` -> "quelque chose", phrase-only replacement "blorpa".
    private let lexicon = SupplementaryLexicon(entries: [
        (userInput: "Zofiak", documentText: "Zofiak"),
        (userInput: "qqc", documentText: "quelque chose"),
        (userInput: "blorpa", documentText: "blorpa")
    ])

    // MARK: - Lexicon words

    func testCapitalizedContactIsKept() {
        XCTAssertEqual(lexicon.decision(for: "Zofiak", isDictionaryWord: false), .keep)
    }

    func testLowercaseContactTakesLexiconCasing() {
        XCTAssertEqual(
            lexicon.decision(for: "zofiak", isDictionaryWord: false),
            .replace(with: "Zofiak")
        )
    }

    /// An all-caps `ST` entry turned the `st` of a mistyped `ce st` into "ST" (#1006).
    func testTwoLetterLowercaseWordIsKeptButNotRecased() {
        let initials = SupplementaryLexicon(entries: [(userInput: "ST", documentText: "ST")])
        XCTAssertEqual(initials.decision(for: "st", isDictionaryWord: false), .keep)
        XCTAssertEqual(initials.decision(for: "ST", isDictionaryWord: false), .keep)
        let threeLetters = SupplementaryLexicon(entries: [(userInput: "STE", documentText: "STE")])
        XCTAssertEqual(threeLetters.decision(for: "ste", isDictionaryWord: false), .replace(with: "STE"))
    }

    func testAllCapsContactIsKeptAsTyped() {
        XCTAssertEqual(lexicon.decision(for: "ZOFIAK", isDictionaryWord: false), .keep)
    }

    func testPhraseOnlyReplacementIsKept() {
        XCTAssertEqual(lexicon.decision(for: "blorpa", isDictionaryWord: false), .keep)
        XCTAssertEqual(lexicon.decision(for: "Blorpa", isDictionaryWord: false), .keep)
    }

    /// A contact named like a common word ("Pierre", "Rose") must not
    /// capitalize the common word: "une pierre" stays lowercase.
    func testLowercaseDictionaryWordIsNotRecased() {
        let names = SupplementaryLexicon(entries: [(userInput: "Pierre", documentText: "Pierre")])
        XCTAssertEqual(names.decision(for: "pierre", isDictionaryWord: true), .keep)
    }

    // MARK: - Shortcuts

    func testShortcutIsReplacedByItsPhrase() {
        XCTAssertEqual(
            lexicon.decision(for: "qqc", isDictionaryWord: false),
            .replace(with: "quelque chose")
        )
    }

    func testCapitalizedShortcutCapitalizesThePhrase() {
        // Sentence start: autocap typed "Qqc".
        XCTAssertEqual(
            lexicon.decision(for: "Qqc", isDictionaryWord: false),
            .replace(with: "Quelque chose")
        )
    }

    func testShortcutIsReplacedEvenWhenItIsADictionaryWord() {
        let replacements = SupplementaryLexicon(entries: [(userInput: "sac", documentText: "sans aucun doute")])
        XCTAssertEqual(
            replacements.decision(for: "sac", isDictionaryWord: true),
            .replace(with: "sans aucun doute")
        )
    }

    /// The phrase of a shortcut is protected from autocorrect, but typing it
    /// lowercase does not recase it: "bonjour" stays "bonjour" when the user
    /// has `bjr` -> "Bonjour".
    func testShortcutPhraseIsKeptButNotRecased() {
        let replacements = SupplementaryLexicon(entries: [(userInput: "bjr", documentText: "Bonjour")])
        XCTAssertEqual(replacements.decision(for: "bonjour", isDictionaryWord: true), .keep)
    }

    func testMultiWordPhraseIsNotIndexedAsAWord() {
        XCTAssertNil(lexicon.decision(for: "quelque", isDictionaryWord: true))
        XCTAssertNil(lexicon.decision(for: "chose", isDictionaryWord: true))
    }

    // MARK: - Outside the lexicon

    func testWordOutsideLexiconIsLeftToTheCorrectionPipeline() {
        XCTAssertNil(lexicon.decision(for: "batrau", isDictionaryWord: false))
        XCTAssertNil(lexicon.decision(for: "bateau", isDictionaryWord: true))
    }

    func testEmptyLexiconDecidesNothing() {
        let empty = SupplementaryLexicon.empty
        XCTAssertTrue(empty.isEmpty)
        for word in ["Zofiak", "zofiak", "qqc", "blorpa", "batrau"] {
            XCTAssertNil(empty.decision(for: word, isDictionaryWord: false), word)
        }
    }

    func testEmptyStringsAreIgnored() {
        let odd = SupplementaryLexicon(entries: [(userInput: "", documentText: ""), (userInput: "x", documentText: "")])
        XCTAssertTrue(odd.isEmpty)
        XCTAssertNil(odd.decision(for: "", isDictionaryWord: false))
    }

    func testFirstEntryWinsOnDuplicateKeys() {
        let duplicates = SupplementaryLexicon(entries: [
            (userInput: "Zofiak", documentText: "Zofiak"),
            (userInput: "ZOFIAK", documentText: "ZOFIAK")
        ])
        XCTAssertEqual(duplicates.decision(for: "zofiak", isDictionaryWord: false), .replace(with: "Zofiak"))
    }

    // MARK: - Against the previous-word rules (#500)

    func testShortcutOutranksContextRules() {
        XCTAssertTrue(SupplementaryLexicon.Decision.replace(with: "quelque chose").outranksContextRules(isDictionaryWord: true))
        XCTAssertTrue(SupplementaryLexicon.Decision.replace(with: "Zofiak").outranksContextRules(isDictionaryWord: false))
    }

    func testKeptNameOutranksContextRules() {
        XCTAssertTrue(SupplementaryLexicon.Decision.keep.outranksContextRules(isDictionaryWord: false))
    }

    func testKeptDictionaryWordYieldsToContextRules() {
        // Device test of PR #970: the lexicon held "ma", so "il ma" stayed "il ma".
        let withMa = SupplementaryLexicon(entries: [(userInput: "ma", documentText: "ma")])
        let decision = withMa.decision(for: "ma", isDictionaryWord: true)
        XCTAssertEqual(decision, .keep)
        XCTAssertEqual(decision?.outranksContextRules(isDictionaryWord: true), false)
    }
}
