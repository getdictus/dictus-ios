// DictusCore/Tests/DictusCoreTests/TranscriptionHistoryCrossProcessTests.swift
// The history file written by more than one process (#1056): the Share extension
// appends voice notes it transcribed with the app closed or suspended; the app must
// show them and must not erase them, and the other way round.
//
// Two store instances on one file stand for the two processes: each loads the file once
// when it is created, exactly as `TranscriptionHistoryStore.shared` does in each process.
// Ported from the #992 spike (commit ccd9d616), where the second writer was the keyboard.
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
        TranscriptionRecord(text: text, language: "fr", durationSeconds: 3, createdAt: Date(),
                            sttProvider: "apple-speechtranscriber")
    }

    /// The app is suspended with its copy loaded, the extension transcribes a voice note
    /// and writes, the user opens the app. The entry must be on screen.
    func testExtensionEntryAppearsWhenTheAppComesBack() {
        let app = process()
        let shareExtension = process()
        shareExtension.append(record("transcrit par l'extension"))

        XCTAssertTrue(app.records.isEmpty, "the app's copy is from before the extension wrote")
        app.reloadFromDisk() // what the app does when it becomes active
        XCTAssertEqual(app.records.map(\.text), ["transcrit par l'extension"])
    }

    /// The erasure: the app saves its own entry from a stale copy. Before #1056 this wrote
    /// the app's array over the file and the extension's entry was gone for good.
    func testAppWriteKeepsTheExtensionEntry() {
        let app = process()
        let shareExtension = process()
        shareExtension.append(record("extension"))
        app.append(record("app"))

        XCTAssertEqual(process().records.map(\.text), ["app", "extension"])
        XCTAssertEqual(app.records.map(\.text), ["app", "extension"])
    }

    /// And the other way round: an extension process loaded earlier must not erase what
    /// the app wrote since.
    func testExtensionWriteKeepsTheAppEntry() {
        let shareExtension = process()
        let app = process()
        app.append(record("app"))
        shareExtension.append(record("extension"))

        XCTAssertEqual(process().records.map(\.text), ["extension", "app"])
    }

    /// Updates from both sides on their own entries survive each other.
    func testUpdatesFromBothSidesSurvive() throws {
        let shareExtension = process()
        let app = process()
        let made = try XCTUnwrap(shareExtension.append(record("brut")))
        let other = try XCTUnwrap(app.append(record("autre")))
        shareExtension.updateText(id: made.id, to: "poli")
        app.updateText(id: other.id, to: "autre poli")

        XCTAssertEqual(Set(process().records.map(\.text)), ["poli", "autre poli"])
    }

    /// Deleting by offset from a stale list removes the row the user swiped, not whatever
    /// sits at that index in the file now.
    func testDeleteByOffsetUsesTheRowOnScreen() {
        let app = process()
        app.append(record("ancien"))
        let shareExtension = process()
        shareExtension.append(record("nouveau de l'extension"))
        // On screen the app shows ["ancien"]; the user deletes row 0.
        app.delete(atOffsets: IndexSet(integer: 0))

        XCTAssertEqual(process().records.map(\.text), ["nouveau de l'extension"])
    }

    /// Two writers interleaving many appends lose nothing, and the cap still holds across
    /// them: the file never exceeds `maxRecords`, and what falls off is the oldest.
    func testInterleavedWritersLoseNothingAndKeepTheCap() {
        let app = process()
        let shareExtension = process()
        let perWriter = TranscriptionHistoryStore.maxRecords / 2 + 10
        for index in 0..<perWriter {
            app.append(record("app \(index)"))
            shareExtension.append(record("extension \(index)"))
        }

        let onDisk = process().records.map(\.text)
        XCTAssertEqual(onDisk.count, TranscriptionHistoryStore.maxRecords)
        XCTAssertEqual(onDisk.first, "extension \(perWriter - 1)")
        // 2 × 110 writes, 200 kept: the 20 oldest (10 of each writer) fell off.
        XCTAssertEqual(onDisk.last, "app 10")
        XCTAssertEqual(Set(onDisk).count, onDisk.count, "no entry written twice")
    }

    /// Two writers at the same moment, on two threads: the test's main actor through the
    /// store, and a second thread doing what another process's store does, a coordinated
    /// read-modify-write of the same file. Without the coordinator, the two
    /// read-modify-write cycles overlap and one side's entries vanish.
    func testConcurrentWritersLoseNoEntry() {
        let perWriter = 60
        let fileURL = url!
        let app = process()

        let otherProcessDone = expectation(description: "other writer finished")
        let otherThread = Thread {
            for index in 0..<perWriter {
                Self.coordinatedAppend(Self.makeRecord("extension \(index)"), to: fileURL)
            }
            otherProcessDone.fulfill()
        }
        otherThread.start()
        for index in 0..<perWriter {
            app.append(record("app \(index)"))
        }
        wait(for: [otherProcessDone], timeout: 30)

        let onDisk = Set(process().records.map(\.text))
        let expected = Set((0..<perWriter).flatMap { ["app \($0)", "extension \($0)"] })
        XCTAssertEqual(onDisk, expected)
    }

    // MARK: - The other process's writer

    /// What the store's `mutate` does in another process, rebuilt off the main actor
    /// with the same file format (ISO 8601 dates, newest first).
    private nonisolated static func coordinatedAppend(_ record: TranscriptionRecord, to url: URL) {
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
            writingItemAt: url, options: .forMerging, error: &error
        ) { url in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            var current = (try? Data(contentsOf: url))
                .flatMap { try? decoder.decode([TranscriptionRecord].self, from: $0) } ?? []
            current.insert(record, at: 0)
            if let data = try? encoder.encode(current) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private nonisolated static func makeRecord(_ text: String) -> TranscriptionRecord {
        TranscriptionRecord(text: text, language: "fr", durationSeconds: 3, createdAt: Date(),
                            sttProvider: "apple-speechtranscriber")
    }
}
