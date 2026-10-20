// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteIsland.swift
// The rules of the voice note island, as values (#620, design grilled 2026-10-01).
import Foundation

/// The notes the ring shows, and what each one is.
///
/// ### The current set
///
/// A note joins when it is shared and leaves when its outcome is read — a result
/// opened on its card, or a failure seen there. A note still running never leaves:
/// there is nothing to read yet. The set also empties when the ready state times out
/// (`readyLifetime`): the notes are still unread in the stack and in History, but the
/// island has said what it had to say.
///
/// ### Batches
///
/// A batch starts when a note joins a set with nothing pending, and ends when the
/// last pending note finishes (the queue drains). The success alert is per batch —
/// never per note, never on a replay — so the batch number is what an alert is
/// remembered against. See `VoiceNoteAlertPolicy`.
public struct VoiceNoteIsland: Equatable, Sendable {

    public struct Entry: Equatable, Sendable {
        public let id: UUID
        public var segment: VoiceNoteSegment
    }

    /// In share order.
    public private(set) var entries: [Entry] = []

    /// Increments each time a note starts a batch.
    public private(set) var batch = 0

    /// Whether the batch that last drained produced at least one result.
    public private(set) var batchSucceeded = false

    /// How long the ready state stays on the island before it goes (decision 4).
    public static let readyLifetime: TimeInterval = 5 * 60

    /// A note slower than this shows "Voice note received" (decision 7). A faster one
    /// gives a single moment: the haptic at share, then the ring and the alert.
    public static let receivedDelay: TimeInterval = 3

    public init() {}

    public var segments: [VoiceNoteSegment] { entries.map(\.segment) }
    public var isEmpty: Bool { entries.isEmpty }
    public var hasPending: Bool { entries.contains { $0.segment == .pending } }
    public var readyCount: Int { entries.filter { $0.segment == .ready }.count }
    public var failedCount: Int { entries.filter { $0.segment == .failed }.count }

    public func contains(_ id: UUID) -> Bool { entries.contains { $0.id == id } }

    /// A note was shared.
    public mutating func add(_ id: UUID) {
        guard !contains(id) else { return }
        if !hasPending {
            batch += 1
            batchSucceeded = false
        }
        entries.append(Entry(id: id, segment: .pending))
    }

    /// A note finished. Returns true when this drained the batch.
    @discardableResult
    public mutating func finish(_ id: UUID, succeeded: Bool) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return false }
        entries[index].segment = succeeded ? .ready : .failed
        if succeeded { batchSucceeded = true }
        return !hasPending
    }

    /// The user read a note's outcome. A pending note stays: nothing was read.
    public mutating func markRead(_ id: UUID) {
        entries.removeAll { $0.id == id && $0.segment != .pending }
    }

    /// The ready state timed out: finished notes leave, pending ones stay.
    public mutating func expireFinished() {
        entries.removeAll { $0.segment != .pending }
    }
}

/// When the island alerts (decisions 3 and 5).
public enum VoiceNoteAlertPolicy {

    public enum Decision: Equatable, Sendable {
        /// No alert.
        case none
        /// Alert with this update.
        case now
        /// Alert when the running dictation hands the island back.
        case afterDictation
    }

    /// - Parameters:
    ///   - drained: the last pending note of the batch just finished.
    ///   - batchSucceeded: at least one note of the batch has a result. A batch of
    ///     failures only turns segments red; it does not expand the island.
    ///   - alreadyAlerted: this batch has had its alert. A replay of the same
    ///     content (a refresh, a read, a reconnect) must not alert again.
    ///   - dictationActive: a dictation owns the island (decision 1).
    public static func decide(drained: Bool, batchSucceeded: Bool,
                              alreadyAlerted: Bool, dictationActive: Bool) -> Decision {
        guard drained, batchSucceeded, !alreadyAlerted else { return .none }
        return dictationActive ? .afterDictation : .now
    }
}

/// Who draws the island for a given dictation phase and voice note content.
///
/// **The rule that keeps dictation exactly as it was**: with no voice note on the
/// island, every phase renders as before #620. With one:
///
/// - a dictation in progress (recording, transcribing, processing) owns the island,
///   and so does a dictation failure — voice notes continue behind it (decision 1);
/// - the dictation's brief success flash (`ready`) gives way to a voice note
///   **failure**, the one exception decision 1 names; a voice note success waits;
/// - standby belongs to the voice notes.
public enum LiveActivityRenderOwner: Equatable, Sendable {
    case dictation
    case voiceNotes

    public static func resolve(phase: LiveActivityStateMachine.Phase,
                               voiceNote: VoiceNoteActivityContent?) -> LiveActivityRenderOwner {
        guard let voiceNote, !voiceNote.isEmpty else { return .dictation }
        switch phase {
        case .standby:
            return .voiceNotes
        case .ready:
            return voiceNote.failedCount > 0 ? .voiceNotes : .dictation
        case .idle, .recording, .transcribing, .processing, .failed:
            return .dictation
        }
    }
}

/// The warm engine's idle window, from one place (#620 decision 4).
///
/// The engine releases itself after this long without a dictation, which ends the
/// standby pill. Read here, and only here, so #380 — a user setting for this timeout
/// (immediately, 1 to 5 minutes, 1 to 2 hours, indefinitely) — plugs in without
/// touching the voice note island, whose ready state has its own 5-minute lifetime
/// (`VoiceNoteIsland.readyLifetime`) precisely so the two never depend on each other.
public enum WarmEngineTimeout {
    /// 10 minutes, the value #106 Phase B shipped.
    public static var interval: TimeInterval { 10 * 60 }
}
