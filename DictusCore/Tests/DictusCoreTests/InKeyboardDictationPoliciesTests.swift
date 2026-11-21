// DictusCore/Tests/DictusCoreTests/InKeyboardDictationPoliciesTests.swift
// Tests for the rules around in-keyboard dictation (#992): permission refused, Full
// Access off, interruptions, the one-time explanation, the default setting.
import XCTest
@testable import DictusCore

final class InKeyboardDictationPoliciesTests: XCTestCase {

    private let suiteName = "dictus.tests.inKeyboardPolicies"
    private var defaults = UserDefaults.standard

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func route(fullAccess: Bool = true,
                       microphone: InKeyboardDictationRoute.MicrophonePermission = .granted,
                       appAnswered: Bool = false) -> InKeyboardDictationRoute {
        InKeyboardDictationRoute.decide(settingEnabled: true, appAnswered: appAnswered, systemMajorVersion: 26,
                                        localeInstalled: true, hasFullAccess: fullAccess, microphone: microphone)
    }

    // MARK: - Permission refused, Full Access off

    func testMicrophoneRefusedSaysSoAndOpensNothing() {
        XCTAssertEqual(route(microphone: .denied), .microphoneDenied)
    }

    func testMicrophoneNeverAskedGoesToTheAppWhichCanAsk() {
        XCTAssertEqual(route(microphone: .undetermined), .openAppURL)
    }

    func testFullAccessOffKeepsTodaysPath() {
        XCTAssertEqual(route(fullAccess: false), .openAppURL)
        XCTAssertEqual(route(fullAccess: false, microphone: .denied), .openAppURL)
    }

    func testAWarmAppIsNeverRefusedHere() {
        XCTAssertEqual(route(microphone: .denied, appAnswered: true), .appIsRecording)
    }

    func testGrantedWithFullAccessDictatesInTheKeyboard() {
        XCTAssertEqual(route(), .inKeyboard)
    }

    func testVoiceNotesNeverReachTheMicrophoneRule() {
        XCTAssertEqual(VoiceNoteRoute.decide(appTookIt: false, settingEnabled: true, systemMajorVersion: 26,
                                             localeInstalled: true), .shareExtension)
    }

    // MARK: - Interruptions

    func testCallOrSiriKeepsTheTextSoFar() {
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .interruptionBegan, recordedSeconds: 4), .finishKeepingText)
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .captureEnded, recordedSeconds: 2), .finishKeepingText)
    }

    func testAnInterruptionRightAfterTheTapEndsQuietly() {
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .interruptionBegan, recordedSeconds: 0.2), .discard)
    }

    func testAirPodsTakenOutDoNotStopTheDictation() {
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .inputDeviceLost, recordedSeconds: 5), .continue)
    }

    // MARK: - First use

    func testFirstUseExplanationIsShownOnce() {
        XCTAssertTrue(InKeyboardFirstUse.shouldShow(in: defaults))
        InKeyboardFirstUse.markShown(in: defaults)
        XCTAssertFalse(InKeyboardFirstUse.shouldShow(in: defaults))
    }

    // MARK: - Default setting (decided: on for everyone, Pierre, 2026-11-21)

    /// A new install has no stored value: on.
    func testNewInstallIsOn() {
        XCTAssertTrue(InKeyboardDictationRoute.defaultEnabled)
        XCTAssertTrue(InKeyboardDictationRoute.isSettingEnabled(in: defaults))
    }

    /// An existing user after the update has no stored value either (the key is new):
    /// on too, with nothing written and no question — the app has no such question any more.
    func testExistingUserIsOnWithoutAQuestion() {
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        XCTAssertTrue(InKeyboardDictationRoute.isSettingEnabled(in: defaults))
        XCTAssertNil(defaults.object(forKey: SharedKeys.inKeyboardDictationEnabled))
    }

    /// A user who turned it off keeps it off.
    func testAChoiceTheUserMadeIsKept() {
        defaults.set(false, forKey: SharedKeys.inKeyboardDictationEnabled)
        XCTAssertFalse(InKeyboardDictationRoute.isSettingEnabled(in: defaults))
    }

    // MARK: - Languages Apple does not cover

    /// SpeechTranscriber's supported locales, printed on macOS 26 on 2026-11-21.
    private let appleSupported = ["bn-IN", "de-AT", "de-CH", "de-DE", "en-AU", "en-CA", "en-GB", "en-IE", "en-IN",
                                  "en-NZ", "en-SG", "en-US", "en-ZA", "es-CL", "es-ES", "es-MX", "es-US", "fr-BE",
                                  "fr-CA", "fr-CH", "fr-FR", "gu-IN", "hi-IN", "it-CH", "it-IT", "ja-JP", "kn-IN",
                                  "ko-KR", "ks-IN", "mai-IN", "ml-IN", "mr-IN", "mul-IN", "ne-IN", "or-IN", "pa-IN",
                                  "pt-BR", "pt-PT", "ta-IN", "te-IN", "ur-IN", "yue-CN", "zh-CN", "zh-HK", "zh-TW"]

    func testCoverageReadsTheLanguageSubtagOnly() {
        XCTAssertTrue(InKeyboardDictationRoute.isLanguageCovered("zh", bySupportedLocales: appleSupported))
        XCTAssertTrue(InKeyboardDictationRoute.isLanguageCovered("fr", bySupportedLocales: appleSupported))
        XCTAssertFalse(InKeyboardDictationRoute.isLanguageCovered("ru", bySupportedLocales: appleSupported))
        XCTAssertFalse(InKeyboardDictationRoute.isLanguageCovered("nl", bySupportedLocales: appleSupported))
    }

    /// The fallback: a language Apple does not cover (or whose model is not installed)
    /// answers "not installed", and the tap takes today's path — open the app — with no
    /// error line and nothing inserted.
    func testUncoveredLanguageOpensTheAppQuietly() {
        let route = InKeyboardDictationRoute.decide(settingEnabled: true, appAnswered: false, systemMajorVersion: 26,
                                                    localeInstalled: false, hasFullAccess: true, microphone: .granted)
        XCTAssertEqual(route, .openAppURL)
    }

    // MARK: - Activation by the chosen dictation language (Pierre, 2026-11-21)

    private func eligibility(_ mode: TranscriptionLanguageMode, keyboard: String = "fr") -> InKeyboardLanguageEligibility {
        InKeyboardLanguageEligibility.evaluate(mode: mode, keyboardLanguageCode: keyboard, supportedLocales: appleSupported)
    }

    func testCoveredLanguageKeepsTheSettingOn() {
        XCTAssertEqual(eligibility(.followKeyboard), .covered("fr"))
        XCTAssertTrue(InKeyboardLanguageEligibility.isEffectivelyOn(userChoice: nil, eligibility: eligibility(.followKeyboard)))
    }

    func testUncoveredLanguageTurnsTheSettingOff() {
        let uncovered = InKeyboardLanguageEligibility.evaluate(mode: .followKeyboard, keyboardLanguageCode: "ru",
                                                               supportedLocales: appleSupported)
        XCTAssertEqual(uncovered, .notCovered("ru"))
        XCTAssertFalse(InKeyboardLanguageEligibility.isEffectivelyOn(userChoice: nil, eligibility: uncovered))
        XCTAssertFalse(InKeyboardLanguageEligibility.isEffectivelyOn(userChoice: true, eligibility: uncovered))
    }

    /// The user never touched the toggle: off while the language is not covered, back on
    /// when they return to a covered one.
    func testChangingToAnUncoveredLanguageTurnsItOffAndBackOnWhenCoveredAgain() {
        let before = InKeyboardLanguageEligibility.evaluate(mode: .followKeyboard, keyboardLanguageCode: "fr", supportedLocales: appleSupported)
        let during = InKeyboardLanguageEligibility.evaluate(mode: .followKeyboard, keyboardLanguageCode: "ru", supportedLocales: appleSupported)
        let after = InKeyboardLanguageEligibility.evaluate(mode: .explicit(.german), keyboardLanguageCode: "ru", supportedLocales: appleSupported)
        XCTAssertTrue(InKeyboardLanguageEligibility.isEffectivelyOn(userChoice: nil, eligibility: before))
        XCTAssertFalse(InKeyboardLanguageEligibility.isEffectivelyOn(userChoice: nil, eligibility: during))
        XCTAssertTrue(InKeyboardLanguageEligibility.isEffectivelyOn(userChoice: nil, eligibility: after))
    }

    /// The user turned it off themselves: a covered language never turns it back on.
    func testAUserWhoTurnedItOffStaysOffWhenTheLanguageIsCoveredAgain() {
        for mode in [TranscriptionLanguageMode.followKeyboard, .explicit(.english)] {
            XCTAssertFalse(InKeyboardLanguageEligibility.isEffectivelyOn(userChoice: false, eligibility: eligibility(mode)))
        }
    }

    /// Covered, but Apple's model for it is not on the iPhone yet: today's path for this
    /// dictation (the keyboard reserves the locale and starts the download, logged as
    /// `reserve` / `assetInstall`); nothing is shown and nothing is inserted.
    func testCoveredLanguageWithoutTheModelTakesTodaysPathForThatDictation() {
        XCTAssertTrue(eligibility(.followKeyboard).isCovered)
        XCTAssertEqual(InKeyboardDictationRoute.decide(settingEnabled: true, appAnswered: false, systemMajorVersion: 26,
                                                       localeInstalled: false), .openAppURL)
    }

    /// Automatic detection, whatever the spoken language declared in onboarding: no
    /// single language to dictate in, so off in effect and today's path.
    func testAutoDetectTurnsItOff() {
        XCTAssertEqual(eligibility(.autoDetect), .autoDetect)
        XCTAssertNil(InKeyboardDictationRoute.dictationLanguageCode(mode: .autoDetect, keyboardLanguageCode: "en"))
        XCTAssertFalse(InKeyboardLanguageEligibility.isEffectivelyOn(userChoice: true, eligibility: .autoDetect))
    }

    /// Several keyboard languages in "follow the keyboard": each tap dictates in the
    /// keyboard language of the moment, checked again each time.
    func testFollowKeyboardFollowsEachKeyboardLanguage() {
        for code in ["fr", "en", "es", "de"] {
            XCTAssertEqual(InKeyboardDictationRoute.dictationLanguageCode(mode: .followKeyboard, keyboardLanguageCode: code), code)
            XCTAssertTrue(eligibility(.followKeyboard, keyboard: code).isCovered)
        }
    }

    func testChineseLocaleFollowsTheDeviceRegion() {
        XCTAssertEqual(InKeyboardDictationRoute.speechLocaleIdentifier(languageCode: "zh", deviceLocaleIdentifier: "en_US"), "zh-CN")
        XCTAssertEqual(InKeyboardDictationRoute.speechLocaleIdentifier(languageCode: "zh", deviceLocaleIdentifier: "zh_TW"), "zh-TW")
        // Russian is not listed by Apple: the bare code goes to `supportedLocale`, which answers nil.
        XCTAssertEqual(InKeyboardDictationRoute.speechLocaleIdentifier(languageCode: "ru", deviceLocaleIdentifier: "ru_RU"), "ru-RU")
    }
}
