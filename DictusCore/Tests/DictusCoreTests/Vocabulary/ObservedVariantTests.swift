// DictusCore/Tests/DictusCoreTests/Vocabulary/ObservedVariantTests.swift
// A selection in a history entry becomes a variant, and the entry it makes corrects the next dictation (#723).
import XCTest
@testable import DictusCore

@MainActor
final class ObservedVariantTests: XCTestCase {

    // MARK: - Cleaning the selection

    func testAWordSelectedAloneIsTakenAsIs() {
        XCTAssertEqual(ObservedVariant.from(selection: "cubernetes"), "cubernetes")
    }

    func testSentenceMarksAndQuotesAtEitherEndAreDropped() {
        XCTAssertEqual(ObservedVariant.from(selection: "cloud code,"), "cloud code")
        XCTAssertEqual(ObservedVariant.from(selection: " «parakit» "), "parakit")
        XCTAssertEqual(ObservedVariant.from(selection: "(dictus)."), "dictus")
    }

    func testPunctuationInsideASpellingIsKept() {
        XCTAssertEqual(ObservedVariant.from(selection: "l'ampli"), "l'ampli")
        XCTAssertEqual(ObservedVariant.from(selection: "node.js"), "node.js")
    }

    func testMarksThatEndRealSpellingsAreKept() {
        XCTAssertEqual(ObservedVariant.from(selection: "C#"), "C#")
        XCTAssertEqual(ObservedVariant.from(selection: "c++"), "c++")
    }

    func testASpanAcrossALineBreakIsJoinedWithOneSpace() {
        XCTAssertEqual(ObservedVariant.from(selection: "cloud\n  code"), "cloud code")
    }

    func testNothingUsableGivesNoVariant() {
        XCTAssertNil(ObservedVariant.from(selection: ""))
        XCTAssertNil(ObservedVariant.from(selection: "  \n"))
        XCTAssertNil(ObservedVariant.from(selection: " , . "))
    }

    func testASelectionLongerThanAVariantMayBeGivesNoVariant() {
        // `VocabularyEntry` would drop it, and the sheet would open with nothing in it.
        let atLimit = String(repeating: "a", count: VocabularyEntry.maxFieldLength)
        XCTAssertEqual(ObservedVariant.from(selection: atLimit), atLimit)
        XCTAssertNil(ObservedVariant.from(selection: atLimit + "a"))
    }

    // MARK: - Merging into a stored term

    func testAddingAVariantKeepsTheEntryItsDateAndItsSwitch() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let stored = try XCTUnwrap(VocabularyEntry(
            term: "Kubernetes", variants: ["cubernetes"], isEnabled: false, dateAdded: date
        ))
        let merged = stored.addingVariants(["kubernetès"])
        XCTAssertEqual(merged.id, stored.id)
        XCTAssertEqual(merged.dateAdded, date)
        XCTAssertFalse(merged.isEnabled)
        XCTAssertEqual(merged.variants, ["cubernetes", "kubernetès"])
    }

    func testAddingAVariantAlreadyThereChangesNothing() throws {
        let stored = try XCTUnwrap(VocabularyEntry(term: "Kubernetes", variants: ["cubernetes"]))
        XCTAssertEqual(stored.addingVariants(["CUBERNETES"]), stored)
        XCTAssertEqual(stored.addingVariants(["Kubernetes"]), stored)
    }

    func testTheStoreFindsAStoredTermWhateverTheCase() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vocabulary-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = VocabularyStore(fileURL: url, isEntitled: { true })
        let stored = try XCTUnwrap(VocabularyEntry(term: "Kubernetes", variants: ["cubernetes"]))
        XCTAssertTrue(store.add(stored))

        XCTAssertEqual(store.entry(matchingTerm: "  kubernetes ")?.id, stored.id)
        XCTAssertNil(store.entry(matchingTerm: "Kube"))
        XCTAssertNil(store.entry(matchingTerm: "   "))
    }

    // MARK: - End to end, without the screen

    func testAnEntryMadeFromASelectionCorrectsTheNextTranscript() throws {
        // The acceptance line "the next dictation applies it", at the level a test can
        // reach: the variant the sheet is prefilled with, the term the user types,
        // the entry the sheet builds, and the pass every dictation goes through.
        let variant = try XCTUnwrap(ObservedVariant.from(selection: "parakit,"))
        let entry = try XCTUnwrap(VocabularyEntry(
            term: "Parakeet", variants: VocabularyEntry.variants(fromLine: variant)
        ))
        XCTAssertTrue(entry.hasEffect)
        XCTAssertEqual(
            CustomVocabulary.corrected("J'utilise parakit sur iPhone.", entries: [entry]),
            "J'utilise Parakeet sur iPhone."
        )
    }

    func testAVariantMergedIntoAStoredTermCorrectsTheNextTranscript() throws {
        let stored = try XCTUnwrap(VocabularyEntry(term: "Parakeet", variants: ["parakit"]))
        let variant = try XCTUnwrap(ObservedVariant.from(selection: "para kit"))
        let merged = stored.addingVariants([variant])
        XCTAssertEqual(
            CustomVocabulary.corrected("parakit puis para kit", entries: [merged]),
            "Parakeet puis Parakeet"
        )
    }
}
