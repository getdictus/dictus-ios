// DictusCore/Tests/DictusCoreTests/CorrectionRankingTests.swift
// Covers how an unknown word's trie candidates are ranked and when one replaces it (#993).
import XCTest
@testable import DictusCore

/// The candidate lists are the trie's, read off the shipped dictionaries for the words
/// the #954 bench typed: cost, frequency and bigram score after the previous word.
final class CorrectionRankingTests: XCTestCase {

    private func candidate(_ word: String, _ cost: Double, _ frequency: UInt16, context: UInt16 = 0) -> CorrectionCandidate {
        CorrectionCandidate(word: word, cost: cost, frequency: frequency, context: context)
    }

    private func replacement(_ candidates: [CorrectionCandidate]) -> String? {
        CorrectionRanking.decide(candidates).replacement
    }

    // MARK: - Real typos are still fixed

    func testANeighbouringKeyTypoIsFixed() {
        // `atill`: `still` and `atoll` cost the same, `still` is far more frequent.
        XCTAssertEqual(replacement([
            candidate("still", 0.40, 52_000), candidate("atoll", 0.40, 37_000), candidate("till", 1.00, 45_000)
        ]), "still")
    }

    func testACheapCorrectionBeatsAMoreFrequentDearOne() {
        // `bookes`: one slipped key to `booked`, a missing letter to `books`. The scores
        // are close, but the two are not equally easy to have mistyped.
        XCTAssertEqual(replacement([
            candidate("booked", 0.40, 41_046), candidate("books", 1.00, 54_525), candidate("hooked", 0.85, 41_000)
        ]), "booked")
    }

    func testAFrequentWordOneExtraLetterAwayBeatsARareNeighbour() {
        // `Beeing`: `bering` is one slipped key away, `being` one letter too many.
        XCTAssertEqual(replacement([
            candidate("bering", 0.40, 36_145), candidate("being", 1.00, 53_021), candidate("seeing", 1.00, 46_919)
        ]), "being")
    }

    // MARK: - Context

    func testContextLiftsANearCandidate() {
        // `an boue`: `blue` is the closest, `hour` is what follows `an`.
        XCTAssertEqual(replacement([
            candidate("blue", 0.41, 51_223), candidate("hour", 0.85, 49_674, context: 49_707),
            candidate("bone", 0.81, 45_811), candidate("boys", 0.90, 48_865)
        ]), "hour")
        // `we meef`
        XCTAssertEqual(replacement([
            candidate("meet", 0.50, 50_394), candidate("need", 0.80, 53_774, context: 50_486),
            candidate("meer", 0.41, 38_760), candidate("beef", 0.80, 44_631)
        ]), "need")
    }

    func testContextDoesNotLiftAFarCandidate() {
        // `vers lidi`: `lui` follows `vers` far more often, but it is a whole letter
        // further from what was typed than `midi`.
        XCTAssertEqual(replacement([
            candidate("midi", 0.40, 37_000), candidate("lieu", 0.81, 42_000),
            candidate("lui", 1.40, 55_000, context: 47_000), candidate("ici", 1.45, 53_000)
        ]), "midi")
    }

    func testTheContextWindowIsAnchoredOnTheWinnerNotOnTheCheapestCandidate() {
        // German `wenn ic`: the cheapest candidate is the rare English `if`, which must
        // not shut `ich` out of its context.
        XCTAssertEqual(replacement([
            candidate("ich", 1.00, 65_535, context: 56_781), candidate("in", 1.00, 58_955),
            candidate("im", 1.00, 54_267), candidate("if", 0.40, 29_459)
        ]), "ich")
    }

    // MARK: - Ambiguity keeps the typed word

    func testTwoEquallyGoodReadingsKeepTheTypedWord() {
        // `la reùion`: `région` or `réunion`, nothing says which.
        let decision = CorrectionRanking.decide([
            candidate("région", 1.15, 35_201), candidate("réunion", 1.30, 36_517), candidate("recoin", 1.70, 23_593)
        ])
        XCTAssertNil(decision.replacement)
        XCTAssertEqual(Array(decision.ranked.prefix(2)), ["région", "réunion"],
                       "The candidates stay ranked for whoever wants to offer them")
        // `thursday irning`: the n-gram data has no `thursday morning`.
        XCTAssertNil(replacement([
            candidate("irving", 0.80, 41_799), candidate("inning", 1.00, 40_002),
            candidate("ironing", 1.00, 39_855), candidate("morning", 1.40, 48_864)
        ]))
    }

    func testNoCandidateKeepsTheTypedWord() {
        XCTAssertEqual(CorrectionRanking.decide([]), .init(replacement: nil, ranked: []))
    }

    func testASingleCandidateIsTaken() {
        XCTAssertEqual(replacement([candidate("tomorrow", 1.94, 46_000)]), "tomorrow")
    }

    // MARK: - Determinism

    func testTheOrderOfTheInputDoesNotChangeTheAnswer() {
        let candidates = [
            candidate("blue", 0.41, 51_223), candidate("hour", 0.85, 49_674, context: 49_707),
            candidate("bone", 0.81, 45_811), candidate("boyd", 0.81, 41_790), candidate("bout", 0.80, 41_263)
        ]
        let expected = CorrectionRanking.decide(candidates)
        for _ in 0..<20 {
            XCTAssertEqual(CorrectionRanking.decide(candidates.shuffled()), expected)
        }
    }

    func testAnExactTieFallsToTheWord() {
        // `meef` used to be `meer` or `meet` depending on the process's hash seed.
        XCTAssertEqual(CorrectionRanking.decide([
            candidate("zeta", 0.4, 32_768), candidate("beta", 0.4, 32_768)
        ]).ranked, ["beta", "zeta"])
        XCTAssertEqual(CorrectionRanking.decide([
            candidate("beta", 0.4, 32_768), candidate("zeta", 0.4, 32_768)
        ]).ranked, ["beta", "zeta"])
    }

    // MARK: - Accent spellings

    func testTwoEquallyLikelyAccentSpellingsAreAmbiguous() {
        // `nous avons reserve`: `réserve` or `réservé`.
        XCTAssertTrue(CorrectionRanking.accentSpellingIsAmbiguous(typed: "reserve", candidates: [
            candidate("réserve", 0.15, 33_835), candidate("réservé", 0.30, 31_794),
            candidate("réserves", 1.15, 29_642), candidate("préserve", 1.15, 24_437)
        ]))
    }

    func testAClearlyMoreFrequentAccentSpellingIsNotAmbiguous() {
        // `pres`: `près` is far more frequent than `prés`.
        XCTAssertFalse(CorrectionRanking.accentSpellingIsAmbiguous(typed: "pres", candidates: [
            candidate("près", 0.15, 43_000), candidate("prés", 0.15, 32_000), candidate("pris", 1.00, 46_000)
        ]))
    }

    func testASingleAccentSpellingIsNotAmbiguous() {
        // `tres`: other candidates do not share its letters.
        XCTAssertFalse(CorrectionRanking.accentSpellingIsAmbiguous(typed: "tres", candidates: [
            candidate("très", 0.15, 52_000), candidate("tes", 1.00, 47_000), candidate("près", 1.15, 43_000)
        ]))
    }
}
