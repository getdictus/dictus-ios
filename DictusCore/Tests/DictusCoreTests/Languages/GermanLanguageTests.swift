// DictusCore/Tests/DictusCoreTests/Languages/GermanLanguageTests.swift
// First per-language test file (per locked decision #10 of issue #110).
// Pins the German profile data and exercises the algorithm helpers against it.
import XCTest
@testable import DictusCore

final class GermanLanguageTests: XCTestCase {

    // MARK: - Profile data snapshot

    func test_germanProfile_displayFields() {
        let p = germanProfile
        XCTAssertEqual(p.code, "de")
        XCTAssertEqual(p.displayName, "Deutsch")
        XCTAssertEqual(p.shortCode, "DE")
        XCTAssertEqual(p.defaultLayout, .qwerty,
                       "QWERTY on launch — QWERTZ deferred to issue #151.")
        XCTAssertEqual(p.spaceName, "Leertaste")
        XCTAssertEqual(p.returnName, "Eingabe")
    }

    func test_supportedLanguage_german_resolvesToGermanProfile() {
        XCTAssertEqual(SupportedLanguage.german.profile.code, "de")
    }

    func test_supportedLanguage_german_enumAccessorsAgreeWithProfile() {
        let lang = SupportedLanguage.german
        let p = lang.profile
        XCTAssertEqual(p.code, lang.rawValue)
        XCTAssertEqual(p.displayName, lang.displayName)
        XCTAssertEqual(p.shortCode, lang.shortCode)
        XCTAssertEqual(p.defaultLayout, lang.defaultLayout)
        XCTAssertEqual(p.spaceName, lang.spaceName)
        XCTAssertEqual(p.returnName, lang.returnName)
    }

    // MARK: - Override map (empty per ADR 0001)

    func test_germanProfile_overridesIsEmptyPerADR0001() {
        XCTAssertTrue(germanProfile.overrides.isEmpty,
                      "German ships with empty overrides per ADR 0001 — populated post-launch from native-speaker feedback on issue #109.")
    }

    func test_german_applyOverride_returnsNilForCommonInputs() {
        // No overrides means every input falls through to the trie/accent pipeline.
        XCTAssertNil(applyOverride(profile: germanProfile, word: "schon"))
        XCTAssertNil(applyOverride(profile: germanProfile, word: "uber"))
        XCTAssertNil(applyOverride(profile: germanProfile, word: "madchen"))
        XCTAssertNil(applyOverride(profile: germanProfile, word: "strasse"))
        XCTAssertNil(applyOverride(profile: germanProfile, word: "ich"))
    }

    // MARK: - Accent map (ä, ö, ü, ß)

    func test_germanProfile_accentMapMatchesSpec() {
        XCTAssertEqual(germanProfile.accentMap, [
            "a": ["\u{00E4}"],   // ä
            "o": ["\u{00F6}"],   // ö
            "u": ["\u{00FC}"],   // ü
            "s": ["\u{00DF}"],   // ß
        ])
    }

    func test_german_expandAccents_uberCorrectsToUmlaut() {
        // "uber" not in dict → any matching accented variant wins.
        let provider = MockFrequencyProvider(frequencies: [
            "\u{00FC}ber": 60_000   // über
        ])
        XCTAssertEqual(
            expandAccents(profile: germanProfile, word: "uber", provider: provider),
            "\u{00FC}ber"
        )
    }

    func test_german_expandAccents_schonCorrectsToUmlaut() {
        let provider = MockFrequencyProvider(frequencies: [
            "sch\u{00F6}n": 50_000   // schön
        ])
        XCTAssertEqual(
            expandAccents(profile: germanProfile, word: "schon", provider: provider),
            "sch\u{00F6}n"
        )
    }

    func test_german_expandAccents_madchenCorrectsToUmlaut() {
        let provider = MockFrequencyProvider(frequencies: [
            "m\u{00E4}dchen": 25_000   // mädchen
        ])
        XCTAssertEqual(
            expandAccents(profile: germanProfile, word: "madchen", provider: provider),
            "m\u{00E4}dchen"
        )
    }

    func test_german_expandAccents_strasseDoesNotMergeSsToEszett() {
        // Documents a known limitation of AccentExpander on launch: the algorithm
        // does only single-character substitutions (o → ö, a → ä, u → ü). The
        // German `ss → ß` collapse needs to merge two characters into one, which
        // the algorithm does not handle. So `strasse` stays as `strasse` here
        // even when `straße` is in the dictionary. ADR 0001 accepts this trade-off
        // for first ship; user can long-press `s` to insert `ß` directly. Future
        // work may add substring-substitution support (tracked in issue #152).
        let provider = MockFrequencyProvider(frequencies: [
            "stra\u{00DF}e": 40_000   // straße is in dict
        ])
        XCTAssertNil(expandAccents(profile: germanProfile, word: "strasse", provider: provider))
    }

    func test_german_expandAccents_5xDominanceProtectsValidUnaccentedWords() {
        // If the unaccented form is itself in the dict and the umlaut form is only
        // ~3x more common, the 5x rule keeps the input unchanged.
        let provider = MockFrequencyProvider(frequencies: [
            "schon": 10_000,                 // valid German word ("already")
            "sch\u{00F6}n": 30_000,          // schön ("beautiful") — only 3x
        ])
        XCTAssertNil(expandAccents(profile: germanProfile, word: "schon", provider: provider),
                     "5x dominance rule must protect 'schon' (already) when 'schön' is not 5x more frequent.")
    }

    func test_german_expandAccents_returnsNilWhenNoMatch() {
        let provider = MockFrequencyProvider(frequencies: [:])
        XCTAssertNil(expandAccents(profile: germanProfile, word: "uber", provider: provider))
    }

    // MARK: - Contractions (empty)

    func test_germanProfile_hasNoContractionPrefixes() {
        XCTAssertTrue(germanProfile.contractionPrefixes.isEmpty,
                      "German `geht's`/`gibt's` style contractions are rare and not curated for first ship.")
    }

    func test_german_expandContractions_returnsNilForAnyInput() {
        let provider = MockFrequencyProvider(frequencies: [
            "geht": 50_000,
            "gibt": 50_000,
        ])
        XCTAssertNil(expandContractions(profile: germanProfile, word: "gehts", provider: provider))
        XCTAssertNil(expandContractions(profile: germanProfile, word: "gibts", provider: provider))
    }
}
