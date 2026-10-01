// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteQueueStore.swift
// The voice note queue on disk: one JSON file, DictusApp its only writer (#620).
import Foundation
import Combine

/// The persisted queue.
///
/// Same shape as `TranscriptionHistoryStore`, for the same reasons: one small JSON
/// file, read once, rewritten whole and atomically on every change, by one process.
/// The share extension never writes it — see `VoiceNoteInbox`.
///
/// ### The queue survives the process
///
/// A note shared while DictusApp was suspended waits in the inbox; a note being
/// transcribed when iOS killed the app is `.transcribing` on disk. Both are picked
/// up the next time the app runs (`ingestInbox`, `VoiceNoteQueue.recoverInterrupted`),
/// which is #620's cold path: the queue starts when Dictus opens.
@MainActor
public final class VoiceNoteQueueStore: ObservableObject {

    public static let shared = VoiceNoteQueueStore(storage: VoiceNoteStorage.appGroup)

    @Published public private(set) var queue: VoiceNoteQueue

    public let storage: VoiceNoteStorage?

    public init(storage: VoiceNoteStorage?) {
        self.storage = storage
        var loaded = Self.read(from: storage?.queueFile)
        loaded.recoverInterrupted()
        self.queue = loaded
    }

    /// Move whatever the share extension dropped into the queue. Returns the notes
    /// that were added, so the caller can tell a new arrival from a quiet launch.
    @discardableResult
    public func ingestInbox(now: Date = Date()) -> [VoiceNote] {
        guard let storage else { return [] }
        let arrived = VoiceNoteInbox.ingest(storage: storage, now: now)
        guard !arrived.isEmpty else { return [] }
        queue.add(arrived)
        persist()
        return arrived
    }

    /// Change the queue and write it.
    public func mutate(_ change: (inout VoiceNoteQueue) -> Void) {
        change(&queue)
        persist()
        sweepUnreferencedAudio()
    }

    /// Delete a note and its audio, whatever its state — except the one being
    /// transcribed, which the processor owns until it hands it back.
    public func delete(_ id: UUID) {
        guard queue.note(id: id).map({ note in
            if case .transcribing = note.state { return false } else { return true }
        }) ?? false else { return }
        mutate { $0.remove(id) }
    }

    /// The decoded-audio file a note points at.
    public func audioURL(for note: VoiceNote) -> URL? {
        storage?.audioURL(for: note)
    }

    // MARK: - Disk

    private func persist() {
        guard let url = storage?.queueFile,
              let data = try? JSONEncoder.voiceNotes.encode(queue.notes) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func read(from url: URL?) -> VoiceNoteQueue {
        guard let url, let data = try? Data(contentsOf: url),
              let notes = try? JSONDecoder.voiceNotes.decode([VoiceNote].self, from: data) else {
            return VoiceNoteQueue()
        }
        return VoiceNoteQueue(notes: notes)
    }

    /// Audio no note points at any more: a note deleted, trimmed, or finished. The
    /// one rule that keeps "no audio kept after transcription" true whichever path
    /// removed the reference.
    func sweepUnreferencedAudio() {
        guard let directory = storage?.audioDirectory,
              let files = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
        let referenced = Set(queue.notes.compactMap(\.audioFileName))
        for file in files where !referenced.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }
}
