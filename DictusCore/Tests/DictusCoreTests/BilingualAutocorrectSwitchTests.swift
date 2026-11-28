// DictusCore/Tests/DictusCoreTests/BilingualAutocorrectSwitchTests.swift
// The bilingual check's Experiments switch and partner language, as the keyboard reads them (#1015).
import XCTest
@testable import DictusCore

/// The keyboard builds its bilingual keyboard from `KeyboardFeatureSettings.bilingualPair(for:)`
/// at each appearance (`BilingualAutocorrect.refresh`): a nil pair is the monolingual keyboard,
/// with no second engine and no other language to consult.
final class BilingualAutocorrectSwitchTests: XCTestCase {
    private let suiteName = "dictus.tests.bilingualAutocorrectSwitch"
    private var defaults: UserDefaults!  // swiftlint:disable:this implicitly_unwrapped_optional

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func settings(_ channel: BuildChannel = .testBuild) -> KeyboardFeatureSettings {
        KeyboardFeatureSettings(store: defaults, channel: channel)
    }

    private func neverLearned(_ word: String) -> Bool { false }

    func testOffByDefaultTheKeyboardIsMonolingual() {
        XCTAssertFalse(settings().isBilingualAutocorrectEffective)
        for language in SupportedLanguage.allCases {
            XCTAssertNil(settings().bilingualPair(for: language), "\(language): no partner engine, no other language")
        }
    }

    func testSwitchedOffTheOtherLanguageIsNeverConsulted() {
        settings().bilingualAutocorrect = false
        settings().setPartnerLanguage(.english)
        XCTAssertFalse(settings().isBilingualAutocorrectEffective)
        // No pair, so nothing asks English: `its raining` stays as typed, as on the
        // monolingual French keyboard, which has no across-space contraction.
        var consulted = false
        let written = settings().bilingualPair(for: .french).flatMap { pair -> String? in
            consulted = true
            return pair.contractionAcrossSpace(previousWord: "its", word: "raining", isLearned: neverLearned)
        }
        XCTAssertNil(written)
        XCTAssertFalse(consulted)
    }

    func testTheAppStoreBuildIgnoresAStoredTrue() {
        settings().bilingualAutocorrect = true
        XCTAssertTrue(settings(.appStore).bilingualAutocorrect, "the stored choice is kept")
        XCTAssertFalse(settings(.appStore).isBilingualAutocorrectEffective)
        XCTAssertNil(settings(.appStore).bilingualPair(for: .french))
        XCTAssertNil(settings(.appStore).bilingualPair(for: .english))
    }

    func testTheKeyboardReadsTheChannelTheAppRecorded() {
        settings().bilingualAutocorrect = true
        XCTAssertFalse(KeyboardFeatureSettings.forKeyboard(store: defaults).isBilingualAutocorrectEffective,
                       "nothing recorded reads as the App Store")
        AppDistribution.record(.testFlight, in: defaults)
        XCTAssertTrue(KeyboardFeatureSettings.forKeyboard(store: defaults).isBilingualAutocorrectEffective)
        AppDistribution.record(.appStore, in: defaults)
        XCTAssertFalse(KeyboardFeatureSettings.forKeyboard(store: defaults).isBilingualAutocorrectEffective)
    }

    func testOnWithEnglishPartnerItsRainingBecomesItsContraction() throws {
        settings().bilingualAutocorrect = true
        settings().setPartnerLanguage(.english)
        let pair = try XCTUnwrap(settings().bilingualPair(for: .french))
        XCTAssertEqual(pair, KeyboardLanguagePair(primary: .french, secondary: .english))
        // From the PR body: on the bilingual keyboard the space after `raining` writes both.
        XCTAssertEqual(pair.contractionAcrossSpace(previousWord: "its", word: "raining", isLearned: neverLearned),
                       "it's raining")
        XCTAssertEqual(pair.contractionAcrossSpace(previousWord: "Its", word: "a", isLearned: neverLearned), "It's a")
        // The possessive stays, and a learned word is never rewritten (ADR 0004).
        XCTAssertNil(pair.contractionAcrossSpace(previousWord: "its", word: "tail", isLearned: neverLearned))
        XCTAssertNil(pair.contractionAcrossSpace(previousWord: "its", word: "raining", isLearned: { $0 == "its" }))
    }

    func testThePartnerLanguageIsReadFromTheSettings() throws {
        settings().bilingualAutocorrect = true
        // Untouched: each keyboard gets its default partner.
        XCTAssertEqual(settings().bilingualPair(for: .french)?.secondary, .english)
        XCTAssertEqual(settings().bilingualPair(for: .english)?.secondary, .french)
        // A partner with no engine pair yet leaves the keyboard monolingual.
        settings().setPartnerLanguage(.spanish)
        XCTAssertEqual(settings().partnerLanguage(for: .french), .spanish)
        XCTAssertNil(settings().bilingualPair(for: .french))
        // Spanish and German have no pair at all.
        settings().setPartnerLanguage(.english)
        XCTAssertNil(settings().bilingualPair(for: .spanish))
        XCTAssertNil(settings().bilingualPair(for: .german))
        // A stored partner equal to the keyboard reads as the default.
        XCTAssertEqual(settings().bilingualPair(for: .english)?.secondary, .french)
    }
}
