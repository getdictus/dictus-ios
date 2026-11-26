// DictusCore/Tests/DictusCoreTests/OnboardingConfirmDownloadTests.swift
import XCTest
@testable import DictusCore

/// #1057: what confirming the onboarding's language downloads, and the Parakeet handoff
/// marker it leaves on Apple's route.
final class OnboardingConfirmDownloadTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "OnboardingConfirmDownloadTests"
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

    /// iPhone 15 Pro Max: 8 GB, Parakeet recommended.
    private let iPhone15ProMax = DeviceCapabilities(physicalMemoryGB: 8, availableMemoryMB: 3000,
                                                    deviceModelIdentifier: "iPhone16,2", thermalState: .nominal)
    /// iPhone 12: 4 GB A14, Whisper Small recommended (#921).
    private let iPhone12 = DeviceCapabilities(physicalMemoryGB: 4, availableMemoryMB: 3000,
                                              deviceModelIdentifier: "iPhone13,2", thermalState: .nominal)

    private func appleAvailability(covered: Bool = true) -> AppleEngineAvailability {
        let language = AppleSpeechLanguage.evaluate(mode: .followKeyboard, keyboardLanguageCode: "fr",
                                                    speechTranscriberAvailable: true,
                                                    supportedLocales: covered ? supported : ["en-US"])
        return AppleEngineAvailability.evaluate(systemMajorVersion: 26, language: language, assetState: .notInstalled)
    }

    /// The whole decision the language step takes, from the device and Apple's coverage.
    private func confirm(on device: DeviceCapabilities, appleCovers: Bool = true) -> OnboardingConfirmDownload {
        let route = OnboardingEngineRoute.decide(spokenLanguageHasDictusKeyboard: true,
                                                 keyboardDictatesWithApple: !device.isPreA14,
                                                 recommendedModelReady: false,
                                                 dictationLanguageCode: "fr",
                                                 appleAvailability: appleAvailability(covered: appleCovers))
        let recommended = ModelInfo.recommendedIdentifier(forSpokenLanguage: "fr", on: device)
        return OnboardingConfirmDownload.decide(route: route, recommendedModel: recommended)
    }

    /// What the onboarding writes for a decision, as `OnboardingView` does.
    private func applyMarker(_ download: OnboardingConfirmDownload) {
        if download.marksParakeetHandoff {
            ParakeetHandoff.markPending(in: defaults)
        } else {
            ParakeetHandoff.cancel(in: defaults)
        }
    }

    // MARK: - Route decision

    func testAppleCoversAndParakeetRecommendedDownloadsParakeetAndMarksHandoff() {
        let download = confirm(on: iPhone15ProMax)
        XCTAssertEqual(download, .parakeetBehindApple(ModelInfo.parakeetV3Identifier))
        XCTAssertEqual(download.model, ModelInfo.parakeetV3Identifier)
        XCTAssertTrue(download.marksParakeetHandoff)

        applyMarker(download)
        XCTAssertTrue(ParakeetHandoff.isPending(in: defaults))
    }

    func testAppleCoversAndWhisperSmallRecommendedDownloadsNothingAndLeavesNoMarker() {
        XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: "fr", on: iPhone12), "openai_whisper-small")
        let download = confirm(on: iPhone12)
        XCTAssertEqual(download, OnboardingConfirmDownload.none)
        XCTAssertNil(download.model)
        XCTAssertFalse(download.marksParakeetHandoff)

        applyMarker(download)
        XCTAssertFalse(ParakeetHandoff.isPending(in: defaults))
    }

    func testAppleDoesNotCoverKeepsTodaysDownloadWithoutMarker() {
        for device in [iPhone15ProMax, iPhone12] {
            let recommended = ModelInfo.recommendedIdentifier(forSpokenLanguage: "fr", on: device)
            let download = confirm(on: device, appleCovers: false)
            XCTAssertEqual(download, .recommended(recommended), device.deviceModelIdentifier)
            XCTAssertFalse(download.marksParakeetHandoff, device.deviceModelIdentifier)
        }
    }

    func testTodaysRouteDownloadsTheRecommendationWhateverItIs() {
        for model in [ModelInfo.parakeetV3Identifier, "openai_whisper-small"] {
            XCTAssertEqual(OnboardingConfirmDownload.decide(route: .downloadedModel, recommendedModel: model),
                           .recommended(model))
        }
    }

    func testOnlyParakeetDownloadsBehindApple() {
        XCTAssertTrue(OnboardingConfirmDownload.downloadsBehindApple(recommendedModel: ModelInfo.parakeetV3Identifier))
        XCTAssertFalse(OnboardingConfirmDownload.downloadsBehindApple(recommendedModel: "openai_whisper-small"))
        XCTAssertFalse(OnboardingConfirmDownload.downloadsBehindApple(recommendedModel: "unknown-model"))
    }

    func testConfirmingAgainOnTodaysRouteClearsAStaleMarker() {
        ParakeetHandoff.markPending(in: defaults)
        applyMarker(confirm(on: iPhone15ProMax, appleCovers: false))
        XCTAssertFalse(ParakeetHandoff.isPending(in: defaults))
    }

    // MARK: - Marker

    func testMarkerIsAbsentByDefault() {
        XCTAssertFalse(ParakeetHandoff.isPending(in: defaults))
    }

    func testAnyEngineChoiceOnModelsPageClearsTheMarkerAndStoresTheChoice() {
        // Apple's card and a downloaded model's card alike.
        for choice in [SpeechEngineChoice.apple, .downloadedModel] {
            SpeechEngineChoice.write(choice == .apple ? .downloadedModel : .apple, to: defaults)
            ParakeetHandoff.markPending(in: defaults)
            ParakeetHandoff.recordModelsPageChoice(choice, in: defaults)
            XCTAssertFalse(ParakeetHandoff.isPending(in: defaults), "\(choice)")
            XCTAssertNil(defaults.object(forKey: SharedKeys.parakeetHandoffPending), "\(choice)")
            XCTAssertEqual(SpeechEngineChoice.read(from: defaults), choice)
        }
    }

    func testMarkingTheHandoffLeavesAppleActive() {
        SpeechEngineChoice.write(.apple, to: defaults)
        ParakeetHandoff.markPending(in: defaults)
        XCTAssertEqual(SpeechEngineChoice.read(from: defaults), .apple)
    }
}
