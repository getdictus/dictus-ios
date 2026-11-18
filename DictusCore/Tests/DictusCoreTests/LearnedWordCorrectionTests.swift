// DictusCore/Tests/DictusCoreTests/LearnedWordCorrectionTests.swift
// Covers the rule that makes a learned word an autocorrect target (#498).
import XCTest
@testable import DictusCore

final class LearnedWordCorrectionTests: XCTestCase {

    /// A few dictionary words: enough for the rule to tell known from unknown.
    private let dictionary: Set<String> = ["merci", "mercy"]

    private func target(for typed: String, _ learned: [String: Int]) -> String? {
        LearnedWordCorrection.target(for: typed, learnedWords: learned, dictionaryKnows: dictionary.contains)
    }

    // MARK: - Corrects toward the learned word

    func testASubstitutionTypoCorrectsToTheLearnedWord() {
        XCTAssertEqual(target(for: "dictis", ["dictus": 3]), "dictus")
    }

    func testAMissingAndAnExtraLetterCorrectToTheLearnedWord() {
        XCTAssertEqual(target(for: "dictu", ["dictus": 2]), "dictus")
        XCTAssertEqual(target(for: "dicttus", ["dictus": 2]), "dictus")
    }

    func testTheTypedCasingDoesNotChangeTheMatch() {
        XCTAssertEqual(target(for: "Dictis", ["dictus": 2]), "dictus",
                       "The caller restores the casing; the match itself is case-blind")
    }

    // MARK: - Does not take over

    func testACorrectlyTypedDictionaryWordIsNeverRewrittenIntoALearnedWord() {
        // `mercu` learned and used often is one edit from `merci`, which the user
        // typed correctly: the dictionary word stays.
        XCTAssertNil(target(for: "merci", ["mercu": 9]))
        XCTAssertNil(target(for: "Merci", ["mercu": 9]))
    }

    func testAWordLearnedOnceIsNotATarget() {
        // A single refused correction learns the word at one use, and that word is
        // often the typo itself (`mzrci` for `merci`).
        XCTAssertNil(target(for: "mzrcu", ["mzrci": 1]))
    }

    func testTwoEditsAwayIsNotATarget() {
        XCTAssertNil(target(for: "dixtis", ["dictus": 5]))
    }

    func testAShortTypedWordIsNotATarget() {
        XCTAssertNil(target(for: "xo", ["xco": 5]))
    }

    func testTheLearnedWordItselfIsNotRewritten() {
        // Distance 0: the caller treats it as learned and immune before asking.
        XCTAssertNil(target(for: "dictus", ["dictus": 5]))
    }

    func testAnEmptyDictionaryHasNoTarget() {
        XCTAssertNil(target(for: "dictis", [:]))
    }

    // MARK: - Choosing between learned words

    func testTheMostUsedLearnedWordWins() {
        let learned = ["dictus": 2, "dictum": 7]
        XCTAssertEqual(target(for: "dictua", learned), "dictum")
    }

    func testATieIsBrokenByTheWordSoTheAnswerIsStable() {
        let learned = ["dictum": 4, "dictus": 4]
        for _ in 0..<20 {
            XCTAssertEqual(target(for: "dictua", learned), "dictum")
        }
    }
}
