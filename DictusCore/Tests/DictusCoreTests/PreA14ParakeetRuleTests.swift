// DictusCore/Tests/DictusCoreTests/PreA14ParakeetRuleTests.swift
import XCTest
@testable import DictusCore

/// Covers the pre-A14 rule (issue #963): Parakeet v3 on the CPU, the only selectable and
/// the recommended model, no drift retry, on every pre-A14 iPhone and iPad. A14 and later
/// are unchanged.
final class PreA14ParakeetRuleTests: XCTestCase {

    private func device(_ identifier: String, ramGB: Int = 4) -> DeviceCapabilities {
        DeviceCapabilities(
            physicalMemoryGB: ramGB,
            availableMemoryMB: 3000,
            deviceModelIdentifier: identifier,
            thermalState: .nominal
        )
    }

    /// iPhone XS, XR, 11, SE 2 (A12/A13), plus the 3 GB A12 iPads.
    private let preA14IPhones = [("iPhone11,2", 4), ("iPhone11,8", 3), ("iPhone12,1", 4), ("iPhone12,8", 3)]
    /// A12X/A12Z iPad Pro (4 and 6 GB), A12 iPad Air 3, A13 iPad 9, A10 iPad 6.
    private let preA14IPads = [("iPad8,1", 4), ("iPad8,11", 6), ("iPad11,3", 3), ("iPad12,1", 3), ("iPad7,5", 2)]
    /// iPhone 12 (A14), iPhone 13 (A15), iPhone 15 Pro Max, iPad Air 4 (A14), M1 iPad Pro.
    private let a14AndLater = [("iPhone13,2", 4), ("iPhone14,5", 4), ("iPhone16,2", 8), ("iPad13,1", 4), ("iPad13,4", 8)]

    private var preA14: [(String, Int)] { preA14IPhones + preA14IPads }

    private let parakeet = ModelInfo.parakeetV3Identifier

    // MARK: - Selectable models

    func testParakeetIsTheOnlySelectableModelBeforeA14() {
        for (identifier, ram) in preA14 {
            let capabilities = device(identifier, ramGB: ram)
            for model in ModelInfo.allIncludingDeprecated {
                if model.identifier == parakeet {
                    XCTAssertNil(model.incompatibilityReason(on: capabilities), identifier)
                } else {
                    XCTAssertEqual(model.incompatibilityReason(on: capabilities), .hardwareGeneration,
                                   "\(identifier) \(model.identifier)")
                }
            }
        }
    }

    /// Tiny and Base named on their own: they were the only pre-A14 models before #963.
    func testTinyAndBaseAreGreyedBeforeA14() {
        for name in ["openai_whisper-tiny", "openai_whisper-base"] {
            guard let model = ModelInfo.forIdentifier(name) else { return XCTFail(name) }
            XCTAssertEqual(model.incompatibilityReason(on: device("iPad8,1")), .hardwareGeneration, name)
            XCTAssertEqual(model.incompatibilityReason(on: device("iPhone11,2")), .hardwareGeneration, name)
        }
    }

    func testA14AndLaterGatingIsUnchanged() {
        for (identifier, ram) in a14AndLater {
            let capabilities = device(identifier, ramGB: ram)
            for model in ModelInfo.allIncludingDeprecated where !ModelInfo.turboIdentifiers.contains(model.identifier) {
                XCTAssertNil(model.incompatibilityReason(on: capabilities), "\(identifier) \(model.identifier)")
            }
        }
    }

    // MARK: - Recommendation

    func testParakeetIsRecommendedBeforeA14WhateverTheLanguage() {
        for (identifier, ram) in preA14 {
            let capabilities = device(identifier, ramGB: ram)
            XCTAssertEqual(ModelInfo.recommendedIdentifier(for: capabilities), parakeet, identifier)
            for language in ["fr", "en", "zh", "ja"] {
                XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: language, on: capabilities),
                               parakeet, "\(identifier) \(language)")
            }
        }
    }

    func testA14AndLaterRecommendationIsUnchanged() {
        XCTAssertEqual(ModelInfo.recommendedIdentifier(for: device("iPhone13,2", ramGB: 4)), "openai_whisper-small")
        XCTAssertEqual(ModelInfo.recommendedIdentifier(for: device("iPhone14,5", ramGB: 4)), parakeet)
        XCTAssertEqual(ModelInfo.recommendedIdentifier(for: device("iPhone16,2", ramGB: 8)), parakeet)
        XCTAssertEqual(ModelInfo.recommendedIdentifier(for: device("iPad13,1", ramGB: 4)), "openai_whisper-small")
    }

    /// The Available list shows Parakeet and no deprecated Tiny/Base before A14.
    func testAvailableListBeforeA14() {
        let identifiers = ModelInfo.available(on: device("iPad8,1")).map(\.identifier)
        XCTAssertTrue(identifiers.contains(parakeet))
        XCTAssertFalse(identifiers.contains("openai_whisper-base"))
        XCTAssertFalse(identifiers.contains("openai_whisper-tiny"))
    }

    // MARK: - Downloaded cards (migration)

    /// A user who had Base before the update keeps it usable while it is active; once
    /// Parakeet is active, Base is greyed. Parakeet is never greyed.
    func testDownloadedCardsBeforeA14() throws {
        let base = try XCTUnwrap(ModelInfo.forIdentifier("openai_whisper-base"))
        let parakeetModel = try XCTUnwrap(ModelInfo.forIdentifier(parakeet))
        for (identifier, ram) in preA14 {
            let capabilities = device(identifier, ramGB: ram)
            XCTAssertNil(base.downloadedCardIncompatibilityReason(on: capabilities, isActive: true), identifier)
            XCTAssertEqual(base.downloadedCardIncompatibilityReason(on: capabilities, isActive: false),
                           .hardwareGeneration, identifier)
            XCTAssertNil(parakeetModel.downloadedCardIncompatibilityReason(on: capabilities, isActive: false), identifier)
        }
    }

    /// A14 and later: the Downloaded section stays ungated, Turbo on an A14 included (#660).
    func testDownloadedCardsUngatedFromA14() throws {
        for (identifier, ram) in a14AndLater {
            for model in ModelInfo.allIncludingDeprecated {
                XCTAssertNil(model.downloadedCardIncompatibilityReason(on: device(identifier, ramGB: ram), isActive: false),
                             "\(identifier) \(model.identifier)")
            }
        }
    }

    // MARK: - Compute units and drift retry

    func testParakeetRunsOnTheCPUOnlyBeforeA14() {
        for (identifier, ram) in preA14 {
            XCTAssertEqual(device(identifier, ramGB: ram).parakeetComputePolicy, .cpuOnly, identifier)
        }
        for (identifier, ram) in a14AndLater {
            XCTAssertEqual(device(identifier, ramGB: ram).parakeetComputePolicy, .fluidAudioDefault, identifier)
        }
        XCTAssertEqual(device("arm64").parakeetComputePolicy, .fluidAudioDefault)
    }

    func testDriftRetryIsSkippedBeforeA14() {
        for (identifier, ram) in preA14 {
            XCTAssertFalse(device(identifier, ramGB: ram).runsParakeetDriftRetry, identifier)
        }
        for (identifier, ram) in a14AndLater {
            XCTAssertTrue(device(identifier, ramGB: ram).runsParakeetDriftRetry, identifier)
        }
    }

    // MARK: - Transcription watchdog

    /// 30 s + 0.5 x the audio before A14 (Pierre, 2026-11-16): the ~71 s dictation the
    /// fixed 30 s cancelled on `iPad8,1` gets 65.5 s.
    func testTranscriptionWatchdogScalesWithAudioBeforeA14() {
        for (identifier, ram) in preA14 {
            let capabilities = device(identifier, ramGB: ram)
            XCTAssertEqual(capabilities.transcriptionWatchdogTimeout(audioSeconds: 0), 30, identifier)
            XCTAssertEqual(capabilities.transcriptionWatchdogTimeout(audioSeconds: 10), 35, identifier)
            XCTAssertEqual(capabilities.transcriptionWatchdogTimeout(audioSeconds: 64.44), 62.22, accuracy: 0.001, identifier)
            XCTAssertEqual(capabilities.transcriptionWatchdogTimeout(audioSeconds: 71), 65.5, identifier)
            XCTAssertEqual(capabilities.transcriptionWatchdogTimeout(audioSeconds: 120), 90, identifier)
            XCTAssertEqual(capabilities.transcriptionWatchdogTimeout(audioSeconds: -5), 30, identifier)
        }
    }

    func testTranscriptionWatchdogStaysThirtySecondsFromA14() {
        for (identifier, ram) in a14AndLater + [("arm64", 16)] {
            let capabilities = device(identifier, ramGB: ram)
            for audio in [0.0, 10, 71, 120, 600] {
                XCTAssertEqual(capabilities.transcriptionWatchdogTimeout(audioSeconds: audio), 30, "\(identifier) \(audio)")
            }
        }
    }

    // MARK: - Process memory log fields

    func testProcessFootprintIsReadable() throws {
        let footprint = try XCTUnwrap(ProcessMemory.footprint())
        XCTAssertGreaterThan(footprint.currentMB, 0)
        XCTAssertGreaterThanOrEqual(footprint.peakMB, footprint.currentMB)
    }
}
