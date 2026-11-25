// DictusCore/Tests/DictusCoreTests/OtherModelsCardRuleTests.swift
import XCTest
@testable import DictusCore

/// #1057 PR 3: when Home presents the other models to someone dictating with Apple's.
final class OtherModelsCardRuleTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "OtherModelsCardRuleTests"

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

    private let appleReady = AppleEngineAvailability.ready(languageCode: "fr")

    private func shows(modelReady: Bool = false, choice: SpeechEngineChoice = .apple,
                       apple: AppleEngineAvailability? = nil,
                       downloaded: Int = 0, dismissed: Bool = false) -> Bool {
        OtherModelsCardRule.shows(modelReady: modelReady, choice: choice,
                                  appleAvailability: apple ?? appleReady,
                                  downloadedModelCount: downloaded, dismissed: dismissed)
    }

    func testShowsWhenDictatingWithAppleAndNoModel() {
        XCTAssertTrue(shows())
    }

    func testHiddenOnceClosed() {
        XCTAssertFalse(shows(dismissed: true))
    }

    func testHiddenWhenADownloadedModelIsActive() {
        XCTAssertFalse(shows(modelReady: true, downloaded: 1))
        XCTAssertFalse(shows(modelReady: true, choice: .downloadedModel, downloaded: 1))
    }

    /// A model downloaded but still preparing: `modelReady` is false, the model is on disk.
    func testHiddenWhenAModelIsOnDiskButNotReadyYet() {
        XCTAssertFalse(shows(modelReady: false, downloaded: 1))
    }

    /// `modelReady` with an empty list cannot happen in the app; the card stays hidden anyway.
    func testHiddenWhenModelReadyEvenWithAnEmptyList() {
        XCTAssertFalse(shows(modelReady: true, downloaded: 0))
    }

    func testHiddenWhenAppleIsNotTheChoice() {
        XCTAssertFalse(shows(choice: .downloadedModel))
    }

    func testHiddenWhenAppleIsNotReady() {
        let notReady: [AppleEngineAvailability] = [
            .needsAsset(.unknown), .needsAsset(.notInstalled), .needsAsset(.installing(fraction: 0.4)),
            .needsAsset(.failed), .unavailable(.systemTooOld), .unavailable(.speechTranscriberUnavailable),
            .unavailable(.autoDetect), .unavailable(.languageNotCovered("it"))
        ]
        for availability in notReady {
            XCTAssertFalse(shows(apple: availability), "\(availability)")
        }
    }

    func testDismissalIsStoredAndStays() {
        XCTAssertFalse(OtherModelsCardRule.isDismissed(in: defaults))
        OtherModelsCardRule.dismiss(in: defaults)
        XCTAssertTrue(OtherModelsCardRule.isDismissed(in: defaults))
        XCTAssertTrue(defaults.bool(forKey: SharedKeys.otherModelsCardDismissed))
        OtherModelsCardRule.dismiss(in: defaults)
        XCTAssertTrue(OtherModelsCardRule.isDismissed(in: defaults))
    }

    // MARK: - The size the card prints

    func testMegabytesLabelIsTheSizeLabelWithoutItsTilde() throws {
        let english = Locale(identifier: "en_US")
        let french = Locale(identifier: "fr_FR")
        let parakeet = try XCTUnwrap(ModelInfo.forIdentifier(ModelInfo.parakeetV3Identifier))
        XCTAssertEqual(parakeet.megabytesLabel(locale: english), "\(parakeet.sizeBytes / 1_000_000) MB")
        for model in ModelInfo.all {
            for locale in [english, french] {
                XCTAssertEqual(model.sizeLabel(locale: locale), "~" + model.megabytesLabel(locale: locale))
            }
        }
        XCTAssertTrue(parakeet.megabytesLabel(locale: french).hasSuffix("Mo"))
    }
}
