// DictusCore/Tests/DictusCoreTests/BilingualCheckSplitTests.swift
// #1071: the active language never splits a word the other language has.
import XCTest
@testable import DictusCore

/// The words of #1071's bench run (`tools/keyboard-bench/corpus/mixed-1071.txt`), with the
/// split each window's engine wrote on `feature/bilingual-check` (4f661f78), traced by
/// `KB_TRACE=1 run.sh --pair fr,en --langs mixed-1071`. Frequencies read with `--probe`
/// on 2026-11-25.
final class BilingualCheckSplitTests: XCTestCase {

    private func french() -> StubEvidence {
        var french = ShippedDictionaries.french
        french.words["franchement"] = -6.79
        french.words["probablement"] = -6.19
        french.words["magnifique"] = -6.16
        french.words["sinon"] = -5.33
        return french
    }

    private func english() -> StubEvidence {
        var english = ShippedDictionaries.english
        english.words["its"] = -3.78
        english.words["raining"] = -9.72
        english.words["cement"] = -8.37
        english.words["basement"] = -8.20
        english.words["unique"] = -5.90
        english.words["notebook"] = -8.0
        english.words["rainbow"] = -8.5
        english.words["tonight"] = -6.5
        english.words["lot"] = -5.38
        english.words["alot"] = -8.27
        return english
    }

    private func decide(_ word: String, before: String, split: String, active: StubEvidence,
                        other: StubEvidence) -> BilingualCheck.Decision {
        BilingualCheck.decide(
            word, before: before, active: active, other: other,
            own: { _ in .autocorrect(split, alternatives: []) }, theirs: { nil }
        )
    }

    /// The issue's sentence: after `its raining`, the English window wrote `fra cement`.
    func testAFrenchWordAfterEnglishWordsIsNotSplit() {
        let decision = decide("franchement", before: "its raining ", split: "fra cement",
                              active: english(), other: french())
        XCTAssertNil(decision.proposal)
        XCTAssertEqual(decision.rule, .keptUnsplit)
    }

    func testOtherFrenchWordsAfterEnglishWordsAreNotSplit() {
        let cases = [
            ("probablement", "the meeting was ", "pro basement"),
            ("magnifique", "the view was ", "mag unique"),
            ("sinon", "we can go now ", "si on")
        ]
        for (word, before, split) in cases {
            let decision = decide(word, before: before, split: split, active: english(), other: french())
            XCTAssertNil(decision.proposal, word)
            XCTAssertEqual(decision.rule, .keptUnsplit, word)
        }
    }

    /// The other way: a French window split English words after French ones.
    func testAnEnglishWordAfterFrenchWordsIsNotSplit() {
        let cases = [
            ("notebook", "j'ai perdu mon ", "note moi"),
            ("rainbow", "on regarde le ", "rai nos"),
            ("tonight", "je sors ", "to light")
        ]
        for (word, before, split) in cases {
            let decision = decide(word, before: before, split: split, active: french(), other: english())
            XCTAssertNil(decision.proposal, word)
            XCTAssertEqual(decision.rule, .keptUnsplit, word)
        }
    }

    /// A real missed space stays fixed: French does not have `alot`.
    func testAMissedSpaceNeitherLanguageHasIsStillSplit() {
        let decision = decide("alot", before: "thanks ", split: "a lot", active: english(), other: french())
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "a lot")
        XCTAssertEqual(decision.rule, .active)
    }

    /// The rule is about splits: a one-word fix of a word the other language has still
    /// goes through the frequency rules (`call` stays, `fait` becomes French's fix).
    func testAOneWordFixIsLeftToTheFrequencyRules() {
        let decision = decide("fait", before: "", split: "faut", active: ShippedDictionaries.french,
                              other: ShippedDictionaries.english)
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "faut")
    }

    /// An elision is no split: English has `cest`, and French's `c'est` still stands.
    func testAnElisionIsNoSplit() {
        var english = ShippedDictionaries.english
        english.words["cest"] = -8.52
        let decision = decide("cest", before: "", split: "c'est", active: ShippedDictionaries.french, other: english)
        XCTAssertEqual(decision.proposal?.autocorrection?.correction, "c'est")
    }
}
