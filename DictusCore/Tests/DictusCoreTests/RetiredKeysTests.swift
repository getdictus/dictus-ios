// DictusCore/Tests/DictusCoreTests/RetiredKeysTests.swift
// Tests for SharedKeys.clearRetiredKeys — the launch-time cleanup of App Group keys
// no live code reads any more.
import XCTest
@testable import DictusCore

final class RetiredKeysTests: XCTestCase {

    private let defaultKeyboardLayer = "dictus.defaultKeyboardLayer"
    private let keyboardMode = "dictus.keyboardMode"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    override func setUp() {
        super.setUp()
        clearStorage()
    }

    override func tearDown() {
        clearStorage()
        super.tearDown()
    }

    private func clearStorage() {
        defaults?.removeObject(forKey: defaultKeyboardLayer)
        defaults?.removeObject(forKey: keyboardMode)
        defaults?.removeObject(forKey: SharedKeys.language)
    }

    /// The literals are what devices carry; a renamed constant would silently
    /// stop clearing them.
    func testRetiredKeyLiteralsMatchWhatDevicesStored() {
        XCTAssertEqual(SharedKeys.retiredDefaultKeyboardLayer, defaultKeyboardLayer)
        XCTAssertEqual(SharedKeys.retiredKeyboardMode, keyboardMode)
    }

    /// #888: a user who had chosen « open on 123 » loses the stored choice at launch.
    func testClearRemovesTheOpenOn123Setting() {
        defaults?.set("numbers", forKey: defaultKeyboardLayer)
        defaults?.set("micro", forKey: keyboardMode)

        SharedKeys.clearRetiredKeys()

        XCTAssertNil(defaults?.object(forKey: defaultKeyboardLayer))
        XCTAssertNil(defaults?.object(forKey: keyboardMode))
    }

    func testClearKeepsLiveKeys() {
        defaults?.set("de", forKey: SharedKeys.language)

        SharedKeys.clearRetiredKeys()

        XCTAssertEqual(defaults?.string(forKey: SharedKeys.language), "de")
    }
}
