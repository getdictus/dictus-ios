// DictusCore/Tests/DictusCoreTests/SpokenLanguageModelRecommendationTests.swift
// The language + device model recommendation rule (#649).
import XCTest
@testable import DictusCore

final class SpokenLanguageModelRecommendationTests: XCTestCase {

    private let parakeet = "parakeet-tdt-0.6b-v3"
    private let turbo = "openai_whisper-large-v3-v20240930_turbo_632MB"
    private let small = "openai_whisper-small"
    private let base = "openai_whisper-base"

    private func device(_ model: String, ramGB: Int) -> DeviceCapabilities {
        DeviceCapabilities(
            physicalMemoryGB: ramGB,
            availableMemoryMB: 3000,
            deviceModelIdentifier: model,
            thermalState: .nominal
        )
    }

    // Real identifiers, with the RAM Apple ships them with.
    private var iPhone15ProMax: DeviceCapabilities { device("iPhone16,2", ramGB: 8) }
    private var iPhone13Pro: DeviceCapabilities { device("iPhone14,2", ramGB: 6) }
    private var iPhone13: DeviceCapabilities { device("iPhone14,5", ramGB: 4) }
    private var iPhone12Pro: DeviceCapabilities { device("iPhone13,3", ramGB: 6) }
    private var iPhone12: DeviceCapabilities { device("iPhone13,2", ramGB: 4) }
    private var iPhone11: DeviceCapabilities { device("iPhone12,1", ramGB: 4) }
    private var iPadProA12Z: DeviceCapabilities { device("iPad8,9", ramGB: 6) }
    private var iPadProM1: DeviceCapabilities { device("iPad13,4", ramGB: 8) }
    private var iPadProM2: DeviceCapabilities { device("iPad14,3", ramGB: 8) }

    // MARK: - The four Dictus keyboard languages keep today's rule

    func testKeyboardLanguagesKeepTheDeviceOnlyRecommendation() {
        let devices = [iPhone15ProMax, iPhone13Pro, iPhone13, iPhone12Pro, iPhone12, iPhone11, iPadProM1]
        for language in SupportedLanguage.allCases {
            for capabilities in devices {
                XCTAssertEqual(
                    ModelInfo.recommendedIdentifier(forSpokenLanguage: language.rawValue, on: capabilities),
                    ModelInfo.recommendedIdentifier(for: capabilities),
                    "\(language.rawValue) on \(capabilities.deviceModelIdentifier)"
                )
            }
        }
    }

    // MARK: - Parakeet languages

    func testParakeetLanguageOnSixGigabytesGetsParakeet() {
        for code in ["fr", "en", "it", "pl", "uk", "pt"] {
            XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: code, on: iPhone15ProMax), parakeet, code)
            XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: code, on: iPhone12Pro), parakeet, code)
        }
    }

    func testParakeetLanguageBelowSixGigabytesGetsSmall() {
        XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: "it", on: iPhone13), small)
        XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: "fr", on: iPhone12), small)
    }

    func testParakeetLanguageSetIsNvidiasTwentyFive() {
        XCTAssertEqual(ModelLanguageSupport.parakeetV3LanguageCodes.count, 25)
        XCTAssertFalse(ModelLanguageSupport.parakeetV3LanguageCodes.contains("zh"))
        XCTAssertFalse(ModelLanguageSupport.parakeetV3LanguageCodes.contains("ja"))
        for code in SupportedLanguage.allCases.map(\.rawValue) {
            XCTAssertTrue(ModelLanguageSupport.parakeetV3LanguageCodes.contains(code), code)
        }
    }

    // MARK: - Languages Parakeet does not speak (acceptance: Chinese gets Whisper)

    func testChineseIsNeverRecommendedParakeet() {
        let devices = [iPhone15ProMax, iPhone13Pro, iPhone13, iPhone12Pro, iPhone12, iPhone11,
                       iPadProA12Z, iPadProM1, iPadProM2]
        for capabilities in devices {
            let recommended = ModelInfo.recommendedIdentifier(forSpokenLanguage: "zh", on: capabilities)
            XCTAssertNotEqual(recommended, parakeet, capabilities.deviceModelIdentifier)
            XCTAssertEqual(ModelInfo.forIdentifier(recommended)?.engine, .whisperKit, capabilities.deviceModelIdentifier)
        }
    }

    func testNonParakeetLanguageOnA15OrLaterWithSixGigabytesGetsTurbo() {
        for code in ["zh", "ja", "ko", "ar", "hi", "tr"] {
            XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: code, on: iPhone15ProMax), turbo, code)
            XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: code, on: iPhone13Pro), turbo, code)
            XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: code, on: iPadProM2), turbo, code)
        }
    }

    /// Argmax lists Turbo for the A15 iPhone 13, but the catalogue's own gate wants 6 GB.
    func testNonParakeetLanguageOnFourGigabyteA15GetsSmall() {
        XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: "zh", on: iPhone13), small)
    }

    /// 6 GB is not enough: Argmax lists only Small for the A14 and omits Turbo for the M1.
    func testNonParakeetLanguageOnA14OrM1GetsSmall() {
        XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: "zh", on: iPhone12Pro), small)
        XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: "zh", on: iPhone12), small)
        XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: "zh", on: iPadProM1), small)
    }

    func testUnknownHardwareIsNotAssumedTurboCapable() {
        let mac = device("Mac15,3", ramGB: 16)
        XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: "zh", on: mac), small)
    }

    // MARK: - Pre-A14 keeps today's rule whatever the language

    func testPreA14GetsBaseInEveryLanguage() {
        for code in ["fr", "en", "zh", "ja", "it"] {
            XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: code, on: iPhone11), base, code)
            XCTAssertEqual(ModelInfo.recommendedIdentifier(forSpokenLanguage: code, on: iPadProA12Z), base, code)
        }
    }

    // MARK: - Every recommendation is runnable on its device

    func testEveryRecommendationIsSupportedOnItsDevice() {
        let devices = [iPhone15ProMax, iPhone13Pro, iPhone13, iPhone12Pro, iPhone12, iPhone11,
                       iPadProA12Z, iPadProM1, iPadProM2]
        for code in SpokenLanguage.selectableCodes {
            for capabilities in devices {
                let identifier = ModelInfo.recommendedIdentifier(forSpokenLanguage: code, on: capabilities)
                guard let model = ModelInfo.forIdentifier(identifier) else {
                    return XCTFail("\(identifier) is not in the catalogue")
                }
                XCTAssertTrue(model.isSupported(on: capabilities), "\(code) → \(identifier) on \(capabilities.deviceModelIdentifier)")
            }
        }
    }

    // MARK: - The chip-tier predicate behind the Turbo branch

    func testIsA15OrLaterFollowsArgmaxTurboListing() {
        XCTAssertTrue(device("iPhone14,2", ramGB: 6).isA15OrLater)
        XCTAssertTrue(device("iPhone18,1", ramGB: 12).isA15OrLater)
        XCTAssertTrue(device("iPad14,1", ramGB: 4).isA15OrLater)
        XCTAssertTrue(device("iPad16,3", ramGB: 8).isA15OrLater)
        XCTAssertFalse(device("iPhone13,4", ramGB: 6).isA15OrLater)
        XCTAssertFalse(device("iPad13,8", ramGB: 8).isA15OrLater)
        XCTAssertFalse(device("iPhone12,1", ramGB: 4).isA15OrLater)
        XCTAssertFalse(device("arm64", ramGB: 8).isA15OrLater)
    }
}
