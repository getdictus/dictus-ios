// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteStackSession.swift
// Which cards one opening of the voice note screen shows (#620, device test of af1985e5).
import Foundation

/// The cards of one opening of the voice note screen, as a value.
///
/// ### The contract (2026-10-01)
///
/// - An opening shows exactly the notes that are unread or still running, oldest
///   first, each once.
/// - A note that becomes stackable while the screen is open is appended; nothing is
///   ever removed under the user's finger, and there is never a second opening.
/// - A note is read once its card has been on screen; read notes are never in a
///   later opening.
/// - **An opening lasts one activation.** When the app leaves the foreground the
///   screen is closed, and the next activation opens a fresh session from what is
///   unread then. The device test of af1985e5 showed why: a screen left open across
///   activations kept the cards of the earlier batch, already read, beside the new
///   ones, so its count matched neither the batch nor the island.
public struct VoiceNoteStackSession: Equatable, Sendable {

    /// One stackable note: its id and when it was shared, the order key.
    public struct Entry: Equatable, Sendable {
        public let id: UUID
        public let sharedAt: Date
        public init(id: UUID, sharedAt: Date) {
            self.id = id
            self.sharedAt = sharedAt
        }
    }

    public private(set) var cards: [UUID]

    /// - Parameters:
    ///   - stackable: unread or running notes, from every store, in any order and
    ///     possibly with the same note twice (a note moves from the queue to History).
    ///   - focus: the note a link named. When it is read already it opens alone.
    public init(stackable: [Entry], focus: UUID? = nil) {
        var ids = Self.ordered(stackable)
        if let focus, !ids.contains(focus) { ids = [focus] }
        cards = ids
    }

    /// Append notes that became stackable while the screen is open. Returns the ids
    /// that were added.
    @discardableResult
    public mutating func append(stackable: [Entry]) -> [UUID] {
        let fresh = Self.ordered(stackable).filter { !cards.contains($0) }
        cards.append(contentsOf: fresh)
        return fresh
    }

    /// Oldest first, each id once.
    public static func ordered(_ entries: [Entry]) -> [UUID] {
        var seen = Set<UUID>()
        return entries.sorted { $0.sharedAt < $1.sharedAt }.compactMap { seen.insert($0.id).inserted ? $0.id : nil }
    }
}
