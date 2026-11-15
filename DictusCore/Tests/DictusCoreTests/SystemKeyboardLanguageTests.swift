// DictusCore/Tests/DictusCoreTests/SystemKeyboardLanguageTests.swift
// Tests for SupportedLanguage.systemKeyboard(preferredLanguages:): the Apple keyboard the
// onboarding's globe tutorial draws, and the two labels it takes from it (#915).
import XCTest
@testable import DictusCore

final class SystemKeyboardLanguageTests: XCTestCase {

    private func labels(_ preferredLanguages: [String]) -> (space: String, menuRow: String) {
        let language = SupportedLanguage.systemKeyboard(preferredLanguages: preferredLanguages)
        return (language.spaceName, language.displayName)
    }

    func testEachSupportedDeviceLanguageDrawsItsOwnLabels() {
        XCTAssertEqual(labels(["fr-FR"]).space, "espace")
        XCTAssertEqual(labels(["fr-FR"]).menuRow, "Fran\u{00E7}ais")
        XCTAssertEqual(labels(["en-US"]).space, "space")
        XCTAssertEqual(labels(["en-US"]).menuRow, "English")
        XCTAssertEqual(labels(["de-DE"]).space, "Leertaste")
        XCTAssertEqual(labels(["de-DE"]).menuRow, "Deutsch")
        XCTAssertEqual(labels(["es-ES"]).space, "espacio")
        XCTAssertEqual(labels(["es-ES"]).menuRow, "Espa\u{00F1}ol")
    }

    func testRegionAndScriptDoNotChangeTheLanguage() {
        XCTAssertEqual(SupportedLanguage.systemKeyboard(preferredLanguages: ["de-AT"]), .german)
        XCTAssertEqual(SupportedLanguage.systemKeyboard(preferredLanguages: ["es-419"]), .spanish)
        XCTAssertEqual(SupportedLanguage.systemKeyboard(preferredLanguages: ["fr_CA"]), .french)
        XCTAssertEqual(SupportedLanguage.systemKeyboard(preferredLanguages: ["DE"]), .german)
    }

    func testUnsupportedDeviceLanguageFallsBackToEnglish() {
        XCTAssertEqual(labels(["it-IT"]).space, "space")
        XCTAssertEqual(labels(["it-IT"]).menuRow, "English")
        XCTAssertEqual(SupportedLanguage.systemKeyboard(preferredLanguages: ["zh-Hans-CN"]), .english)
        XCTAssertEqual(SupportedLanguage.systemKeyboard(preferredLanguages: []), .english)
    }

    /// The drawn keyboard follows the iPhone's first language, as the page always did:
    /// a later supported language does not win over an unsupported first one.
    func testOnlyTheFirstPreferredLanguageCounts() {
        XCTAssertEqual(SupportedLanguage.systemKeyboard(preferredLanguages: ["it-IT", "de-DE"]), .english)
        XCTAssertEqual(SupportedLanguage.systemKeyboard(preferredLanguages: ["es-ES", "fr-FR"]), .spanish)
    }
}
