// DictusCore/Tests/DictusCoreTests/DriftRetrySpliceTests.swift
// Choosing among a #623 span's re-decodes and splicing the winner back.
import XCTest
@testable import DictusCore

final class DriftRetrySpliceTests: XCTestCase {

    private func piece(_ token: String, _ frame: Int, _ confidence: Float = 0.99) -> DriftRetryPiece {
        SyntheticTokens.piece(token, frame: frame, confidence: confidence)
    }

    private func text(_ pieces: [DriftRetryPiece]) -> String { DriftRetryText.text(of: pieces) }

    // MARK: - Selection

    func testTheMostConfidentCandidateWins() {
        let firstPass = [piece(" and", 10, 0.6), piece(" Boche", 12, 0.5)]
        let candidates = [[piece(" et", 10, 0.9)], [piece(" et", 10, 0.97), piece(" une", 12, 0.95)], []]
        XCTAssertEqual(DriftRetrySelection.winner(candidates: candidates, firstPass: firstPass), 1)
    }

    /// The first pass is one of the candidates, and keeps the span on a tie.
    func testTheFirstPassWinsATie() {
        let firstPass = [piece(" bonjour", 10, 0.9)]
        XCTAssertNil(DriftRetrySelection.winner(candidates: [[piece(" bonsoir", 10, 0.9)]], firstPass: firstPass))
    }

    /// An empty re-decode is the 0.100 failure mode: it has no score and cannot win.
    func testAnEmptyCandidateNeverWins() {
        XCTAssertNil(DriftRetrySelection.winner(candidates: [[], [], [piece(".", 10, 1)]], firstPass: []))
    }

    func testPunctuationDoesNotScore() {
        let firstPass = [piece(" oui", 10, 0.8)]
        let padded = [piece(" non", 10, 0.7), piece(".", 12, 1.0), piece(",", 13, 1.0)]
        XCTAssertNil(DriftRetrySelection.winner(candidates: [padded], firstPass: firstPass))
    }

    // MARK: - Word range

    func testAWordRangeSkipsALeadingContinuationAndFinishesATrailingWord() {
        let pieces = [piece(" bon", 8), piece("jour", 10), piece(" tout", 12), piece(" le", 14), piece(" mon", 18), piece("de", 22)]
        let range = DriftRetrySplice.wordRange(in: pieces, fromFrame: 10, toFrame: 20)
        XCTAssertEqual(range, 2..<6, "`jour` belongs to the word before; `de` finishes `monde`")
    }

    func testAnEmptyWordRangeWhenNothingStartsInside() {
        let pieces = [piece(" un", 2), piece(" deux", 40)]
        XCTAssertTrue(DriftRetrySplice.wordRange(in: pieces, fromFrame: 10, toFrame: 20).isEmpty)
    }

    // MARK: - Splice

    func testTheWinnerReplacesOnlyItsRange() {
        let firstPass = [piece(" Sur", 0), piece(" le", 2), piece(" chemin", 4), piece(" I", 8, 0.4), piece(" crossed", 10, 0.4),
                         piece(" my", 12, 0.4), piece(" voisin", 14), piece(".", 16)]
        let choice = DriftRetryChoice(range: 3..<6, pieces: [piece(" j'ai", 8), piece(" croisé", 10), piece(" ma", 12)],
                                      keepsFirstPass: false)
        let spliced = DriftRetrySplice.splice(firstPass: firstPass, choices: [choice])
        XCTAssertEqual(text(spliced), "Sur le chemin j'ai croisé ma voisin.")
    }

    func testAWinnerRepeatingTheWordsAcrossItsSeamsIsDeduped() {
        let firstPass = [piece(" il", 0), piece(" faisait", 2), piece(" très", 4), piece(" showing", 8, 0.3),
                         piece(" chaud", 12), piece(" ce", 14)]
        // The re-decode heard a little past both edges.
        let candidate = [piece(" très", 6), piece(" chaud", 8), piece(" ce", 12)]
        let spliced = DriftRetrySplice.splice(
            firstPass: firstPass, choices: [DriftRetryChoice(range: 3..<4, pieces: candidate, keepsFirstPass: false)])
        XCTAssertEqual(text(spliced), "il faisait très chaud ce",
                       "`très` is already before the seam and `chaud ce` already after it")
    }

    /// "Keep the first pass" must reproduce its tokens exactly, duplicates and all.
    func testAFirstPassChoiceIsNeverDeduped() {
        let firstPass = [piece(" de", 0), piece(" de", 2), piece(" la", 4)]
        let spliced = DriftRetrySplice.splice(
            firstPass: firstPass, choices: [DriftRetryChoice(range: 1..<2, pieces: [firstPass[1]], keepsFirstPass: true)])
        XCTAssertEqual(spliced, firstPass)
    }

    func testDedupeLooksAtThreeWordsAtMost() {
        let before = [piece(" a", 0), piece(" b", 1), piece(" c", 2), piece(" d", 3)]
        let candidate = [piece(" a", 4), piece(" b", 5), piece(" c", 6), piece(" d", 7), piece(" e", 8)]
        let kept = DriftRetrySplice.dedupeSeams(candidate, before: before, after: [])
        XCTAssertEqual(text(kept), "a b c d e", "the 4-word repeat is not a seam artifact")
        let three = DriftRetrySplice.dedupeSeams([piece(" b", 4), piece(" c", 5), piece(" d", 6), piece(" e", 7)],
                                                 before: before, after: [])
        XCTAssertEqual(text(three), "e")
    }

    func testDedupeComparesNormalisedWords() {
        let before = [piece(" qu", 0), piece("\u{2019}", 1), piece("elle", 2)]
        let candidate = [piece(" Qu", 3), piece("'", 4), piece("elle", 5), piece(",", 6), piece(" venait", 7)]
        let kept = DriftRetrySplice.dedupeSeams(candidate, before: before, after: [])
        XCTAssertEqual(text(kept), "venait", "case, apostrophe style and the comma left behind all fold away")
    }

    /// Two spans that touch: the first one's tail is compared with the second one's chosen text.
    func testTouchingSpansDedupeAgainstEachOthersChoice() {
        let firstPass = [piece(" x", 0, 0.3), piece(" y", 10, 0.3), piece(" fin", 20)]
        let first = DriftRetryChoice(range: 0..<1, pieces: [piece(" un", 0), piece(" deux", 6)], keepsFirstPass: false)
        let second = DriftRetryChoice(range: 1..<2, pieces: [piece(" deux", 9), piece(" trois", 12)], keepsFirstPass: false)
        let spliced = DriftRetrySplice.splice(firstPass: firstPass, choices: [second, first])
        XCTAssertEqual(text(spliced), "un deux trois fin")
    }
}
