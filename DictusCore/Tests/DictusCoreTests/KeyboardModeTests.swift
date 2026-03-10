// DictusCore/Tests/DictusCoreTests/KeyboardModeTests.swift
// Tests for DefaultKeyboardLayer enum — shared contract for default layer selection.
import XCTest
@testable import DictusCore

final class KeyboardModeTests: XCTestCase {

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    override func tearDown() {
        super.tearDown()
        defaults?.removeObject(forKey: SharedKeys.defaultKeyboardLayer)
        defaults?.removeObject(forKey: "dictus.keyboardMode")
    }

    // MARK: - Cases

    func testEnumHasExactlyTwoCases() {
        XCTAssertEqual(DefaultKeyboardLayer.allCases.count, 2)
    }

    // MARK: - Raw Values

    func testRawValues() {
        XCTAssertEqual(DefaultKeyboardLayer.letters.rawValue, "letters")
        XCTAssertEqual(DefaultKeyboardLayer.numbers.rawValue, "numbers")
    }

    // MARK: - Display Names

    func testDisplayNameLetters() {
        XCTAssertEqual(DefaultKeyboardLayer.letters.displayName, "ABC")
    }

    func testDisplayNameNumbers() {
        XCTAssertEqual(DefaultKeyboardLayer.numbers.displayName, "123")
    }

    // MARK: - Active Property

    func testActiveDefaultsToLetters() {
        defaults?.removeObject(forKey: SharedKeys.defaultKeyboardLayer)
        XCTAssertEqual(DefaultKeyboardLayer.active, .letters)
    }

    func testActiveReadsStoredValue() {
        defaults?.set("numbers", forKey: SharedKeys.defaultKeyboardLayer)
        XCTAssertEqual(DefaultKeyboardLayer.active, .numbers)
    }

    func testActiveReturnsLettersForInvalidValue() {
        defaults?.set("invalid", forKey: SharedKeys.defaultKeyboardLayer)
        XCTAssertEqual(DefaultKeyboardLayer.active, .letters)
    }

    // MARK: - Migration

    func testMigrationMicroToNumbers() {
        defaults?.removeObject(forKey: SharedKeys.defaultKeyboardLayer)
        defaults?.set("micro", forKey: "dictus.keyboardMode")

        DefaultKeyboardLayer.migrateFromKeyboardModeIfNeeded()

        XCTAssertEqual(defaults?.string(forKey: SharedKeys.defaultKeyboardLayer), "numbers")
        XCTAssertNil(defaults?.string(forKey: "dictus.keyboardMode"))
    }

    func testMigrationFullToLetters() {
        defaults?.removeObject(forKey: SharedKeys.defaultKeyboardLayer)
        defaults?.set("full", forKey: "dictus.keyboardMode")

        DefaultKeyboardLayer.migrateFromKeyboardModeIfNeeded()

        XCTAssertEqual(defaults?.string(forKey: SharedKeys.defaultKeyboardLayer), "letters")
        XCTAssertNil(defaults?.string(forKey: "dictus.keyboardMode"))
    }

    func testMigrationEmojiMicroToLetters() {
        defaults?.removeObject(forKey: SharedKeys.defaultKeyboardLayer)
        defaults?.set("emojiMicro", forKey: "dictus.keyboardMode")

        DefaultKeyboardLayer.migrateFromKeyboardModeIfNeeded()

        XCTAssertEqual(defaults?.string(forKey: SharedKeys.defaultKeyboardLayer), "letters")
        XCTAssertNil(defaults?.string(forKey: "dictus.keyboardMode"))
    }

    func testMigrationIsIdempotent() {
        defaults?.removeObject(forKey: SharedKeys.defaultKeyboardLayer)
        defaults?.set("micro", forKey: "dictus.keyboardMode")

        DefaultKeyboardLayer.migrateFromKeyboardModeIfNeeded()
        // Second call should be a no-op (new key already exists)
        DefaultKeyboardLayer.migrateFromKeyboardModeIfNeeded()

        XCTAssertEqual(defaults?.string(forKey: SharedKeys.defaultKeyboardLayer), "numbers")
    }

    func testMigrationNoOpWhenNoOldValue() {
        defaults?.removeObject(forKey: SharedKeys.defaultKeyboardLayer)
        defaults?.removeObject(forKey: "dictus.keyboardMode")

        DefaultKeyboardLayer.migrateFromKeyboardModeIfNeeded()

        // No new key written — defaults will handle it
        XCTAssertNil(defaults?.string(forKey: SharedKeys.defaultKeyboardLayer))
    }

    // MARK: - SharedKeys

    func testSharedKeyValue() {
        XCTAssertEqual(SharedKeys.defaultKeyboardLayer, "dictus.defaultKeyboardLayer")
    }
}
