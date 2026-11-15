// DictusCore/Tests/DictusCoreTests/ClearHistoryTests.swift
// "Clear history" empties the polish journal too (#906).
//
// Temporary files for both stores, the seam TranscriptionHistoryStoreTests and
// PolishEventStoreTests already use.
import XCTest
@testable import DictusCore

@MainActor
final class ClearHistoryTests: XCTestCase {

    private var historyURL: URL!
    private var journalURL: URL!

    override func setUpWithError() throws {
        let tmp = FileManager.default.temporaryDirectory
        historyURL = tmp.appendingPathComponent("history-\(UUID().uuidString).json")
        journalURL = tmp.appendingPathComponent("polish-events-\(UUID().uuidString).jsonl")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: historyURL)
        try? FileManager.default.removeItem(at: journalURL)
    }

    private func makeHistory() -> TranscriptionHistoryStore {
        TranscriptionHistoryStore(fileURL: historyURL, isEntitled: { true })
    }

    private func record(_ text: String) -> TranscriptionRecord {
        TranscriptionRecord(text: text, language: "fr", durationSeconds: 3,
                            createdAt: Date(), sttProvider: SpeechEngine.whisperKit.rawValue)
    }

    private func appendJournal(_ raw: String) {
        let entry = PolishDebugEntry(
            raw: raw,
            vocabularyCorrected: raw,
            polished: raw,
            metrics: PolishMetrics(
                engine: "apple-fm", mode: "natural", targetLanguage: .french,
                detectedLanguage: "fr", rawCharCount: raw.count, polishedCharCount: raw.count,
                latencyMs: 1, outcome: .success
            ),
            writer: "<KBD>"
        )
        PolishEventStore.append(entry, to: journalURL)
    }

    private func journalBytes() -> Int {
        (try? Data(contentsOf: journalURL).count) ?? 0
    }

    // MARK: - Clearing

    func testClearEmptiesTheHistoryAndTheJournal() {
        let history = makeHistory()
        history.append(record("rendez-vous chez le dentiste"))
        appendJournal("rendez-vous chez le dentiste")
        XCTAssertGreaterThan(journalBytes(), 0)

        ClearHistory.run(history: history, journalURL: journalURL)

        XCTAssertTrue(history.isEmpty)
        XCTAssertTrue(TranscriptionHistoryStore(fileURL: historyURL, isEntitled: { true }).isEmpty,
                      "the history file itself is empty, not just the in-memory copy")
        XCTAssertEqual(journalBytes(), 0, "no dictated text left in the journal file")
        XCTAssertTrue(PolishEventStore.readAll(applyingRetention: false, from: journalURL).isEmpty)
    }

    /// The case #906 names: no history (no Dictus Pro), but a journal. The history
    /// store's own `clear()` returns early on an empty history; the journal must not.
    func testClearEmptiesTheJournalWhenTheHistoryIsEmpty() {
        let history = makeHistory()
        appendJournal("un")
        appendJournal("deux")

        ClearHistory.run(history: history, journalURL: journalURL)

        XCTAssertEqual(journalBytes(), 0)
    }

    // MARK: - Whether the row has anything to delete

    func testNothingToDeleteWithoutHistoryOrJournal() {
        XCTAssertFalse(ClearHistory.hasSomethingToDelete(history: makeHistory(), journalURL: journalURL))
        XCTAssertFalse(ClearHistory.hasSomethingToDelete(history: makeHistory(), journalURL: nil))
    }

    func testAJournalAloneIsSomethingToDelete() {
        appendJournal("un")
        XCTAssertTrue(ClearHistory.hasSomethingToDelete(history: makeHistory(), journalURL: journalURL),
                      "a user without Dictus Pro still has dictated text to delete")
    }

    func testAHistoryAloneIsSomethingToDelete() {
        let history = makeHistory()
        history.append(record("un"))
        XCTAssertTrue(ClearHistory.hasSomethingToDelete(history: history, journalURL: journalURL))
    }

    func testNothingLeftAfterClearing() {
        let history = makeHistory()
        history.append(record("un"))
        appendJournal("un")

        ClearHistory.run(history: history, journalURL: journalURL)

        XCTAssertFalse(ClearHistory.hasSomethingToDelete(history: history, journalURL: journalURL))
    }
}
