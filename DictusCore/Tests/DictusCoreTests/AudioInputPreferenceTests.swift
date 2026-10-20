import XCTest
@testable import DictusCore

final class AudioInputPreferenceTests: XCTestCase {
    func testExistingInstallsKeepBuiltInInput() {
        XCTAssertEqual(AudioInputPreference(storedValue: nil), .builtIn)
    }

    func testUnknownValuesFallBackToBuiltInInput() {
        XCTAssertEqual(AudioInputPreference(storedValue: "removed-device-uid"), .builtIn)
        XCTAssertEqual(AudioInputPreference(storedValue: ""), .builtIn)
    }

    func testBothChoicesSurviveStorageRoundTrip() {
        for preference in AudioInputPreference.allCases {
            XCTAssertEqual(AudioInputPreference(storedValue: preference.rawValue), preference)
        }
    }
}
