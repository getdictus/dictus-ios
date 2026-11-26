// DictusCore/VoiceNotes/VoiceNoteClaim.swift
// One transcriber per shared voice note, across the app and the share extension (#1056).
import Foundation

/// Who transcribes one shared voice note: DictusApp or the share extension, decided once.
///
/// WHY it exists: the share extension transcribes a note nobody took (#1056), and the app
/// can start while it does (the user opens Dictus from the home screen). Without a single
/// owner both would transcribe it, and the note would land twice in History.
///
/// Both sides claim the note before transcribing, and the first claim wins. The claim is a
/// file named after the note in the App Group, created with `link(2)`: the kernel either
/// creates the name or fails with `EEXIST`, atomically across processes, and the content
/// (the owner) is in place before the name appears, so a loser always reads the winner. A
/// `UserDefaults` key could not do this: two processes can both read "free" and both write.
///
/// Reduced from #992's `DictationSessionClaim`: the keyboard owner and the keyboard start
/// answer are gone with the in-keyboard dictation. Added, from #992's review: a claim the
/// extension can no longer honour is recoverable. The extension releases it when it fails,
/// and touches it while it works; a claim nobody touched for `heartbeatTimeout` is
/// abandoned (the extension was killed or suspended), and the app may take it over.
public enum VoiceNoteClaim {

    public enum Owner: String, Sendable {
        case app
        case shareExtension
    }

    static let directoryName = "voice-note-claims"
    /// Claims older than this are removed by `prune`: a note is done in minutes.
    public static let maximumAge: TimeInterval = 3600
    /// A share-extension claim untouched for this long is abandoned. The extension touches
    /// its claim every second while it decodes and transcribes, so 30 s is many missed
    /// beats, and short enough that an app opened after a killed extension does not leave
    /// the note waiting.
    public static let heartbeatTimeout: TimeInterval = 30

    public static var defaultDirectory: URL? {
        AppGroup.containerURL?.appendingPathComponent(directoryName)
    }

    /// Claim `id` for `owner`. Returns the owner afterwards: `owner` when this call won,
    /// the other side when it had already claimed, nil when the claim could not be written
    /// or read at all.
    @discardableResult
    public static func claim(_ id: UUID, as owner: Owner, in directory: URL) -> Owner? {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = file(for: id, in: directory)
        let staging = directory.appendingPathComponent(".\(id.uuidString).\(owner.rawValue).\(UUID().uuidString)")
        guard fileManager.createFile(atPath: staging.path, contents: Data(owner.rawValue.utf8)) else { return nil }
        defer { try? fileManager.removeItem(at: staging) }
        if link(staging.path, target.path) == 0 { return owner }
        guard errno == EEXIST else { return nil }
        return current(id, in: directory)
    }

    /// The owner of `id`, or nil when nobody has claimed it.
    public static func current(_ id: UUID, in directory: URL) -> Owner? {
        guard let data = FileManager.default.contents(atPath: file(for: id, in: directory).path),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        return Owner(rawValue: raw)
    }

    /// Seconds since the claim was last written or touched, nil when there is none.
    public static func age(_ id: UUID, in directory: URL, now: Date = Date()) -> TimeInterval? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file(for: id, in: directory).path),
              let modified = attributes[.modificationDate] as? Date else { return nil }
        return now.timeIntervalSince(modified)
    }

    /// The owner's heartbeat: moves the claim's modification date to now.
    public static func touch(_ id: UUID, in directory: URL, now: Date = Date()) {
        try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: file(for: id, in: directory).path)
    }

    /// Give the note up, only if `owner` still holds it: the app's takeover must not be
    /// undone by a late extension, nor the reverse. Returns whether a claim was removed.
    @discardableResult
    public static func release(_ id: UUID, as owner: Owner, in directory: URL) -> Bool {
        guard current(id, in: directory) == owner else { return false }
        return (try? FileManager.default.removeItem(at: file(for: id, in: directory))) != nil
    }

    /// The app's reading of a share-extension claim on a note with no result file.
    public enum ExtensionClaimState: Equatable, Sendable {
        /// Touched recently: the extension is working on it, wait for its result.
        case inProgress
        /// Not touched for `heartbeatTimeout`: the extension is gone, take the note over.
        case abandoned
    }

    /// Pure: whether a share-extension claim of this age is still alive.
    /// A claim whose age cannot be read reads as abandoned, never as a wait forever.
    public static func extensionClaimState(age: TimeInterval?) -> ExtensionClaimState {
        guard let age, age <= heartbeatTimeout else { return .abandoned }
        return .inProgress
    }

    /// The app takes over an abandoned share-extension claim. Returns whether it now owns
    /// the note.
    public static func takeOver(_ id: UUID, in directory: URL) -> Bool {
        release(id, as: .shareExtension, in: directory)
        return claim(id, as: .app, in: directory) == .app
    }

    /// Remove claims older than `maximumAge`.
    public static func prune(in directory: URL, now: Date = Date()) {
        let fileManager = FileManager.default
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names {
            let url = directory.appendingPathComponent(name)
            guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                  let modified = attributes[.modificationDate] as? Date,
                  now.timeIntervalSince(modified) > maximumAge else { continue }
            try? fileManager.removeItem(at: url)
        }
    }

    static func file(for id: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent(id.uuidString)
    }
}
