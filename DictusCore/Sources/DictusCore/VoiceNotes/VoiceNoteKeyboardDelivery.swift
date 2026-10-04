// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteKeyboardDelivery.swift
// How a finished voice note transcript reaches the keyboard, how the keyboard says it was used,
// and how long it stays there (#637, #639).
import Foundation

/// One finished voice note transcript, offered to the keyboard.
///
/// ### Why a copy of the transcript, and not a pointer into History
///
/// `TranscriptionHistoryStore` and `VoiceNoteQueueStore` load their file once and
/// treat that copy as the truth for the life of a process. A keyboard that
/// instantiated either before the app finished a note would hold a stale snapshot,
/// and a keyboard that wrote either would race DictusApp, their only writer. So the
/// app publishes a small envelope the keyboard rereads from disk every time it asks
/// (#637, Option A), and the stores stay single-writer.
///
/// It is an envelope, not a second History: it leaves the keyboard `idleWindow` after
/// its last use, when the user deletes it from the keyboard's reader, or when the
/// note is deleted in DictusApp (#639).
public struct VoiceNoteKeyboardDelivery: Codable, Identifiable, Equatable, Sendable {
    /// The voice note's id, which is also its History record's id.
    public let id: UUID
    public let transcript: String
    /// When the note was shared. Orders the reader's pages: oldest first, the order
    /// the user shared them in.
    public let sharedAt: Date
    /// When the transcript was produced. Starts the `idleWindow` clock for a note the
    /// keyboard has never used.
    public let transcribedAt: Date
    /// The transcription language code ("fr", "auto", …), for the reader's header.
    public let language: String?
    public let durationSeconds: Int?

    public init(id: UUID, transcript: String, sharedAt: Date, transcribedAt: Date,
                language: String?, durationSeconds: Int?) {
        self.id = id
        self.transcript = transcript
        self.sharedAt = sharedAt
        self.transcribedAt = transcribedAt
        self.language = language
        self.durationSeconds = durationSeconds
    }

    /// How long the keyboard keeps a transcript after its **last use**: 15 minutes
    /// (#639, replacing #637's 24 h from the transcription).
    ///
    /// A use is the reader showing the note, an insertion, or a quoted passage (#640),
    /// and each one restarts the countdown. A note never opened gets its 15 minutes
    /// from the transcription. Time and nothing else takes a note out of the keyboard
    /// — inserting it no longer does, so a long note can be quoted in several passes —
    /// and the window stays short because the text is somebody's conversation: a
    /// keyboard that surfaces it much later in an unrelated field is the leak this
    /// envelope must not become. History on or off; DictusApp keeps its own copy by
    /// its own rules.
    public static let idleWindow: TimeInterval = 15 * 60

    /// When the keyboard stops offering this note, given its last use (nil: never
    /// used). A use dated before the transcription, a clock change, counts as none.
    public func expiresAt(lastUsedAt: Date?) -> Date {
        max(transcribedAt, lastUsedAt ?? transcribedAt).addingTimeInterval(Self.idleWindow)
    }

    public func isExpired(at now: Date, lastUsedAt: Date?) -> Bool {
        now >= expiresAt(lastUsedAt: lastUsedAt)
    }

    /// `1:42`, the reader header's form (#637 visual direction). Nil when unknown.
    public var durationLabel: String? {
        guard let durationSeconds else { return nil }
        let seconds = max(0, durationSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// `FR`, or nil for auto-detection and an unknown language: "AUTO" says nothing
    /// about the text in front of the user.
    public var languageBadge: String? {
        guard let language, !language.isEmpty, language != "auto" else { return nil }
        return language.uppercased()
    }
}

/// What the keyboard did with a delivery. Every one means the note was read: the
/// app marks it so — History or queue, and the island's segment — on its next
/// foreground. Since #639 a receipt no longer hides the note from the keyboard; only
/// time or the reader's Delete does.
///
/// #637 decision 6 said viewing was not reading, and only `Insert` left a receipt.
/// Pierre reversed it on 2026-10-03 (#639, decision A): a note **shown** in the reader
/// is read, so the unread cards in DictusApp are exactly what the user has seen
/// nowhere.
public enum VoiceNoteKeyboardAction: String, Codable, Sendable {
    /// The reader put the note on screen (#639 decision A).
    case shown
    case inserted
    /// Written only by the build that still had a `Copy` button (rev cd2d96b4, removed
    /// after device feedback on PR #638). Kept so a receipt that build left on a device
    /// still decodes and still reaches the app as "read".
    case copied
}

/// The last time the keyboard used a delivery (#639): shown it in the reader, inserted
/// it, or quoted from it. What restarts the note's `idleWindow`.
public struct VoiceNoteKeyboardUse: Codable, Equatable, Sendable {
    public let id: UUID
    public let at: Date

    public init(id: UUID, at: Date) {
        self.id = id
        self.at = at
    }
}

/// The keyboard's receipt for one delivery.
public struct VoiceNoteKeyboardAcknowledgement: Codable, Equatable, Sendable {
    public let id: UUID
    public let action: VoiceNoteKeyboardAction
    public let at: Date

    public init(id: UUID, action: VoiceNoteKeyboardAction, at: Date) {
        self.id = id
        self.action = action
        self.at = at
    }
}

/// The delivery directories in the App Group, and every operation on them.
///
/// ```
/// VoiceNotes/KeyboardDelivery/
///   Deliveries/<id>.json        written and deleted by DictusApp only
///   Acknowledgements/<id>.json  written by the keyboard, deleted by DictusApp
///   Presented/<id>              written by the keyboard, deleted by DictusApp
///   Uses/<id>.json              written by the keyboard, deleted by DictusApp
///   Deleted/<id>                written by the keyboard, deleted by DictusApp
/// ```
///
/// ### Who writes what
///
/// One file per note and one writer per file, which is the whole of the
/// concurrency story: there is no shared array for two processes to rewrite, so
/// nothing to coordinate. DictusApp publishes and withdraws deliveries; the
/// keyboard never touches a delivery, it drops files beside it. A receipt — a note
/// shown or inserted — is what DictusApp turns into "read" when it next comes to the
/// foreground (#639 decision A) — the keyboard
/// does not mutate either store. A use is what keeps the note in
/// the keyboard 15 more minutes (#639). A deletion marker is what takes it out of
/// the keyboard at once when the user deletes it from the reader (#639): the
/// keyboard cannot delete the delivery, which is DictusApp's file, so it marks it
/// and DictusApp withdraws it on its next run.
///
/// A value with no cache: every read goes to the disk, because the reader is a
/// process that can be suspended for hours and resumed after the app wrote.
public struct VoiceNoteKeyboardDeliveryStore: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    /// The App Group layout, or nil when the container is unreachable — which is
    /// the keyboard without Full Access.
    public static var appGroup: VoiceNoteKeyboardDeliveryStore? {
        VoiceNoteStorage.appGroup.map {
            VoiceNoteKeyboardDeliveryStore(root: $0.root.appendingPathComponent("KeyboardDelivery", isDirectory: true))
        }
    }

    var deliveriesDirectory: URL { root.appendingPathComponent("Deliveries", isDirectory: true) }
    var acknowledgementsDirectory: URL { root.appendingPathComponent("Acknowledgements", isDirectory: true) }
    var presentedDirectory: URL { root.appendingPathComponent("Presented", isDirectory: true) }
    var usesDirectory: URL { root.appendingPathComponent("Uses", isDirectory: true) }
    var deletedDirectory: URL { root.appendingPathComponent("Deleted", isDirectory: true) }

    private func deliveryFile(_ id: UUID) -> URL {
        deliveriesDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func acknowledgementFile(_ id: UUID) -> URL {
        acknowledgementsDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func presentedFile(_ id: UUID) -> URL {
        presentedDirectory.appendingPathComponent(id.uuidString)
    }

    private func useFile(_ id: UUID) -> URL {
        usesDirectory.appendingPathComponent("\(id.uuidString).json")
    }

    private func deletedFile(_ id: UUID) -> URL {
        deletedDirectory.appendingPathComponent(id.uuidString)
    }

    // MARK: - DictusApp

    /// Offer a finished transcript to the keyboard. Atomic: the keyboard sees the
    /// whole file or none of it. Called after the transcript is durable in History
    /// or the queue, and before `voiceNoteResultReady` is posted — persist first,
    /// signal second.
    public func publish(_ delivery: VoiceNoteKeyboardDelivery) throws {
        try FileManager.default.createDirectory(at: deliveriesDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.voiceNotes.encode(delivery)
        try data.write(to: deliveryFile(delivery.id), options: .atomic)
    }

    /// Take a note out of the keyboard, with everything the keyboard wrote beside it.
    /// Idempotent. Since #639 three things call for it: the note's `idleWindow`
    /// running out, the user deleting the note in DictusApp, and DictusApp cleaning
    /// up after a deletion from the keyboard (`deletedIDs`).
    public func withdraw(_ id: UUID) {
        for url in [deliveryFile(id), acknowledgementFile(id), presentedFile(id), useFile(id), deletedFile(id)] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Drop a receipt the app has turned into "read". The delivery stays: reading a
    /// note does not take it out of the keyboard (#639).
    public func clearAcknowledgement(_ id: UUID) {
        try? FileManager.default.removeItem(at: acknowledgementFile(id))
    }

    /// Every delivery on disk, expired or acknowledged ones included, oldest share
    /// first. The app's view; the keyboard reads `pending(at:)`.
    public func allDeliveries() -> [VoiceNoteKeyboardDelivery] {
        Self.ordered(files(in: deliveriesDirectory).compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder.voiceNotes.decode(VoiceNoteKeyboardDelivery.self, from: data)
        })
    }

    /// The keyboard's receipts, for DictusApp to turn into "read".
    public func acknowledgements() -> [VoiceNoteKeyboardAcknowledgement] {
        files(in: acknowledgementsDirectory).compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder.voiceNotes.decode(VoiceNoteKeyboardAcknowledgement.self, from: data)
        }
    }

    /// Delete every delivery past its `idleWindow`. Returns the ids withdrawn.
    ///
    /// Run by DictusApp, the files' writer. The keyboard needs no part in it: it
    /// filters expired deliveries out on read, so an expired transcript is never
    /// *shown* whether or not the app has run since.
    @discardableResult
    public func pruneExpired(now: Date = Date()) -> [UUID] {
        let uses = lastUsedDates()
        let expired = allDeliveries().filter { $0.isExpired(at: now, lastUsedAt: uses[$0.id]) }.map(\.id)
        expired.forEach(withdraw)
        return expired
    }

    // MARK: - Keyboard

    /// What the keyboard may offer right now: every delivery inside its `idleWindow`
    /// that the user has not deleted from the keyboard, oldest share first. Inserted
    /// ones included (#639): a receipt says "read", and a note read once can still be
    /// quoted from.
    public func pending(at now: Date = Date()) -> [VoiceNoteKeyboardDelivery] {
        let uses = lastUsedDates()
        let deleted = deletedIDs()
        return allDeliveries().filter { !deleted.contains($0.id) && !$0.isExpired(at: now, lastUsedAt: uses[$0.id]) }
    }

    /// The user deleted a note from the keyboard's reader (#639): it leaves the
    /// keyboard at once, and only the keyboard. DictusApp keeps the note itself by its
    /// own History and queue rules; it only withdraws the delivery on its next run.
    /// An empty marker file: existence is the fact. Idempotent. Returns whether the
    /// marker is on disk.
    @discardableResult
    public func deleteFromKeyboard(_ id: UUID) -> Bool {
        if FileManager.default.fileExists(atPath: deletedFile(id).path) { return true }
        do {
            try FileManager.default.createDirectory(at: deletedDirectory, withIntermediateDirectories: true)
            return FileManager.default.createFile(atPath: deletedFile(id).path, contents: Data())
        } catch {
            return false
        }
    }

    /// The notes the user deleted from the keyboard and DictusApp has not withdrawn yet.
    public func deletedIDs() -> Set<UUID> {
        Set(files(in: deletedDirectory).compactMap { UUID(uuidString: $0.lastPathComponent) })
    }

    /// When the earliest of these deliveries leaves the keyboard, or nil for none. The
    /// keyboard rereads then, so the ☰ halo does not outlive the last note.
    public func nextExpiry(of deliveries: [VoiceNoteKeyboardDelivery]) -> Date? {
        let uses = lastUsedDates()
        return deliveries.map { $0.expiresAt(lastUsedAt: uses[$0.id]) }.min()
    }

    /// Record a use of a note — shown in the reader, inserted, quoted — and so restart
    /// its 15 minutes (#639). Atomic, and overwrites the previous use: only the last
    /// one counts, and the keyboard is this file's only writer. A use never moves the
    /// clock back. Returns whether the file is on disk.
    @discardableResult
    public func noteUsed(_ id: UUID, at date: Date = Date()) -> Bool {
        if let previous = lastUsedDates()[id], previous >= date { return true }
        do {
            try FileManager.default.createDirectory(at: usesDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder.voiceNotes.encode(VoiceNoteKeyboardUse(id: id, at: date))
            try data.write(to: useFile(id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// The last use of every note the keyboard has used.
    public func lastUsedDates() -> [UUID: Date] {
        var dates: [UUID: Date] = [:]
        for url in files(in: usesDirectory) {
            guard let data = try? Data(contentsOf: url),
                  let use = try? JSONDecoder.voiceNotes.decode(VoiceNoteKeyboardUse.self, from: data) else { continue }
            dates[use.id] = use.at
        }
        return dates
    }

    /// Record that the user saw or inserted a note. Atomic, and overwrites a previous
    /// receipt for the same note: the keyboard is this file's only writer, and every
    /// action means the same thing to the app — read — so a later one losing an
    /// earlier one loses nothing. Returns whether the receipt is on disk.
    @discardableResult
    public func acknowledge(_ id: UUID, action: VoiceNoteKeyboardAction, at date: Date = Date()) -> Bool {
        do {
            try FileManager.default.createDirectory(at: acknowledgementsDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder.voiceNotes.encode(VoiceNoteKeyboardAcknowledgement(id: id, action: action, at: date))
            try data.write(to: acknowledgementFile(id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Record that the reader has shown these notes, so it never opens on its own
    /// for them again (#637 decision 2). Not what the ☰ halo reads: that one shows for
    /// every offered note, shown or not (#639, 2026-10-04). Empty marker
    /// files: existence is the fact.
    public func markPresented(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        try? FileManager.default.createDirectory(at: presentedDirectory, withIntermediateDirectories: true)
        for id in ids where !FileManager.default.fileExists(atPath: presentedFile(id).path) {
            FileManager.default.createFile(atPath: presentedFile(id).path, contents: Data())
        }
    }

    /// The notes the reader has already shown.
    public func presentedIDs() -> Set<UUID> {
        Set(files(in: presentedDirectory).compactMap { UUID(uuidString: $0.lastPathComponent) })
    }

    // MARK: - Helpers

    /// Oldest share first. Two notes shared in the same instant fall back to the
    /// transcription order, which is the queue's — it runs oldest first — and then
    /// to the id, so the order is total and never flickers between two reads.
    static func ordered(_ deliveries: [VoiceNoteKeyboardDelivery]) -> [VoiceNoteKeyboardDelivery] {
        deliveries.sorted {
            if $0.sharedAt != $1.sharedAt { return $0.sharedAt < $1.sharedAt }
            if $0.transcribedAt != $1.transcribedAt { return $0.transcribedAt < $1.transcribedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func files(in directory: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }
}

/// When the reader opens on its own, as a rule the keyboard follows and the tests
/// drive by hand (#637 decisions 1 to 3).
public enum VoiceNoteKeyboardPresentation {

    /// What a keyboard appearance does with the notes waiting for it.
    public enum Decision: Equatable, Sendable {
        /// Take the surface over and show the reader.
        case openReader
        /// Leave the keys. The ☰ halo says a note is waiting, and a tap on ☰
        /// opens it (#639).
        case keysOnly
    }

    /// The decision at a keyboard **appearance** — the only moment the reader opens
    /// by itself.
    ///
    /// A note that lands while the keyboard is on screen never comes through here:
    /// it rings the ☰, always (decision 1, #639). Taking the surface over under a moving
    /// thumb is how a tap meant for a key lands on `Insert` and writes a private
    /// transcript into the wrong field.
    ///
    /// At an appearance the user has just come back to the conversation and has not
    /// started typing, so the reader opens — once per note: a note the reader has
    /// already shown is reachable from a tap on ☰ only (decision 2, #639). Nothing opens over
    /// a dictation, which owns the whole area, or over a picker the user left open.
    ///
    /// - Parameter autoOpenEnabled: decision 3's Debug switch, for the device
    ///   comparison between "auto-open" and "tap on ☰ only".
    public static func onAppearance(pending: [VoiceNoteKeyboardDelivery],
                                    presentedIDs: Set<UUID>,
                                    autoOpenEnabled: Bool,
                                    dictationOwnsArea: Bool,
                                    currentMode: KeyboardAreaMode) -> Decision {
        guard autoOpenEnabled, !dictationOwnsArea, currentMode == .keys else { return .keysOnly }
        return pending.contains { !presentedIDs.contains($0.id) } ? .openReader : .keysOnly
    }

    /// Whether the ☰ wears its halo: while the keyboard offers at least one note.
    ///
    /// `pending` is the store's answer — inside its 15-minute window, not deleted from
    /// the keyboard — and nothing else counts (Pierre, 2026-10-04). The first version
    /// lit it only for a note never shown, but auto-open on appearance shows a new
    /// note at once, so that halo was almost never on screen. Shown or not, a note
    /// still in the keyboard is what the halo announces; it goes when the last one
    /// expires or is deleted.
    public static func showsMenuHalo(pending: [VoiceNoteKeyboardDelivery]) -> Bool {
        !pending.isEmpty
    }

    /// Decision 3's switch, read at each appearance. On unless a Debug build turned
    /// it off; a Release build has no switch and always opens.
    public static var autoOpenEnabled: Bool {
        #if DEBUG
        return !AppGroup.defaults.bool(forKey: SharedKeys.debugVoiceNoteAutoOpenDisabled)
        #else
        return true
        #endif
    }
}
