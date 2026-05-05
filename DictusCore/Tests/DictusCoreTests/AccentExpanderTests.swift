// DictusCore/Tests/DictusCoreTests/AccentExpanderTests.swift
// Algorithm-level regression tests for expandAccents.
// Confirms the accent-expansion behavior previously inside
// AOSPTrieEngine.accentExpansion is preserved when driven by a
// LanguageProfile + FrequencyProvider — including the 5x dominance rule.
import XCTest
@testable import DictusCore

final class AccentExpanderTests: XCTestCase {

    // MARK: - French single-substitution

    func test_french_tres_correctsToTresGrave_whenInputAbsentFromDict() {
        // "tres" not in dict (input freq = 0) → any matching variant wins.
        let provider = MockFrequencyProvider(frequencies: [
            "tr\u{00E8}s": 50_000  // "très"
        ])
        XCTAssertEqual(
            expandAccents(profile: frenchProfile, word: "tres", provider: provider),
            "tr\u{00E8}s"
        )
    }

    // MARK: - French double-substitution

    func test_french_apres_correctsToApresGrave_pickingHighestFrequency() {
        // Both "âpres" and "après" are valid words; "après" is much more common.
        let provider = MockFrequencyProvider(frequencies: [
            "\u{00E2}pres": 200,        // âpres (rare)
            "apr\u{00E8}s": 60_000,     // après (common)
        ])
        XCTAssertEqual(
            expandAccents(profile: frenchProfile, word: "apres", provider: provider),
            "apr\u{00E8}s"
        )
    }

    func test_french_deja_correctsToDeja_doubleSubstitution() {
        let provider = MockFrequencyProvider(frequencies: [
            "d\u{00E9}j\u{00E0}": 60_000  // déjà
        ])
        XCTAssertEqual(
            expandAccents(profile: frenchProfile, word: "deja", provider: provider),
            "d\u{00E9}j\u{00E0}"
        )
    }

    // MARK: - 5x dominance rule

    func test_french_publie_returnsNil_whenInputItselfIsValidAndNotDominated() {
        // "publie" is a valid French verb form (je publie). The accented "publié"
        // exists too, but only ~3x more common. The 5x rule rejects.
        let provider = MockFrequencyProvider(frequencies: [
            "publie": 10_000,
            "publi\u{00E9}": 30_000,  // 3x dominance — below threshold
        ])
        XCTAssertNil(expandAccents(profile: frenchProfile, word: "publie", provider: provider))
    }

    func test_french_publie_correctsToPublie_when5xDominated() {
        let provider = MockFrequencyProvider(frequencies: [
            "publie": 10_000,
            "publi\u{00E9}": 60_000,  // 6x dominance over 10_000 — above threshold
        ])
        XCTAssertEqual(
            expandAccents(profile: frenchProfile, word: "publie", provider: provider),
            "publi\u{00E9}"
        )
    }

    func test_french_5xRule_skippedWhenInputAbsentFromDict() {
        // When the unaccented form is not in the dict at all, ANY matching
        // accented form wins — even at low frequency.
        let provider = MockFrequencyProvider(frequencies: [
            "rarewordwithaccent\u{00E9}": 5  // tiny frequency, but unaccented form is absent
        ])
        XCTAssertEqual(
            expandAccents(profile: frenchProfile, word: "rarewordwithaccente", provider: provider),
            "rarewordwithaccent\u{00E9}"
        )
    }

    // MARK: - Spanish

    func test_spanish_espanol_correctsToEspanol() {
        let provider = MockFrequencyProvider(frequencies: [
            "espa\u{00F1}ol": 60_000  // español
        ])
        XCTAssertEqual(
            expandAccents(profile: spanishProfile, word: "espanol", provider: provider),
            "espa\u{00F1}ol"
        )
    }

    // MARK: - English (empty accent map)

    func test_english_returnsNil_becauseAccentMapEmpty() {
        let provider = MockFrequencyProvider(frequencies: [
            "caf\u{00E9}": 60_000  // even if "café" is in dict
        ])
        XCTAssertNil(expandAccents(profile: englishProfile, word: "cafe", provider: provider))
    }

    // MARK: - Negative cases

    func test_returnsNil_whenNoAccentablePositions() {
        // "xyz" has no characters in the French accent map.
        let provider = MockFrequencyProvider(frequencies: [:])
        XCTAssertNil(expandAccents(profile: frenchProfile, word: "xyz", provider: provider))
    }

    func test_returnsNil_whenNoVariantMatchesDict() {
        let provider = MockFrequencyProvider(frequencies: [:])
        XCTAssertNil(expandAccents(profile: frenchProfile, word: "tres", provider: provider))
    }

    func test_returnsNil_forShortInput() {
        let provider = MockFrequencyProvider(frequencies: [
            "\u{00E0}": 1000
        ])
        XCTAssertNil(expandAccents(profile: frenchProfile, word: "a", provider: provider))
    }

    func test_returnsNil_whenProviderNotReady() {
        let provider = MockFrequencyProvider(
            isReady: false,
            frequencies: ["tr\u{00E8}s": 50_000]
        )
        XCTAssertNil(expandAccents(profile: frenchProfile, word: "tres", provider: provider))
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
        XCTAssertEqual(
            expandAccents(profile: frenchProfile, word: "tres", provider: provider),
            "tr\u{00E8}s"
        )
    }
}
