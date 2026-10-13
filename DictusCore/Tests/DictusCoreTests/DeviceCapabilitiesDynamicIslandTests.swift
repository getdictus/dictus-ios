// DictusCore/Tests/DictusCoreTests/DeviceCapabilitiesDynamicIslandTests.swift
// The Dynamic Island table that picks the onboarding's stop-Dictus variant (#681).
import XCTest
@testable import DictusCore

final class DeviceCapabilitiesDynamicIslandTests: XCTestCase {

    private func device(_ identifier: String) -> DeviceCapabilities {
        DeviceCapabilities(
            physicalMemoryGB: 8,
            availableMemoryMB: 0,
            deviceModelIdentifier: identifier,
            thermalState: .nominal
        )
    }

    /// Every iOS 17 iPhone without an island, by name, so a wrong identifier in the table
    /// reads as a model here.
    private let withoutIsland: [String: String] = [
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone17,5": "iPhone 16e",
        "iPhone18,5": "iPhone 17e",
    ]

    /// Every iPhone Apple lists "with the Dynamic Island", as of 2026-10-12.
    private let withIsland: [String: String] = [
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone Air",
        "iPhone19,2": "iPhone 18 Pro",
        "iPhone19,3": "iPhone 18 Pro Max",
        "iPhone19,7": "iPhone 18 Pro Max",
    ]

    func testTheKnownModelsWithoutAnIslandAnswerFalse() {
        for (identifier, name) in withoutIsland {
            XCTAssertFalse(device(identifier).hasDynamicIsland, "\(name) (\(identifier))")
        }
    }

    func testTheTableIsExactlyTheModelsWithoutAnIsland() {
        XCTAssertEqual(DeviceCapabilities.identifiersWithoutDynamicIsland, Set(withoutIsland.keys))
    }

    func testTheModelsWithAnIslandAnswerTrue() {
        for (identifier, name) in withIsland {
            XCTAssertTrue(device(identifier).hasDynamicIsland, "\(name) (\(identifier))")
        }
    }

    /// The point of listing the models WITHOUT one: an iPhone released after the table
    /// is shown the island.
    func testAnUnknownIdentifierCountsAsHavingAnIsland() {
        XCTAssertTrue(device("iPhone19,4").hasDynamicIsland, "unannounced in Xcode 27.0's table")
        XCTAssertTrue(device("iPhone20,1").hasDynamicIsland)
        XCTAssertTrue(device("iPhone99,9").hasDynamicIsland)
        XCTAssertTrue(device("arm64").hasDynamicIsland)
        XCTAssertTrue(device("").hasDynamicIsland)
    }

    /// The table matches whole identifiers: a prefix of a listed one is not listed.
    func testMatchingIsOnTheWholeIdentifier() {
        XCTAssertTrue(device("iPhone14,70").hasDynamicIsland)
        XCTAssertTrue(device("iPhone14").hasDynamicIsland)
    }

    /// No iPad has an island; Dictus runs there in compatibility mode (#612).
    func testAnIPadHasNoIsland() {
        XCTAssertFalse(device("iPad8,1").hasDynamicIsland)
        XCTAssertFalse(device("iPad13,4").hasDynamicIsland)
        XCTAssertFalse(device("iPad16,3").hasDynamicIsland)
    }

    func testIsIPadReadsTheProductLine() {
        XCTAssertTrue(device("iPad8,1").isIPad)
        XCTAssertTrue(device("iPad16,3").isIPad)
        XCTAssertFalse(device("iPhone16,2").isIPad)
        XCTAssertFalse(device("iPhone14,7").isIPad)
        XCTAssertFalse(device("arm64").isIPad)
    }
}
