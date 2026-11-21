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

    // MARK: - Close readings are settled (#997 device test)

    // The lists below are the trie's top ten, read off the shipped dictionaries with the
    // previous word the device journal recorded. The n-gram data has no pair for any of
    // them (`est arrivé`, `suis arrivé`, `les sais`, `passai que` all score 0).

    func testAnAccentVariantOfTheSameReadingIsCorrected() {
        // `est zrrive` and `suis arribe`: `arrive` and `arrivé` are one reading.
        // Without context the more frequent spelling is written; `arrivé` is offered.
        for typed in ["zrrive", "arribe"] {
            let decision = CorrectionRanking.decide([
                candidate("arrive", 0.40, 46_814), candidate("arrivé", 0.55, 42_907),
                candidate("arriva", 1.20, 33_054), candidate("arriver", 1.40, 42_504),
                candidate("arrivée", 1.40, 37_712), candidate("arrives", 1.40, 33_700),
                candidate("arrivez", 1.40, 29_504), candidate("arrivés", 1.55, 35_334),
                typed == "zrrive" ? candidate("servie", 1.5123, 25_343) : candidate("arrose", 1.40, 25_202),
                candidate("atroce", 1.60, 30_337)
            ])
            XCTAssertEqual(decision.replacement, "arrive", typed)
            XCTAssertEqual(decision.proposal?.autocorrection?.alternatives.first, "arrivé", typed)
        }
    }

    func testTwoCloseReadingsGoToTheMoreFrequent() {
        // `zrreve`: `arrête` scores 0.003 above `arrive`, which is the more frequent.
        XCTAssertEqual(replacement([
            candidate("arrête", 1.3562, 45_984), candidate("arrive", 1.40, 46_814),
            candidate("arrivé", 1.55, 42_907), candidate("arrêté", 1.5062, 38_872),
            candidate("trêve", 1.55, 29_434), candidate("erreur", 1.80, 39_674),
            candidate("grève", 1.7903, 32_706), candidate("errer", 1.80, 26_024),
            candidate("serve", 1.8123, 27_622), candidate("artère", 1.8044, 24_859)
        ]), "arrive")
        // `les sats`: `sais` or `sans`, one key away each.
        XCTAssertEqual(replacement([
            candidate("sais", 1.00, 53_558), candidate("sans", 1.00, 52_050),
            candidate("rats", 0.8062, 33_454), candidate("date", 0.90, 35_206),
            candidate("sage", 0.9123, 35_143), candidate("sacs", 0.9434, 34_881),
            candidate("dans", 1.40, 58_363), candidate("bats", 1.00, 30_589),
            candidate("sers", 1.20, 35_631), candidate("gars", 1.40, 44_012)
        ]), "sais")
        // `passai qur`: `sur` and `que` are one neighbouring key away each and as
        // frequent. The device wanted `que`, which nothing in the data tells apart:
        // the typed word is corrected, to `sur`, and `que` is the first alternative.
        let qur = CorrectionRanking.decide([
            candidate("sur", 0.40, 55_999), candidate("que", 0.40, 55_817),
            candidate("sûr", 0.55, 48_865), candidate("qui", 1.00, 58_631),
            candidate("air", 0.8123, 47_869), candidate("dur", 0.80, 41_552),
            candidate("mur", 1.00, 40_213), candidate("sud", 0.90, 34_480),
            candidate("pur", 1.00, 35_507), candidate("sir", 0.80, 29_477)
        ])
        XCTAssertEqual(qur.replacement, "sur")
        XCTAssertEqual(qur.proposal?.autocorrection?.alternatives.first, "que")
    }

    func testContextPicksBetweenCloseReadingsBeforeFrequency() {
        XCTAssertEqual(replacement([
            candidate("sais", 1.00, 53_558), candidate("sans", 1.00, 52_050, context: 1_000)
        ]), "sans")
    }

    func testAWordOneKeyFromASingleReadingIsCorrected() {
        // `Disxord` in French: the dictionary has `discord`, one key away.
        XCTAssertEqual(replacement([
            candidate("discord", 0.40, 17_303), candidate("discorde", 1.40, 22_279),
            candidate("discours", 1.80, 37_027), candidate("dissous", 1.8472, 21_283)
        ]), "discord")
    }

    func testAClearWinnerIsNotHeldBackByRarerNeighboursOfIt() {
        // `rins` (en-learned bench): `rims`, `ribs` and `fins` are as easy to reach as
        // `runs` and score within the band, but the runner-up is `find`, a key further.
        XCTAssertEqual(replacement([
            candidate("runs", 0.40, 46_873), candidate("find", 0.8123, 55_016),
            candidate("rims", 0.40, 40_215), candidate("ribs", 0.40, 40_194),
            candidate("fins", 0.4123, 39_320), candidate("tins", 0.40, 38_118),
            candidate("wins", 0.80, 45_298), candidate("fine", 0.9123, 49_682),
            candidate("tons", 0.80, 44_551), candidate("tina", 0.80, 42_091)
        ]), "runs")
    }

    // MARK: - The typed word is kept when no reading stands out

    func testThreeCloseReadingsKeepTheTypedWord() {
        // `thursday irning`: `irving`, `inning` or `ironing`; `morning` was meant.
        XCTAssertNil(replacement([
            candidate("irving", 0.80, 41_799), candidate("inning", 1.00, 40_002),
            candidate("ironing", 1.00, 39_855), candidate("urging", 1.1211, 39_702),
            candidate("owning", 1.20, 40_663), candidate("morning", 1.40, 48_864),
            candidate("turning", 1.40, 45_536), candidate("burning", 1.40, 45_489),
            candidate("corning", 1.40, 39_286), candidate("signing", 1.6403, 43_935)
        ]))
    }

    func testAnImplausiblePickKeepsTheTypedWord() {
        // `est decalee` (meant `décalée`): `déclaré` would be picked, at -0.01.
        XCTAssertNil(replacement([
            candidate("déclare", 1.25, 31_256), candidate("dévaler", 0.95, 18_820),
            candidate("déclaré", 1.40, 31_713), candidate("dealer", 1.40, 28_317),
            candidate("déceler", 1.35, 24_155), candidate("décalé", 1.30, 16_448),
            candidate("escales", 1.4123, 17_869), candidate("défaire", 1.6375, 28_656),
            candidate("dévale", 1.55, 21_747), candidate("décampe", 1.55, 21_521)
        ]))
        // `la reùion`: `réunion` would be picked, at 0.10, against `région`.
        let decision = CorrectionRanking.decide([
            candidate("région", 1.15, 35_201), candidate("réunion", 1.30, 36_517), candidate("recoin", 1.70, 23_593)
        ])
        XCTAssertNil(decision.replacement)
        XCTAssertEqual(Array(decision.ranked.prefix(2)), ["région", "réunion"],
                       "The candidates stay ranked for whoever wants to offer them")
    }

    func testAnEnglishTypoFarFromEveryWordIsKept() {
        // `Disxord` in English, whose dictionary has no `discord`: `discard` is a
        // missing letter away and scores 0.12. Not written, offered.
        let decision = CorrectionRanking.decide([
            candidate("discard", 1.40, 39_806), candidate("discogs", 1.4403, 37_041),
            candidate("diadora", 1.6472, 36_361), candidate("discos", 1.80, 37_179),
            candidate("distort", 1.8062, 36_923)
        ])
        XCTAssertNil(decision.replacement)
        XCTAssertEqual(decision.proposal, .suggest(["discard", "discogs"]))
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
        XCTAssertEqual(CorrectionRanking.ambiguousAccentSpellings(typed: "reserve", candidates: [
            candidate("réserve", 0.15, 33_835), candidate("réservé", 0.30, 31_794),
            candidate("réserves", 1.15, 29_642), candidate("préserve", 1.15, 24_437)
        ]), ["réserve", "réservé"], "Both spellings are offered, neither is written")
    }

    func testAClearlyMoreFrequentAccentSpellingIsNotAmbiguous() {
        // `pres`: `près` is far more frequent than `prés`.
        XCTAssertNil(CorrectionRanking.ambiguousAccentSpellings(typed: "pres", candidates: [
            candidate("près", 0.15, 43_000), candidate("prés", 0.15, 32_000), candidate("pris", 1.00, 46_000)
        ]))
    }

    func testASingleAccentSpellingIsNotAmbiguous() {
        // `tres`: other candidates do not share its letters.
        XCTAssertNil(CorrectionRanking.ambiguousAccentSpellings(typed: "tres", candidates: [
            candidate("très", 0.15, 52_000), candidate("tes", 1.00, 47_000), candidate("près", 1.15, 43_000)
        ]))
    }

    // MARK: - A kept word is still suggested

    func testAKeptWordIsSuggestedButNotApplied() {
        // `la reùion`: kept as typed, as Apple's keyboard does, with both readings in
        // the bar for a tap.
        let proposal = CorrectionRanking.decide([
            candidate("région", 1.15, 35_201), candidate("réunion", 1.30, 36_517), candidate("recoin", 1.70, 23_593)
        ]).proposal
        XCTAssertEqual(proposal, .suggest(["région", "réunion"]))
        XCTAssertNil(proposal?.autocorrection, "Nothing is written on space")
        XCTAssertEqual(proposal?.suggestionRow(typedWord: "reùion"), ["reùion", "région", "réunion"],
                       "The typed word comes first and keeps it; the candidates follow")
    }

    func testASureCorrectionIsAppliedAndHasNoSuggestionRow() {
        let proposal = CorrectionRanking.decide([
            candidate("still", 0.40, 52_000), candidate("atoll", 0.40, 37_000), candidate("till", 1.00, 45_000)
        ]).proposal
        XCTAssertEqual(proposal, .autocorrect("still", alternatives: ["atoll", "till"]))
        XCTAssertEqual(proposal?.autocorrection?.correction, "still")
        XCTAssertNil(proposal?.suggestionRow(typedWord: "atill"), "Its row is the corrections row, bold slot included")
    }

    func testNoCandidateProposesNothing() {
        XCTAssertNil(CorrectionRanking.decide([]).proposal)
    }

    func testCasingIsRestoredOnEveryWord() {
        XCTAssertEqual(CorrectionProposal.suggest(["région", "réunion"]).mapWords { $0.capitalized },
                       .suggest(["Région", "Réunion"]))
        XCTAssertEqual(CorrectionProposal.autocorrect("being", alternatives: ["bering"]).mapWords { $0.capitalized },
                       .autocorrect("Being", alternatives: ["Bering"]))
    }
}
