// DictusCore/Tests/DictusCoreTests/KeyboardFeatureSettingsTests.swift
// The keyboard feature switches: their defaults, a round trip through the store, the
// Adaptive touch rule, the partner language and the Experiments page per build channel.

import XCTest
@testable import DictusCore

final class KeyboardFeatureSettingsTests: XCTestCase {

    /// A suite of its own: the shared App Group suite is live state on a developer machine.
    private let suiteName = "dictus.tests.keyboardFeatureSettings"
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

    private func settings(_ channel: BuildChannel = .testBuild) -> KeyboardFeatureSettings {
        KeyboardFeatureSettings(store: defaults, channel: channel)
    }

    // MARK: - Keys

    /// The strings are a contract with every install's stored choices: renaming one resets
    /// it. Pinned here so a rename is a decision, not an accident.
    func testTheKeysAreTheAgreedStrings() {
        XCTAssertEqual(SharedKeys.keyboardSpatialAutocorrect, "dictus.keyboard.spatialAutocorrect")
        XCTAssertEqual(SharedKeys.keyboardAdaptiveTouch, "dictus.keyboard.adaptiveTouch")
        XCTAssertEqual(SharedKeys.keyboardBilingualAutocorrect, "dictus.keyboard.bilingualAutocorrect")
        XCTAssertEqual(SharedKeys.keyboardPartnerLanguage, "dictus.keyboard.partnerLanguage")
        XCTAssertEqual(SharedKeys.keyboardDeleteWordSwipe, "dictus.keyboard.deleteWordSwipe")
        XCTAssertEqual(SharedKeys.keyboardSwipeTyping, "dictus.keyboard.swipeTyping")
        XCTAssertEqual(SharedKeys.keyboardSwipeTrail, "dictus.keyboard.swipeTrail")
    }

    /// The older keyboard settings keep their names (renaming would reset them).
    func testTheOlderKeyboardKeysAreUnchanged() {
        XCTAssertEqual(SharedKeys.autocorrectEnabled, "dictus.autocorrectEnabled")
        XCTAssertEqual(SharedKeys.hapticsEnabled, "dictus.hapticsEnabled")
        XCTAssertEqual(SharedKeys.numberRowEnabled, "dictus.numberRowEnabled")
    }

    // MARK: - Defaults

    func testAnUntouchedInstallReadsTheAgreedDefaults() {
        let fresh = settings()
        XCTAssertFalse(fresh.spatialAutocorrect)
        XCTAssertFalse(fresh.adaptiveTouch)
        XCTAssertFalse(fresh.bilingualAutocorrect)
        XCTAssertTrue(fresh.deleteWordSwipe, "Delete-word swipe is on by default (#609)")
        XCTAssertFalse(fresh.swipeTyping)
        XCTAssertTrue(fresh.swipeTrail)
    }

    /// What an untouched install reads is what `Defaults` says, the value the screen's
    /// @AppStorage takes: the two cannot disagree.
    func testAnUntouchedInstallReadsDefaultsAndWritesNothing() {
        let fresh = settings()
        XCTAssertEqual(fresh.spatialAutocorrect, KeyboardFeatureSettings.Defaults.spatialAutocorrect)
        XCTAssertEqual(fresh.adaptiveTouch, KeyboardFeatureSettings.Defaults.adaptiveTouch)
        XCTAssertEqual(fresh.bilingualAutocorrect, KeyboardFeatureSettings.Defaults.bilingualAutocorrect)
        XCTAssertEqual(fresh.deleteWordSwipe, KeyboardFeatureSettings.Defaults.deleteWordSwipe)
        XCTAssertEqual(fresh.swipeTyping, KeyboardFeatureSettings.Defaults.swipeTyping)
        XCTAssertEqual(fresh.swipeTrail, KeyboardFeatureSettings.Defaults.swipeTrail)
        XCTAssertNil(defaults.object(forKey: SharedKeys.keyboardDeleteWordSwipe),
                     "reading a default must not store it, or a later default change would not reach this install")
    }

    // MARK: - Round trip

    func testEverySwitchReadsBackWhatWasWritten() {
        let writer = settings()
        writer.spatialAutocorrect = true
        writer.adaptiveTouch = true
        writer.bilingualAutocorrect = true
        writer.deleteWordSwipe = false
        writer.swipeTyping = true
        writer.swipeTrail = false

        // A second instance on the same store, the way the keyboard reads what the app wrote.
        let reader = settings()
        XCTAssertTrue(reader.spatialAutocorrect)
        XCTAssertTrue(reader.adaptiveTouch)
        XCTAssertTrue(reader.bilingualAutocorrect)
        XCTAssertFalse(reader.deleteWordSwipe)
        XCTAssertTrue(reader.swipeTyping)
        XCTAssertFalse(reader.swipeTrail)
    }

    /// The screen writes through @AppStorage, which stores a plain Bool under the key.
    func testAValueWrittenStraightToTheKeyIsRead() {
        defaults.set(false, forKey: SharedKeys.keyboardDeleteWordSwipe)
        defaults.set(true, forKey: SharedKeys.keyboardSpatialAutocorrect)
        XCTAssertFalse(settings().deleteWordSwipe)
        XCTAssertTrue(settings().spatialAutocorrect)
    }

    // MARK: - Adaptive touch

    func testAdaptiveTouchIsEffectiveOnlyWithTheSpatialDecoder() {
        func rule(_ adaptive: Bool, _ spatial: Bool) -> Bool {
            KeyboardFeatureSettings.isAdaptiveTouchEffective(adaptiveTouch: adaptive, spatialAutocorrect: spatial)
        }
        XCTAssertTrue(rule(true, true))
        XCTAssertFalse(rule(true, false), "no decoder, nothing for the key centres to act on")
        XCTAssertFalse(rule(false, true))
        XCTAssertFalse(rule(false, false))
    }

    func testTheStoredSwitchesFollowTheSameRule() {
        let stored = settings()
        stored.adaptiveTouch = true
        XCTAssertFalse(stored.isAdaptiveTouchEffective)
        XCTAssertTrue(stored.adaptiveTouch, "the user's choice is kept while it has no effect")
        stored.spatialAutocorrect = true
        XCTAssertTrue(stored.isAdaptiveTouchEffective)
    }

    // MARK: - Partner language

    func testEachKeyboardLanguageHasADefaultPartnerOtherThanItself() {
        XCTAssertEqual(KeyboardFeatureSettings.defaultPartnerLanguage(for: .french), .english)
        XCTAssertEqual(KeyboardFeatureSettings.defaultPartnerLanguage(for: .english), .french)
        XCTAssertEqual(KeyboardFeatureSettings.defaultPartnerLanguage(for: .spanish), .english)
        XCTAssertEqual(KeyboardFeatureSettings.defaultPartnerLanguage(for: .german), .english)
        for language in SupportedLanguage.allCases {
            XCTAssertNotEqual(KeyboardFeatureSettings.defaultPartnerLanguage(for: language), language)
        }
    }

    func testAnUntouchedInstallGetsTheDefaultPartner() {
        XCTAssertEqual(settings().partnerLanguage(for: .french), .english)
        XCTAssertEqual(settings().partnerLanguage(for: .english), .french)
    }

    func testAChosenPartnerIsReadBack() {
        settings().setPartnerLanguage(.spanish)
        XCTAssertEqual(settings().partnerLanguage(for: .french), .spanish)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.keyboardPartnerLanguage), "es")
    }

    /// One global key: a partner equal to the keyboard's own language would pair a
    /// language with itself, so it reads as the default.
    func testAPartnerEqualToTheKeyboardReadsAsTheDefault() {
        settings().setPartnerLanguage(.english)
        XCTAssertEqual(settings().partnerLanguage(for: .french), .english)
        XCTAssertEqual(settings().partnerLanguage(for: .english), .french)
    }

    func testAnUnknownStoredPartnerReadsAsTheDefault() {
        defaults.set("zh", forKey: SharedKeys.keyboardPartnerLanguage)
        XCTAssertEqual(settings().partnerLanguage(for: .french), .english)
    }

    // MARK: - Experiments page

    func testTheExperimentsPageIsHiddenInTheAppStoreBuild() {
        XCTAssertFalse(KeyboardFeatureSettings.isExperimentsPageVisible(on: .appStore))
        XCTAssertFalse(settings(.appStore).isExperimentsPageVisible)
    }

    func testTheExperimentsPageIsShownOnATestBuild() {
        XCTAssertTrue(KeyboardFeatureSettings.isExperimentsPageVisible(on: .testBuild))
        XCTAssertTrue(settings(.testBuild).isExperimentsPageVisible)
    }

    /// End to end from the binary's facts to the page, through `BuildChannel.detect`:
    /// Debug, TestFlight (a `sandboxReceipt`) and the App Store (a `receipt`).
    func testThePageFollowsEachDistributionChannel() {
        let storeKit = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/X/StoreKit")
        func visible(isDebug: Bool, receipt: String?) -> Bool {
            let channel = BuildChannel.detect(isDebug: isDebug,
                                              receiptURL: receipt.map { storeKit.appendingPathComponent($0) })
            return settings(channel).isExperimentsPageVisible
        }
        XCTAssertTrue(visible(isDebug: true, receipt: nil), "Debug")
        XCTAssertTrue(visible(isDebug: true, receipt: "receipt"), "Debug, whatever its receipt")
        XCTAssertTrue(visible(isDebug: false, receipt: "sandboxReceipt"), "TestFlight")
        XCTAssertFalse(visible(isDebug: false, receipt: "receipt"), "App Store")
        XCTAssertFalse(visible(isDebug: false, receipt: nil), "no receipt URL: the side that shows nothing")
    }

    /// The page is a property of the binary, not of the store: nothing in the App Group
    /// can make it appear in the App Store build.
    func testNoStoredValueShowsThePageInTheAppStoreBuild() {
        let stored = settings(.appStore)
        stored.spatialAutocorrect = true
        stored.bilingualAutocorrect = true
        XCTAssertFalse(stored.isExperimentsPageVisible)
    }
}
