// DictusCore/Tests/DictusCoreTests/LigatureTests.swift
// A word typed with œ or æ is looked up in the dictionary's spelling (#1042).
import XCTest
@testable import DictusCore

final class LigatureTests: XCTestCase {

    // MARK: - Spelling out

    func testSpelledOutWritesEachLigatureAsItsTwoLetters() {
        XCTAssertEqual(Ligature.spelledOut("cœur"), "coeur")
        XCTAssertEqual(Ligature.spelledOut("Œuvre"), "OEuvre")
        XCTAssertEqual(Ligature.spelledOut("vitæ"), "vitae")
        XCTAssertEqual(Ligature.spelledOut("ÆQUO"), "AEQUO")
        XCTAssertEqual(Ligature.spelledOut("cœurs"), "coeurs")
    }

    func testAWordWithoutLigatureIsUnchanged() {
        XCTAssertFalse(Ligature.contains("coeur"))
        XCTAssertEqual(Ligature.spelledOut("coeur"), "coeur")
        XCTAssertEqual(Ligature.spelledOut("poète"), "poète")
    }

    /// Why a table and not Unicode normalization: neither decomposition touches them.
    func testUnicodeDecompositionLeavesTheLigaturesWhole() {
        XCTAssertEqual("œ".decomposedStringWithCompatibilityMapping, "œ")
        XCTAssertEqual("æ".decomposedStringWithCompatibilityMapping, "æ")
    }

    // MARK: - The shipped French dictionary

    /// `fr_frequency.json`, the word list `fr_spellcheck.dict` is built from, as a
    /// `FrequencyProvider`: the same words the trie answers `wordExists` for.
    private struct FrenchWordList: FrequencyProvider {
        let words: [String: Int]
        var isReady: Bool { true }
        func frequency(of word: String) -> UInt16 { UInt16(clamping: words[word] ?? 0) }
        func wordExists(_ word: String) -> Bool { words[word] != nil }
        var frequencyScale: FrequencyScale { .corpusCount }
    }

    private static let french: FrenchWordList = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusKeyboard/Resources/fr_frequency.json")
        let data = (try? Data(contentsOf: url)) ?? Data("{}".utf8)
        let words = (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        return FrenchWordList(words: words)
    }()

    /// The words Pierre's device test and the #1042 diagnosis listed, typed with their
    /// ligature: each was corrected on space (cœur → cour, sœur → sur, œuvre → ouvre,
    /// œil → il, nœud → nous, vœu → vu, vitæ → vite, æquo → qui). The space bar keeps a
    /// word the dictionary knows, and now it knows every one of them.
    func testEveryLigatureWordIsKnownToTheFrenchDictionary() {
        XCTAssertGreaterThan(Self.french.words.count, 30_000, "fr_frequency.json not found")
        let typed = ["cœur", "sœur", "œuvre", "œil", "nœud", "vœu", "bœuf", "vitæ", "æquo",
                     "cœurs", "sœurs", "œuvres", "vœux", "œufs"]
        for word in typed {
            XCTAssertTrue(Self.french.knowsWord(word), word)
            XCTAssertTrue(Self.french.hasWord(word), word)
        }
    }

    /// A capital is how a sentence starts: "Œuvre", "Œil", "Cœur" are known too.
    func testCapitalizedLigatureWordsAreKnown() {
        for word in ["Œuvre", "Œil", "Cœur", "Sœur", "Nœud", "Vœu", "Bœuf", "Vitæ", "Æquo", "ŒIL"] {
            XCTAssertTrue(Self.french.knowsWord(word), word)
        }
    }

    /// After an elision, as the corrector splits it: "l'œil", "d'œuvre".
    func testElidedLigatureWordsAreKnown() {
        XCTAssertTrue(Self.french.knowsWord("l'œil"))
        XCTAssertTrue(Self.french.knowsWord("d'œuvre"))
        XCTAssertTrue(Self.french.knowsWord("L'Œil"))
    }

    /// "coeur" typed with two letters stays the valid word it always was: the keyboard keeps
    /// it as typed, as before (#1042 does not rewrite it into "cœur").
    func testTheSpelledOutFormStaysKnown() {
        for word in ["coeur", "soeur", "oeuvre", "oeil", "noeud", "voeu", "boeuf", "vitae", "aequo"] {
            XCTAssertTrue(Self.french.knowsWord(word), word)
        }
    }

    /// The second lookup only ever finds the dictionary's own word: an unknown word with a
    /// ligature stays unknown, and a word without one is asked exactly as before.
    func testNothingElseBecomesKnown() {
        XCTAssertFalse(Self.french.knowsWord("cœurr"))
        XCTAssertFalse(Self.french.knowsWord("œzorglub"))
        XCTAssertFalse(Self.french.knowsWord("zorglub"))
        XCTAssertTrue(Self.french.hasWord("cour"))
    }
}
