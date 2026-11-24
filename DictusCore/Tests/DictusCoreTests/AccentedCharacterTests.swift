// DictusCore/Tests/DictusCoreTests/AccentedCharacterTests.swift
// Per-language long-press accents (#1042).
import XCTest
@testable import DictusCore

final class AccentedCharacterTests: XCTestCase {

    // MARK: - Lists per language, in Apple's order

    /// Apple's French keyboard, as Hex observed it. Pins the order as well as the contents:
    /// a reordering is a change a French user sees under the finger.
    func testFrenchListsMatchApplesFrenchKeyboard() {
        XCTAssertEqual(AccentedCharacters.mappings(for: .french, layout: .azerty), [
            "a": ["à", "â", "æ", "á", "ä", "ã", "å", "ā", "ª"],
            "e": ["é", "è", "ê", "ë", "ę", "ė", "ē"],
            "y": ["ÿ"],
            "u": ["û", "ù", "ü", "ú", "ū"],
            "i": ["î", "ï", "ì", "í", "į", "ī"],
            "o": ["ö", "ô", "œ", "ò", "ó", "õ", "ø", "ō", "º"],
            "c": ["ç", "ć", "č"],
            "n": ["ñ", "ń"]
        ])
    }

    func testEnglishListsMatchApplesEnglishKeyboard() {
        XCTAssertEqual(AccentedCharacters.mappings(for: .english, layout: .qwerty), [
            "w": ["ŵ"],
            "e": ["ë", "é", "è", "ê", "ě", "ẽ", "ē", "ė", "ę"],
            "r": ["ř"],
            "t": ["ț", "ť", "þ"],
            "y": ["ý", "ŷ", "ÿ"],
            "u": ["ū", "ǔ", "û", "ù", "ú", "ü", "ũ", "ű", "ů", "ų"],
            "i": ["ǐ", "î", "ì", "í", "ï", "ĩ", "ī", "ı", "į"],
            "o": ["ô", "ò", "ó", "ö", "ǒ", "œ", "ø", "õ", "ō", "ő"],
            "a": ["à", "á", "â", "ä", "ǎ", "æ", "ã", "å", "ā", "ă", "ą"],
            "s": ["ß", "ş", "ș", "ś", "š"],
            "d": ["ď", "ð"],
            "g": ["ğ", "ġ"],
            "h": ["ħ"],
            "k": ["ķ"],
            "l": ["ł", "ļ", "ľ"],
            "z": ["ź", "ž", "ż"],
            "c": ["ç", "ć", "č", "ċ"],
            "n": ["ñ", "ń", "ņ", "ň"]
        ])
    }

    /// Apple's Spanish keyboard has a ñ key; Dictus's QWERTY does not, so ñ comes first on n.
    func testSpanishListsMatchApplesSpanishKeyboardWithÑOnN() {
        XCTAssertEqual(AccentedCharacters.mappings(for: .spanish, layout: .qwerty), [
            "e": ["é", "è", "ë", "ê", "ę", "ė", "ē"],
            "u": ["ú", "ü", "ù", "û", "ū"],
            "i": ["í", "ï", "ì", "î", "į", "ī"],
            "o": ["ö", "ó", "ò", "ô", "õ", "ø", "œ", "ō", "º"],
            "a": ["á", "à", "ä", "â", "ã", "å", "ą", "æ", "ā", "ª"],
            "s": ["š"],
            "d": ["đ"],
            "l": ["l·l"],
            "c": ["ç", "ć", "č"],
            "n": ["ñ", "ń"]
        ])
    }

    /// On QWERTZ, ä ö ü have keys of their own, so their base letters do not hold them.
    func testGermanListsMatchApplesGermanKeyboardOnQWERTZ() {
        XCTAssertEqual(AccentedCharacters.mappings(for: .german, layout: .qwertz), [
            "e": ["é", "è", "ê", "ë", "ė"],
            "u": ["û", "ù", "ú", "ū"],
            "i": ["î", "ï", "í", "ī", "ì"],
            "o": ["ô", "ò", "ó", "õ", "œ", "ø", "ō"],
            "a": ["à", "á", "â", "æ", "ã", "å", "ā"],
            "s": ["ß", "ś", "š"],
            "y": ["ÿ"],
            "c": ["ç", "ć", "č"],
            "n": ["ñ", "ń"]
        ])
    }

    // MARK: - Letters with a key of their own (#272: layout is not language)

    /// German on QWERTY or AZERTY has no ä ö ü keys: Apple's keyboard then holds each one
    /// right after its base letter, and Dictus must too, or German loses its umlauts.
    func testGermanOffLayoutHoldsItsUmlautsFirst() {
        for layout in [LayoutType.qwerty, .azerty] {
            let mappings = AccentedCharacters.mappings(for: .german, layout: layout)
            XCTAssertEqual(mappings["a"], ["ä", "à", "á", "â", "æ", "ã", "å", "ā"], "\(layout)")
            XCTAssertEqual(mappings["o"], ["ö", "ô", "ò", "ó", "õ", "œ", "ø", "ō"], "\(layout)")
            XCTAssertEqual(mappings["u"], ["ü", "û", "ù", "ú", "ū"], "\(layout)")
        }
    }

    func testGermanOnQWERTZDoesNotHoldWhatHasAKey() {
        let mappings = AccentedCharacters.mappings(for: .german, layout: .qwertz)
        for letter in ["ä", "ö", "ü"] {
            XCTAssertFalse(mappings.values.joined().contains(letter), letter)
        }
    }

    /// No Dictus layout has a ñ key, so Spanish holds ñ first on n everywhere.
    func testSpanishHoldsÑFirstOnEveryLayout() {
        for layout in LayoutType.allCases {
            XCTAssertEqual(AccentedCharacters.accents(for: "n", language: .spanish, layout: layout)?.first, "ñ",
                           "\(layout)")
        }
    }

    /// French declares no letter with a key of its own, so its lists never depend on the layout.
    func testFrenchIsTheSameOnEveryLayout() {
        let azerty = AccentedCharacters.mappings(for: .french, layout: .azerty)
        for layout in LayoutType.allCases {
            XCTAssertEqual(AccentedCharacters.mappings(for: .french, layout: layout), azerty, "\(layout)")
        }
    }

    // MARK: - œ and æ in French (the reason for #1042)

    func testFrenchHoldsŒOnOAndÆOnA() {
        XCTAssertTrue(AccentedCharacters.accents(for: "o", language: .french, layout: .azerty)?
            .contains("\u{0153}") == true, "œ (U+0153) on o: cœur, sœur, œuvre")
        XCTAssertTrue(AccentedCharacters.accents(for: "a", language: .french, layout: .azerty)?
            .contains("\u{00E6}") == true, "æ (U+00E6) on a: ex æquo")
    }

    func testŒAndÆAreOnEveryLanguagesKeyboard() {
        for language in SupportedLanguage.allCases {
            for layout in LayoutType.allCases {
                let mappings = AccentedCharacters.mappings(for: language, layout: layout)
                XCTAssertTrue(mappings["o"]?.contains("œ") == true, "\(language) \(layout)")
                XCTAssertTrue(mappings["a"]?.contains("æ") == true, "\(language) \(layout)")
            }
        }
    }

    // MARK: - Upper case

    /// The popup capitalizes on shifted and caps-lock pages with `shifted(_:)`.
    func testShiftedFrenchŒAndÆAreTheirCapitals() {
        XCTAssertEqual(AccentedCharacters.shifted("œ"), "\u{0152}")   // Œ
        XCTAssertEqual(AccentedCharacters.shifted("æ"), "\u{00C6}")   // Æ
        XCTAssertEqual(AccentedCharacters.shifted("é"), "É")
        XCTAssertEqual(AccentedCharacters.shifted("ç"), "Ç")
    }

    func testShiftedKeepsTheSpecialCapitals() {
        XCTAssertEqual(AccentedCharacters.shifted("ß"), "\u{1E9E}", "ẞ, never SS (#322)")
        XCTAssertEqual(AccentedCharacters.shifted("ı"), "\u{0130}", "İ, not the key's own I")
        XCTAssertEqual(AccentedCharacters.shifted("ª"), "ª")
        XCTAssertEqual(AccentedCharacters.shifted("º"), "º")
        XCTAssertEqual(AccentedCharacters.shifted("l·l"), "L·L")
    }

    /// One key in, one key out, nothing shown twice, and never the base letter itself:
    /// the bridge inserts the shifted candidate verbatim.
    func testEveryShiftedPopupIsDistinctAndKeepsItsLength() {
        for language in SupportedLanguage.allCases {
            for layout in LayoutType.allCases {
                for (base, variants) in AccentedCharacters.mappings(for: language, layout: layout) {
                    let shifted = variants.map(AccentedCharacters.shifted)
                    XCTAssertEqual(Set(shifted).count, shifted.count, "\(language) \(layout) \(base)")
                    XCTAssertFalse(shifted.contains(base.uppercased()), "\(language) \(layout) \(base)")
                    for (variant, capital) in zip(variants, shifted) {
                        XCTAssertEqual(capital.count, variant.count, "\(language) \(variant)")
                        // ª and º have no capital; every other variant must take one.
                        if variant != "ª" && variant != "º" {
                            XCTAssertNotEqual(capital, variant, "\(language) \(variant) must be capitalized")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data conventions

    func testEveryLanguageDeclaresItsList() {
        for language in SupportedLanguage.allCases {
            XCTAssertFalse(language.profile.longPressAccents.isEmpty, "\(language)")
        }
    }

    /// Precomposed, lowercase, one character, not the base, no duplicates: what the popup and
    /// the bridge assume. Spanish `l·l` is Apple's one multi-character option.
    func testVariantsArePrecomposedLowercaseSingleCharacters() {
        for language in SupportedLanguage.allCases {
            for layout in LayoutType.allCases {
                for (base, variants) in AccentedCharacters.mappings(for: language, layout: layout) {
                    XCTAssertEqual(base, base.lowercased())
                    XCTAssertFalse(variants.contains(base), "\(language) \(base)")
                    XCTAssertEqual(Set(variants).count, variants.count, "\(language) \(base)")
                    for variant in variants {
                        XCTAssertEqual(variant, variant.precomposedStringWithCanonicalMapping, variant)
                        XCTAssertEqual(variant, variant.lowercased(), variant)
                        if variant != "l·l" {
                            XCTAssertEqual(variant.count, 1, variant)
                            XCTAssertEqual(variant.unicodeScalars.count, 1, "\(variant) must be precomposed")
                        }
                    }
                }
            }
        }
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(AccentedCharacters.accents(for: "E", language: .french, layout: .azerty),
                       AccentedCharacters.accents(for: "e", language: .french, layout: .azerty))
    }

    func testALetterWithoutAccentsHoldsNothing() {
        XCTAssertNil(AccentedCharacters.accents(for: "z", language: .french, layout: .azerty))
        XCTAssertNil(AccentedCharacters.accents(for: "s", language: .french, layout: .azerty))
        XCTAssertNil(AccentedCharacters.accents(for: "1", language: .english, layout: .qwerty))
    }

    /// The adaptive key and the held vowel must agree: whatever the key shows after a vowel,
    /// holding that vowel offers it too.
    func testFrenchHeldVowelsOfferTheAdaptiveKeysAccent() {
        let mappings = AccentedCharacters.mappings(for: .french, layout: .azerty)
        for (vowel, accent) in FrenchAdaptiveKey.defaults {
            XCTAssertTrue(mappings[vowel]?.contains(accent) == true, "\(vowel) → \(accent)")
        }
    }
}
