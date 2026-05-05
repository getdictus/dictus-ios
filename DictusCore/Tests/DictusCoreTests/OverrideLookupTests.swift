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
