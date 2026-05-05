// DictusCore/Tests/DictusCoreTests/FrequencyDictionaryTests.swift
import XCTest
@testable import DictusCore

final class FrequencyDictionaryTests: XCTestCase {

    func testRankReturnsCorrectValueForKnownWord() {
        var dict = FrequencyDictionary()
        let json = #"{"de": 1, "la": 2, "le": 3, "bonjour": 500}"#
        dict.load(from: json.data(using: .utf8)!)
        XCTAssertEqual(dict.rank(of: "de"), 1)
        XCTAssertEqual(dict.rank(of: "bonjour"), 500)
    }

    func testRankReturnsZeroForUnknownWord() {
        // `rank(of:)` returns the raw frequency count (higher = more common),
        // and 0 when the word is not in the dictionary.
        var dict = FrequencyDictionary()
        let json = #"{"de": 1}"#
        dict.load(from: json.data(using: .utf8)!)
        XCTAssertEqual(dict.rank(of: "xylophone"), 0)
    }

    func testRankIsCaseInsensitive() {
        var dict = FrequencyDictionary()
        let json = #"{"bonjour": 42}"#
        dict.load(from: json.data(using: .utf8)!)
        XCTAssertEqual(dict.rank(of: "Bonjour"), 42)
        XCTAssertEqual(dict.rank(of: "BONJOUR"), 42)
    }

    func testLoadFromInvalidDataProducesEmptyDict() {
        var dict = FrequencyDictionary()
        dict.load(from: "not json".data(using: .utf8)!)
        // Empty dict → unknown words return 0.
        XCTAssertEqual(dict.rank(of: "de"), 0)
    }

    func testCommonWordsRankHigherThanUncommon() {
        var dict = FrequencyDictionary()
        let json = #"{"de": 1, "la": 2, "anticonstitutionnellement": 9999}"#
        dict.load(from: json.data(using: .utf8)!)
        XCTAssertTrue(dict.rank(of: "de") < dict.rank(of: "anticonstitutionnellement"))
    }

    func testLoadFromFixtureFile() {
        guard let url = Bundle.module.url(forResource: "fr_frequency_test", withExtension: "json", subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Test fixture fr_frequency_test.json not found in test bundle")
            return
        }
        var dict = FrequencyDictionary()
        dict.load(from: data)
        XCTAssertEqual(dict.rank(of: "de"), 1)
        XCTAssertTrue(dict.rank(of: "le") < dict.rank(of: "anticonstitutionnellement"))
    }
}
