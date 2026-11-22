// DictusCore/Tests/DictusCoreTests/GluedWordSplitTests.swift
// Which split of a glued word is proposed, and how its halves are written (#1006).
import XCTest
@testable import DictusCore

/// Counts and bigram scores are the French dictionary's, read from the shipped
/// `fr_frequency.json` and `fr_ngrams.dict` (2026-11-21). Stored frequencies are the
/// trie's log-scaled values.
final class GluedWordSplitTests: XCTestCase {

    private let french = LogNormalizedFrequencyProvider(rawFrequencies: [
        "suis": 144_878, "arrive": 41_680, "arriv\u{00E9}": 17_151,
        "donne": 32_552, "don": 3_390, "quoi": 115_401,
    ], maxFrequency: 2_933_327)

    private func candidate(_ left: String, _ right: String, boundary: Bool, bigram: UInt16) -> GluedWordSplit.Candidate {
        GluedWordSplit.Candidate(
            left: left, right: right, usesBoundaryKey: boundary, bigram: bigram,
            frequencyProduct: UInt64(french.frequency(of: left)) * UInt64(french.frequency(of: right))
        )
    }

    private func written(_ candidate: GluedWordSplit.Candidate, after previous: String? = nil) -> String {
        GluedWordSplit.written(candidate, previousWord: previous) {
            restoreAccents(profile: frenchProfile, word: $0, previousWord: $1, provider: french)
        }
    }

    // MARK: - Choosing the split

    func testASplitWithABigramBeatsABoundarySplitWithout() {
        // `donnequoi`: cut at the `n` next to the spacebar, `equoi` is corrected to `quoi`.
        let boundary = candidate("don", "quoi", boundary: true, bigram: 0)
        let direct = candidate("donne", "quoi", boundary: false, bigram: 22_349)
        XCTAssertEqual(GluedWordSplit.best([boundary, direct]), direct, "device test 2026-11-20")
        XCTAssertEqual(GluedWordSplit.best([direct, boundary]), direct, "whatever the order")
    }

    func testABoundarySplitWithABigramBeatsADirectOne() {
        let boundary = candidate("suis", "arrive", boundary: true, bigram: 10)
        let direct = candidate("donne", "quoi", boundary: false, bigram: 22_349)
        XCTAssertEqual(GluedWordSplit.best([direct, boundary]), boundary)
    }

    func testWithoutBigramsTheBoundarySplitStillWins() {
        let boundary = candidate("suis", "arrive", boundary: true, bigram: 0)
        XCTAssertEqual(GluedWordSplit.best([boundary]), boundary)
        XCTAssertNil(GluedWordSplit.best([]))
    }

    func testTheBigramAfterThePreviousWordBreaksATie() {
        let plain = GluedWordSplit.Candidate(
            left: "don", right: "quoi", usesBoundaryKey: true, bigram: 0, contextBigram: 0, frequencyProduct: 100
        )
        let inContext = GluedWordSplit.Candidate(
            left: "donne", right: "quoi", usesBoundaryKey: true, bigram: 0, contextBigram: 5, frequencyProduct: 100
        )
        XCTAssertEqual(GluedWordSplit.best([plain, inContext]), inContext)
    }

    func testTheScoreDoesNotOverflowOnTheMostFrequentWords() {
        let top = GluedWordSplit.Candidate(
            left: "de", right: "la", usesBoundaryKey: false, bigram: .max, contextBigram: .max,
            frequencyProduct: UInt64(UInt16.max) * UInt64(UInt16.max)
        )
        XCTAssertEqual(GluedWordSplit.best([top]), top)
    }

    // MARK: - Writing the halves

    func testTheRightHalfTakesItsAccentAfterTheLeftOne() {
        let split = candidate("suis", "arrive", boundary: true, bigram: 0)
        XCTAssertEqual(written(split), "suis arriv\u{00E9}", "suisnarrive, device test 2026-11-20")
        XCTAssertEqual(written(split, after: "je"), "suis arriv\u{00E9}")
    }

    func testAHalfWithoutAParticipleContextStaysAsTyped() {
        XCTAssertEqual(written(candidate("donne", "quoi", boundary: false, bigram: 22_349)), "donne quoi")
        XCTAssertEqual(written(candidate("quoi", "arrive", boundary: true, bigram: 0)), "quoi arrive")
    }
}
