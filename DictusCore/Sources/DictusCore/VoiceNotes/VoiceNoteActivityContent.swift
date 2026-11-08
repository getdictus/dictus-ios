// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteActivityContent.swift
// What the Live Activity shows about shared voice notes: the ring (#620 island design).
import Foundation

/// One note's segment of the ring.
public enum VoiceNoteSegment: String, Codable, Hashable, Sendable {
    /// Waiting or being transcribed. White, translucent.
    case pending
    /// Transcribed, not yet read. Green `#22C55E`.
    case ready
    /// Failed, not yet seen. Red `#EF4444`.
    case failed
}

/// The voice note part of the Live Activity's content.
///
/// ### The design, grilled with the maintainer on 2026-10-01 (#620)
///
/// A **ring** of one segment per note in the current set — pending white, ready
/// green, failed red — with the number of ready unread notes in its centre, like a
/// badge. Opening a card takes its note out of the set; when every note is read the
/// ring is gone. No text preview in the island (unreadable, tested on device).
///
/// ### Why this rides on the existing activity instead of being a phase of its own
///
/// `LiveActivityStateMachine` is the #42 / #257 machine, and every one of its edges
/// was argued for against a dictation desync. A voice note phase would need edges to
/// and from every dictation phase; each would be a new way for the island to show
/// one thing while the app does another. So the machine is untouched: a voice note
/// is *content*, and `LiveActivityRenderOwner` decides, per state, who draws.
///
/// ### Why the app sends words, not counts
///
/// ActivityKit renders whatever the app last pushed even after the app is suspended,
/// and the same failures are worded in the app's list and result screen. DictusApp
/// localises the lines with its own catalog (`VoiceNoteCopy`) and the widget prints
/// them verbatim. The widget's own catalog (#664) holds only the dictation labels it
/// draws itself; these lines are not in it.
public struct VoiceNoteActivityContent: Codable, Hashable, Sendable {
    /// One per note in the current set, in the order they were shared.
    public var segments: [VoiceNoteSegment]
    /// "Voice note received" — the compact island's line while a note takes longer
    /// than `VoiceNoteIsland.receivedDelay` to transcribe. Nil otherwise.
    public var receivedLine: String?
    /// "3 voice notes ready · Tap to read", or the failure line. Expanded island and
    /// Lock Screen. Nil while nothing is finished.
    public var statusLine: String?
    /// Set only on the update that carries the batch's alert, so the expanded island
    /// the alert opens draws the alert layout (logo, large ring, line) rather than the
    /// long-press one (dictation buttons on top). Cleared by the next update.
    public var isAlerting: Bool

    public init(segments: [VoiceNoteSegment], receivedLine: String? = nil,
                statusLine: String? = nil, isAlerting: Bool = false) {
        self.segments = segments
        self.receivedLine = receivedLine
        self.statusLine = statusLine
        self.isAlerting = isAlerting
    }

    /// The badge in the centre of the ring: ready notes not yet read.
    public var readyCount: Int { segments.filter { $0 == .ready }.count }
    public var failedCount: Int { segments.filter { $0 == .failed }.count }
    public var hasPending: Bool { segments.contains(.pending) }
    /// Every note finished: the moment the ring pulses once.
    public var allFinished: Bool { !segments.isEmpty && !hasPending }
    /// Nothing left to show: the ring is gone.
    public var isEmpty: Bool { segments.isEmpty }

    /// Where a tap goes: the voice note screen, which opens on the oldest unread note.
    public var url: URL? {
        var components = URLComponents()
        components.scheme = "dictus"
        components.host = VoiceNoteURL.host
        return components.url
    }
}

/// `dictus://voice-note[?id=<uuid>]`: opens the voice note screen, on a given note
/// when an id is given.
public enum VoiceNoteURL {
    public static let host = "voice-note"
    static let idItem = "id"

    /// The link to one note, as the share extension opens it on the cold path.
    public static func url(for id: UUID?) -> URL? {
        var components = URLComponents()
        components.scheme = "dictus"
        components.host = host
        if let id { components.queryItems = [URLQueryItem(name: idItem, value: id.uuidString)] }
        return components.url
    }

    /// Nil when `url` is not a voice note link; `.some(nil)` for the screen itself.
    public static func target(of url: URL) -> UUID?? {
        guard url.scheme == "dictus", url.host == host else { return nil }
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == idItem }?.value
        return .some(value.flatMap(UUID.init(uuidString:)))
    }
}
