// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteInbox.swift
// How a voice note crosses from the share extension to DictusApp (#620).
import Foundation

/// Where voice notes live in the App Group container.
///
/// ```
/// VoiceNotes/
///   Inbox/   <id>.<ext> + <id>.json   written by the share extension only
///   Audio/   <id>.<ext>               owned by DictusApp until transcribed
///   queue.json                        owned by DictusApp
/// ```
public struct VoiceNoteStorage: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// The App Group layout, or nil when the container is unreachable.
    public static var appGroup: VoiceNoteStorage? {
        AppGroup.containerURL.map { VoiceNoteStorage(root: $0.appendingPathComponent("VoiceNotes", isDirectory: true)) }
    }

    public var inboxDirectory: URL { root.appendingPathComponent("Inbox", isDirectory: true) }
    public var audioDirectory: URL { root.appendingPathComponent("Audio", isDirectory: true) }
    public var queueFile: URL { root.appendingPathComponent("queue.json") }

    public func audioURL(for note: VoiceNote) -> URL? {
        note.audioFileName.map { audioDirectory.appendingPathComponent($0) }
    }

    func ensureDirectories() throws {
        for directory in [inboxDirectory, audioDirectory] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}

/// What the share extension writes beside the audio: everything the app needs to
/// queue the note without opening the file.
public struct VoiceNoteDrop: Codable, Equatable, Sendable {
    public let id: UUID
    public let receivedAt: Date
    public let format: SharedAudioFormat
    public let durationSeconds: Int?

    public init(id: UUID = UUID(), receivedAt: Date = Date(), format: SharedAudioFormat, durationSeconds: Int?) {
        self.id = id
        self.receivedAt = receivedAt
        self.format = format
        self.durationSeconds = durationSeconds
    }

    var audioFileName: String { "\(id.uuidString).\(format.fileExtension)" }
    var sidecarFileName: String { "\(id.uuidString).json" }
}

/// The drop box between the two processes.
///
/// ### Why a drop box and not a shared queue file
///
/// The queue has one writer, DictusApp — the same single-writer property that lets
/// `TranscriptionHistoryStore` skip `NSFileCoordinator`. The extension never touches
/// the queue: it leaves the audio and a small sidecar in `Inbox/`, and the app moves
/// them into the queue when it next runs. Two processes, two directories, no file
/// either of them shares for writing.
///
/// ### Why the sidecar is written last
///
/// It is the commit marker. The app ingests only notes whose sidecar exists, and the
/// sidecar is written atomically after the audio copy completed, so a note the
/// extension was killed in the middle of copying is never picked up half-written.
/// The orphaned audio is swept on the next ingest.
///
/// ### How the extension knows the app is alive
///
/// It posts `voiceNoteQueued` and watches its own sidecar. A live DictusApp ingests
/// it within milliseconds and the file disappears; a suspended or dead one never
/// receives the post, and the file stays. That is #620's warm detection, and it is a
/// measurement rather than a heartbeat: `LiveActivityLiveness` describes the
/// activity, not the process, and a heartbeat is what #315 already declined to build
/// for a backgrounded app that cannot beat reliably.
public enum VoiceNoteInbox {

    /// Copy `source` into the inbox and commit it. Called by the share extension.
    /// Returns the drop, whose sidecar the extension then watches.
    @discardableResult
    public static func drop(copying source: URL, format: SharedAudioFormat, durationSeconds: Int?,
                            storage: VoiceNoteStorage, now: Date = Date()) throws -> VoiceNoteDrop {
        try storage.ensureDirectories()
        let drop = VoiceNoteDrop(receivedAt: now, format: format, durationSeconds: durationSeconds)
        let audio = storage.inboxDirectory.appendingPathComponent(drop.audioFileName)
        try FileManager.default.copyItem(at: source, to: audio)
        let data = try JSONEncoder.voiceNotes.encode(drop)
        try data.write(to: storage.inboxDirectory.appendingPathComponent(drop.sidecarFileName), options: .atomic)
        return drop
    }

    /// Whether the extension's drop is still waiting in the inbox.
    public static func isPending(_ drop: VoiceNoteDrop, storage: VoiceNoteStorage) -> Bool {
        FileManager.default.fileExists(atPath: storage.inboxDirectory.appendingPathComponent(drop.sidecarFileName).path)
    }

    /// Remove the sidecars of notes the queue now holds on disk.
    ///
    /// The sidecar is the staging marker: while it exists, the note is not safely in
    /// the queue yet, and the next ingest takes it up again. Removing it is also what
    /// tells the share extension the app took the note, so it must come after the queue
    /// write, never before — a process killed in between would otherwise lose a note
    /// the extension had reported as accepted.
    public static func acknowledge(_ notes: [VoiceNote], storage: VoiceNoteStorage) {
        for note in notes {
            try? FileManager.default.removeItem(at: storage.inboxDirectory.appendingPathComponent("\(note.id.uuidString).json"))
        }
    }

    /// Move every committed drop into `Audio/` and hand back the notes to queue. Their
    /// sidecars stay until `acknowledge`.
    /// Called by DictusApp. Audio left without a sidecar for more than an hour is a
    /// copy the extension never finished, and is deleted.
    public static func ingest(storage: VoiceNoteStorage, now: Date = Date()) -> [VoiceNote] {
        try? storage.ensureDirectories()
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: storage.inboxDirectory, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        var notes: [VoiceNote] = []
        var claimedAudio: Set<String> = []
        for sidecar in entries where sidecar.pathExtension == "json" {
            guard let data = try? Data(contentsOf: sidecar),
                  let drop = try? JSONDecoder.voiceNotes.decode(VoiceNoteDrop.self, from: data) else {
                // A sidecar that does not decode will never decode: drop it.
                try? fileManager.removeItem(at: sidecar)
                continue
            }
            let source = storage.inboxDirectory.appendingPathComponent(drop.audioFileName)
            let destination = storage.audioDirectory.appendingPathComponent(drop.audioFileName)
            claimedAudio.insert(drop.audioFileName)
            do {
                if fileManager.fileExists(atPath: source.path) {
                    if fileManager.fileExists(atPath: destination.path) { try fileManager.removeItem(at: destination) }
                    try fileManager.moveItem(at: source, to: destination)
                } else if !fileManager.fileExists(atPath: destination.path) {
                    // Neither in the inbox nor already moved: nothing to transcribe.
                    throw CocoaError(.fileNoSuchFile)
                }
                // Otherwise a previous ingest moved it and died before the queue was
                // written: the audio is staged, the note is taken up again.
            } catch {
                // No audio, nothing to transcribe. The sidecar goes too, or the note
                // would be retried forever.
                try? fileManager.removeItem(at: sidecar)
                continue
            }
            // The sidecar stays until the queue holding the note is on disk; see
            // `acknowledge`.
            notes.append(VoiceNote(id: drop.id, receivedAt: drop.receivedAt, audioFileName: drop.audioFileName,
                                   format: drop.format, durationSeconds: drop.durationSeconds))
        }

        for audio in entries where audio.pathExtension != "json" && !claimedAudio.contains(audio.lastPathComponent) {
            let modified = (try? audio.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, now.timeIntervalSince(modified) > 3600 {
                try? fileManager.removeItem(at: audio)
            }
        }
        return notes
    }
}

extension JSONEncoder {
    /// Shared by every voice note file, so writer and reader cannot drift on dates.
    ///
    /// ISO 8601 **with fractional seconds**: the share time orders the queue and the
    /// cards, and several notes shared at once fall in the same second (device test
    /// of a5345688). The history file keeps its own whole-second format; it is older
    /// than this and an older build must still read it.
    static var voiceNotes: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(VoiceNoteDates.formatter(fractional: true).string(from: date))
        }
        return encoder
    }
}

extension JSONDecoder {
    /// Reads both forms: fractional, and the whole-second one earlier builds wrote.
    static var voiceNotes: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = VoiceNoteDates.formatter(fractional: true).date(from: text)
                ?? VoiceNoteDates.formatter(fractional: false).date(from: text) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "not an ISO 8601 date: \(text)")
        }
        return decoder
    }
}

enum VoiceNoteDates {
    /// A new formatter per use: `ISO8601DateFormatter` is not `Sendable`, and these
    /// files are read and written a handful of times per note.
    static func formatter(fractional: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractional ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return formatter
    }
}
