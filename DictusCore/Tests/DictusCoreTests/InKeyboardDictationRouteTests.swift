// DictusCore/Tests/DictusCoreTests/InKeyboardDictationRouteTests.swift
// Tests for InKeyboardDictationRoute — whether a cold-start mic tap dictates inside the
// keyboard or opens DictusApp through the URL fallback (spike).
import XCTest
@testable import DictusCore

final class InKeyboardDictationRouteTests: XCTestCase {

    private let suiteName = "dictus.tests.inKeyboardDictationRoute"
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

    // MARK: - The full grid

    /// Every combination of setting × app warm/cold × iOS version × locale state. Only
    /// one cell dictates in the keyboard; a warm app always keeps its own path.
    func testEveryCombination() {
        let versions = [17, 18, 25, 26, 27]
        let localeStates: [Bool?] = [nil, false, true]
        for setting in [false, true] {
            for appAnswered in [false, true] {
                for version in versions {
                    for locale in localeStates {
                        let route = InKeyboardDictationRoute.decide(
                            settingEnabled: setting,
                            appAnswered: appAnswered,
                            systemMajorVersion: version,
                            localeInstalled: locale
                        )
                        let expected: InKeyboardDictationRoute
                        if appAnswered {
                            expected = .appIsRecording
                        } else if setting, version >= 26, locale == true {
                            expected = .inKeyboard
                        } else {
                            expected = .openAppURL
                        }
                        XCTAssertEqual(
                            route, expected,
                            "setting=\(setting) appAnswered=\(appAnswered) iOS=\(version) locale=\(String(describing: locale))"
                        )
                    }
                }
            }
        }
    }

    // MARK: - The cells that matter, by name

    func testWarmAppKeepsTodaysPathEvenWithEverythingOn() {
        XCTAssertEqual(
            InKeyboardDictationRoute.decide(
                settingEnabled: true, appAnswered: true, systemMajorVersion: 26, localeInstalled: true
            ),
            .appIsRecording
        )
    }

    func testColdAppWithSettingOffOpensTheApp() {
        XCTAssertEqual(
            InKeyboardDictationRoute.decide(
                settingEnabled: false, appAnswered: false, systemMajorVersion: 26, localeInstalled: true
            ),
            .openAppURL
        )
    }

    func testColdAppBeforeIOS26OpensTheApp() {
        XCTAssertEqual(
            InKeyboardDictationRoute.decide(
                settingEnabled: true, appAnswered: false, systemMajorVersion: 18, localeInstalled: true
            ),
            .openAppURL
        )
    }

    func testMissingLocaleOpensTheApp() {
        XCTAssertEqual(
            InKeyboardDictationRoute.decide(
                settingEnabled: true, appAnswered: false, systemMajorVersion: 26, localeInstalled: false
            ),
            .openAppURL
        )
    }

    /// The asset check is asynchronous. If it has not answered by the time the 500 ms
    /// wait ends, the keyboard must not gamble on a model that may be missing.
    func testUnansweredLocaleCheckOpensTheApp() {
        XCTAssertEqual(
            InKeyboardDictationRoute.decide(
                settingEnabled: true, appAnswered: false, systemMajorVersion: 26, localeInstalled: nil
            ),
            .openAppURL
        )
    }

    func testColdAppWithEverythingReadyDictatesInTheKeyboard() {
        XCTAssertEqual(
            InKeyboardDictationRoute.decide(
                settingEnabled: true, appAnswered: false, systemMajorVersion: 26, localeInstalled: true
            ),
            .inKeyboard
        )
    }

    // MARK: - Inputs

    /// Decided on 2026-11-21: on for everyone; an absent key reads as on.
    func testAbsentSettingIsOn() {
        XCTAssertTrue(InKeyboardDictationRoute.defaultEnabled)
        XCTAssertTrue(InKeyboardDictationRoute.isSettingEnabled(in: defaults))
    }

    func testSettingReadsTheAppGroupKey() {
        defaults.set(false, forKey: SharedKeys.inKeyboardDictationEnabled)
        XCTAssertFalse(InKeyboardDictationRoute.isSettingEnabled(in: defaults))
        defaults.set(true, forKey: SharedKeys.inKeyboardDictationEnabled)
        XCTAssertTrue(InKeyboardDictationRoute.isSettingEnabled(in: defaults))
    }

    // `majorVersion(of:)` and the speech locale's region moved to `AppleEngineAvailability`
    // and `AppleSpeechLanguage` with #1036; their tests are in `AppleSpeechEngineChoiceTests`.

    // MARK: - Locales reserved ahead of the first cold tap

    func testReservesTheKeyboardLanguageInFollowMode() {
        XCTAssertEqual(
            InKeyboardDictationRoute.speechLocalesToReserve(
                transcriptionMode: .followKeyboard, keyboardLanguageCode: "fr", deviceLocaleIdentifier: "fr_FR"
            ),
            ["fr-FR"]
        )
    }

    func testReservesTheExplicitLanguageFirstThenTheKeyboardOne() {
        XCTAssertEqual(
            InKeyboardDictationRoute.speechLocalesToReserve(
                transcriptionMode: .explicit(.english), keyboardLanguageCode: "fr", deviceLocaleIdentifier: "fr_FR"
            ),
            ["en-US", "fr-FR"]
        )
    }

    func testAutoDetectReservesNothing() {
        XCTAssertEqual(
            InKeyboardDictationRoute.speechLocalesToReserve(
                transcriptionMode: .autoDetect, keyboardLanguageCode: "en", deviceLocaleIdentifier: "en_GB"
            ),
            []
        )
    }

    func testDeviceRegionWinsForItsOwnLanguage() {
        XCTAssertEqual(
            InKeyboardDictationRoute.speechLocalesToReserve(
                transcriptionMode: .followKeyboard, keyboardLanguageCode: "fr", deviceLocaleIdentifier: "fr_CA"
            ),
            ["fr-CA"]
        )
    }
}
