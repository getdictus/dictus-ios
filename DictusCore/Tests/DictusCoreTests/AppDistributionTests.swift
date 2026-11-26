// DictusCore/Tests/DictusCoreTests/AppDistributionTests.swift
// The distribution the app hands the keyboard, and swipe typing's switches as the keyboard
// applies them on each one (#948).
import XCTest
@testable import DictusCore

final class AppDistributionTests: XCTestCase {

    /// A suite of its own: the shared App Group suite is live state on a developer machine.
    private let suiteName = "dictus.tests.appDistribution"
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

    /// The key and its values are a contract between two processes shipped together but
    /// updated apart: pinned so a rename is a decision.
    func testTheKeyAndValuesAreTheAgreedStrings() {
        XCTAssertEqual(SharedKeys.appDistribution, "dictus.appDistribution")
        XCTAssertEqual(AppDistribution.allCases.map(\.rawValue), ["debug", "testFlight", "appStore"])
    }

    func testDetectionTellsDebugTestFlightAndTheAppStoreApart() {
        let storeKit = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/X/StoreKit")
        XCTAssertEqual(AppDistribution.detect(isDebug: true, receiptURL: storeKit.appendingPathComponent("receipt")), .debug)
        XCTAssertEqual(AppDistribution.detect(isDebug: false, receiptURL: storeKit.appendingPathComponent("sandboxReceipt")), .testFlight)
        XCTAssertEqual(AppDistribution.detect(isDebug: false, receiptURL: storeKit.appendingPathComponent("receipt")), .appStore)
        XCTAssertEqual(AppDistribution.detect(isDebug: false, receiptURL: nil), .appStore)
    }

    /// Same answer as `BuildChannel.detect` on the same facts: one rule, two granularities.
    func testItAgreesWithBuildChannel() {
        let storeKit = URL(fileURLWithPath: "/StoreKit")
        for isDebug in [true, false] {
            for receipt in [nil, "receipt", "sandboxReceipt", "other"] {
                let url = receipt.map { storeKit.appendingPathComponent($0) }
                XCTAssertEqual(AppDistribution.detect(isDebug: isDebug, receiptURL: url).channel,
                               BuildChannel.detect(isDebug: isDebug, receiptURL: url))
            }
        }
    }

    /// The three values the app writes, as the keyboard reads them back.
    func testEachRecordedValueReadsBack() {
        for distribution in AppDistribution.allCases {
            AppDistribution.record(distribution, in: defaults)
            XCTAssertEqual(AppDistribution.recorded(in: defaults), distribution)
        }
        AppDistribution.record(.debug, in: defaults)
        XCTAssertEqual(AppDistribution.recordedChannel(in: defaults), .testBuild)
        AppDistribution.record(.testFlight, in: defaults)
        XCTAssertEqual(AppDistribution.recordedChannel(in: defaults), .testBuild)
        AppDistribution.record(.appStore, in: defaults)
        XCTAssertEqual(AppDistribution.recordedChannel(in: defaults), .appStore)
    }

    /// The app never opened since the install, or wrote something this keyboard does not
    /// know: the App Store, the side where no experiment acts.
    func testAMissingOrUnknownValueReadsAsTheAppStore() {
        XCTAssertNil(AppDistribution.recorded(in: defaults))
        XCTAssertEqual(AppDistribution.recordedChannel(in: defaults), .appStore)
        defaults.set("enterprise", forKey: SharedKeys.appDistribution)
        XCTAssertNil(AppDistribution.recorded(in: defaults))
        XCTAssertEqual(AppDistribution.recordedChannel(in: defaults), .appStore)
        defaults.set(1, forKey: SharedKeys.appDistribution)
        XCTAssertEqual(AppDistribution.recordedChannel(in: defaults), .appStore)
    }

    // MARK: - Swipe typing as the keyboard applies it

    private func keyboard() -> KeyboardFeatureSettings { .forKeyboard(store: defaults) }

    /// Switched on in TestFlight, then the App Store build: ignored, its default acts
    /// (Pierre, 2026-11-24).
    func testAnAppStoreBuildIgnoresSwipeTypingSwitchedOnInTestFlight() {
        keyboard().swipeTyping = true
        keyboard().swipeTrail = false
        AppDistribution.record(.appStore, in: defaults)
        XCTAssertTrue(keyboard().swipeTyping, "the choice is kept")
        XCTAssertFalse(keyboard().isSwipeTypingEffective)
        XCTAssertEqual(keyboard().isSwipeTypingEffective, KeyboardFeatureSettings.Defaults.swipeTyping)
        XCTAssertEqual(keyboard().isSwipeTrailEffective, KeyboardFeatureSettings.Defaults.swipeTrail)
    }

    func testATestBuildActsOnTheSwitches() {
        keyboard().swipeTyping = true
        keyboard().swipeTrail = false
        for distribution in [AppDistribution.debug, .testFlight] {
            AppDistribution.record(distribution, in: defaults)
            XCTAssertTrue(keyboard().isSwipeTypingEffective, distribution.rawValue)
            XCTAssertFalse(keyboard().isSwipeTrailEffective, distribution.rawValue)
        }
    }

    func testWithoutARecordedDistributionSwipeTypingStaysOff() {
        keyboard().swipeTyping = true
        XCTAssertFalse(keyboard().isSwipeTypingEffective)
    }

    func testAnUntouchedInstallHasSwipeTypingOffOnEveryDistribution() {
        for distribution in AppDistribution.allCases {
            AppDistribution.record(distribution, in: defaults)
            XCTAssertFalse(keyboard().isSwipeTypingEffective, distribution.rawValue)
        }
    }

    /// The keyboard builds its swipe controller only on `.on`: every other answer is the
    /// keyboard without swipe typing.
    func testTheKeyboardSwipesOnlyWithTheSwitchOnATestBuildInEnglishFrenchOrSpanish() {
        func availability(_ language: SupportedLanguage) -> SwipeTypingText.Availability {
            SwipeTypingText.availability(keyboard(), language: language)
        }
        AppDistribution.record(.testFlight, in: defaults)
        for language in SupportedLanguage.allCases {
            XCTAssertEqual(availability(language), .off, "untouched install, \(language)")
        }
        keyboard().swipeTyping = true
        XCTAssertEqual(availability(.english), .on)
        XCTAssertEqual(availability(.french), .on)
        XCTAssertEqual(availability(.spanish), .on)
        XCTAssertEqual(availability(.german), .language)
        AppDistribution.record(.appStore, in: defaults)
        XCTAssertEqual(availability(.english), .appStore)
        defaults.removeObject(forKey: SharedKeys.appDistribution)
        XCTAssertEqual(availability(.french), .appStore, "no distribution recorded")
        keyboard().swipeTyping = false
        AppDistribution.record(.debug, in: defaults)
        XCTAssertEqual(availability(.english), .off)
    }

    func testTheExperimentRule() {
        XCTAssertTrue(KeyboardFeatureSettings.experiment(true, default: false, on: .testBuild))
        XCTAssertFalse(KeyboardFeatureSettings.experiment(true, default: false, on: .appStore))
        XCTAssertTrue(KeyboardFeatureSettings.experiment(false, default: true, on: .appStore))
        XCTAssertFalse(KeyboardFeatureSettings.experiment(false, default: true, on: .testBuild))
    }
}
