// DictusCore/Tests/DictusCoreTests/VoiceNoteSpeechAssetPlanTests.swift
import XCTest
@testable import DictusCore

/// The Apple speech model the app reserves for voice notes (#1056): which language, for
/// whom, and when the app asks again.
final class VoiceNoteSpeechAssetPlanTests: XCTestCase {

    private let appleLocales = ["fr-FR", "fr-CA", "en-US", "en-GB", "es-ES", "it-IT", "ja-JP"]

    private func plan(_ language: VoiceNoteLanguage,
                      keyboard: SupportedLanguage = .french,
                      entitled: Bool = true,
                      major: Int = 26,
                      available: Bool = true,
                      locales: [String]? = nil) -> VoiceNoteSpeechAssetPlan {
        VoiceNoteSpeechAssetPlan.evaluate(voiceNoteLanguage: language, keyboardLanguage: keyboard,
                                          isEntitled: entitled,
                                          system: .init(majorVersion: major, speechTranscriberAvailable: available,
                                                        supportedLocales: locales ?? appleLocales))
    }

    // MARK: - Which language

    func testFixedVoiceNoteLanguageIsReserved() {
        XCTAssertEqual(plan(.fixed(.english), keyboard: .french),
                       .reserve(languageCode: "en", source: .voiceNoteLanguage))
    }

    func testAutoDetectReservesTheKeyboardLanguage() {
        XCTAssertEqual(plan(.autoDetect, keyboard: .spanish),
                       .reserve(languageCode: "es", source: .dictationLanguage))
    }

    func testLanguageAppleDoesNotListIsSkipped() {
        XCTAssertEqual(plan(.fixed(.german)), .skip(.languageNotCovered("de")))
        XCTAssertEqual(plan(.autoDetect, keyboard: .german), .skip(.languageNotCovered("de")))
    }

    func testCoverageReadsTheLanguageSubtagOnly() {
        XCTAssertEqual(plan(.fixed(.french), locales: ["fr_CA"]),
                       .reserve(languageCode: "fr", source: .voiceNoteLanguage))
    }

    // MARK: - Nothing to reserve

    func testBeforeIOS26NothingIsReserved() {
        XCTAssertEqual(plan(.fixed(.french), major: 18), .skip(.systemTooOld))
        XCTAssertEqual(plan(.autoDetect, major: 17), .skip(.systemTooOld))
    }

    func testWithoutSpeechTranscriberNothingIsReserved() {
        XCTAssertEqual(plan(.fixed(.french), available: false, locales: []), .skip(.speechTranscriberUnavailable))
    }

    func testWithoutVoiceNotesNothingIsReserved() {
        XCTAssertEqual(plan(.fixed(.french), entitled: false), .skip(.notEntitled))
        // Checked first: a free user on an old iPhone is not told about the iPhone.
        XCTAssertEqual(plan(.autoDetect, entitled: false, major: 17, available: false), .skip(.notEntitled))
    }

    func testRequestedLanguageNeedsNoSystemAnswer() {
        let fixed = VoiceNoteSpeechAssetPlan.requestedLanguage(voiceNoteLanguage: .fixed(.german), keyboardLanguage: .french)
        XCTAssertEqual(fixed.code, "de")
        XCTAssertEqual(fixed.source, .voiceNoteLanguage)
        let auto = VoiceNoteSpeechAssetPlan.requestedLanguage(voiceNoteLanguage: .autoDetect, keyboardLanguage: .english)
        XCTAssertEqual(auto.code, "en")
        XCTAssertEqual(auto.source, .dictationLanguage)
    }

    // MARK: - When

    func testFirstCheckIsTheLaunch() {
        var trigger = VoiceNoteSpeechAssetTrigger()
        XCTAssertEqual(trigger.reason(for: .init(languageCode: "fr", isEntitled: true)), .launch)
    }

    func testFirstCheckRunsEvenWithoutEntitlement() {
        // The launch line is logged for everyone, so a free user's log says why nothing
        // was reserved.
        var trigger = VoiceNoteSpeechAssetTrigger()
        XCTAssertEqual(trigger.reason(for: .init(languageCode: "fr", isEntitled: false)), .launch)
    }

    func testUnchangedInputsDoNothing() {
        var trigger = VoiceNoteSpeechAssetTrigger()
        _ = trigger.reason(for: .init(languageCode: "fr", isEntitled: true))
        XCTAssertNil(trigger.reason(for: .init(languageCode: "fr", isEntitled: true)))
        XCTAssertNil(trigger.reason(for: .init(languageCode: "fr", isEntitled: true)))
    }

    func testLanguageChangeRunsAgainOnce() {
        var trigger = VoiceNoteSpeechAssetTrigger()
        _ = trigger.reason(for: .init(languageCode: "fr", isEntitled: true))
        XCTAssertEqual(trigger.reason(for: .init(languageCode: "en", isEntitled: true)), .languageChanged)
        XCTAssertNil(trigger.reason(for: .init(languageCode: "en", isEntitled: true)))
        XCTAssertEqual(trigger.reason(for: .init(languageCode: "fr", isEntitled: true)), .languageChanged)
    }

    func testGainingEntitlementRunsAgain() {
        var trigger = VoiceNoteSpeechAssetTrigger()
        _ = trigger.reason(for: .init(languageCode: "fr", isEntitled: false))
        XCTAssertEqual(trigger.reason(for: .init(languageCode: "fr", isEntitled: true)), .entitlementChanged)
    }

    func testLosingEntitlementDoesNothing() {
        var trigger = VoiceNoteSpeechAssetTrigger()
        _ = trigger.reason(for: .init(languageCode: "fr", isEntitled: true))
        XCTAssertNil(trigger.reason(for: .init(languageCode: "fr", isEntitled: false)))
    }

    func testLanguageChangeWinsOverEntitlementChange() {
        var trigger = VoiceNoteSpeechAssetTrigger()
        _ = trigger.reason(for: .init(languageCode: "fr", isEntitled: false))
        XCTAssertEqual(trigger.reason(for: .init(languageCode: "es", isEntitled: true)), .languageChanged)
    }
}
