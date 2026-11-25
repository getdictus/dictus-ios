// DictusCore/Tests/DictusCoreTests/OnboardingEngineRouteTests.swift
import XCTest
@testable import DictusCore

/// #1057 PR 2: which engine the onboarding sets up for the confirmed language.
final class OnboardingEngineRouteTests: XCTestCase {

    /// What an iPhone's `SpeechTranscriber.supportedLocales` might list. The rule never
    /// holds a list of its own: these come in as an input, as they do on the device.
    private let supported = ["de-DE", "en-US", "es-ES", "fr-FR", "it-IT", "ja-JP"]

    private func availability(ios: Int = 26, keyboard: String = "fr", speechTranscriber: Bool = true,
                              mode: TranscriptionLanguageMode = .followKeyboard,
                              asset: AppleEngineAssetState = .notInstalled,
                              supportedLocales: [String]? = nil) -> AppleEngineAvailability {
        let language = AppleSpeechLanguage.evaluate(mode: mode, keyboardLanguageCode: keyboard,
                                                    speechTranscriberAvailable: speechTranscriber,
                                                    supportedLocales: supportedLocales ?? supported)
        return AppleEngineAvailability.evaluate(systemMajorVersion: ios, language: language, assetState: asset)
    }

    private func route(hasKeyboard: Bool = true, keyboardDictatesWithApple: Bool = true,
                       recommendedModelReady: Bool = false, language: String? = "fr",
                       _ availability: AppleEngineAvailability) -> OnboardingEngineRoute {
        OnboardingEngineRoute.decide(spokenLanguageHasDictusKeyboard: hasKeyboard,
                                     keyboardDictatesWithApple: keyboardDictatesWithApple,
                                     recommendedModelReady: recommendedModelReady,
                                     dictationLanguageCode: language,
                                     appleAvailability: availability)
    }

    // MARK: - Apple

    func testCoveredLanguageNotInstalledTakesAppleWithInstall() {
        XCTAssertEqual(route(availability()), .apple(languageCode: "fr", needsInstall: true))
    }

    func testCoveredLanguageAlreadyInstalledTakesAppleWithoutInstall() {
        XCTAssertEqual(route(availability(asset: .installed)), .apple(languageCode: "fr", needsInstall: false))
    }

    func testUnknownOrInstallingAssetStillTakesApple() {
        for asset in [AppleEngineAssetState.unknown, .installing(fraction: 0.3), .installing(fraction: nil)] {
            XCTAssertEqual(route(availability(asset: asset)), .apple(languageCode: "fr", needsInstall: true), "\(asset)")
        }
    }

    func testEveryDictusKeyboardLanguageAppleListsTakesApple() {
        for code in ["fr", "en", "es", "de"] {
            XCTAssertEqual(route(language: code, availability(keyboard: code)),
                           .apple(languageCode: code, needsInstall: true), code)
        }
    }

    // MARK: - Today's download

    func testLanguageAppleDoesNotListDownloads() {
        // Read at runtime: the same language is covered or not depending on what the
        // iPhone lists, never on a list in Dictus.
        XCTAssertEqual(route(availability(supportedLocales: ["en-US", "de-DE"])), .downloadedModel)
        XCTAssertTrue(route(availability(supportedLocales: ["fr-CA"])).isApple)
    }

    func testSystemBefore26Downloads() {
        XCTAssertEqual(route(availability(ios: 25)), .downloadedModel)
        XCTAssertEqual(route(availability(ios: 18, asset: .installed)), .downloadedModel)
    }

    func testNoSpeechTranscriberDownloads() {
        XCTAssertEqual(route(availability(speechTranscriber: false)), .downloadedModel)
    }

    func testSpokenLanguageWithoutDictusKeyboardDownloadsEvenWhenAppleCoversIt() {
        // Italian: Apple lists it, but there is no Italian Dictus keyboard, so the spoken
        // language dictates in automatic detection (Pierre, 2026-11-25).
        XCTAssertEqual(route(hasKeyboard: false, language: nil,
                             availability(keyboard: "fr", mode: .autoDetect)), .downloadedModel)
        // Even if the availability somehow read as ready, the keyboard rule wins.
        XCTAssertEqual(route(hasKeyboard: false, availability(asset: .installed)), .downloadedModel)
    }

    func testAutomaticDetectionDownloads() {
        XCTAssertEqual(route(language: nil, availability(mode: .autoDetect)), .downloadedModel)
    }

    func testPreA14IPhoneDownloads() {
        XCTAssertEqual(route(keyboardDictatesWithApple: false, availability(asset: .installed)), .downloadedModel)
    }

    func testRecommendedModelAlreadyReadyKeepsIt() {
        XCTAssertEqual(route(recommendedModelReady: true, availability(asset: .installed)), .downloadedModel)
    }

    func testFailedAssetDownloads() {
        XCTAssertEqual(route(availability(asset: .failed)), .downloadedModel)
    }

    func testNeedsAssetWithoutLanguageDownloads() {
        XCTAssertEqual(route(language: nil, .needsAsset(.notInstalled)), .downloadedModel)
    }

    // MARK: - After the install

    func testInstallSucceededAndReadyStaysApple() {
        XCTAssertEqual(OnboardingEngineRoute.afterAppleInstall(succeeded: true,
                                                               appleAvailability: availability(asset: .installed)),
                       .apple(languageCode: "fr", needsInstall: false))
    }

    func testInstallFailedFallsBackToDownload() {
        XCTAssertEqual(OnboardingEngineRoute.afterAppleInstall(succeeded: false,
                                                               appleAvailability: availability(asset: .installed)),
                       .downloadedModel)
    }

    func testInstallSaidDoneButNotReadyFallsBackToDownload() {
        XCTAssertEqual(OnboardingEngineRoute.afterAppleInstall(succeeded: true,
                                                               appleAvailability: availability(asset: .notInstalled)),
                       .downloadedModel)
        XCTAssertEqual(OnboardingEngineRoute.afterAppleInstall(succeeded: true,
                                                               appleAvailability: availability(speechTranscriber: false)),
                       .downloadedModel)
    }

    // MARK: - The language step's line

    private func setup(_ spoken: String) -> LanguageSetup {
        LanguageSetup(spokenLanguage: spoken, preferredLanguages: ["fr-FR"])
    }

    func testLanguageStepExpectsAppleForCoveredKeyboardLanguage() {
        for code in ["fr", "en", "es", "de"] {
            XCTAssertTrue(OnboardingEngineRoute.expectsApple(for: setup(code), systemMajorVersion: 26,
                                                             supportedLocales: supported,
                                                             keyboardDictatesWithApple: true), code)
        }
    }

    func testLanguageStepExpectsDownloadOtherwise() {
        // Italian: listed by Apple, no Dictus keyboard.
        XCTAssertFalse(OnboardingEngineRoute.expectsApple(for: setup("it"), systemMajorVersion: 26,
                                                          supportedLocales: supported, keyboardDictatesWithApple: true))
        // Not read yet, or no SpeechTranscriber.
        XCTAssertFalse(OnboardingEngineRoute.expectsApple(for: setup("fr"), systemMajorVersion: 26,
                                                          supportedLocales: nil, keyboardDictatesWithApple: true))
        // Not listed on this iPhone.
        XCTAssertFalse(OnboardingEngineRoute.expectsApple(for: setup("fr"), systemMajorVersion: 26,
                                                          supportedLocales: ["en-US"], keyboardDictatesWithApple: true))
        XCTAssertFalse(OnboardingEngineRoute.expectsApple(for: setup("fr"), systemMajorVersion: 18,
                                                          supportedLocales: supported, keyboardDictatesWithApple: true))
        XCTAssertFalse(OnboardingEngineRoute.expectsApple(for: setup("fr"), systemMajorVersion: 26,
                                                          supportedLocales: supported, keyboardDictatesWithApple: false))
    }

    func testIsApple() {
        XCTAssertTrue(OnboardingEngineRoute.apple(languageCode: "fr", needsInstall: true).isApple)
        XCTAssertFalse(OnboardingEngineRoute.downloadedModel.isApple)
    }
}
