// DictusCore/Tests/DictusCoreTests/DictationReadinessTests.swift
import XCTest
@testable import DictusCore

/// #1057: whether Dictus can dictate with no downloaded model, because Apple's engine is
/// picked and ready for the dictation language.
final class DictationReadinessTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "DictationReadinessTests"
    private let supported = ["de-DE", "en-US", "es-ES", "fr-FR"]

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func apple(ios: Int = 26, keyboard: String = "fr", speechTranscriber: Bool = true,
                       mode: TranscriptionLanguageMode = .followKeyboard,
                       asset: AppleEngineAssetState = .installed) -> AppleEngineAvailability {
        let language = AppleSpeechLanguage.evaluate(mode: mode, keyboardLanguageCode: keyboard,
                                                    speechTranscriberAvailable: speechTranscriber,
                                                    supportedLocales: supported)
        return AppleEngineAvailability.evaluate(systemMajorVersion: ios, language: language, assetState: asset)
    }

    // MARK: - The rule

    func testModelReadyCanDictateWhateverApple() {
        for choice in [SpeechEngineChoice.downloadedModel, .apple] {
            for availability in [apple(), apple(ios: 25), apple(keyboard: "it"), apple(speechTranscriber: false)] {
                XCTAssertTrue(DictationReadiness.canDictate(modelReady: true, choice: choice, appleAvailability: availability))
                XCTAssertFalse(DictationReadiness.dictatesWithAppleOnly(modelReady: true, choice: choice,
                                                                        appleAvailability: availability))
            }
        }
    }

    func testAppleChosenAndReadyCanDictateWithoutModel() {
        XCTAssertTrue(DictationReadiness.canDictate(modelReady: false, choice: .apple, appleAvailability: apple()))
        XCTAssertTrue(DictationReadiness.dictatesWithAppleOnly(modelReady: false, choice: .apple, appleAvailability: apple()))
    }

    func testNeitherCannotDictate() {
        XCTAssertFalse(DictationReadiness.canDictate(modelReady: false, choice: .downloadedModel,
                                                     appleAvailability: apple(speechTranscriber: false)))
    }

    func testAppleReadyButNotChosenCannotDictateWithoutModel() {
        XCTAssertFalse(DictationReadiness.canDictate(modelReady: false, choice: .downloadedModel, appleAvailability: apple()))
    }

    func testAppleChosenButLanguageNotCoveredCannotDictate() {
        XCTAssertEqual(apple(keyboard: "it"), .unavailable(.languageNotCovered("it")))
        XCTAssertFalse(DictationReadiness.canDictate(modelReady: false, choice: .apple, appleAvailability: apple(keyboard: "it")))
    }

    func testAppleChosenButAutomaticDetectionCannotDictate() {
        XCTAssertFalse(DictationReadiness.canDictate(modelReady: false, choice: .apple,
                                                     appleAvailability: apple(mode: .autoDetect)))
    }

    func testAppleChosenBeforeIOS26CannotDictate() {
        XCTAssertEqual(apple(ios: 25), .unavailable(.systemTooOld))
        XCTAssertFalse(DictationReadiness.canDictate(modelReady: false, choice: .apple, appleAvailability: apple(ios: 25)))
    }

    func testAppleChosenWithoutSpeechTranscriberCannotDictate() {
        XCTAssertFalse(DictationReadiness.canDictate(modelReady: false, choice: .apple,
                                                     appleAvailability: apple(speechTranscriber: false)))
    }

    func testAppleChosenButModelNotInstalledCannotDictate() {
        for asset in [AppleEngineAssetState.unknown, .notInstalled, .installing(fraction: 0.4), .failed] {
            XCTAssertFalse(DictationReadiness.canDictate(modelReady: false, choice: .apple,
                                                         appleAvailability: apple(asset: asset)), "\(asset)")
        }
    }

    // MARK: - The App Group record

    func testRecordKeepsTheReadyLanguageAndClearsOnAnythingElse() {
        AppleEngineReadinessRecord.write(.ready(languageCode: "fr"), to: defaults)
        XCTAssertEqual(AppleEngineReadinessRecord.readyLanguage(in: defaults), "fr")
        AppleEngineReadinessRecord.write(.unavailable(.autoDetect), to: defaults)
        XCTAssertNil(AppleEngineReadinessRecord.readyLanguage(in: defaults))
        AppleEngineReadinessRecord.write(.ready(languageCode: "en"), to: defaults)
        AppleEngineReadinessRecord.write(.needsAsset(.notInstalled), to: defaults)
        XCTAssertNil(AppleEngineReadinessRecord.readyLanguage(in: defaults))
    }

    func testRecordOnlyCountsForTheSameLanguage() {
        XCTAssertEqual(AppleEngineReadinessRecord.availability(readyLanguage: "fr", dictationLanguageCode: "fr"),
                       .ready(languageCode: "fr"))
        XCTAssertFalse(AppleEngineReadinessRecord.availability(readyLanguage: "fr", dictationLanguageCode: "en").isReady)
        XCTAssertFalse(AppleEngineReadinessRecord.availability(readyLanguage: "fr", dictationLanguageCode: nil).isReady)
        XCTAssertFalse(AppleEngineReadinessRecord.availability(readyLanguage: nil, dictationLanguageCode: "fr").isReady)
    }

    func testDefaultsReadingWithNoKeysCannotDictate() {
        XCTAssertFalse(DictationReadiness.canDictate(defaults: defaults, dictationLanguageCode: "fr"))
    }

    func testDefaultsReadingModelReadyIsUnchanged() {
        defaults.set(true, forKey: SharedKeys.modelReady)
        XCTAssertTrue(DictationReadiness.canDictate(defaults: defaults, dictationLanguageCode: "fr"))
        XCTAssertTrue(DictationReadiness.canDictate(defaults: defaults, dictationLanguageCode: nil))
    }

    func testDefaultsReadingAppleOnly() {
        SpeechEngineChoice.write(.apple, to: defaults)
        AppleEngineReadinessRecord.write(.ready(languageCode: "fr"), to: defaults)
        XCTAssertTrue(DictationReadiness.canDictate(defaults: defaults, dictationLanguageCode: "fr"))
        // The language changed since the app last looked: not ready until it looks again.
        XCTAssertFalse(DictationReadiness.canDictate(defaults: defaults, dictationLanguageCode: "en"))
        XCTAssertFalse(DictationReadiness.canDictate(defaults: defaults, dictationLanguageCode: nil))
        // A record without the choice is not a choice.
        SpeechEngineChoice.write(.downloadedModel, to: defaults)
        XCTAssertFalse(DictationReadiness.canDictate(defaults: defaults, dictationLanguageCode: "fr"))
    }

    // MARK: - The tap routing an Apple-only user reaches (left on `modelReady`)

    /// The keyboard and Home's mic pass `modelReady` to `RecordTapRouting`, not
    /// `canDictate`: with no downloaded model the tap goes straight to `startDictation`,
    /// whatever the load state, so no preparation screen is ever raised for a model that
    /// does not exist. That is what lets an Apple-only user through both.
    func testTapWithNoDownloadedModelAlwaysStartsDictation() {
        for state in [ModelLoadState.idle, .loading, .ready] {
            for warm in [true, false] {
                XCTAssertEqual(RecordTapRouting.decide(dictationStatus: .idle, isModelDownloaded: false,
                                                       loadState: state, isModelWarm: warm), .startDictation)
            }
        }
    }

    // MARK: - The log header

    func testLogHeaderNamesAppleOnlyWhenPicked() {
        let model = PersistentLog.buildExportHeader(iosVersion: "26.5", appVersion: "2.0.3", buildNumber: "46",
                                                    deviceModel: "iPhone", activeModel: "parakeet-tdt-0.6b-v3")
        XCTAssertTrue(model.contains("| Model: parakeet-tdt-0.6b-v3\nWindow:"), model)
        let apple = PersistentLog.buildExportHeader(iosVersion: "26.5", appVersion: "2.0.3", buildNumber: "46",
                                                    deviceModel: "iPhone", activeModel: "none", engineChoice: .apple)
        XCTAssertTrue(apple.contains("| Model: none | Engine: apple\nWindow:"), apple)
    }
}
