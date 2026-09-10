// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularyEntryTests.swift
// The 100-character limit and the cleaning rules that guard it (#80 decision 10).
import XCTest
@testable import DictusCore

final class VocabularyEntryTests: XCTestCase {

    // MARK: - The 100-character limit

    func testATermOfExactlyOneHundredCharactersIsAccepted() {
        let term = String(repeating: "a", count: VocabularyEntry.maxFieldLength)
        XCTAssertNotNil(VocabularyEntry(term: term))
    }

    func testATermLongerThanOneHundredCharactersIsRefused() {
        let term = String(repeating: "a", count: VocabularyEntry.maxFieldLength + 1)
        XCTAssertNil(VocabularyEntry(term: term))
    }

    func testAVariantLongerThanOneHundredCharactersIsDroppedAndTheEntrySurvives() {
        let long = String(repeating: "b", count: VocabularyEntry.maxFieldLength + 1)
        let entry = VocabularyEntry(term: "Kubernetes", variants: [long, "cubernetes"])
        XCTAssertEqual(entry?.variants, ["cubernetes"])
    }

    func testTheLimitCountsCharactersNotBytes() {
        // A hundred emoji is a hundred characters. Counting UTF-8 would refuse a
        // term a quarter of that length.
        let term = String(repeating: "é", count: VocabularyEntry.maxFieldLength)
        XCTAssertNotNil(VocabularyEntry(term: term))
    }

    // MARK: - Cleaning

    func testAnEmptyOrWhitespaceTermIsRefused() {
        XCTAssertNil(VocabularyEntry(term: ""))
        XCTAssertNil(VocabularyEntry(term: "   \n "))
    }

    func testSurroundingWhitespaceIsTrimmedFromBothFields() {
        let entry = VocabularyEntry(term: "  Kubernetes ", variants: [" cubernetes  ", "\tkubernetès"])
        XCTAssertEqual(entry?.term, "Kubernetes")
        XCTAssertEqual(entry?.variants, ["cubernetes", "kubernetès"])
    }

    func testEmptyVariantsAreDropped() {
        let entry = VocabularyEntry(term: "Kubernetes", variants: ["", "  ", "cubernetes"])
        XCTAssertEqual(entry?.variants, ["cubernetes"])
    }

    func testVariantsAreDeduplicatedIgnoringCase() {
        let entry = VocabularyEntry(term: "Kubernetes", variants: ["cubernetes", "CUBERNETES"])
        XCTAssertEqual(entry?.variants, ["cubernetes"])
    }

    func testAVariantIdenticalToItsTermIsDroppedButACaseVariantIsKept() {
        XCTAssertEqual(VocabularyEntry(term: "Ampli", variants: ["Ampli"])?.variants, [])
        XCTAssertEqual(VocabularyEntry(term: "Ampli", variants: ["ampli"])?.variants, ["ampli"])
    }

    // MARK: - The comma-separated line the sheet writes

    func testTheVariantsLineRoundTrips() {
        let entry = VocabularyEntry(term: "Claude Code", variants: ["clode code", "cloud code"])
        XCTAssertEqual(entry?.variantsLine, "clode code, cloud code")
        let parsed = VocabularyEntry.variants(fromLine: "clode code, cloud code")
        XCTAssertEqual(VocabularyEntry(term: "Claude Code", variants: parsed)?.variants,
                       ["clode code", "cloud code"])
    }

    func testALineOfNothingButSeparatorsYieldsNoVariants() {
        let parsed = VocabularyEntry.variants(fromLine: " , ,, ")
        XCTAssertEqual(VocabularyEntry(term: "Kubernetes", variants: parsed)?.variants, [])
    }

    // MARK: - What comes off disk

    func testAnEntryDecodedFromAHandEditedFileIsRejectedWhenItBreaksTheLimit() {
        // `Codable` synthesises its own initialiser, so the file is the one door the
        // failable initialiser does not guard. `isValid` is what the store checks.
        let long = String(repeating: "a", count: VocabularyEntry.maxFieldLength + 1)
        let json = Data("""
        [{"id":"\(UUID().uuidString)","term":"\(long)","variants":[],\
        "isEnabled":true,"dateAdded":"2026-09-07T10:00:00Z"}]
        """.utf8)
        let decoded = try? VocabularyStore.decoder.decode([VocabularyEntry].self, from: json)
        XCTAssertEqual(decoded?.count, 1)
        XCTAssertEqual(decoded?.first?.isValid, false)
    }

    /// The five shapes a hand-edited file could carry that `isValid` used to accept
    /// while `init?` refused or cleaned them. The store trusts this property at load,
    /// so each one was a rule the file could walk straight past.
    func testIsValidRefusesWhatTheInitialiserWouldHaveCleanedOrRefused() {
        XCTAssertEqual(decoded(term: "   ", variants: [])?.isValid, false, "a blank term")
        XCTAssertEqual(decoded(term: " Kubernetes ", variants: [])?.isValid, false, "an untrimmed term")
        XCTAssertEqual(decoded(term: "Kubernetes", variants: ["  "])?.isValid, false, "a blank variant")
        XCTAssertEqual(
            decoded(term: "Kubernetes", variants: ["cubernetes", "CUBERNETES"])?.isValid, false,
            "a duplicate differing only in case"
        )
        XCTAssertEqual(
            decoded(term: "Ampli", variants: ["Ampli"])?.isValid, false,
            "a variant identical to its own term"
        )
        XCTAssertEqual(
            decoded(term: "Kubernetes", variants: ["cubernetes"])?.isValid, true,
            "and a well-formed entry still passes"
        )
    }

    /// An entry as it arrives off disk: through `Codable`, which cannot be routed
    /// through the failable initialiser and is therefore the one door that matters.
    private func decoded(term: String, variants: [String]) -> VocabularyEntry? {
        let variantList = variants.map { "\"\($0)\"" }.joined(separator: ",")
        let json = Data(
            ("{\"id\":\"\(UUID().uuidString)\",\"term\":\"\(term)\","
             + "\"variants\":[\(variantList)],"
             + "\"isEnabled\":true,\"dateAdded\":\"2026-09-07T10:00:00Z\"}").utf8
        )
        return try? VocabularyStore.decoder.decode(VocabularyEntry.self, from: json)
    }

    func testAWellFormedEntryRoundTripsThroughJSON() {
        // A whole second: the ISO-8601 strategy the store shares between its encoder
        // and its decoder has no sub-second field, so a `Date()` would not compare
        // equal to itself across a round trip.
        guard let entry = VocabularyEntry(
            term: "Kubernetes", variants: ["cubernetes"],
            dateAdded: Date(timeIntervalSince1970: 1_757_000_000)
        ) else {
            return XCTFail("entry should be constructible")
        }
        guard let data = try? VocabularyStore.encoder.encode([entry]),
              let decoded = try? VocabularyStore.decoder.decode([VocabularyEntry].self, from: data) else {
            return XCTFail("round trip should succeed")
        }
        XCTAssertEqual(decoded, [entry])
    }
}
