import XCTest
@testable import DictusCore

/// The queue's rules (#620 decision 6) and its two files: the inbox the share
/// extension drops into and the queue DictusApp persists.
final class VoiceNoteQueueTests: XCTestCase {

    private func note(_ seconds: TimeInterval, state: VoiceNoteState = .waiting, audio: String? = "a.ogg") -> VoiceNote {
        VoiceNote(receivedAt: Date(timeIntervalSince1970: seconds), audioFileName: audio, format: .ogg, state: state)
    }

    // MARK: - Order and counts

    func testOldestWaitingNoteGoesFirst() {
        let first = note(100), second = note(200), third = note(300)
        let queue = VoiceNoteQueue(notes: [second, third, first])
        XCTAssertEqual(queue.next?.id, first.id)
        // Shown newest first.
        XCTAssertEqual(queue.notes.map(\.id), [third.id, second.id, first.id])
    }

    func testCountsReadOneInProgressAndTheRestWaiting() {
        let queue = VoiceNoteQueue(notes: [note(1, state: .transcribing(progress: 0.4)), note(2), note(3),
                                           note(4, state: .done, audio: nil)])
        XCTAssertEqual(queue.activityCounts.inProgress, 1)
        XCTAssertEqual(queue.activityCounts.waiting, 2)
        XCTAssertTrue(queue.hasPendingWork)
    }

    func testANoteInterruptedMidTranscriptionGoesBackToWaiting() {
        var queue = VoiceNoteQueue(notes: [note(1, state: .transcribing(progress: 0.7))])
        queue.recoverInterrupted()
        XCTAssertEqual(queue.notes.first?.state, .waiting)
        XCTAssertNotNil(queue.next)
    }

    func testAddingTheSameDropTwiceQueuesItOnce() {
        let arrived = note(1)
        var queue = VoiceNoteQueue()
        queue.add([arrived])
        queue.add([arrived])
        XCTAssertEqual(queue.notes.count, 1)
    }

    // MARK: - Completion

    func testANoteTheHistoryTookLeavesTheQueue() {
        let shared = note(1, state: .transcribing(progress: 1))
        var queue = VoiceNoteQueue(notes: [shared])
        queue.complete(shared.id, transcript: "Salut", language: "auto", savedToHistory: true)
        XCTAssertNil(queue.note(id: shared.id))
    }

    func testANoteTheHistoryRefusedStaysDoneWithItsTextAndWithoutAudio() {
        let shared = note(1, state: .transcribing(progress: 1))
        var queue = VoiceNoteQueue(notes: [shared])
        queue.complete(shared.id, transcript: "Salut", language: "fr", savedToHistory: false)
        let kept = queue.note(id: shared.id)
        XCTAssertEqual(kept?.state, .done)
        XCTAssertEqual(kept?.transcript, "Salut")
        XCTAssertEqual(kept?.language, "fr")
        XCTAssertNil(kept?.audioFileName, "no audio is kept after transcription")
        XCTAssertFalse(queue.hasPendingWork)
    }

    func testOnlyAnEngineFailureKeepsTheAudioAndCanBeRetried() {
        let broken = note(1), engine = note(2)
        var queue = VoiceNoteQueue(notes: [broken, engine])
        queue.fail(broken.id, .unsupportedFormat)
        queue.fail(engine.id, .transcriptionFailed)
        XCTAssertNil(queue.note(id: broken.id)?.audioFileName)
        XCTAssertNotNil(queue.note(id: engine.id)?.audioFileName)

        queue.retry(broken.id)
        XCTAssertEqual(queue.note(id: broken.id)?.state, .failed(.unsupportedFormat))
        queue.retry(engine.id)
        XCTAssertEqual(queue.note(id: engine.id)?.state, .waiting)
    }

    func testFinishedNotesAreCappedAndPendingOnesNeverAre() {
        var notes = (0..<25).map { note(TimeInterval($0), state: .done, audio: nil) }
        notes.append(note(1000))
        var queue = VoiceNoteQueue(notes: notes)
        let last = note(2000, state: .transcribing(progress: 0))
        queue.add([last])
        queue.fail(last.id, .noSpeech)
        XCTAssertEqual(queue.notes.filter(\.state.isFinished).count, VoiceNoteQueue.maxFinished)
        XCTAssertEqual(queue.waitingCount, 1)
        // The newest finished note is the one kept.
        XCTAssertNotNil(queue.note(id: last.id))
    }

    func testFailureRawValuesAnOlderBuildDoesNotKnowDegrade() throws {
        let json = #"{"kind":"failed","failure":"somethingNew"}"#
        let state = try JSONDecoder().decode(VoiceNoteState.self, from: Data(json.utf8))
        XCTAssertEqual(state, .failed(.transcriptionFailed))
        let unknownKind = try JSONDecoder().decode(VoiceNoteState.self, from: Data(#"{"kind":"paused"}"#.utf8))
        XCTAssertEqual(unknownKind, .waiting)
    }

    func testStateRoundTrips() throws {
        for state in [VoiceNoteState.waiting, .transcribing(progress: 0.25), .done, .failed(.tooLong)] {
            let data = try JSONEncoder().encode(state)
            XCTAssertEqual(try JSONDecoder().decode(VoiceNoteState.self, from: data), state)
        }
    }

    // MARK: - Inbox and store

    private func temporaryStorage() throws -> VoiceNoteStorage {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("voicenotes-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return VoiceNoteStorage(root: root)
    }

    private func sourceAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("src-\(UUID()).opus")
        try Data("OggS fake audio".utf8).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testDropThenIngestMovesTheAudioAndQueuesTheNote() throws {
        let storage = try temporaryStorage()
        let drop = try VoiceNoteInbox.drop(copying: try sourceAudio(), format: .ogg, durationSeconds: 42, storage: storage)
        XCTAssertTrue(VoiceNoteInbox.isPending(drop, storage: storage))

        let notes = VoiceNoteInbox.ingest(storage: storage)
        XCTAssertEqual(notes.map(\.id), [drop.id])
        XCTAssertEqual(notes.first?.durationSeconds, 42)
        XCTAssertEqual(notes.first?.audioFileName, "\(drop.id.uuidString).ogg")
        // The extension's signal that a live app took it.
        XCTAssertFalse(VoiceNoteInbox.isPending(drop, storage: storage))
        let moved = storage.audioDirectory.appendingPathComponent("\(drop.id.uuidString).ogg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path))
    }

    func testAudioWithoutASidecarIsNeverIngestedAndIsSweptWhenStale() throws {
        let storage = try temporaryStorage()
        try storage.ensureDirectories()
        let orphan = storage.inboxDirectory.appendingPathComponent("half-copied.ogg")
        try Data("x".utf8).write(to: orphan)

        XCTAssertTrue(VoiceNoteInbox.ingest(storage: storage).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphan.path), "a copy in progress is left alone")

        XCTAssertTrue(VoiceNoteInbox.ingest(storage: storage, now: Date().addingTimeInterval(7200)).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphan.path))
    }

    @MainActor
    func testStorePersistsAndRecoversAcrossProcesses() throws {
        let storage = try temporaryStorage()
        try VoiceNoteInbox.drop(copying: try sourceAudio(), format: .ogg, durationSeconds: nil, storage: storage)

        let first = VoiceNoteQueueStore(storage: storage)
        let arrived = first.ingestInbox()
        XCTAssertEqual(arrived.count, 1)
        let id = try XCTUnwrap(arrived.first?.id)
        first.mutate { $0.update(id) { $0.state = .transcribing(progress: 0.5) } }

        // A new process: the note comes back waiting, its audio intact.
        let second = VoiceNoteQueueStore(storage: storage)
        XCTAssertEqual(second.queue.note(id: id)?.state, .waiting)
        let audio = try XCTUnwrap(second.queue.note(id: id).flatMap(second.audioURL(for:)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: audio.path))
    }

    @MainActor
    func testFinishingANoteDeletesItsAudio() throws {
        let storage = try temporaryStorage()
        try VoiceNoteInbox.drop(copying: try sourceAudio(), format: .ogg, durationSeconds: nil, storage: storage)
        let store = VoiceNoteQueueStore(storage: storage)
        let note = try XCTUnwrap(store.ingestInbox().first)
        let audio = try XCTUnwrap(store.audioURL(for: note))

        store.mutate { $0.complete(note.id, transcript: "ok", language: "fr", savedToHistory: false) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: audio.path))
    }

    @MainActor
    func testDeleteRemovesAWaitingNoteButNotTheOneBeingTranscribed() throws {
        let storage = try temporaryStorage()
        try VoiceNoteInbox.drop(copying: try sourceAudio(), format: .ogg, durationSeconds: nil, storage: storage)
        try VoiceNoteInbox.drop(copying: try sourceAudio(), format: .ogg, durationSeconds: nil, storage: storage)
        let store = VoiceNoteQueueStore(storage: storage)
        let notes = store.ingestInbox()
        let busy = notes[0].id, idle = notes[1].id
        store.mutate { $0.update(busy) { $0.state = .transcribing(progress: 0.1) } }

        store.delete(busy)
        store.delete(idle)
        XCTAssertNotNil(store.queue.note(id: busy))
        XCTAssertNil(store.queue.note(id: idle))
    }
}
