import XCTest
@testable import DictusCore

/// The 2026-10-01 rework of #620 after the first device test: Signal's MP3-in-`.mpg`
/// voice notes, no summary for very short notes, and the unread stack.
final class VoiceNoteReworkTests: XCTestCase {

    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/SharedAudio"))
    }

    // MARK: - Signal's .mpg

    /// Signal hands a received voice note over as bare MP3 frames in a `.mpg` file,
    /// which iOS types as video (`public.mpeg`). The bytes say audio.
    func testSignalMpgIsRecognisedAsMP3() throws {
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: try fixture("signal-voice.mpg")), .mp3)
    }

    /// A real `.mpg` film is an MPEG program stream: no signature Dictus accepts.
    func testARealMpgFilmIsRefusedByTheSniff() throws {
        XCTAssertNil(SharedAudioFormat.sniff(contentsOf: try fixture("film.mpg")))
    }

    /// The path the note takes for real: the extension stores it under the sniffed
    /// extension, `.mp3`, and DictusApp decodes that copy.
    func testSignalMpgDecodesOnceStoredAsMP3() async throws {
        let storage = VoiceNoteStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent("vn-\(UUID())"))
        defer { try? FileManager.default.removeItem(at: storage.root) }
        let source = try fixture("signal-voice.mpg")
        let format = try XCTUnwrap(SharedAudioFormat.sniff(contentsOf: source))
        let drop = try VoiceNoteInbox.drop(copying: source, format: format, durationSeconds: nil, storage: storage)
        let note = try XCTUnwrap(VoiceNoteInbox.ingest(storage: storage).first { $0.id == drop.id })
        XCTAssertEqual(note.audioFileName?.hasSuffix(".mp3"), true)
        let samples = try await SharedAudioDecoder.decode(url: try XCTUnwrap(storage.audioURL(for: note)))
        XCTAssertEqual(Double(samples.count) / SharedAudioDecoder.sampleRate, 2.0, accuracy: 0.1)
    }

    func testVideoTrackDetection() async throws {
        let film = await SharedAudioDecoder.hasVideoTrack(try fixture("film.mp4"))
        XCTAssertTrue(film)
        let voiceMemo = await SharedAudioDecoder.hasVideoTrack(try fixture("voice-aac.m4a"))
        XCTAssertFalse(voiceMemo)
    }

    /// A real received Signal note, when `DICTUS_SIGNAL_SAMPLE` points at one. Never
    /// committed: it is someone's voice. The 2026-10-01 sample is 22 s of 32 kHz mono.
    func testARealSignalSampleWhenProvided() async throws {
        guard let path = ProcessInfo.processInfo.environment["DICTUS_SIGNAL_SAMPLE"],
              FileManager.default.isReadableFile(atPath: path) else {
            throw XCTSkip("set DICTUS_SIGNAL_SAMPLE to a received Signal .mpg to run this")
        }
        let url = URL(fileURLWithPath: path)
        XCTAssertEqual(SharedAudioFormat.sniff(contentsOf: url), .mp3)
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("signal-\(UUID()).mp3")
        try FileManager.default.copyItem(at: url, to: copy)
        defer { try? FileManager.default.removeItem(at: copy) }
        let samples = try await SharedAudioDecoder.decode(url: copy)
        XCTAssertEqual(Double(samples.count) / SharedAudioDecoder.sampleRate, 22, accuracy: 1.5)
    }

    // MARK: - Short notes

    func testShortNotesGetNoSummary() {
        XCTAssertEqual(VoiceNoteAvailability.summaryMinimumCharacters, 200)
        // The device failure: an 8-second, 132-character note.
        XCTAssertFalse(VoiceNoteAvailability.summaryRuns(onTranscriptOfLength: 132))
        XCTAssertFalse(VoiceNoteAvailability.summaryRuns(onTranscriptOfLength: 199))
        XCTAssertTrue(VoiceNoteAvailability.summaryRuns(onTranscriptOfLength: 200))
    }

    // MARK: - Unread stack

    private func note(_ seconds: TimeInterval, _ state: VoiceNoteState) -> VoiceNote {
        VoiceNote(receivedAt: Date(timeIntervalSince1970: seconds), audioFileName: nil, format: .ogg, state: state)
    }

    func testTheStackIsPendingAndUnseenNotesInTheOrderTheyWereShared() {
        let seen = note(1, .failed(.noSpeech)), unseen = note(2, .done)
        let running = note(3, .transcribing(progress: 0.3)), waiting = note(4, .waiting)
        var queue = VoiceNoteQueue(notes: [waiting, seen, running, unseen])
        queue.markOpened(seen.id)
        XCTAssertEqual(queue.stackable.map(\.id), [unseen.id, running.id, waiting.id])
    }

    func testClosingTheScreenRemovesOnlySeenFinishedNotes() {
        let seenDone = note(1, .done), unseenDone = note(2, .done), seenRunning = note(3, .transcribing(progress: 0))
        var queue = VoiceNoteQueue(notes: [seenDone, unseenDone, seenRunning])
        queue.markOpened(seenDone.id)
        queue.markOpened(seenRunning.id)
        queue.removeOpenedFinished()
        XCTAssertEqual(Set(queue.notes.map(\.id)), [unseenDone.id, seenRunning.id])
    }

    @MainActor
    func testHistoryTracksUnreadVoiceNotesOldestFirst() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = TranscriptionHistoryStore(fileURL: url, isEntitled: { true })
        let older = TranscriptionRecord(text: "a", language: "fr", durationSeconds: 1,
                                        createdAt: Date(timeIntervalSince1970: 10), sttProvider: "PK", source: .sharedFile)
        let newer = TranscriptionRecord(text: "b", language: "fr", durationSeconds: 1,
                                        createdAt: Date(timeIntervalSince1970: 20), sttProvider: "PK", source: .sharedFile)
        let dictation = TranscriptionRecord(text: "c", language: "fr", durationSeconds: 1, sttProvider: "PK")
        store.append(older); store.append(newer); store.append(dictation)
        XCTAssertEqual(store.unreadVoiceNotes.map(\.id), [older.id, newer.id])

        store.markOpened(id: older.id, at: Date(timeIntervalSince1970: 30))
        store.markOpened(id: older.id, at: Date(timeIntervalSince1970: 99))
        XCTAssertEqual(store.unreadVoiceNotes.map(\.id), [newer.id])
        XCTAssertEqual(store.record(id: older.id)?.openedAt, Date(timeIntervalSince1970: 30), "first opening kept")

        // Survives a new process.
        let reread = TranscriptionHistoryStore(fileURL: url, isEntitled: { true })
        XCTAssertEqual(reread.unreadVoiceNotes.map(\.id), [newer.id])
    }
}
