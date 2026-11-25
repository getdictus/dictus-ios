import XCTest
@testable import DictusCore

/// #984: the copy names the device the user holds, read from the hardware
/// identifier because an iPad runs the iPhone-only app with the `.phone` idiom.
final class DeviceNounTests: XCTestCase {

    func testIPadIdentifiersAreNamedIPad() {
        XCTAssertEqual(DeviceNoun.name(forModelIdentifier: "iPad13,1"), "iPad")
        XCTAssertEqual(DeviceNoun.name(forModelIdentifier: "iPad16,6"), "iPad")
    }

    func testIPhoneIdentifiersAreNamedIPhone() {
        XCTAssertEqual(DeviceNoun.name(forModelIdentifier: "iPhone16,2"), "iPhone")
        XCTAssertEqual(DeviceNoun.name(forModelIdentifier: "iPhone18,1"), "iPhone")
    }

    /// A host architecture (a simulator without SIMULATOR_MODEL_IDENTIFIER, or the
    /// Mac running these tests) is not an iPad: the copy keeps its iPhone wording.
    func testUnknownIdentifiersFallBackToIPhone() {
        XCTAssertEqual(DeviceNoun.name(forModelIdentifier: "arm64"), "iPhone")
        XCTAssertEqual(DeviceNoun.name(forModelIdentifier: ""), "iPhone")
    }

    func testCurrentIsOneOfTheTwoNouns() {
        XCTAssertTrue(["iPhone", "iPad"].contains(DeviceNoun.current))
    }
}
