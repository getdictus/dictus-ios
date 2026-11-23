// DictusCore/Tests/DictusCoreTests/ElisionOnsetTests.swift
// French never elides before a consonant: `d'cirre` must not become `d'votre`.
import XCTest
@testable import DictusCore

final class ElisionOnsetTests: XCTestCase {

    // MARK: - The rule

    func test_french_rejectsAConsonantAfterEveryElisionPrefix() {
        let prefixes = ["d'", "l'", "j'", "m'", "n'", "t'", "s'", "c'", "qu'", "jusqu'", "lorsqu'", "puisqu'"]
        for prefix in prefixes {
            for word in ["votre", "dire", "maison", "bombe", "quelle", "\u{00E7}a", "pelle"] {
                XCTAssertFalse(frenchProfile.allowsElided(word, after: prefix), "\(prefix)\(word)")
                XCTAssertFalse(frenchProfile.allowsElision(prefix + word), "\(prefix)\(word)")
            }
        }
    }

    func test_french_allowsVowelsAccentedVowelsYAndH() {
        let words = [
            "l'homme", "l'h\u{00F4}tel", "j'ai", "qu'il", "s'il", "jusqu'\u{00E0}", "d'accord", "l'\u{00E9}t\u{00E9}",
            "j'y", "l'\u{0153}uvre", "d'\u{00EA}tre", "c'\u{00E9}tait", "l'\u{00EE}le", "l'\u{00E2}ge", "d'o\u{00F9}",
            "lorsqu'elle", "puisqu'on", "n'est", "m'appelle", "t'aime", "l'eau", "d'abord", "l'\u{00E6}ther"
        ]
        for word in words {
            XCTAssertTrue(frenchProfile.allowsElision(word), word)
        }
    }

    func test_french_readsCapitalsAndTheTypographicApostrophe() {
        XCTAssertFalse(frenchProfile.allowsElision("D'votre"))
        XCTAssertFalse(frenchProfile.allowsElision("d\u{2019}votre"))
        XCTAssertFalse(frenchProfile.allowsElided("Votre", after: "D'"))
        XCTAssertTrue(frenchProfile.allowsElision("L'Homme"))
        XCTAssertTrue(frenchProfile.allowsElision("l\u{2019}homme"))
    }

    /// Only the listed prefixes elide: `aujourd'hui` and a word with no apostrophe pass.
    func test_french_leavesOtherApostrophesAndPlainWordsAlone() {
        XCTAssertTrue(frenchProfile.allowsElision("votre"))
        XCTAssertTrue(frenchProfile.allowsElision("aujourd'hui"))
        XCTAssertTrue(frenchProfile.allowsElided("votre", after: nil))
        XCTAssertTrue(frenchProfile.allowsElided("votre", after: "aujourd'"))
    }

    /// Every elision `ElisionRepair` writes from a slip or a space already starts with a
    /// vowel; the rule must never have to reject one.
    func test_french_everyRepairedElisionPassesTheRule() throws {
        let repair = try XCTUnwrap(frenchProfile.elisionRepair)
        for (prefix, words) in repair.elidedWords {
            for word in words {
                XCTAssertTrue(frenchProfile.allowsElided(word, after: prefix + "'"), "\(prefix)'\(word)")
            }
        }
    }

    // MARK: - English is untouched

    func test_english_hasNoElisionRule() {
        XCTAssertNil(englishProfile.elisionOnset)
        for word in ["don't", "it's", "i'm", "I'm", "you're", "can't", "d'votre"] {
            XCTAssertTrue(englishProfile.allowsElision(word), word)
        }
    }

    /// English contractions are not French elision prefixes, so even the French rule
    /// passes them.
    func test_french_rule_passesEnglishContractions() {
        for word in ["don't", "it's", "i'm", "you're", "can't", "won't", "they're", "let's"] {
            XCTAssertTrue(frenchProfile.allowsElision(word), word)
        }
    }

    func test_english_contractionOverridesAreUnchanged() {
        XCTAssertEqual(englishProfile.overrides["dont"], "don't")
        XCTAssertEqual(englishProfile.overrides["im"], "i'm")
        XCTAssertTrue(englishProfile.contextualContractions.contains { $0.word == "its" && $0.contraction == "it's" })
    }

    // MARK: - The trie pass, on the candidates the shipped French trie gives

    /// What `TextPredictionEngine.trieCorrection` does: drop the candidates the prefix
    /// cannot take, then rank the rest.
    private func decide(_ candidates: [CorrectionCandidate], after prefix: String) -> CorrectionRanking.Decision {
        CorrectionRanking.decide(candidates.filter { frenchProfile.allowsElided($0.word, after: prefix) })
    }

    private func candidates(_ rows: [(String, Double, UInt16)]) -> [CorrectionCandidate] {
        rows.map { CorrectionCandidate(word: $0.0, cost: $0.1, frequency: $0.2) }
    }

    /// The device report: `d'cirre` gave `d'votre`. The trie's ten candidates for
    /// `cirre` all start with a consonant, so the typed word is kept and nothing is offered.
    func test_dCirre_neverGivesAConsonantWord() {
        let cirre = candidates([
            ("votre", 1.2, 52313), ("vitre", 0.8, 33347), ("corde", 0.9, 35198), ("cidre", 0.5, 24471),
            ("cirer", 0.7, 25493), ("vivre", 1.254, 43777), ("virer", 1.1, 33460), ("cire", 1.0, 29668),
            ("dire", 1.447, 51965), ("forte", 1.247, 37347)
        ])
        XCTAssertEqual(CorrectionRanking.decide(cirre).replacement, "votre", "the bug this guards against")

        let decision = decide(cirre, after: "d'")
        XCTAssertNil(decision.replacement)
        XCTAssertNil(decision.proposal)
    }

    func test_typosAfterAnElision_stillCorrectToAVowelOrHWord() {
        let homne = candidates([
            ("homme", 1.0, 49697), ("bombe", 0.847, 36342), ("tombe", 1.04, 38607), ("tomb\u{00E9}", 1.19, 38167),
            ("hymne", 1.0, 27979), ("bonne", 1.447, 47558), ("home", 1.0, 25412), ("bomb\u{00E9}", 0.997, 19551),
            ("nomme", 1.447, 30150), ("gomme", 1.4, 27375)
        ])
        XCTAssertEqual(decide(homne, after: "l'").proposal, .autocorrect("homme", alternatives: ["hymne", "home"]))

        let hotrl = candidates([
            ("h\u{00F4}tel", 0.4, 41281), ("notre", 1.597, 50300), ("h\u{00F4}te", 1.4, 31434),
            ("n\u{00F4}tre", 1.447, 33528), ("h\u{00F4}tels", 1.4, 30127), ("motel", 1.55, 28435)
        ])
        XCTAssertEqual(decide(hotrl, after: "l'").replacement, "h\u{00F4}tel")

        let abird = candidates([
            ("abord", 0.4, 24828), ("bord", 1.4, 41076), ("abris", 1.1, 26311), ("agite", 1.26, 28231),
            ("aviez", 1.44, 36513), ("agir", 1.447, 35930)
        ])
        XCTAssertEqual(decide(abird, after: "d'").replacement, "abord")

        let ik = candidates([
            ("il", 0.4, 62281), ("ok", 0.4, 42730), ("un", 1.121, 61790), ("on", 1.121, 59510), ("in", 0.721, 36098)
        ])
        XCTAssertEqual(decide(ik, after: "qu'").replacement, "il")
        XCTAssertEqual(decide(ik, after: "s'").replacement, "il")

        let ao = candidates([("ai", 0.4, 56840), ("au", 0.8, 56995), ("a", 1.0, 58024), ("si", 1.04, 53134)])
        XCTAssertEqual(decide(ao, after: "j'").replacement, "ai")
    }

    /// `d'vptre`: `votre` is the trie's clear winner and is dropped; no other candidate
    /// starts with a vowel, so the typed word is kept.
    func test_dVptre_keepsTheTypedWord() {
        let vptre = candidates([
            ("votre", 0.4, 52313), ("notre", 1.2, 50300), ("vitre", 0.8, 33347), ("v\u{00F4}tre", 1.0, 34713),
            ("voter", 1.1, 28414), ("cotre", 0.8, 17635)
        ])
        XCTAssertNil(decide(vptre, after: "d'").proposal)
    }

    // MARK: - Contraction expansion

    func test_contractionExpansion_neverGluesAPrefixToAConsonant() {
        let provider = MockFrequencyProvider(frequencies: ["votre": 1000, "maison": 1000, "homme": 1000, "h\u{00F4}tel": 900])
        XCTAssertNil(expandContractions(profile: frenchProfile, word: "dvotre", provider: provider))
        XCTAssertNil(expandContractions(profile: frenchProfile, word: "lmaison", provider: provider))
        XCTAssertEqual(expandContractions(profile: frenchProfile, word: "lhomme", provider: provider), "l'homme")
    }
}
