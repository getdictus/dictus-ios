// DictusCore/Tests/DictusCoreTests/KeyboardDictationAvailabilityTests.swift
import XCTest
@testable import DictusCore

/// Covers the keyboard dictation gate on pre-A14 hardware (issues #635, #963).
final class KeyboardDictationAvailabilityTests: XCTestCase {

    private let parakeet = ModelInfo.parakeetV3Identifier
    private let whisperModels = ["openai_whisper-tiny", "openai_whisper-base", "openai_whisper-small"]

    private func device(_ identifier: String, ramGB: Int = 4) -> DeviceCapabilities {
        DeviceCapabilities(
            physicalMemoryGB: ramGB,
            availableMemoryMB: 3000,
            deviceModelIdentifier: identifier,
            thermalState: .nominal
        )
    }

    /// The identifiers #635's brief names: A12X iPad Pro, A13 iPad, iPhone 11, iPhone XR,
    /// plus the iPhone XS (#963's second test device). Whisper stays refused there.
    func testPreA14DevicesCannotDictateFromTheKeyboardWithWhisper() {
        for identifier in ["iPad8,1", "iPad12,1", "iPhone12,1", "iPhone11,8", "iPhone11,2"] {
            for model in whisperModels {
                XCTAssertFalse(device(identifier).supportsKeyboardDictation(activeModel: model), "\(identifier) \(model)")
            }
        }
    }

    /// #963: Parakeet active reopens the keyboard on every pre-A14 iPhone and iPad.
    func testPreA14DevicesDictateFromTheKeyboardWithParakeet() {
        for identifier in ["iPad8,1", "iPad8,11", "iPad11,3", "iPad12,1", "iPad7,5",
                           "iPhone11,2", "iPhone11,8", "iPhone12,1", "iPhone12,8"] {
            XCTAssertTrue(device(identifier).supportsKeyboardDictation(activeModel: parakeet), identifier)
        }
    }

    /// No active model yet (mid-onboarding, or the App Group key never written): refused
    /// before A14, as Whisper is.
    func testPreA14DevicesWithNoActiveModelCannotDictate() {
        XCTAssertFalse(device("iPad8,1").supportsKeyboardDictation(activeModel: nil))
        XCTAssertFalse(device("iPhone11,2").supportsKeyboardDictation(activeModel: nil))
    }

    /// A14 iPad Air 4, iPhone 12 (A14), iPhone 15 Pro Max (A17 Pro): unchanged, any model.
    func testA14AndLaterDevicesKeepKeyboardDictation() {
        for identifier in ["iPad13,1", "iPhone13,2", "iPhone16,2"] {
            for model in whisperModels + [parakeet] {
                XCTAssertTrue(device(identifier).supportsKeyboardDictation(activeModel: model), "\(identifier) \(model)")
            }
            XCTAssertTrue(device(identifier).supportsKeyboardDictation(activeModel: nil), identifier)
        }
    }

    /// A chip-tier call, never a memory one: the 6 GB A12Z iPad Pro is still refused
    /// with Whisper.
    func testMemoryDoesNotReopenKeyboardDictation() {
        for ram in [3, 4, 6, 8] {
            XCTAssertFalse(device("iPad8,3", ramGB: ram).supportsKeyboardDictation(activeModel: "openai_whisper-base"))
            XCTAssertTrue(device("iPhone13,2", ramGB: ram).supportsKeyboardDictation(activeModel: "openai_whisper-base"))
        }
    }

    /// An identifier that is not an iPhone or iPad (a Mac, some simulators) carries no
    /// chip tier, so nothing is taken away from it.
    func testUnknownIdentifiersKeepKeyboardDictation() {
        for identifier in ["arm64", "Mac14,2", "iPhoneTest,1"] {
            XCTAssertTrue(device(identifier).supportsKeyboardDictation(activeModel: "openai_whisper-base"), identifier)
        }
    }

    /// One floor for everything: with Whisper active the gate is exactly the complement
    /// of `isPreA14`.
    func testTheWhisperGateIsTheComplementOfThePreA14Floor() {
        for identifier in ["iPhone11,2", "iPhone12,8", "iPhone13,2", "iPad7,5", "iPad8,1",
                           "iPad11,3", "iPad12,1", "iPad13,1", "iPad13,4", "arm64"] {
            let capabilities = device(identifier)
            XCTAssertEqual(capabilities.supportsKeyboardDictation(activeModel: "openai_whisper-base"),
                           !capabilities.isPreA14, identifier)
        }
    }
}
