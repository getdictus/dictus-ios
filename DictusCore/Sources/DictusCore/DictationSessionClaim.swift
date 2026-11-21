// DictusCore/DictationSessionClaim.swift
import Foundation

/// Who records a keyboard dictation: one owner per session, decided once (spike).
///
/// WHY it exists: the keyboard waits 500 ms for DictusApp to answer its Darwin start
/// post, then dictates by itself. An app that answers just after the window (measured
/// at 525 ms on the simulator, 2026-11-20) would start recording too, and the same words
/// would be captured twice — once in the keyboard, once in the app.
///
/// Both sides claim the session before recording, and the first claim wins. The claim is
/// a file named after the session in the App Group, created with `link(2)`: the kernel
/// either creates the name or fails with `EEXIST`, atomically across processes, and the
/// content (the owner) is in place before the name appears, so a loser always reads the
/// winner. A `UserDefaults` key could not do this: two processes can both read "free"
/// and both write.
public enum DictationSessionClaim {

    public enum Owner: String, Sendable {
        case keyboard
        case app
        /// The share extension transcribing a voice note itself (#992, voice notes
        /// without the app). The session is the note's id.
        case shareExtension
    }

    static let directoryName = "session-claims"
    /// Claims older than this are removed by `prune`; a session lasts minutes at most.
    static let maximumAge: TimeInterval = 3600

    public static var defaultDirectory: URL? {
        AppGroup.containerURL?.appendingPathComponent(directoryName)
    }

    /// Claim `sessionID` for `owner`. Returns the owner of the session afterwards — `owner`
    /// when this call won, the other side when it had already claimed — or nil when the
    /// claim could not be written or read at all.
    @discardableResult
    public static func claim(_ sessionID: String, as owner: Owner, in directory: URL) -> Owner? {
        guard isValid(sessionID) else { return nil }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent(sessionID)
        let staging = directory.appendingPathComponent(".\(sessionID).\(owner.rawValue).\(UUID().uuidString)")
        guard fileManager.createFile(atPath: staging.path, contents: Data(owner.rawValue.utf8)) else { return nil }
        defer { try? fileManager.removeItem(at: staging) }
        if link(staging.path, target.path) == 0 { return owner }
        guard errno == EEXIST else { return nil }
        return current(sessionID, in: directory)
    }

    /// The owner of `sessionID`, or nil when nobody has claimed it.
    public static func current(_ sessionID: String, in directory: URL) -> Owner? {
        guard isValid(sessionID),
              let data = fileManager.contents(atPath: directory.appendingPathComponent(sessionID).path),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        return Owner(rawValue: raw)
    }

    /// The app's side, called when the keyboard's Darwin start post arrives: claim the
    /// session the keyboard wrote beside it. False means the keyboard already dictates
    /// this session itself, and the app must not record.
    ///
    /// Fails open — true — when there is no session id (a keyboard from before this
    /// change) or the claim cannot be written: that is today's behaviour, and refusing
    /// to record over a filesystem error would be a worse failure than the double.
    public static func appMayStart(defaults: UserDefaults, directory: URL?) -> Bool {
        guard let sessionID = defaults.string(forKey: SharedKeys.dictationSessionRequest),
              let directory else { return true }
        let owner = claim(sessionID, as: .app, in: directory)
        return owner == nil || owner == .app
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

    private static var fileManager: FileManager { .default }

    /// Session ids are short tokens the keyboard generates; anything else could escape
    /// the directory.
    static func isValid(_ sessionID: String) -> Bool {
        !sessionID.isEmpty && sessionID.count <= 64
            && sessionID.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
