// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteKeyboardEvictionTests.swift
// A voice note evicted by History's or the queue's cap leaves the keyboard; a read
// History-off note does not (#639, decision C).
import XCTest
@testable import DictusCore

@MainActor
final class VoiceNoteKeyboardEvictionTests: XCTestCase {

    private var root: URL!
    private var historyURL: URL!
    private var deliveries: VoiceNoteKeyboardDeliveryStore!
    private let now = Date()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceNoteKeyboardEvictionTests-\(UUID().uuidString)", isDirectory: true)
        historyURL = root.appendingPathComponent("history.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        deliveries = VoiceNoteKeyboardDeliveryStore(root: root.appendingPathComponent("KeyboardDelivery"))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func publish(_ id: UUID) throws {
        try deliveries.publish(VoiceNoteKeyboardDelivery(
            id: id, transcript: "Salut", sharedAt: now, transcribedAt: now, language: "fr", durationSeconds: 7
        ))
    }

    private func record(id: UUID = UUID(), source: TranscriptionSource = .dictation) -> TranscriptionRecord {
        TranscriptionRecord(id: id, text: "texte", language: "fr", durationSeconds: 3,
                            sttProvider: SpeechEngine.whisperKit.rawValue, source: source)
    }

    // MARK: - History's cap

    /// The 201st record pushes the oldest out; the hook hears exactly that id, and the
    /// wiring DictusApp installs takes its delivery out of the keyboard.
    func testAVoiceNoteEvictedByTheHistoryCapLeavesTheKeyboard() throws {
        let history = TranscriptionHistoryStore(fileURL: historyURL, isEntitled: { true })
        var heard: [UUID] = []
        history.onEvicted = { ids in
            heard += ids
            ids.forEach(self.deliveries.withdraw)
        }
        let oldNote = UUID()
        let recentNote = UUID()
        XCTAssertNotNil(history.append(record(id: oldNote, source: .sharedFile)))
        XCTAssertNotNil(history.append(record(id: recentNote, source: .sharedFile)))
        try publish(oldNote)
        try publish(recentNote)

        for _ in 0..<(TranscriptionHistoryStore.maxRecords - 2) { history.append(record()) }
        XCTAssertEqual(heard, [], "at the cap, nothing is evicted yet")
        XCTAssertEqual(deliveries.pending(at: now).count, 2)

        history.append(record())
        XCTAssertEqual(heard, [oldNote])
        XCTAssertNil(history.record(id: oldNote))
        XCTAssertEqual(deliveries.pending(at: now).map(\.id), [recentNote])
    }

    /// Deleting and clearing are not evictions: they withdraw through their own call
    /// sites in DictusApp, and the hook stays silent.
    func testDeletesDoNotReportEvictions() {
        let history = TranscriptionHistoryStore(fileURL: historyURL, isEntitled: { true })
        var heard: [UUID] = []
        history.onEvicted = { heard += $0 }
        let first = record()
        history.append(first)
        history.append(record())
        history.delete(id: first.id)
        history.clear()
        XCTAssertEqual(heard, [])
    }

    // MARK: - The queue's cap (History off)

    private func doneNote(_ seconds: TimeInterval) -> VoiceNote {
        VoiceNote(receivedAt: Date(timeIntervalSince1970: seconds), audioFileName: nil, format: .ogg, state: .done)
    }

    /// With History off, finished notes live in the queue, capped at 20. The 21st
    /// pushes the oldest out, `complete` reports it, and its delivery is withdrawn.
    func testATranscriptEvictedByTheQueueCapLeavesTheKeyboard() throws {
        let done = (0..<VoiceNoteQueue.maxFinished).map { doneNote(TimeInterval($0)) }
        var queue = VoiceNoteQueue(notes: done)
        let oldest = done[0].id
        try publish(oldest)
        try publish(done[1].id)

        let incoming = VoiceNote(receivedAt: Date(timeIntervalSince1970: 1_000), audioFileName: "a.ogg",
                                 format: .ogg, state: .transcribing(progress: 0.5))
        queue.add([incoming])
        let evicted = queue.complete(incoming.id, transcript: "Salut", language: "fr", savedToHistory: false)
        XCTAssertEqual(evicted, [oldest])
        evicted.forEach(deliveries.withdraw)

        XCTAssertNil(queue.note(id: oldest))
        XCTAssertEqual(deliveries.pending(at: now).map(\.id), [done[1].id])
    }

    /// A failure takes a finished slot too, and reports what it pushed out.
    func testAFailureThatHitsTheQueueCapReportsTheEviction() {
        let done = (0..<VoiceNoteQueue.maxFinished).map { doneNote(TimeInterval($0)) }
        var queue = VoiceNoteQueue(notes: done)
        let incoming = VoiceNote(receivedAt: Date(timeIntervalSince1970: 1_000), audioFileName: "a.ogg",
                                 format: .ogg, state: .transcribing(progress: 0.5))
        queue.add([incoming])
        XCTAssertEqual(queue.fail(incoming.id, .noSpeech), [done[0].id])
    }

    /// Saved to History: the note leaves the queue by design, which is not an eviction.
    func testCompletingIntoHistoryReportsNoEviction() {
        var queue = VoiceNoteQueue(notes: [])
        let incoming = VoiceNote(receivedAt: Date(), audioFileName: "a.ogg", format: .ogg,
                                 state: .transcribing(progress: 0.5))
        queue.add([incoming])
        XCTAssertEqual(queue.complete(incoming.id, transcript: "Salut", language: "fr", savedToHistory: true), [])
    }

    // MARK: - The legitimate case: History off, read, gone from the queue

    /// A History-off note the user has read leaves the queue — through the keyboard
    /// receipt's reconcile (`markOpened` + `remove`) or the result screen's close
    /// (`removeOpenedFinished`). Neither is reported, so the keyboard keeps offering it
    /// for its 15 minutes, though it is in neither store.
    func testAReadHistoryOffNoteStaysInTheKeyboardAfterLeavingTheQueue() throws {
        var queue = VoiceNoteQueue(notes: [])
        let readInKeyboard = VoiceNote(receivedAt: Date(timeIntervalSince1970: 10), audioFileName: "a.ogg",
                                       format: .ogg, state: .transcribing(progress: 0.5))
        let readInApp = VoiceNote(receivedAt: Date(timeIntervalSince1970: 20), audioFileName: "b.ogg",
                                  format: .ogg, state: .transcribing(progress: 0.5))
        queue.add([readInKeyboard, readInApp])
        XCTAssertEqual(queue.complete(readInKeyboard.id, transcript: "a", language: "fr", savedToHistory: false), [])
        XCTAssertEqual(queue.complete(readInApp.id, transcript: "b", language: "fr", savedToHistory: false), [])
        try publish(readInKeyboard.id)
        try publish(readInApp.id)

        // What `reconcileKeyboardDeliveries` does with a receipt for a History-off note.
        queue.markOpened(readInKeyboard.id)
        queue.remove(readInKeyboard.id)
        // What the result screen does on close.
        queue.markOpened(readInApp.id)
        queue.removeOpenedFinished()

        XCTAssertTrue(queue.notes.isEmpty)
        XCTAssertEqual(Set(deliveries.pending(at: now).map(\.id)), [readInKeyboard.id, readInApp.id])
    }
}
