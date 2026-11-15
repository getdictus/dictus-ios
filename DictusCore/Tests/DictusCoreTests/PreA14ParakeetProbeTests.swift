// DictusCore/Tests/DictusCoreTests/PreA14ParakeetProbeTests.swift
import XCTest
@testable import DictusCore

/// Covers the Debug-only Parakeet probe on A12X/A12Z iPads (issue #963).
final class PreA14ParakeetProbeTests: XCTestCase {

    private func device(_ identifier: String, ramGB: Int = 4) -> DeviceCapabilities {
        DeviceCapabilities(
            physicalMemoryGB: ramGB,
            availableMemoryMB: 3000,
            deviceModelIdentifier: identifier,
            thermalState: .nominal
        )
    }

    private var parakeet: ModelInfo {
        guard let model = ModelInfo.forIdentifier(PreA14ParakeetProbe.parakeetIdentifier) else {
            XCTFail("Parakeet v3 missing from the catalogue")
            fatalError("unreachable")
        }
        return model
    }

    /// Every A12X/A12Z identifier: 11-inch and 12.9-inch, 2018 and 2020.
    private let a12xA12zIPads = (1...12).map { "iPad8,\($0)" }

    func testA12XAndA12ZIPadsAreDetected() {
        for identifier in a12xA12zIPads {
            XCTAssertTrue(device(identifier).isA12XOrA12ZIPadPro, identifier)
        }
        for identifier in ["iPad7,5", "iPad11,3", "iPad12,1", "iPad13,1", "iPad18,1", "iPhone11,8", "iPhone8,1", "arm64"] {
            XCTAssertFalse(device(identifier).isA12XOrA12ZIPadPro, identifier)
        }
    }

    func testProbeOffersParakeetOnA12XIPadsOnly() {
        for identifier in a12xA12zIPads {
            XCTAssertNil(PreA14ParakeetProbe.incompatibilityReason(
                of: parakeet, on: device(identifier), probeEnabled: true), identifier)
        }
        for identifier in ["iPad11,3", "iPad12,1", "iPhone12,1", "iPhone11,8"] {
            XCTAssertEqual(PreA14ParakeetProbe.incompatibilityReason(
                of: parakeet, on: device(identifier), probeEnabled: true), .hardwareGeneration, identifier)
        }
    }

    /// A Release build passes `false`: the #612 floor holds.
    func testProbeOffIsTodaysGate() {
        let iPad = device("iPad8,1")
        XCTAssertEqual(PreA14ParakeetProbe.incompatibilityReason(
            of: parakeet, on: iPad, probeEnabled: false), .hardwareGeneration)
        XCTAssertFalse(PreA14ParakeetProbe.supportsKeyboardDictation(on: iPad, probeEnabled: false))
    }

    /// Only Parakeet: Small, Medium and Turbo keep their reasons on the probed iPad.
    func testProbeUnlocksNoOtherModel() {
        let iPad = device("iPad8,1")
        for model in ModelInfo.all where model.identifier != PreA14ParakeetProbe.parakeetIdentifier {
            XCTAssertEqual(
                PreA14ParakeetProbe.incompatibilityReason(of: model, on: iPad, probeEnabled: true),
                model.incompatibilityReason(on: iPad), model.identifier)
        }
    }

    func testProbeOpensKeyboardDictationOnA12XIPadsOnly() {
        XCTAssertTrue(PreA14ParakeetProbe.supportsKeyboardDictation(on: device("iPad8,1"), probeEnabled: true))
        XCTAssertTrue(PreA14ParakeetProbe.supportsKeyboardDictation(on: device("iPad8,11", ramGB: 6), probeEnabled: true))
        for identifier in ["iPad12,1", "iPhone12,1", "iPhone11,8"] {
            XCTAssertFalse(PreA14ParakeetProbe.supportsKeyboardDictation(
                on: device(identifier), probeEnabled: true), identifier)
        }
        // A14 and later keep keyboard dictation either way.
        XCTAssertTrue(PreA14ParakeetProbe.supportsKeyboardDictation(on: device("iPhone16,2"), probeEnabled: false))
    }

    /// The recommendation does not move: onboarding still installs Base on the iPad.
    func testRecommendationStaysBase() {
        XCTAssertEqual(ModelInfo.recommendedIdentifier(for: device("iPad8,1")), "openai_whisper-base")
    }

    func testProcessFootprintIsReadable() {
        let footprint = ProcessMemory.footprint()
        XCTAssertNotNil(footprint)
        if let footprint {
            XCTAssertGreaterThan(footprint.currentMB, 0)
            XCTAssertGreaterThanOrEqual(footprint.peakMB, footprint.currentMB)
        }
    }
}
