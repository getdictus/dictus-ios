// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteKeyboardReceiptsTests.swift
// The keyboard's receipts becoming "read" in DictusApp, idempotently (#637, #639).
import XCTest
@testable import DictusCore

@MainActor
final class VoiceNoteKeyboardReceiptsTests: XCTestCase {

    private var root: URL!
    private var deliveries: VoiceNoteKeyboardDeliveryStore!
    private var history: TranscriptionHistoryStore!
    private var queue: VoiceNoteQueueStore!
    private let shownAt = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceNoteKeyboardReceiptsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        deliveries = VoiceNoteKeyboardDeliveryStore(root: root.appendingPathComponent("KeyboardDelivery"))
        history = TranscriptionHistoryStore(fileURL: root.appendingPathComponent("history.json"), isEntitled: { true })
        queue = VoiceNoteQueueStore(storage: VoiceNoteStorage(root: root.appendingPathComponent("VoiceNotes")))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func savedVoiceNote() -> UUID {
        let record = TranscriptionRecord(text: "Salut", language: "fr", durationSeconds: 7,
                                         sttProvider: SpeechEngine.whisperKit.rawValue, source: .sharedFile)
        history.append(record)
        return record.id
    }

    private func apply() -> [VoiceNoteKeyboardAcknowledgement] {
        VoiceNoteKeyboardReceipts.apply(from: deliveries, history: history, queue: queue)
    }

    /// Decision A: a note shown in the keyboard is read in History, at the time it was
    /// shown, and the receipt is spent.
    func testAShownReceiptMarksTheHistoryRecordRead() {
        let id = savedVoiceNote()
        XCTAssertEqual(history.unreadVoiceNotes.map(\.id), [id])
        deliveries.acknowledge(id, action: .shown, at: shownAt)
        XCTAssertEqual(apply().map(\.id), [id])
        XCTAssertEqual(history.record(id: id)?.openedAt, shownAt)
        XCTAssertEqual(history.unreadVoiceNotes, [])
        XCTAssertEqual(deliveries.acknowledgements(), [])
    }

    /// Every entry point and the live signal call this: a second pass with nothing new
    /// does nothing and returns nothing (so the island is not touched again).
    func testApplyingTwiceIsANoOp() {
        let id = savedVoiceNote()
        deliveries.acknowledge(id, action: .shown, at: shownAt)
        apply()
        XCTAssertEqual(apply(), [])
        XCTAssertEqual(history.record(id: id)?.openedAt, shownAt)
    }

    /// Shown, reconciled, then inserted later: the second receipt keeps the first
    /// read date — one "read", not two.
    func testAnInsertAfterAShownKeepsTheFirstReadDate() {
        let id = savedVoiceNote()
        deliveries.acknowledge(id, action: .shown, at: shownAt)
        apply()
        deliveries.acknowledge(id, action: .inserted, at: shownAt.addingTimeInterval(60))
        XCTAssertEqual(apply().map(\.action), [.inserted])
        XCTAssertEqual(history.record(id: id)?.openedAt, shownAt)
    }

    /// History off: the note lives in the queue, done. The receipt marks it read and
    /// removes it, as the result screen does on close. A later receipt finds nothing.
    func testAHistoryOffNoteIsMarkedReadAndLeavesTheQueue() {
        let note = VoiceNote(receivedAt: Date(), audioFileName: nil, format: .ogg, state: .done)
        queue.mutate { $0.add([note]) }
        deliveries.acknowledge(note.id, action: .shown, at: shownAt)
        apply()
        XCTAssertNil(queue.queue.note(id: note.id))
        deliveries.acknowledge(note.id, action: .inserted, at: shownAt.addingTimeInterval(5))
        XCTAssertEqual(apply().count, 1, "the receipt is still spent")
        XCTAssertNil(queue.queue.note(id: note.id))
    }

    /// A receipt is spent, never the delivery: the note stays in the keyboard.
    func testApplyingAReceiptKeepsTheDelivery() throws {
        let id = savedVoiceNote()
        try deliveries.publish(VoiceNoteKeyboardDelivery(id: id, transcript: "Salut", sharedAt: Date(),
                                                         transcribedAt: Date(), language: "fr", durationSeconds: 7))
        deliveries.acknowledge(id, action: .shown)
        apply()
        XCTAssertEqual(deliveries.pending().map(\.id), [id])
    }

    /// The keyboard → app signal is its own name, distinct from every other one: a
    /// collision would make the app reconcile on an unrelated event, or miss this one.
    func testTheReceiptSignalHasItsOwnName() {
        let others: [CFString] = [
            DarwinNotificationName.transcriptionReady, DarwinNotificationName.statusChanged,
            DarwinNotificationName.stopRecording, DarwinNotificationName.cancelRecording,
            DarwinNotificationName.waveformUpdate, DarwinNotificationName.startRecording,
            DarwinNotificationName.audioSessionInterrupted, DarwinNotificationName.polishWillRun,
            DarwinNotificationName.polishDidFinish, DarwinNotificationName.warmStateReleased,
            DarwinNotificationName.voiceNoteQueued, DarwinNotificationName.voiceNoteAccepted,
            DarwinNotificationName.voiceNoteResultReady
        ]
        let name = DarwinNotificationName.voiceNoteKeyboardReceipt as String
        XCTAssertEqual(name, "com.pivi.dictus.voiceNoteKeyboardReceipt")
        XCTAssertFalse(others.map { $0 as String }.contains(name))
    }
}
