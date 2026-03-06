// DictusCore/Tests/DictusCoreTests/SharedKeysExtensionTests.swift
// Tests for Phase 4 SharedKeys extensions: language, hapticsEnabled, fillerWordsEnabled, hasCompletedOnboarding.
import XCTest
@testable import DictusCore

final class SharedKeysExtensionTests: XCTestCase {

    func testLanguageKeyExists() {
        XCTAssertEqual(SharedKeys.language, "dictus.language")
    }

    func testHapticsEnabledKeyExists() {
        XCTAssertEqual(SharedKeys.hapticsEnabled, "dictus.hapticsEnabled")
    }

    func testFillerWordsEnabledKeyExists() {
        XCTAssertEqual(SharedKeys.fillerWordsEnabled, "dictus.fillerWordsEnabled")
    }

    func testHasCompletedOnboardingKeyExists() {
        XCTAssertEqual(SharedKeys.hasCompletedOnboarding, "dictus.hasCompletedOnboarding")
    }

    func testNewKeysAreUnique() {
        let newKeys = [
            SharedKeys.language,
            SharedKeys.hapticsEnabled,
            SharedKeys.fillerWordsEnabled,
            SharedKeys.hasCompletedOnboarding,
        ]
        XCTAssertEqual(newKeys.count, Set(newKeys).count, "New SharedKeys must be unique")
    }

    func testNewKeysHaveDictusPrefix() {
        XCTAssertTrue(SharedKeys.language.hasPrefix("dictus."))
        XCTAssertTrue(SharedKeys.hapticsEnabled.hasPrefix("dictus."))
        XCTAssertTrue(SharedKeys.fillerWordsEnabled.hasPrefix("dictus."))
        XCTAssertTrue(SharedKeys.hasCompletedOnboarding.hasPrefix("dictus."))
    }
}
