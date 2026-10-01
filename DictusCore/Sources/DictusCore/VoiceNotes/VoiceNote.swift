// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNote.swift
// One shared voice note on its way to a transcript, and the queue they wait in (#620).
import Foundation

/// Why a voice note produced no transcript. Stored, so a string an older build does
/// not know degrades to `.transcriptionFailed` rather than failing the whole queue.
public enum VoiceNoteFailure: String, Codable, Sendable, CaseIterable {
    /// Not an audio container Dictus recognises.
    case unsupportedFormat
    /// Recognised, and still unreadable on this iPhone.
    case unreadable
    /// Over the ten-minute cap.
    case tooLong
    /// Decoded, transcribed, and nothing was said.
    case noSpeech
    /// The engine failed, or no model is installed. The only failure worth a retry,
    /// which is why it is the one that keeps the audio.
    case transcriptionFailed

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VoiceNoteFailure(rawValue: raw) ?? .transcriptionFailed
    }

    /// Whether trying again could produce a different answer. Every other failure is
    /// a property of the file, and the audio is deleted as soon as it is known.
    public var isRetryable: Bool { self == .transcriptionFailed }
}

/// Where a voice note is.
public enum VoiceNoteState: Equatable, Sendable {
    /// In the queue, not started.
    case waiting
    /// Being transcribed. `progress` is the share of chunks done, 0...1.
    case transcribing(progress: Double)
    /// Transcribed, and kept here because the history could not take it (see
    /// `VoiceNoteQueue.complete`). A note the history took leaves the queue.
    case done
    /// Gave up. See `VoiceNoteFailure`.
    case failed(VoiceNoteFailure)

    public var isFinished: Bool {
        switch self {
        case .done, .failed: return true
        case .waiting, .transcribing: return false
        }
    }
}

extension VoiceNoteState: Codable {
    private enum CodingKeys: String, CodingKey { case kind, progress, failure }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "transcribing":
            self = .transcribing(progress: try container.decodeIfPresent(Double.self, forKey: .progress) ?? 0)
        case "done":
            self = .done
        case "failed":
            self = .failed(try container.decodeIfPresent(VoiceNoteFailure.self, forKey: .failure) ?? .transcriptionFailed)
        default:
            // "waiting", and anything a later build invents: the safe reading of an
            // unknown state is "not started", which the queue will simply run.
            self = .waiting
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .waiting:
            try container.encode("waiting", forKey: .kind)
        case .transcribing(let progress):
            try container.encode("transcribing", forKey: .kind)
            try container.encode(progress, forKey: .progress)
        case .done:
            try container.encode("done", forKey: .kind)
        case .failed(let failure):
            try container.encode("failed", forKey: .kind)
            try container.encode(failure, forKey: .failure)
        }
    }
}

/// One shared voice note.
public struct VoiceNote: Identifiable, Codable, Equatable, Sendable {
    /// Also the id of the history record its transcript becomes, so the Live
    /// Activity's link and the history point at the same thing.
    public let id: UUID
    public let receivedAt: Date
    /// File name inside `VoiceNoteStorage.audioDirectory`. Nil once the audio is
    /// deleted, which happens as soon as it can no longer be useful (#620: no audio
    /// kept after transcription).
    public var audioFileName: String?
    public let format: SharedAudioFormat
    /// Length, when the container said or once decoded.
    public var durationSeconds: Int?
    public var state: VoiceNoteState
    /// The transcript, held here only for a note the history could not take.
    public var transcript: String?
    /// See `TranscriptionRecord.summary`; the same, for a note kept here.
    public var summary: String?
    public var summaryModeIdentifier: String?
    /// The transcription language code ("fr", "auto", …), for the result screen.
    public var language: String?

    public init(id: UUID = UUID(),
                receivedAt: Date = Date(),
                audioFileName: String?,
                format: SharedAudioFormat,
                durationSeconds: Int? = nil,
                state: VoiceNoteState = .waiting) {
        self.id = id
        self.receivedAt = receivedAt
        self.audioFileName = audioFileName
        self.format = format
        self.durationSeconds = durationSeconds
        self.state = state
    }

    /// `1m 05s`, the history card's format.
    public var durationLabel: String? {
        guard let seconds = durationSeconds else { return nil }
        guard seconds >= 60 else { return "\(max(0, seconds))s" }
        return String(format: "%dm %02ds", seconds / 60, seconds % 60)
    }
}

/// The queue's rules, as a value. `VoiceNoteQueueStore` persists it; nothing here
/// touches a file, so every rule is tested on the Mac.
///
/// ### One at a time, oldest first (#620 decision 6)
///
/// Two transcriptions at once would share one engine and one Neural Engine, which is
/// #144 and the reason `EngineAccessGate` exists. So the queue hands out one note at
/// a time, in the order they were shared.
public struct VoiceNoteQueue: Equatable, Sendable {

    /// Newest first, the order the list shows.
    public private(set) var notes: [VoiceNote]

    /// How many finished notes the queue keeps: done notes the history could not
    /// take, and failures the user has not dismissed. Oldest go first.
    public static let maxFinished = 20

    public init(notes: [VoiceNote] = []) {
        self.notes = notes.sorted { $0.receivedAt > $1.receivedAt }
    }

    public func note(id: UUID) -> VoiceNote? {
        notes.first { $0.id == id }
    }

    /// The note to transcribe next: the oldest waiting one.
    public var next: VoiceNote? {
        notes.last { $0.state == .waiting }
    }

    /// The note being transcribed, if any.
    public var inProgress: VoiceNote? {
        notes.first { if case .transcribing = $0.state { return true } else { return false } }
    }

    public var waitingCount: Int { notes.filter { $0.state == .waiting }.count }

    /// Whether anything is left to transcribe.
    public var hasPendingWork: Bool { notes.contains { !$0.state.isFinished } }

    /// Add notes the share extension dropped. A note already queued (the same id
    /// ingested twice after a crash between the two steps of `VoiceNoteInbox.ingest`)
    /// is ignored.
    public mutating func add(_ newNotes: [VoiceNote]) {
        let known = Set(notes.map(\.id))
        notes.append(contentsOf: newNotes.filter { !known.contains($0.id) })
        notes.sort { $0.receivedAt > $1.receivedAt }
    }

    public mutating func update(_ id: UUID, _ change: (inout VoiceNote) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        change(&notes[index])
    }

    public mutating func remove(_ id: UUID) {
        notes.removeAll { $0.id == id }
    }

    /// A process that died mid-note left it `.transcribing`. Nothing is transcribing
    /// it any more, so it goes back to the queue — its audio is still there, since
    /// audio is deleted only after a transcript exists.
    public mutating func recoverInterrupted() {
        for index in notes.indices {
            if case .transcribing = notes[index].state { notes[index].state = .waiting }
        }
    }

    /// Record a finished transcription.
    ///
    /// - Parameter savedToHistory: whether the history took it. When it did, the
    ///   note leaves the queue: the history is where results live (#620 decision 7),
    ///   and two copies of the text would mean deleting one leaves the other. When it
    ///   did not — History switched off — the note stays here, done, so the result
    ///   is never lost to a setting about something else.
    public mutating func complete(_ id: UUID, transcript: String, language: String, savedToHistory: Bool) {
        if savedToHistory {
            remove(id)
            return
        }
        update(id) {
            $0.state = .done
            $0.transcript = transcript
            $0.language = language
            $0.audioFileName = nil
        }
        trimFinished()
    }

    public mutating func fail(_ id: UUID, _ failure: VoiceNoteFailure) {
        update(id) {
            $0.state = .failed(failure)
            if !failure.isRetryable { $0.audioFileName = nil }
        }
        trimFinished()
    }

    /// Put a retryable failure back in the queue.
    public mutating func retry(_ id: UUID) {
        update(id) {
            guard case .failed(let failure) = $0.state, failure.isRetryable, $0.audioFileName != nil else { return }
            $0.state = .waiting
        }
    }

    /// Drop the oldest finished notes past `maxFinished`. Pending ones are never
    /// dropped: they are work the user asked for.
    mutating func trimFinished() {
        // `notes` is newest first, so the first `maxFinished` finished ones are kept.
        let dropped = Set(notes.filter(\.state.isFinished).dropFirst(Self.maxFinished).map(\.id))
        guard !dropped.isEmpty else { return }
        notes.removeAll { dropped.contains($0.id) }
    }

    /// The status line for the Live Activity and the list header: "1 in progress,
    /// 2 waiting" (#620 decision 6), as counts — the app words them.
    public var activityCounts: (inProgress: Int, waiting: Int) {
        (inProgress == nil ? 0 : 1, waitingCount)
    }
}
