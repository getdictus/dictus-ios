// DictusCore/Tests/DictusCoreTests/AccentExpanderTests.swift
// Algorithm-level regression tests for restoreAccents: which spellings it generates,
// driven by a LanguageProfile + FrequencyProvider. The decision itself is pinned on
// real corpus counts in AccentRestorationTests.
import XCTest
@testable import DictusCore

final class AccentExpanderTests: XCTestCase {

    // MARK: - French single-substitution

    func test_french_tres_correctsToTresGrave_whenInputAbsentFromDict() {
        // "tres" not in dict (input freq = 0) → any matching variant wins.
        let provider = MockFrequencyProvider(frequencies: [
            "tr\u{00E8}s": 50_000  // "très"
        ])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "tres", provider: provider), .restore("tr\u{00E8}s")
        )
    }

    // MARK: - French double-substitution

    func test_french_apres_correctsToApresGrave_pickingHighestFrequency() {
        // Both "âpres" and "après" are valid words; "après" is much more common.
        let provider = MockFrequencyProvider(frequencies: [
            "\u{00E2}pres": 200,        // âpres (rare)
            "apr\u{00E8}s": 60_000,     // après (common)
        ])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "apres", provider: provider), .restore("apr\u{00E8}s")
        )
    }

    func test_french_deja_correctsToDeja_doubleSubstitution() {
        let provider = MockFrequencyProvider(frequencies: [
            "d\u{00E9}j\u{00E0}": 60_000  // déjà
        ])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "deja", provider: provider), .restore("d\u{00E9}j\u{00E0}")
        )
    }

    // MARK: - Typed word odds

    func test_french_publie_keepsTyped_whenInputItselfIsValidAndNotDominated() {
        // "publie" is a valid French verb form (je publie). The accented "publié"
        // exists too, but only ~3x more common.
        let provider = MockFrequencyProvider(frequencies: [
            "publie": 10_000,
            "publi\u{00E9}": 30_000,  // 3x — below `typedWordOdds`
        ])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "publie", provider: provider), .keepTyped)
    }

    func test_french_publie_correctsToPublie_when10xDominated() {
        let provider = MockFrequencyProvider(frequencies: [
            "publie": 1_000,
            "publi\u{00E9}": 11_000,  // 11x over 1_000 — above `typedWordOdds`
        ])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "publie", provider: provider), .restore("publi\u{00E9}")
        )
    }

    func test_french_typedWordOdds_skippedWhenInputAbsentFromDict() {
        // When the unaccented form is not in the dict at all, ANY matching
        // accented form wins — even at low frequency.
        let provider = MockFrequencyProvider(frequencies: [
            "rarewordwithaccent\u{00E9}": 5  // tiny frequency, but unaccented form is absent
        ])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "rarewordwithaccente", provider: provider), .restore("rarewordwithaccent\u{00E9}")
        )
    }

    // MARK: - Spanish

    func test_spanish_espanol_correctsToEspanol() {
        let provider = MockFrequencyProvider(frequencies: [
            "espa\u{00F1}ol": 60_000  // español
        ])
        XCTAssertEqual(restoreAccents(profile: spanishProfile, word: "espanol", provider: provider), .restore("espa\u{00F1}ol")
        )
    }

    // MARK: - English (empty accent map)

    func test_english_keepsTyped_becauseAccentMapEmpty() {
        let provider = MockFrequencyProvider(frequencies: [
            "caf\u{00E9}": 60_000  // even if "café" is in dict
        ])
        XCTAssertEqual(restoreAccents(profile: englishProfile, word: "cafe", provider: provider), .keepTyped)
    }

    // MARK: - Negative cases

    func test_keepsTyped_whenNoAccentablePositions() {
        // "xyz" has no characters in the French accent map.
        let provider = MockFrequencyProvider(frequencies: [:])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "xyz", provider: provider), .keepTyped)
    }

    func test_keepsTyped_whenNoVariantMatchesDict() {
        let provider = MockFrequencyProvider(frequencies: [:])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "tres", provider: provider), .keepTyped)
    }

    func test_keepsTyped_forShortInput() {
        let provider = MockFrequencyProvider(frequencies: [
            "\u{00E0}": 1000
        ])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "a", provider: provider), .keepTyped)
    }

    func test_keepsTyped_whenProviderNotReady() {
        let provider = MockFrequencyProvider(
            isReady: false,
            frequencies: ["tr\u{00E8}s": 50_000]
        )
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "tres", provider: provider), .keepTyped)
    }

    // MARK: - Frequency-fallback behavior (freq=0 but wordExists)

    func test_picksWordExistsFallback_whenAllFrequenciesAreZero() {
        // Edge case: word is in dict but `frequency(of:)` returns 0.
        // Algorithm falls back to `wordExists` and picks it (with bestFreq=0).
        // MockFrequencyProvider returns 0 for nil, but wordExists is true if key present.
        // To simulate freq=0 with key present, set frequency value to 0 in dict.
        let provider = MockFrequencyProvider(frequencies: [
            "tr\u{00E8}s": 0  // present in dict (wordExists = true) but freq=0
        ])
        XCTAssertEqual(restoreAccents(profile: frenchProfile, word: "tres", provider: provider), .restore("tr\u{00E8}s")
        )
    }
}
