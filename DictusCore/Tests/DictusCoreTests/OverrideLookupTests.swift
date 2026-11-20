// DictusCore/Tests/DictusCoreTests/OverrideLookupTests.swift
// Algorithm-level regression tests for applyOverride.
// Confirms that the override-lookup behavior previously inside AOSPTrieEngine
// is preserved exactly when driven against each language's profile.
import XCTest
@testable import DictusCore

final class OverrideLookupTests: XCTestCase {

    // MARK: - French overrides (regression vs. legacy AOSPTrieEngine.languageOverride)

    func test_french_caCorrectsToCaCedille() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "ca"), "\u{00E7}a")
    }

    func test_french_capitalizedCa_capitalizesCorrection() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "Ca"), "\u{00C7}a")
    }

    func test_french_tresCorrectsToTresGrave() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "tres"), "tr\u{00E8}s")
    }

    func test_french_apresCorrectsToApres() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "apres"), "apr\u{00E8}s")
    }

    func test_french_dejaCorrectsToDeja() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "deja"), "d\u{00E9}j\u{00E0}")
    }

    func test_french_eteCorrectsToEte() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "ete"), "\u{00E9}t\u{00E9}")
    }

    func test_french_unknownWordReturnsNil() {
        XCTAssertNil(applyOverride(profile: frenchProfile, word: "bonjour"))
    }

    // MARK: - Missed-apostrophe contractions colliding with rare dictionary words (#222)

    func test_french_laiCorrectsToLApostropheAi() {
        // "lai" (medieval poem, freq 77) is a real dictionary word, so the
        // valid-word guard would protect it and "je lai vu" would never
        // correct. The override wins over the rare word.
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "lai"), "l'ai")
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "Lai"), "L'ai")
    }

    func test_french_lestCorrectsToLApostropheEst() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "lest"), "l'est")
    }

    func test_french_louvreIsNotOverridden() {
        // "louvre" must NOT be overridden: the lookup re-capitalizes, so an
        // override would corrupt "Louvre" (the museum) into "L'ouvre".
        XCTAssertNil(applyOverride(profile: frenchProfile, word: "louvre"))
        XCTAssertNil(applyOverride(profile: frenchProfile, word: "Louvre"))
    }

    func test_french_excludedAmbiguousWordsReturnNil() {
        // These words are valid in French — they must NOT be overridden.
        XCTAssertNil(applyOverride(profile: frenchProfile, word: "a"))
        XCTAssertNil(applyOverride(profile: frenchProfile, word: "ou"))
        XCTAssertNil(applyOverride(profile: frenchProfile, word: "meme"))
    }

    // MARK: - English overrides

    func test_english_imCorrectsToIm() {
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "im"), "i'm")
    }

    func test_english_capitalizedIm_capitalizesCorrection() {
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "Im"), "I'm")
    }

    func test_english_dontCorrectsToDont() {
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "dont"), "don't")
    }

    func test_english_youreCorrectsToYoure() {
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "youre"), "you're")
    }

    func test_english_excludedAmbiguousWordsReturnNil() {
        // Valid English words — must NOT be overridden.
        XCTAssertNil(applyOverride(profile: englishProfile, word: "were"))
        XCTAssertNil(applyOverride(profile: englishProfile, word: "well"))
        XCTAssertNil(applyOverride(profile: englishProfile, word: "its"))
        XCTAssertNil(applyOverride(profile: englishProfile, word: "lets"))
        XCTAssertNil(applyOverride(profile: englishProfile, word: "wont"))
        XCTAssertNil(applyOverride(profile: englishProfile, word: "ill"))
    }

    // MARK: - Known misspellings (#995)

    func test_english_listedMisspellingsCorrectToTheirTarget() {
        // Left to the trie, these became ten, relieve, deprive and asn.
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "teh"), "the")
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "recieve"), "receive")
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "beleive"), "believe")
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "adn"), "and")
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "Definately"), "Definitely")
    }

    func test_english_listedRealWordsAreNotCorrected() {
        // Named by the source list, kept because they are words.
        XCTAssertNil(applyOverride(profile: englishProfile, word: "thru"))
        XCTAssertNil(applyOverride(profile: englishProfile, word: "loosing"))
    }

    func test_spanish_listedMisspellingsCorrectToTheirTarget() {
        XCTAssertEqual(applyOverride(profile: spanishProfile, word: "desici\u{00F3}n"), "decisi\u{00F3}n")
        XCTAssertEqual(applyOverride(profile: spanishProfile, word: "llendo"), "yendo")
    }

    func test_spanish_missingAccentIsNotAMisspelling() {
        // The accent rule's case (#994), not this list's.
        XCTAssertNil(applyOverride(profile: spanishProfile, word: "tambien"))
    }

    // MARK: - Spanish overrides (empty per ADR 0001)

    func test_spanish_anyWordReturnsNilBecauseOverridesEmpty() {
        XCTAssertNil(applyOverride(profile: spanishProfile, word: "espanol"))
        XCTAssertNil(applyOverride(profile: spanishProfile, word: "que"))
        XCTAssertNil(applyOverride(profile: spanishProfile, word: "no"))
    }

    // MARK: - Case handling

    func test_uppercaseFirstLetter_correctionIsCapitalized() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "Tres"), "Tr\u{00E8}s")
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "Dont"), "Don't")
    }

    func test_allCapsInput_onlyFirstLetterCapitalized() {
        // Matches legacy behavior: capitalize() lowercases all but first.
        XCTAssertEqual(applyOverride(profile: englishProfile, word: "DONT"), "Don't")
    }
}
