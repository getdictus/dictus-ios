// DictusCore/Tests/DictusCoreTests/KeyboardModeTests.swift
// Tests for KeyboardMode enum — shared contract for keyboard mode switching.
import XCTest
@testable import DictusCore

final class KeyboardModeTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        // Clean up any stored keyboard mode value after each test
        UserDefaults(suiteName: AppGroup.identifier)?.removeObject(forKey: SharedKeys.keyboardMode)
    }

    // MARK: - Cases

    func testEnumHasExactlyThreeCases() {
        XCTAssertEqual(KeyboardMode.allCases.count, 3)
    }

    func testCasesExist() {
        // Verify all three cases compile and are distinct
        let modes: [KeyboardMode] = [.micro, .emojiMicro, .full]
        XCTAssertEqual(Set(modes.map(\.rawValue)).count, 3)
    }

    // MARK: - Raw Values

    func testRawValues() {
        XCTAssertEqual(KeyboardMode.micro.rawValue, "micro")
        XCTAssertEqual(KeyboardMode.emojiMicro.rawValue, "emojiMicro")
        XCTAssertEqual(KeyboardMode.full.rawValue, "full")
    }

    // MARK: - Display Names

    func testDisplayNameMicro() {
        XCTAssertEqual(KeyboardMode.micro.displayName, "Micro")
    }

    func testDisplayNameEmojiMicro() {
        XCTAssertEqual(KeyboardMode.emojiMicro.displayName, "Emoji+")
    }

    func testDisplayNameFull() {
        XCTAssertEqual(KeyboardMode.full.displayName, "Complet")
    }

    // MARK: - CaseIterable

    func testCaseIterableCount() {
        XCTAssertEqual(KeyboardMode.allCases.count, 3)
    }

    // MARK: - Active Property

    func testActiveDefaultsToFull() {
        // When no value is stored, active should return .full (safe default for existing users)
        UserDefaults(suiteName: AppGroup.identifier)?.removeObject(forKey: SharedKeys.keyboardMode)
        XCTAssertEqual(KeyboardMode.active, .full)
    }

    func testActiveReadsStoredValue() {
        // Store "micro" and verify active reads it correctly
        UserDefaults(suiteName: AppGroup.identifier)?.set("micro", forKey: SharedKeys.keyboardMode)
        XCTAssertEqual(KeyboardMode.active, .micro)
    }

    func testActiveReadsEmojiMicro() {
        UserDefaults(suiteName: AppGroup.identifier)?.set("emojiMicro", forKey: SharedKeys.keyboardMode)
        XCTAssertEqual(KeyboardMode.active, .emojiMicro)
    }

    func testActiveReturnsFullForInvalidValue() {
        // Invalid stored value should fall back to .full
        UserDefaults(suiteName: AppGroup.identifier)?.set("invalid_mode", forKey: SharedKeys.keyboardMode)
        XCTAssertEqual(KeyboardMode.active, .full)
    }

    // MARK: - SharedKeys

    func testSharedKeyValue() {
        XCTAssertEqual(SharedKeys.keyboardMode, "dictus.keyboardMode")
    }
}
