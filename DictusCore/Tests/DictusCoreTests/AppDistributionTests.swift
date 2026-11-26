// DictusCore/Tests/DictusCoreTests/AppDistributionTests.swift
// The distribution the app hands the keyboard, and swipe typing's switches as the keyboard
// applies them on each one (#948).
import CoreGraphics
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
    func testTheKeyboardSwipesOnlyWithTheSwitchOnATestBuildInEnglishFrenchSpanishOrGerman() {
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
        XCTAssertEqual(availability(.german), .on)
        AppDistribution.record(.appStore, in: defaults)
        XCTAssertEqual(availability(.english), .appStore)
        defaults.removeObject(forKey: SharedKeys.appDistribution)
        XCTAssertEqual(availability(.french), .appStore, "no distribution recorded")
        keyboard().swipeTyping = false
        AppDistribution.record(.debug, in: defaults)
        XCTAssertEqual(availability(.english), .off)
    }

    // MARK: - Spatial autocorrect as the keyboard applies it

    /// The buffer of a fully typed word, its taps on the key centres.
    private func typedBuffer(_ word: String) -> SpatialTouchBuffer {
        var buffer = SpatialTouchBuffer()
        let keys = SpatialDecoder.Keys(
            centres: ["a": CGPoint(x: 20, y: 27), "b": CGPoint(x: 60, y: 27)],
            pitch: CGSize(width: 40, height: 54), bottomRowY: 135, space: CGRect(x: 100, y: 162, width: 200, height: 54)
        )
        var token = ""
        for c in word {
            token.append(c)
            buffer.typed(String(c), at: CGPoint(x: token.count, y: 0), keys: keys, token: token)
        }
        return buffer
    }

    /// The Experiments switch off (its default) on every build: the space bar asks the
    /// decoder nothing, though the buffer holds every tap of the word.
    func testSpatialAutocorrectOffGivesTheDecoderNothing() {
        let buffer = typedBuffer("ab")
        XCTAssertNotNil(buffer.decoderInput(for: "ab", isOn: true), "the buffer holds the word")
        for distribution in AppDistribution.allCases {
            AppDistribution.record(distribution, in: defaults)
            XCTAssertFalse(keyboard().isSpatialAutocorrectEffective, "untouched, \(distribution.rawValue)")
            keyboard().spatialAutocorrect = false
            XCTAssertFalse(keyboard().isSpatialAutocorrectEffective, "off, \(distribution.rawValue)")
            XCTAssertNil(buffer.decoderInput(for: "ab", isOn: keyboard().isSpatialAutocorrectEffective))
            defaults.removeObject(forKey: SharedKeys.keyboardSpatialAutocorrect)
        }
    }

    /// Switched on in TestFlight, then the App Store build: ignored, as swipe typing is.
    func testAnAppStoreBuildIgnoresSpatialAutocorrectSwitchedOn() {
        let buffer = typedBuffer("ab")
        keyboard().spatialAutocorrect = true
        AppDistribution.record(.appStore, in: defaults)
        XCTAssertTrue(keyboard().spatialAutocorrect, "the choice is kept")
        XCTAssertFalse(keyboard().isSpatialAutocorrectEffective)
        XCTAssertNil(buffer.decoderInput(for: "ab", isOn: keyboard().isSpatialAutocorrectEffective))
        defaults.removeObject(forKey: SharedKeys.appDistribution)
        XCTAssertFalse(keyboard().isSpatialAutocorrectEffective, "no distribution recorded")
    }

    func testATestBuildWithSpatialAutocorrectOnGivesTheDecoderTheTaps() {
        let buffer = typedBuffer("ab")
        keyboard().spatialAutocorrect = true
        for distribution in [AppDistribution.debug, .testFlight] {
            AppDistribution.record(distribution, in: defaults)
            XCTAssertTrue(keyboard().isSpatialAutocorrectEffective, distribution.rawValue)
            let input = buffer.decoderInput(for: "ab", isOn: keyboard().isSpatialAutocorrectEffective)
            XCTAssertEqual(input?.taps, [CGPoint(x: 1, y: 0), CGPoint(x: 2, y: 0)], distribution.rawValue)
        }
    }

    // MARK: - Delete swipe, a normal setting

    func testDeleteWordSwipeActsAsStoredOnEveryBuild() {
        for distribution in AppDistribution.allCases {
            AppDistribution.record(distribution, in: defaults)
            defaults.removeObject(forKey: SharedKeys.keyboardDeleteWordSwipe)
            XCTAssertTrue(keyboard().deleteWordSwipe, "untouched, \(distribution.rawValue)")
            keyboard().deleteWordSwipe = false
            XCTAssertFalse(keyboard().deleteWordSwipe, "switched off, \(distribution.rawValue)")
        }
    }

    func testTheExperimentRule() {
        XCTAssertTrue(KeyboardFeatureSettings.experiment(true, default: false, on: .testBuild))
        XCTAssertFalse(KeyboardFeatureSettings.experiment(true, default: false, on: .appStore))
        XCTAssertTrue(KeyboardFeatureSettings.experiment(false, default: true, on: .appStore))
        XCTAssertFalse(KeyboardFeatureSettings.experiment(false, default: true, on: .testBuild))
    }
}
