// DictusCore/Tests/DictusCoreTests/AppleSpeechEngineChoiceTests.swift
import XCTest
@testable import DictusCore

/// "Apple (on-device)" on the Models screen: when it can be picked (iOS version ×
/// dictation language × asset state), what the app dictates with once it is, and how
/// the choice is kept.
final class AppleSpeechEngineChoiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "AppleSpeechEngineChoiceTests"

    /// A slice of `SpeechTranscriber.supportedLocales` (macOS 27 / iOS 26), as BCP-47.
    private let supported = ["de-DE", "en-US", "en-GB", "es-ES", "fr-CA", "fr-FR", "ja-JP"]

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

    private func evaluate(ios: Int = 26,
                          mode: TranscriptionLanguageMode = .followKeyboard,
                          keyboard: String = "fr",
                          locales: [String]? = nil,
                          asset: AppleEngineAssetState = .installed) -> AppleEngineAvailability {
        AppleEngineAvailability.evaluate(systemMajorVersion: ios, mode: mode, keyboardLanguageCode: keyboard,
                                         supportedLocales: locales ?? supported, assetState: asset)
    }

    // MARK: - Availability: iOS version

    func testBeforeIOS26ItIsGreyedWhateverTheLanguageAndAsset() {
        for ios in [17, 18, 25] {
            for asset in [AppleEngineAssetState.unknown, .notInstalled, .installed] {
                XCTAssertEqual(evaluate(ios: ios, asset: asset), .unavailable(.systemTooOld), "iOS \(ios) \(asset)")
            }
        }
    }

    func testFromIOS26ItIsReadyWithTheModelInstalled() {
        for ios in [26, 27] {
            XCTAssertEqual(evaluate(ios: ios), .ready(languageCode: "fr"), "iOS \(ios)")
        }
    }

    func testAnUnreadableSystemVersionIsGreyed() {
        XCTAssertEqual(evaluate(ios: InKeyboardDictationRoute.majorVersion(of: "")), .unavailable(.systemTooOld))
    }

    // MARK: - Availability: language

    func testAutomaticDetectionIsGreyed() {
        XCTAssertEqual(evaluate(mode: .autoDetect), .unavailable(.autoDetect))
    }

    func testALanguageAppleDoesNotListIsGreyed() {
        XCTAssertEqual(evaluate(mode: .explicit(.german), locales: ["en-US", "fr-FR"]), .unavailable(.languageNotCovered("de")))
    }

    func testNoSupportedLocaleAtAllIsGreyed() {
        XCTAssertEqual(evaluate(locales: []), .unavailable(.languageNotCovered("fr")))
    }

    func testFollowKeyboardFollowsTheKeyboardLanguage() {
        XCTAssertEqual(evaluate(keyboard: "en"), .ready(languageCode: "en"))
        XCTAssertEqual(evaluate(keyboard: "de", locales: ["fr-FR"]), .unavailable(.languageNotCovered("de")))
    }

    func testAnExplicitLanguageWinsOverTheKeyboard() {
        XCTAssertEqual(evaluate(mode: .explicit(.spanish), keyboard: "fr"), .ready(languageCode: "es"))
    }

    func testOnlyTheLanguageSubtagCounts() {
        XCTAssertEqual(evaluate(locales: ["fr-CA"]), .ready(languageCode: "fr"))
        XCTAssertEqual(evaluate(locales: ["fr_CH"]), .ready(languageCode: "fr"))
    }

    // MARK: - Availability: asset state

    func testACoveredLanguageWithoutTheModelIsSelectableButNotReady() {
        for asset in [AppleEngineAssetState.unknown, .notInstalled, .installing(fraction: 0.4),
                      .installing(fraction: nil), .failed] {
            let availability = evaluate(asset: asset)
            XCTAssertEqual(availability, .needsAsset(asset), "\(asset)")
            XCTAssertTrue(availability.isSelectable, "\(asset)")
            XCTAssertFalse(availability.isReady, "\(asset)")
        }
    }

    func testGreyedIsNeverSelectable() {
        for reason in [AppleEngineAvailability.Reason.systemTooOld, .autoDetect, .languageNotCovered("fr")] {
            XCTAssertFalse(AppleEngineAvailability.unavailable(reason).isSelectable)
        }
    }

    func testTheGreyedReasonDoesNotDependOnTheAsset() {
        for asset in [AppleEngineAssetState.notInstalled, .installed] {
            XCTAssertEqual(evaluate(mode: .autoDetect, asset: asset), .unavailable(.autoDetect))
        }
    }

    // MARK: - What a dictation runs

    func testNotPickedDictatesWithTheDownloadedModel() {
        XCTAssertEqual(EffectiveSpeechEngine.resolve(choice: .downloadedModel, availability: evaluate()),
                       .downloadedModel)
    }

    func testPickedAndReadyDictatesWithApple() {
        XCTAssertEqual(EffectiveSpeechEngine.resolve(choice: .apple, availability: evaluate()),
                       .apple(languageCode: "fr"))
    }

    func testPickedButModelNotInstalledYetFallsBackToTheDownloadedModel() {
        XCTAssertEqual(EffectiveSpeechEngine.resolve(choice: .apple, availability: evaluate(asset: .installing(fraction: 0.5))),
                       .downloadedModel)
    }

    func testPickedThenLanguageChangedToAutoDetectFallsBackToTheDownloadedModel() {
        XCTAssertEqual(EffectiveSpeechEngine.resolve(choice: .apple, availability: evaluate(mode: .autoDetect)),
                       .downloadedModel)
    }

    func testPickedOnAnOlderSystemFallsBackToTheDownloadedModel() {
        XCTAssertEqual(EffectiveSpeechEngine.resolve(choice: .apple, availability: evaluate(ios: 18)),
                       .downloadedModel)
    }

    // MARK: - Selection persistence

    func testAbsentChoiceIsTheDownloadedModel() {
        XCTAssertEqual(SpeechEngineChoice.read(from: defaults), .downloadedModel)
    }

    func testPickingAppleIsKept() {
        SpeechEngineChoice.write(.apple, to: defaults)
        XCTAssertEqual(SpeechEngineChoice.read(from: defaults), .apple)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.speechEngineChoice), "apple")
    }

    func testPickingAModelAgainReplacesApple() {
        SpeechEngineChoice.write(.apple, to: defaults)
        SpeechEngineChoice.write(.downloadedModel, to: defaults)
        XCTAssertEqual(SpeechEngineChoice.read(from: defaults), .downloadedModel)
    }

    func testAnUnknownStoredValueReadsAsTheDownloadedModel() {
        defaults.set("whisper-on-mars", forKey: SharedKeys.speechEngineChoice)
        XCTAssertEqual(SpeechEngineChoice.read(from: defaults), .downloadedModel)
    }

    func testPickingAppleLeavesTheActiveModelAlone() {
        defaults.set("parakeet-tdt-0.6b-v3", forKey: SharedKeys.activeModel)
        SpeechEngineChoice.write(.apple, to: defaults)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.activeModel), "parakeet-tdt-0.6b-v3")
    }

    // MARK: - The rest of the pipeline, for the Apple engine

    func testApplePickedIsNeverSentToTheModelPreparationScreen() {
        // A downloaded model that never ran an inference in this install is cold...
        defaults.set("parakeet-tdt-0.6b-v3", forKey: SharedKeys.activeModel)
        let components = ["/", "var", "containers", "Bundle", "Application", "UUID-1", "Dictus.app"]
        XCTAssertFalse(ModelWarmth.isActiveModelWarm(defaults: defaults, bundlePathComponents: components,
                                                     systemVersion: "26.5"))
        // ...and does not matter once the user dictates with Apple.
        SpeechEngineChoice.write(.apple, to: defaults)
        XCTAssertTrue(ModelWarmth.isActiveModelWarm(defaults: defaults, bundlePathComponents: components,
                                                    systemVersion: "26.5"))
    }

    func testAppleIsGivenTheChosenLanguage() {
        let policy = TranscriptionLanguagePolicy(mode: .explicit(.spanish), keyboardLanguage: .french,
                                                 engine: .apple, modelIdentifier: AppleSpeechEngineIdentity.identifier)
        XCTAssertTrue(policy.sttLanguageIsEffective)
        XCTAssertEqual(policy.sttLanguageCode, "es")
    }

    func testApplePolishesInNaturalMode() {
        XCTAssertEqual(PolishPipeline.mode(sttEngine: .apple, detected: .english, target: .french), .natural)
    }

    func testAppleIsNotACatalogueDownload() {
        XCTAssertFalse(ModelInfo.allIncludingDeprecated.contains { $0.engine == .apple })
        XCTAssertNil(ModelInfo.forIdentifier(AppleSpeechEngineIdentity.identifier))
    }

    func testTheEngineSurvivesThePolicyEncoding() throws {
        let policy = TranscriptionLanguagePolicy(mode: .followKeyboard, keyboardLanguage: .french,
                                                 engine: .apple, modelIdentifier: AppleSpeechEngineIdentity.identifier)
        let decoded = try JSONDecoder().decode(TranscriptionLanguagePolicy.self, from: JSONEncoder().encode(policy))
        XCTAssertEqual(decoded.engine, .apple)
    }

    // MARK: - Recording shape

    func testFloatSamplesBecomeClippedInt16() {
        let recording = OnDeviceRecording(samples: [0, 1, -1, 2, -2, 0.5])
        let values = recording.pcm16.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }.map { Int16(littleEndian: $0) }
        XCTAssertEqual(values, [0, 32_767, -32_767, 32_767, -32_767, 16_383])
        XCTAssertEqual(recording.seconds, 6.0 / 16_000, accuracy: 1e-9)
    }
}
