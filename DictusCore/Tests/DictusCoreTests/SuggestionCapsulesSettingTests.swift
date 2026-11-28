// DictusCore/Tests/DictusCoreTests/SuggestionCapsulesSettingTests.swift
// The capsule suggestion bar's switch (#502): its key, its default, a round trip, and the
// Experiments rule on each distribution. In a file of its own so the switch adds no line to
// the shared settings tests other open branches edit.
import XCTest
@testable import DictusCore

final class SuggestionCapsulesSettingTests: XCTestCase {

    /// A suite of its own: the shared App Group suite is live state on a developer machine.
    private let suiteName = "dictus.tests.suggestionCapsules"
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

    private func keyboard() -> KeyboardFeatureSettings { .forKeyboard(store: defaults) }

    /// The string is a contract with every install's stored choice: renaming it resets it.
    func testTheKeyIsTheAgreedString() {
        XCTAssertEqual(SharedKeys.keyboardSuggestionCapsules, "dictus.keyboard.suggestionCapsules")
    }

    func testAnUntouchedInstallReadsOffAndWritesNothing() {
        XCTAssertFalse(KeyboardFeatureSettings.Defaults.suggestionCapsules)
        XCTAssertEqual(keyboard().suggestionCapsules, KeyboardFeatureSettings.Defaults.suggestionCapsules)
        XCTAssertNil(defaults.object(forKey: SharedKeys.keyboardSuggestionCapsules))
    }

    /// The screen writes through @AppStorage, a plain Bool under the key; the keyboard reads it.
    func testTheSwitchReadsBackWhatTheScreenWrote() {
        defaults.set(true, forKey: SharedKeys.keyboardSuggestionCapsules)
        XCTAssertTrue(keyboard().suggestionCapsules)
        keyboard().suggestionCapsules = false
        XCTAssertFalse(keyboard().suggestionCapsules)
    }

    func testATestBuildActsOnTheSwitch() {
        keyboard().suggestionCapsules = true
        for distribution in [AppDistribution.debug, .testFlight] {
            AppDistribution.record(distribution, in: defaults)
            XCTAssertTrue(keyboard().isSuggestionCapsulesEffective, distribution.rawValue)
        }
    }

    /// Switched on in TestFlight, then the App Store build: the default (off) acts.
    func testTheAppStoreBuildIgnoresTheSwitch() {
        keyboard().suggestionCapsules = true
        AppDistribution.record(.appStore, in: defaults)
        XCTAssertTrue(keyboard().suggestionCapsules, "the choice is kept")
        XCTAssertFalse(keyboard().isSuggestionCapsulesEffective)
    }

    func testWithoutARecordedDistributionTheSwitchDoesNotAct() {
        keyboard().suggestionCapsules = true
        XCTAssertFalse(keyboard().isSuggestionCapsulesEffective)
    }
}
