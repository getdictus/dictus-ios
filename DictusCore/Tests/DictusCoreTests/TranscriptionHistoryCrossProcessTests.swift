// DictusCore/Tests/DictusCoreTests/TranscriptionHistoryCrossProcessTests.swift
// The history file written by two processes (#992): the keyboard appends dictations it
// ran with the app closed or suspended; the app must show them and must not erase them.
//
// Two store instances on one file stand for the two processes: each loads the file once
// when it is created, exactly as `TranscriptionHistoryStore.shared` does in each process.
import XCTest
@testable import DictusCore

@MainActor
final class TranscriptionHistoryCrossProcessTests: XCTestCase {

    private var url: URL!

    override func setUpWithError() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-xproc-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: url)
    }

    private func process() -> TranscriptionHistoryStore {
        TranscriptionHistoryStore(fileURL: url, isEntitled: { true })
    }

    private func record(_ text: String) -> TranscriptionRecord {
        TranscriptionRecord(text: text, language: "fr", durationSeconds: 3, createdAt: Date(), sttProvider: "apple-speechtranscriber")
    }

    /// Pierre's case: the app is suspended with its copy loaded, the keyboard dictates by
    /// itself and writes, the user opens the app. The entry must be on screen.
    func testKeyboardEntryAppearsWhenTheAppComesBack() {
        let app = process()
        let keyboard = process()
        keyboard.append(record("dicté dans le clavier"))

        XCTAssertTrue(app.records.isEmpty, "the app's copy is from before the keyboard wrote")
        app.reloadFromDisk() // what the app does when it becomes active
        XCTAssertEqual(app.records.map(\.text), ["dicté dans le clavier"])
    }

    /// The erasure: the app saves its own entry from a stale copy. Before #992 this wrote
    /// the app's array over the file and the keyboard's dictation was gone for good.
    func testAppWriteKeepsTheKeyboardEntry() {
        let app = process()
        let keyboard = process()
        keyboard.append(record("clavier"))
        app.append(record("app"))

        XCTAssertEqual(process().records.map(\.text), ["app", "clavier"])
        XCTAssertEqual(app.records.map(\.text), ["app", "clavier"])
    }

    /// And the other way round: a long-lived keyboard process must not erase what the
    /// app wrote since the keyboard loaded the file.
    func testKeyboardWriteKeepsTheAppEntry() {
        let keyboard = process()
        let app = process()
        app.append(record("app"))
        keyboard.append(record("clavier"))

        XCTAssertEqual(process().records.map(\.text), ["clavier", "app"])
    }

    /// The keyboard's tail updates its own entry with the polished text; the app's copy
    /// must see the update, and an app-side update must not revert it.
    func testUpdatesFromBothSidesSurvive() throws {
        let keyboard = process()
        let app = process()
        let made = try XCTUnwrap(keyboard.append(record("brut")))
        let other = try XCTUnwrap(app.append(record("autre")))
        keyboard.updateText(id: made.id, to: "poli")
        app.updateText(id: other.id, to: "autre poli")

        XCTAssertEqual(Set(process().records.map(\.text)), ["poli", "autre poli"])
    }

    /// Deleting by offset from a stale list removes the row the user swiped, not whatever
    /// sits at that index in the file now.
    func testDeleteByOffsetUsesTheRowOnScreen() {
        let app = process()
        app.append(record("ancien"))
        let keyboard = process()
        keyboard.append(record("nouveau du clavier"))
        // On screen the app shows ["ancien"]; the user deletes row 0.
        app.delete(atOffsets: IndexSet(integer: 0))

        XCTAssertEqual(process().records.map(\.text), ["nouveau du clavier"])
    }
}
