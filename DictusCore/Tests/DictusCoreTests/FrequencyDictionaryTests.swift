// DictusCore/Tests/DictusCoreTests/FrequencyDictionaryTests.swift
import XCTest
@testable import DictusCore

final class FrequencyDictionaryTests: XCTestCase {

    func testFrequencyCountReturnsCorrectValueForKnownWord() {
        var dict = FrequencyDictionary()
        let json = #"{"de": 1, "la": 2, "le": 3, "bonjour": 500}"#
        dict.load(from: Data(json.utf8))
        XCTAssertEqual(dict.frequencyCount(of: "de"), 1)
        XCTAssertEqual(dict.frequencyCount(of: "bonjour"), 500)
    }

    func testFrequencyCountReturnsZeroForUnknownWord() {
        // `frequencyCount(of:)` returns the raw frequency count (higher = more
        // common), and 0 when the word is not in the dictionary.
        var dict = FrequencyDictionary()
        let json = #"{"de": 1}"#
        dict.load(from: Data(json.utf8))
        XCTAssertEqual(dict.frequencyCount(of: "xylophone"), 0)
    }

    func testFrequencyCountIsCaseInsensitive() {
        var dict = FrequencyDictionary()
        let json = #"{"bonjour": 42}"#
        dict.load(from: Data(json.utf8))
        XCTAssertEqual(dict.frequencyCount(of: "Bonjour"), 42)
        XCTAssertEqual(dict.frequencyCount(of: "BONJOUR"), 42)
    }

    func testLoadFromInvalidDataProducesEmptyDict() {
        var dict = FrequencyDictionary()
        dict.load(from: Data("not json".utf8))
        // Empty dict → unknown words return 0.
        XCTAssertEqual(dict.frequencyCount(of: "de"), 0)
    }

    func testCommonWordsHaveHigherCountsThanUncommon() {
        var dict = FrequencyDictionary()
        let json = #"{"de": 1, "la": 2, "anticonstitutionnellement": 9999}"#
        dict.load(from: Data(json.utf8))
        XCTAssertTrue(dict.frequencyCount(of: "de") < dict.frequencyCount(of: "anticonstitutionnellement"))
    }

    func testLoadFromFixtureFile() {
        guard let url = Bundle.module.url(forResource: "fr_frequency_test", withExtension: "json", subdirectory: "Fixtures"),
              let data = try? Data(contentsOf: url) else {
            XCTFail("Test fixture fr_frequency_test.json not found in test bundle")
            return
        }
        var dict = FrequencyDictionary()
        dict.load(from: data)
        XCTAssertEqual(dict.frequencyCount(of: "de"), 1)
        XCTAssertTrue(dict.frequencyCount(of: "le") < dict.frequencyCount(of: "anticonstitutionnellement"))
    }

    // MARK: - Ordering

    func testSortedMostCommonFirstPutsTheMostCommonWordFirst() {
        // The suggestion bar's contract, pinned (#365): typing "le" must offer
        // "les" before "lesparre". UITextChecker hands its completions over in
        // alphabetical order, so this ordering is the whole value we add.
        var dict = FrequencyDictionary()
        let json = #"{"les": 9000, "lesparre": 3}"#
        dict.load(from: Data(json.utf8))
        XCTAssertEqual(dict.sortedMostCommonFirst(["lesparre", "les"]), ["les", "lesparre"])
    }

    func testSortedMostCommonFirstSinksWordsTheDictionaryDoesNotKnow() {
        // Only the top 10K words are kept in memory, so a rare completion counts
        // 0 and must land last rather than wherever the caller passed it.
        var dict = FrequencyDictionary()
        let json = #"{"les": 9000, "lesparre": 3}"#
        dict.load(from: Data(json.utf8))
        XCTAssertEqual(
            dict.sortedMostCommonFirst(["lesquiller", "lesparre", "les"]),
            ["les", "lesparre", "lesquiller"]
        )
    }

    // MARK: - The shipped files (#555)

    /// `load(from:)` parses with `JSONSerialization` since #555. On every shipped
    /// file it must keep what the `JSONDecoder` version kept: each word whose count
    /// is above the 10 000th, with its count. Words tied at the cut were already a
    /// per-process draw, so they are not pinned.
    func testShippedFilesKeepEveryWordAboveTheCut() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DictusCoreTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // DictusCore/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("DictusKeyboard/Resources")
        for language in ["fr", "en", "es", "de"] {
            let data = try Data(contentsOf: resources.appendingPathComponent("\(language)_frequency.json"))
            let reference = try JSONDecoder().decode([String: Int].self, from: data)
            let cut = reference.values.sorted(by: >)[9_999]
            var dict = FrequencyDictionary()
            dict.load(from: data)
            for (word, count) in reference where count > cut {
                XCTAssertEqual(dict.frequencyCount(of: word), count, "\(language): \(word)")
            }
            for (word, count) in reference where count < cut {
                XCTAssertEqual(dict.frequencyCount(of: word), 0, "\(language): \(word)")
            }
        }
    }
}
