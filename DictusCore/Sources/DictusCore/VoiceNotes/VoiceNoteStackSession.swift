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
/// - **Closing the screen marks every note it presented as read** (maintainer
///   decision, 2026-10-01), including cards never swiped to and notes appended while
///   it was open. So "four shared, four cards" always holds; the unopened ones are
///   in History. A note still being transcribed has no result to read and stays
///   unread until its result arrives.
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

    /// The notes closing this screen marks read: every card it presented. The caller
    /// skips those still running (see the type's contract).
    public var readOnDismiss: [UUID] { cards }

    /// Oldest first, each id once. **Stable**: notes shared in the same instant keep
    /// the order they are given in, which the callers make the share order (device
    /// test of a5345688: three notes shared within one second came out newest first,
    /// because the sort was not stable and the timestamps tied).
    public static func ordered(_ entries: [Entry]) -> [UUID] {
        var seen = Set<UUID>()
        return entries.enumerated()
            .sorted { $0.element.sharedAt == $1.element.sharedAt ? $0.offset < $1.offset : $0.element.sharedAt < $1.element.sharedAt }
            .compactMap { seen.insert($0.element.id).inserted ? $0.element.id : nil }
    }
}
