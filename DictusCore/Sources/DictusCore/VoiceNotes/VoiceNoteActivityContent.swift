// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteActivityContent.swift
// What the Live Activity shows about the voice note queue (#620 decision 2).
import Foundation

/// The voice note part of the Live Activity's content.
///
/// ### Why this rides on the standby phase instead of being a phase of its own
///
/// `LiveActivityStateMachine` is the #42 / #257 machine, and every one of its edges
/// was argued for against a dictation desync. A voice note phase would need edges to
/// and from every dictation phase — a dictation can start while a note transcribes,
/// and a note can finish while a dictation records — and each would be a new way for
/// the Dynamic Island to show one thing while the app does another. So the machine
/// is untouched: a voice note is *content* the standby pill carries, the dictation
/// phases replace it while they run, and it comes back with standby.
///
/// ### Why the app sends words, not counts
///
/// The widget extension has no string catalog, and ActivityKit renders whatever the
/// app last pushed even after the app is suspended. DictusApp localises the lines
/// with its own catalog and the widget prints them. The payload stays far under
/// ActivityKit's 4 KB: two short lines and a preview capped at `previewLength`.
public struct VoiceNoteActivityContent: Codable, Hashable, Sendable {
    /// "Transcribing a voice note…", "Voice note transcribed".
    public var headline: String
    /// "1 in progress, 2 waiting", or nil when there is nothing else to say.
    public var detail: String?
    /// 0...1 while transcribing; nil when done or not yet started.
    public var progress: Double?
    /// The first lines of the transcript, as soon as the first chunk is done.
    public var preview: String?
    /// The note (and history record) a tap opens. Nil while nothing is finished.
    public var noteID: UUID?
    /// Whether the newest note is finished. Drives the checkmark.
    public var isDone: Bool

    /// Longest preview pushed, in characters: two lines of the expanded island.
    public static let previewLength = 140

    public init(headline: String, detail: String? = nil, progress: Double? = nil,
                preview: String? = nil, noteID: UUID? = nil, isDone: Bool = false) {
        self.headline = headline
        self.detail = detail
        self.progress = progress.map { min(max($0, 0), 1) }
        self.preview = preview.map { Self.trimmedPreview($0) }
        self.noteID = noteID
        self.isDone = isDone
    }

    /// The opening of `text`, cut on a word boundary with an ellipsis when cut.
    public static func trimmedPreview(_ text: String) -> String {
        let flat = text.split(whereSeparator: \.isNewline).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard flat.count > previewLength else { return flat }
        let head = flat.prefix(previewLength)
        let cut = head.lastIndex(of: " ").map { head[..<$0] } ?? head
        return cut.trimmingCharacters(in: .whitespaces) + "…"
    }

    /// The link a tap on the activity opens: the note's result, or the list.
    public var url: URL? {
        var components = URLComponents()
        components.scheme = "dictus"
        components.host = VoiceNoteURL.host
        if let noteID { components.queryItems = [URLQueryItem(name: VoiceNoteURL.idItem, value: noteID.uuidString)] }
        return components.url
    }
}

/// `dictus://voice-note[?id=<uuid>]`: opens the voice notes, on a result when an id
/// is given.
public enum VoiceNoteURL {
    public static let host = "voice-note"
    static let idItem = "id"

    /// Nil when `url` is not a voice note link; `.some(nil)` for the list itself.
    public static func target(of url: URL) -> UUID?? {
        guard url.scheme == "dictus", url.host == host else { return nil }
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == idItem }?.value
        return .some(value.flatMap(UUID.init(uuidString:)))
    }
}
