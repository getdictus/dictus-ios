// DictusCore/Tests/DictusCoreTests/LanguageSetupTests.swift
// The onboarding language screen's rules: spoken language → keyboard language, layout and
// transcription mode, and what it writes to the App Group (#649).
import XCTest
@testable import DictusCore

final class LanguageSetupTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults }

    private let keys = [
        SharedKeys.language,
        SharedKeys.keyboardLayout,
        SharedKeys.keyboardLayoutsByLanguage,
        SharedKeys.transcriptionLanguage,
        SharedKeys.spokenLanguage,
        SharedKeys.hasCompletedOnboarding
    ]

    override func setUp() {
        super.setUp()
        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { defaults.removeObject(forKey: $0) }
        super.tearDown()
    }

    // MARK: - Reading the iPhone's language

    func testLanguageTagsReduceToTheirLanguage() {
        XCTAssertEqual(SpokenLanguage.code(fromLanguageTag: "en-US"), "en")
        XCTAssertEqual(SpokenLanguage.code(fromLanguageTag: "fr-FR"), "fr")
        XCTAssertEqual(SpokenLanguage.code(fromLanguageTag: "zh-Hans-CN"), "zh")
        XCTAssertEqual(SpokenLanguage.code(fromLanguageTag: "pt_BR"), "pt")
        XCTAssertEqual(SpokenLanguage.code(fromLanguageTag: "DE"), "de")
    }

    func testIOSCodesWhisperSpellsDifferentlyAreMapped() {
        XCTAssertEqual(SpokenLanguage.code(fromLanguageTag: "nb-NO"), "no")
        XCTAssertEqual(SpokenLanguage.code(fromLanguageTag: "fil-PH"), "tl")
    }

    func testLanguagesNoModelTranscribesAreRejected() {
        XCTAssertNil(SpokenLanguage.code(fromLanguageTag: "chr-US"))
        XCTAssertNil(SpokenLanguage.code(fromLanguageTag: ""))
    }

    func testPrefillTakesTheFirstTranscribableLanguage() {
        XCTAssertEqual(SpokenLanguage.prefilled(from: ["de-DE", "en-US"]), "de")
        XCTAssertEqual(SpokenLanguage.prefilled(from: ["chr-US", "es-ES"]), "es")
        XCTAssertEqual(SpokenLanguage.prefilled(from: []), "en")
    }

    // MARK: - Acceptance: an English, German or Spanish iPhone gets its own keyboard

    func testEnglishIPhoneGetsEnglishQwerty() {
        let setup = LanguageSetup.prefilled(preferredLanguages: ["en-GB"])
        XCTAssertEqual(setup.spokenLanguage, "en")
        XCTAssertEqual(setup.keyboardLanguage, .english)
        XCTAssertEqual(setup.layout, .qwerty)
        XCTAssertTrue(setup.spokenLanguageHasDictusKeyboard)
        XCTAssertEqual(setup.transcriptionMode, .followKeyboard)
    }

    func testGermanIPhoneGetsGermanQwertz() {
        let setup = LanguageSetup.prefilled(preferredLanguages: ["de-AT"])
        XCTAssertEqual(setup.keyboardLanguage, .german)
        XCTAssertEqual(setup.layout, .qwertz)
    }

    func testSpanishIPhoneGetsSpanishQwerty() {
        let setup = LanguageSetup.prefilled(preferredLanguages: ["es-MX"])
        XCTAssertEqual(setup.keyboardLanguage, .spanish)
        XCTAssertEqual(setup.layout, .qwerty)
    }

    func testFrenchIPhoneGetsFrenchAzerty() {
        let setup = LanguageSetup.prefilled(preferredLanguages: ["fr-CA"])
        XCTAssertEqual(setup.keyboardLanguage, .french)
        XCTAssertEqual(setup.layout, .azerty)
    }

    func testEveryKeyboardLanguageMapsToItselfAndItsDefaultLayout() {
        for language in SupportedLanguage.allCases {
            let setup = LanguageSetup(spokenLanguage: language.rawValue, preferredLanguages: [])
            XCTAssertEqual(setup.keyboardLanguage, language)
            XCTAssertEqual(setup.layout, language.defaultLayout)
            XCTAssertEqual(setup.transcriptionMode, .followKeyboard)
        }
    }

    // MARK: - A spoken language without a Dictus keyboard

    func testChineseIPhoneAsksForAKeyboardAndAutoDetects() {
        let setup = LanguageSetup.prefilled(preferredLanguages: ["zh-Hans-CN"])
        XCTAssertEqual(setup.spokenLanguage, "zh")
        XCTAssertFalse(setup.spokenLanguageHasDictusKeyboard)
        XCTAssertEqual(setup.keyboardLanguage, .english, "no supported language among the preferred ones")
        XCTAssertEqual(setup.transcriptionMode, .autoDetect)
    }

    func testKeyboardForAnUnsupportedLanguageComesFromTheNextPreferredLanguage() {
        let setup = LanguageSetup.prefilled(preferredLanguages: ["it-IT", "fr-FR", "en-US"])
        XCTAssertEqual(setup.spokenLanguage, "it")
        XCTAssertEqual(setup.keyboardLanguage, .french)
        XCTAssertEqual(setup.layout, .azerty)
    }

    func testKeyboardLanguageCanBeChangedOnlyWithoutADictusKeyboard() {
        var chinese = LanguageSetup(spokenLanguage: "zh", preferredLanguages: [])
        chinese.setKeyboardLanguage(.german)
        XCTAssertEqual(chinese.keyboardLanguage, .german)
        XCTAssertEqual(chinese.layout, .qwertz, "the layout follows the keyboard language")

        var english = LanguageSetup(spokenLanguage: "en", preferredLanguages: [])
        english.setKeyboardLanguage(.german)
        XCTAssertEqual(english.keyboardLanguage, .english)
    }

    func testChangingTheSpokenLanguageResetsKeyboardAndLayout() {
        var setup = LanguageSetup(spokenLanguage: "fr", preferredLanguages: [])
        setup.layout = .qwerty
        setup.setSpokenLanguage("de", preferredLanguages: [])
        XCTAssertEqual(setup.keyboardLanguage, .german)
        XCTAssertEqual(setup.layout, .qwertz)
    }

    func testLayoutResolverIsHonoured() {
        let setup = LanguageSetup(spokenLanguage: "fr", preferredLanguages: []) { _ in .qwerty }
        XCTAssertEqual(setup.layout, .qwerty)
    }

    // MARK: - What the screen writes

    func testApplyWritesKeyboardLanguageModeAndSpokenLanguage() {
        LanguageSetup.prefilled(preferredLanguages: ["de-DE"]).apply()
        XCTAssertEqual(SupportedLanguage.active, .german)
        XCTAssertEqual(LayoutType.active, .qwertz)
        XCTAssertEqual(TranscriptionLanguageMode.active, .followKeyboard)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.spokenLanguage), "de")
        XCTAssertTrue(KeyboardLayoutPreference.isInherited(for: .german), "a confirmed default stays a default")
    }

    func testApplyRecordsALayoutTheUserChanged() {
        var setup = LanguageSetup(spokenLanguage: "fr", preferredLanguages: [])
        setup.layout = .qwerty
        setup.apply()
        XCTAssertEqual(LayoutType.active, .qwerty)
        XCTAssertEqual(KeyboardLayoutPreference.explicitLayout(for: .french), .qwerty)
    }

    func testApplyForChineseAutoDetectsOnTheChosenKeyboard() {
        var setup = LanguageSetup(spokenLanguage: "zh", preferredLanguages: [])
        setup.setKeyboardLanguage(.spanish)
        setup.apply()
        XCTAssertEqual(SupportedLanguage.active, .spanish)
        XCTAssertEqual(TranscriptionLanguageMode.active, .autoDetect)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.spokenLanguage), "zh")
    }

    func testApplyResetsAnEarlierExplicitTranscriptionLanguage() {
        defaults.set("de", forKey: SharedKeys.transcriptionLanguage)
        LanguageSetup(spokenLanguage: "en", preferredLanguages: []).apply()
        XCTAssertEqual(TranscriptionLanguageMode.active, .followKeyboard)
    }

    // MARK: - Which language the Models screen recommends for

    func testRecommendationLanguageFollowsTheSettings() {
        XCTAssertEqual(SpokenLanguage.forRecommendation(
            mode: .explicit(.spanish), keyboardLanguage: .french,
            declaredSpokenLanguage: "zh", preferredLanguages: ["ja-JP"]), "es")
        XCTAssertEqual(SpokenLanguage.forRecommendation(
            mode: .followKeyboard, keyboardLanguage: .german,
            declaredSpokenLanguage: "zh", preferredLanguages: ["ja-JP"]), "de")
        XCTAssertEqual(SpokenLanguage.forRecommendation(
            mode: .autoDetect, keyboardLanguage: .english,
            declaredSpokenLanguage: "zh", preferredLanguages: ["ja-JP"]), "zh")
    }

    func testAutoDetectWithoutADeclaredLanguageUsesTheIPhoneLanguage() {
        XCTAssertEqual(SpokenLanguage.forRecommendation(
            mode: .autoDetect, keyboardLanguage: .english,
            declaredSpokenLanguage: nil, preferredLanguages: ["ja-JP"]), "ja")
        XCTAssertEqual(SpokenLanguage.forRecommendation(
            mode: .autoDetect, keyboardLanguage: .english,
            declaredSpokenLanguage: "garbage", preferredLanguages: ["fr-FR"]), "fr")
    }

    /// End to end on the App Group: what onboarding writes for a Chinese speaker makes the
    /// Models screen recommend the same Whisper model onboarding installed.
    func testChineseSetupRecommendsWhisperThroughTheStoredSettings() {
        let iPhone15ProMax = DeviceCapabilities(
            physicalMemoryGB: 8, availableMemoryMB: 3000,
            deviceModelIdentifier: "iPhone16,2", thermalState: .nominal
        )
        let setup = LanguageSetup(spokenLanguage: "zh", preferredLanguages: [])
        setup.apply()
        XCTAssertEqual(SpokenLanguage.forRecommendation(), "zh")
        XCTAssertEqual(
            ModelInfo.recommendedIdentifier(forSpokenLanguage: SpokenLanguage.forRecommendation(), on: iPhone15ProMax),
            setup.recommendedModel(on: iPhone15ProMax)
        )
        XCTAssertNotEqual(setup.recommendedModel(on: iPhone15ProMax), "parakeet-tdt-0.6b-v3")
    }
}
