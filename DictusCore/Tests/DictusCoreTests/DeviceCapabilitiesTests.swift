// DictusCore/Tests/DictusCoreTests/DeviceCapabilitiesTests.swift
import XCTest
@testable import DictusCore

/// Covers the device-tier rules that decide how Whisper is compiled (issue #370)
/// and which hardware families are Argmax-restricted (issues #362, #612).
final class DeviceCapabilitiesTests: XCTestCase {

    private func makeCapabilities(
        ramGB: Int = 4,
        availableMB: Int = 3000,
        model: String,
        thermal: ProcessInfo.ThermalState = .nominal
    ) -> DeviceCapabilities {
        DeviceCapabilities(
            physicalMemoryGB: ramGB,
            availableMemoryMB: availableMB,
            deviceModelIdentifier: model,
            thermalState: thermal
        )
    }

    // MARK: - Pre-A14 detection (issues #362, #612)

    func testA12AndA13IPhonesAreDetected() {
        // iPhone11,x = XS / XS Max / XR (A12). iPhone12,x = 11 / 11 Pro / SE 2 (A13).
        for identifier in ["iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8",
                           "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPhone12,8"] {
            XCTAssertTrue(makeCapabilities(model: identifier).isPreA14, identifier)
        }
    }

    /// Issue #612: every iPad below family 13 is pre-A14, including the ones
    /// Argmax's matrix does not list at all.
    func testPreA14IPadsAreDetected() {
        // iPad7,x = A10/A10X (iPad 6th/7th gen, iPad Pro 2017), still on iPadOS 17.
        // iPad8,x = A12X/A12Z iPad Pro 2018/2020. iPad11,x = A12 mini 5 / Air 3 /
        // iPad 8th gen. iPad12,x = A13 iPad 9th gen, the only ones Argmax lists.
        for identifier in ["iPad7,1", "iPad7,4", "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12",
                           "iPad8,1", "iPad8,3", "iPad8,9", "iPad8,12",
                           "iPad11,1", "iPad11,3", "iPad11,6", "iPad11,7",
                           "iPad12,1", "iPad12,2"] {
            XCTAssertTrue(makeCapabilities(model: identifier).isPreA14, identifier)
        }
    }

    func testA14AndNewerAreNotDetected() {
        // iPhone13,x is A14 — the first tier Argmax lists Small for, and the reason
        // RAM alone cannot make this call: iPhone13,2 is 4 GB, same as an iPhone 11.
        // iPad13,1 is the A14 iPad Air 4, iPad13,4 an M1 iPad Pro, iPad14,1 the A15 mini.
        for identifier in ["iPhone13,2", "iPhone14,5", "iPhone15,4", "iPhone16,2", "iPhone18,1",
                           "iPad13,1", "iPad13,4", "iPad13,18", "iPad14,1", "iPad16,3"] {
            XCTAssertFalse(makeCapabilities(model: identifier).isPreA14, identifier)
        }
    }

    /// The rule is a floor: a family below the A12 still gets the most restrictive
    /// tier. None of these can install iOS 17, so this states intent, not reach.
    func testOlderFamiliesFallUnderTheFloor() {
        for identifier in ["iPhone10,3", "iPhone1,1", "iPad6,11"] {
            XCTAssertTrue(makeCapabilities(model: identifier).isPreA14, identifier)
        }
    }

    /// Only a parsable iPhone/iPad family is restricted. A Mac, a simulator reporting
    /// its host architecture, or a malformed identifier keeps the RAM rule.
    func testNonIPhoneOrIPadIdentifiersAreNotDetected() {
        for identifier in ["arm64", "x86_64", "Mac14,2", "iPod9,1", "iPhoneTest,1",
                           "iPhone,1", "iPad", "iPhone12", "", "RealityDevice14,1"] {
            XCTAssertFalse(makeCapabilities(model: identifier).isPreA14, identifier)
        }
    }

    /// The family is read up to the comma, so a longer number is never mistaken for
    /// a shorter one: "iPhone110,1" is family 110, not 11.
    func testFamilyIsReadUpToTheComma() {
        XCTAssertFalse(makeCapabilities(model: "iPhone110,1").isPreA14)
        XCTAssertFalse(makeCapabilities(model: "iPad120,1").isPreA14)
        XCTAssertFalse(makeCapabilities(model: "iPhone13,2").isPreA14)
        XCTAssertTrue(makeCapabilities(model: "iPhone12,8").isPreA14)
    }

    // MARK: - Audio encoder compute policy (issue #370)

    func testPreA14GetCpuAndGpuAudioEncoder() {
        for identifier in ["iPhone11,2", "iPhone11,8", "iPhone12,1", "iPhone12,8",
                           "iPad7,5", "iPad8,1", "iPad8,3", "iPad11,3", "iPad12,1"] {
            XCTAssertEqual(makeCapabilities(model: identifier).audioEncoderComputePolicy,
                           .cpuAndGPU,
                           "\(identifier) must keep the audio encoder off the Neural Engine")
        }
    }

    /// The blast-radius guarantee: every other device keeps WhisperKit's own default,
    /// which the app expresses by passing no compute options at all.
    func testEveryOtherDeviceKeepsTheWhisperKitDefault() {
        for identifier in ["iPhone13,2", "iPhone14,5", "iPhone15,4", "iPhone16,2",
                           "iPhone17,3", "iPhone18,1", "iPad13,1", "iPad13,4",
                           "iPad14,1", "iPad16,3", "arm64"] {
            XCTAssertEqual(makeCapabilities(model: identifier).audioEncoderComputePolicy,
                           .whisperKitDefault,
                           "\(identifier) must not have its compute path changed")
        }
    }

    /// The policy is a hardware-generation call, never a memory one. A pre-A14 chip
    /// with plenty of RAM still needs it (the 6 GB A12Z iPad Pro); a 4 GB A14 still
    /// must not get it.
    func testPolicyIgnoresRamAndThermalState() {
        for ram in [3, 4, 6, 8, 12] {
            XCTAssertEqual(makeCapabilities(ramGB: ram, model: "iPhone12,1").audioEncoderComputePolicy,
                           .cpuAndGPU)
            XCTAssertEqual(makeCapabilities(ramGB: ram, model: "iPad8,3").audioEncoderComputePolicy,
                           .cpuAndGPU)
            XCTAssertEqual(makeCapabilities(ramGB: ram, model: "iPhone13,2").audioEncoderComputePolicy,
                           .whisperKitDefault)
        }
        XCTAssertEqual(makeCapabilities(model: "iPhone12,1", thermal: .critical).audioEncoderComputePolicy,
                       .cpuAndGPU)
    }

    /// The policy and the catalog gate must key off the same hardware test, so a
    /// device can never be handed Base by one rule and compiled for the ANE by the other.
    func testPolicyTracksTheSamePredicateAsTheCatalogGate() {
        for identifier in ["iPhone11,2", "iPhone12,1", "iPhone13,2", "iPhone16,2",
                           "iPad8,1", "iPad12,1", "iPad13,1", "iPad13,4", "arm64"] {
            let device = makeCapabilities(model: identifier)
            XCTAssertEqual(device.audioEncoderComputePolicy == .cpuAndGPU,
                           device.isPreA14,
                           identifier)
        }
    }
}
