// DictusCore/Sources/DictusCore/KeyboardOpenURL.swift
// The URLs the keyboard sends to bring the app to a particular screen (issues #241, #404).
import Foundation

/// Where the keyboard is asking the app to land.
///
/// Distinct from `KeyboardDictationIntent`, which answers a different question on a
/// different host: that one says *what to do with a dictation*, this one says *which
/// screen to show*. Keeping them apart is what stops a paywall request from reaching
/// `ColdStartLaunch`, whose whole job is deciding the first frame of a dictation.
public enum KeyboardOpenIntent: String, Sendable, Equatable, CaseIterable {

    /// The paywall. Sent by the hamburger panel's Dictus Pro pill (#241) and by the
    /// long-press fan's Dictus Pro row (#404).
    case pro

    /// The app's settings. It has no route of its own — the app simply comes to the
    /// foreground — and that is still true; the case exists so the vocabulary is
    /// closed rather than open to typos.
    case settings

    /// A shared voice note's result screen, from the keyboard's voice note reader
    /// (#637). Unlike the two above it does not travel on `dictus://open`: it targets
    /// the voice note link the Live Activity and the share extension already use,
    /// `dictus://voice-note?id=<uuid>`, so the app routes it with the code that
    /// already opens a note — `VoiceNoteURL`, then `VoiceNoteProcessor.open`.
    case voiceNote
}

/// The `dictus://open` URLs, built by the keyboard and read by the app.
///
/// WHY a shared type rather than a string on each side: the keyboard extension has no
/// test bundle, so a URL it builds by interpolation and the app parses by hand is a
/// cross-process contract nothing can check. #404 is the bill for that being loose —
/// the fan's Dictus Pro row carried `intent=pro` faithfully, and the app had no `open`
/// route at all, so the one row in the fan that leads anywhere landed on whatever
/// screen happened to be showing. Building and parsing here makes the round trip a
/// test rather than a hope.
///
/// WHY the host is not `dictate`: `KeyboardDictationURL` deliberately answers nil for
/// everything that is not a dictation, and that nil is load-bearing — it is what keeps
/// the widget's own `dictus://dictate` out of the keyboard hand-off path. Adding a
/// screen intent to that enum would put a paywall request inside the type the
/// cold-start overlay switches on.
public enum KeyboardOpenURL {

    /// The scheme registered by DictusApp in `CFBundleURLTypes`.
    private static let scheme = "dictus"

    /// The host that carries a "bring the app to this screen" request.
    private static let host = "open"

    /// The URL the keyboard opens for `intent`.
    ///
    /// - Parameter voiceNoteID: the note `.voiceNote` opens on. Ignored by every other
    ///   intent; nil opens the voice note screen on the oldest unread note.
    public static func url(intent: KeyboardOpenIntent, voiceNoteID: UUID? = nil) -> URL? {
        switch intent {
        case .voiceNote:
            // `source=keyboard` rides along so the app can tell the keyboard's link
            // from the island's and the share extension's; `VoiceNoteURL.target`
            // reads only the id, so the routing is the same for all three.
            guard let link = VoiceNoteURL.url(for: voiceNoteID),
                  var components = URLComponents(url: link, resolvingAgainstBaseURL: false) else { return nil }
            components.queryItems = (components.queryItems ?? []) + [URLQueryItem(name: "source", value: "keyboard")]
            return components.url
        case .pro, .settings:
            return URL(string: "\(scheme)://\(host)?source=keyboard&intent=\(intent.rawValue)")
        }
    }

    /// The intent carried by `url`, or nil when it is not one of ours.
    ///
    /// `source=keyboard` is required for the same reason `KeyboardDictationURL` requires
    /// it: the scheme is public, and a screen request is only a screen request when we
    /// sent it.
    public static func intent(from url: URL) -> KeyboardOpenIntent? {
        guard url.scheme?.lowercased() == scheme,
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              queryItems.contains(where: { $0.name == "source" && $0.value == "keyboard" })
        else {
            return nil
        }
        if url.host?.lowercased() == VoiceNoteURL.host { return .voiceNote }
        guard url.host?.lowercased() == host,
              let raw = queryItems.first(where: { $0.name == "intent" })?.value,
              let intent = KeyboardOpenIntent(rawValue: raw),
              // `.voiceNote` lives on its own host; an `open` URL naming it is not ours.
              intent != .voiceNote
        else {
            return nil
        }
        return intent
    }
}
