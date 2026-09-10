// DictusCore/Sources/DictusCore/Vocabulary/VocabularyStore.swift
// The user's vocabulary: one JSON file in the App Group (#80 decision 10).
import Foundation
import SwiftUI

/// Every term the user taught Dictus, newest first.
///
/// ### Why a file and not App Group `UserDefaults` (#80 decision 10)
///
/// #428 is the reason, and it is worth stating in full because the alternative looks
/// cheaper: `dictus.modelLoadState = "loading"` stuck in shared `UserDefaults` locked
/// the whole app six launches running, and reinstalling did not clear it — the App
/// Group container survives a reinstall, measured on 2026-08-26 across six
/// reinstalls and a TestFlight build. A corrupted vocabulary would survive exactly
/// the same way, and a user with no way out. A file is inspectable, removable in one
/// action, and **Reset vocabulary** is that action.
///
/// The shape is `TranscriptionHistoryStore`'s, deliberately: same container, same
/// load-once/write-whole discipline, same atomic write, same injectable URL for
/// tests. Two files with the same lifecycle should not have two implementations.
///
/// ### Single writer
///
/// Every mutation below runs in DictusApp, which is the only process with a
/// vocabulary screen. The keyboard extension **reads** — the replacement pass runs
/// wherever the dictation lands — and never writes, which is what lets this file
/// skip `NSFileCoordinator`, exactly as the history does. A second writer arriving
/// later has to revisit this paragraph, not just add a call.
///
/// ### The entitlement gates growth, never removal
///
/// `add` refuses without the Pro entitlement, on the model of
/// `TranscriptionHistoryStore.append`. `delete`, `update` and `resetAll` are
/// ungated: a lapsed subscription must not imprison data the user can no longer see.
@MainActor
public final class VocabularyStore: ObservableObject {

    /// The app-wide store. A singleton for the reason `TranscriptionHistoryStore` is
    /// one: the in-memory copy IS the truth, so two instances would silently
    /// overwrite each other's writes.
    public static let shared = VocabularyStore()

    /// Newest first, the order the list renders directly.
    @Published public private(set) var entries: [VocabularyEntry]

    /// Maximum number of entries (#80 decision 10).
    ///
    /// WHY a refusal and not an eviction, which is what the history does: a
    /// transcription that falls off the end of a log is a record the user is not
    /// looking for, but a vocabulary term that vanished would stop correcting text
    /// with nothing on screen to say why. The 201st add is refused and the sheet
    /// says so.
    public static let maxEntries = 200

    /// `nonisolated` so `defaultFileURL`, which is itself nonisolated because it is
    /// the default argument of `init`, can name it.
    nonisolated static let fileName = "vocabulary.json"

    /// Where the entries live, or nil when the App Group container is unreachable —
    /// which on device means the entitlement is broken and nothing else works either.
    ///
    /// `nonisolated` so it can be the default argument of `init`, which runs before
    /// the instance exists and therefore outside the actor.
    nonisolated public static var defaultFileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName)
    }

    private let fileURL: URL?

    /// The Pro gate, read at each call rather than captured once: an entitlement can
    /// lapse while the process lives.
    private let isEntitled: () -> Bool

    /// - Parameters:
    ///   - fileURL: the backing file. Defaults to the App Group container; the tests
    ///     pass a temporary path so they exercise the real read/write path without a
    ///     shared container.
    ///   - isEntitled: injected so the tests can drive both directions. Nobody can be
    ///     a subscriber on a device until #279 opens the paywall, so a gate reachable
    ///     only through `FeatureGate` would be a gate only one half of which anyone
    ///     could exercise.
    init(fileURL: URL? = VocabularyStore.defaultFileURL,
         isEntitled: @escaping () -> Bool = { VocabularyAvailability.isEntitled }) {
        self.fileURL = fileURL
        self.isEntitled = isEntitled
        self.entries = Self.read(from: fileURL)
    }

    // MARK: - Reading

    public var count: Int { entries.count }

    public var isEmpty: Bool { entries.isEmpty }

    public var isFull: Bool { entries.count >= Self.maxEntries }

    // MARK: - Writing

    /// Store a term, or refuse.
    ///
    /// Refused without the entitlement, at the cap, and when the term duplicates one
    /// already stored — two entries claiming the same canonical spelling would make
    /// the list unreadable and buy nothing the variants of one entry do not.
    @discardableResult
    public func add(_ entry: VocabularyEntry) -> Bool {
        guard isEntitled(), !isFull else { return false }
        guard !contains(term: entry.term) else { return false }
        var candidate = entries
        candidate.insert(entry, at: 0)
        return commit(candidate)
    }

    /// Whether a canonical spelling is already stored, ignoring case.
    /// `excluding` skips one entry, so the edit sheet does not collide with itself.
    public func contains(term: String, excluding id: UUID? = nil) -> Bool {
        let needle = term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries.contains { $0.id != id && $0.term.lowercased() == needle }
    }

    /// Replace an entry in place, keeping its position and its `dateAdded`.
    /// Ungated: it cannot grow the file.
    @discardableResult
    public func update(_ entry: VocabularyEntry) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        guard entries[index] != entry else { return true }
        var candidate = entries
        candidate[index] = entry
        return commit(candidate)
    }

    @discardableResult
    public func delete(id: UUID) -> Bool {
        let remaining = entries.filter { $0.id != id }
        guard remaining.count != entries.count else { return false }
        return commit(remaining)
    }

    /// Delete by row offsets, for `List`'s own swipe-to-delete.
    @discardableResult
    public func delete(atOffsets offsets: IndexSet) -> Bool {
        guard !offsets.isEmpty else { return false }
        var candidate = entries
        candidate.remove(atOffsets: offsets)
        return commit(candidate)
    }

    /// **Reset vocabulary** (#80 decision 10), on the model of #287's "Reset learned
    /// words": the one action that empties the list, and the exit from a file that
    /// would otherwise survive a reinstall.
    @discardableResult
    public func resetAll() -> Bool {
        guard !entries.isEmpty else { return true }
        return commit([])
    }

    /// Re-read the file. The app's own screen is the only writer, so this exists for
    /// the same reason `UserDictionary.reload()` does: a settings screen opened after
    /// something else touched the container should not show a stale list.
    public func reload() {
        entries = Self.read(from: fileURL)
    }

    // MARK: - Disk

    /// Write first, publish second. **Every mutation goes through here**, and that
    /// ordering is the whole point of the method.
    ///
    /// `write` used to be a `try?` whose failure nobody read, with the in-memory list
    /// already mutated by the time it ran: an unreachable App Group container or a
    /// full disk produced a screen showing entries that would be gone at the next
    /// launch, and an `add` that returned `true` while storing nothing. A store whose
    /// memory and disk can disagree is a store that lies, and this one is read by a
    /// second process — so the disagreement would not even be visible to the process
    /// that caused it.
    ///
    /// Applying it to removal as well as to growth is deliberate. A delete that
    /// vanished from the list and stayed on disk would come back at the next launch,
    /// which for **Reset vocabulary** — the only exit from a file that survives a
    /// reinstall — is the failure that matters most.
    ///
    /// Returns whether the write succeeded, and publishes nothing when it did not.
    private func commit(_ candidate: [VocabularyEntry]) -> Bool {
        guard Self.write(candidate, to: fileURL) else {
            PersistentLog.log(.diagnosticProbe(
                component: "VocabularyStore",
                instanceID: "commit",
                action: "writeFailed",
                details: "entries=\(candidate.count) hasURL=\(fileURL != nil ? "yes" : "no")"
            ))
            return false
        }
        entries = candidate
        return true
    }

    /// The cross-process read. `nonisolated` and static because its caller is the
    /// replacement pass, which is not on the main actor and which runs inside the
    /// keyboard extension as well as in the app.
    nonisolated public static func loadEntries(
        from url: URL? = VocabularyStore.defaultFileURL
    ) -> [VocabularyEntry] {
        read(from: url)
    }

    nonisolated static func read(from url: URL?) -> [VocabularyEntry] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        // A file that will not decode is treated as an empty vocabulary rather than
        // as a fatal error, and an entry that violates the limits is dropped rather
        // than trusted: this file is hand-editable by anyone with the container, and
        // an over-long needle would cost a full scan of every transcript.
        let decoded = (try? decoder.decode([VocabularyEntry].self, from: data)) ?? []
        return decoded.filter { $0.isValid }
    }

    /// Returns whether the file now holds `entries`. The caller publishes only then.
    @discardableResult
    nonisolated static func write(_ entries: [VocabularyEntry], to url: URL?) -> Bool {
        guard let url, let data = try? encoder.encode(entries) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Shared so the writer and the reader cannot drift on the date strategy, which
    /// is the one disagreement that would silently drop every entry.
    nonisolated static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }

    nonisolated static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
