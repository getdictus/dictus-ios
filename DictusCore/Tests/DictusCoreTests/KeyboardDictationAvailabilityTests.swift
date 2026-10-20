// DictusCore/Tests/DictusCoreTests/KeyboardDictationAvailabilityTests.swift
import XCTest
@testable import DictusCore

/// Covers the keyboard dictation gate on pre-A14 hardware (issue #635).
final class KeyboardDictationAvailabilityTests: XCTestCase {

    private func device(_ identifier: String, ramGB: Int = 4) -> DeviceCapabilities {
        DeviceCapabilities(
            physicalMemoryGB: ramGB,
            availableMemoryMB: 3000,
            deviceModelIdentifier: identifier,
            thermalState: .nominal
        )
    }

    /// The identifiers #635's brief names: A12X iPad Pro, A13 iPad, iPhone 11, iPhone XR.
    func testPreA14DevicesCannotDictateFromTheKeyboard() {
        for identifier in ["iPad8,1", "iPad12,1", "iPhone12,1", "iPhone11,8"] {
            XCTAssertFalse(device(identifier).supportsKeyboardDictation, identifier)
        }
    }

    /// A14 iPad Air 4, iPhone 12 (A14), iPhone 15 Pro Max (A17 Pro).
    func testA14AndLaterDevicesKeepKeyboardDictation() {
        for identifier in ["iPad13,1", "iPhone13,2", "iPhone16,2"] {
            XCTAssertTrue(device(identifier).supportsKeyboardDictation, identifier)
        }
    }

    /// A chip-tier call, never a memory one: the 6 GB A12Z iPad Pro is still refused.
    func testMemoryDoesNotReopenKeyboardDictation() {
        for ram in [3, 4, 6, 8] {
            XCTAssertFalse(device("iPad8,3", ramGB: ram).supportsKeyboardDictation)
            XCTAssertTrue(device("iPhone13,2", ramGB: ram).supportsKeyboardDictation)
        }
    }

    /// An identifier that is not an iPhone or iPad (a Mac, some simulators) carries no
    /// chip tier, so nothing is taken away from it.
    func testUnknownIdentifiersKeepKeyboardDictation() {
        for identifier in ["arm64", "Mac14,2", "iPhoneTest,1"] {
            XCTAssertTrue(device(identifier).supportsKeyboardDictation, identifier)
        }
    }

    /// One floor for everything: the gate is exactly the complement of `isPreA14`.
    func testTheGateIsTheComplementOfThePreA14Floor() {
        for identifier in ["iPhone11,2", "iPhone12,8", "iPhone13,2", "iPad7,5", "iPad8,1",
                           "iPad11,3", "iPad12,1", "iPad13,1", "iPad13,4", "arm64"] {
            let capabilities = device(identifier)
            XCTAssertEqual(capabilities.supportsKeyboardDictation, !capabilities.isPreA14, identifier)
        }
    }
}
