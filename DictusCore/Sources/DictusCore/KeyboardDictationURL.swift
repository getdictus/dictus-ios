// DictusCore/Sources/DictusCore/KeyboardDictationURL.swift
// The single rule that recognises the dictation URLs the keyboard sends to the app.
import Foundation

/// What the keyboard is asking the app to do with a `dictus://dictate` URL.
public enum KeyboardDictationIntent: String, Sendable, Equatable, CaseIterable {
    /// Start a dictation now (`dictus://dictate?source=keyboard`).
    case record
    /// Only load the active model, without recording (`&intent=prepare`, issue #262).
    case prepare
}

/// Recognises the dictation URLs sent by the keyboard extension.
///
/// WHY a shared parser instead of inline query lookups:
/// The same URL is inspected in three places — at scene connection (to decide the very
/// first frame, issue #264), in `MainTabView.onOpenURL`, and in `DictusApp.handleIncomingURL`.
/// Three copies of "host is dictate, source is keyboard, intent may be prepare" drift the
/// moment one of them gains a parameter, and a drifting copy shows the wrong overlay.
///
/// WHY in DictusCore:
/// The rule is pure `Foundation` and testable off-device, and the keyboard side may later
/// build its URLs from the same vocabulary.
public enum KeyboardDictationURL {
    /// The scheme registered by DictusApp in `CFBundleURLTypes`.
    private static let scheme = "dictus"
    /// The only host that carries a dictation request.
    private static let host = "dictate"

    /// The query item naming the app the keyboard was serving (#23).
    private static let hostIdItem = "hostId"

    /// Returns the intent carried by `url`, or `nil` when the URL is not a keyboard
    /// dictation request.
    ///
    /// Returning `nil` covers everything the caller must not treat as a keyboard
    /// dictation: another scheme, `dictus://stop`, and the widget's `dictus://dictate`
    /// deep link, which has no `source=keyboard` query item.
    public static func intent(from url: URL) -> KeyboardDictationIntent? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              queryItems.contains(where: { $0.name == "source" && $0.value == "keyboard" })
        else {
            return nil
        }

        let isPrepareOnly = queryItems.contains { $0.name == "intent" && $0.value == "prepare" }
        return isPrepareOnly ? .prepare : .record
    }

    /// The bundle identifier of the app the keyboard was serving, or nil when the URL
    /// carries none.
    ///
    /// Nil is the normal case for every URL that is not a keyboard hand-off, and also for
    /// a hand-off whose host the keyboard could not resolve. The caller must treat both
    /// the same way: no auto-return, show the overlay. It must never fall back to a
    /// guess — opening the wrong app is worse than opening none, which is the whole
    /// reason #23 sat unsolved for six months rather than shipping an enumeration.
    ///
    /// `URLComponents` percent-decodes for us. The encoding on the way out is the
    /// keyboard's job; see `dictationURL(intent:hostId:)`.
    public static func hostId(from url: URL) -> String? {
        guard intent(from: url) != nil,
              let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let value = queryItems.first(where: { $0.name == hostIdItem })?.value,
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    /// The URL the keyboard opens to hand a dictation to the app.
    ///
    /// WHY a builder rather than a string literal at the call site: the two sides of this
    /// URL now have to agree about three query items instead of one, and the parser above
    /// lives in this same file. A literal built by hand in the extension is exactly how a
    /// percent-encoding bug ships — enterprise bundle identifiers can carry characters
    /// outside the query-safe set, and `addingPercentEncoding` is easy to forget once and
    /// impossible to notice until a customer's MDM app is the host.
    ///
    /// Returns nil only if percent-encoding or URL parsing fails, which no bundle
    /// identifier reachable here should be able to cause. The caller falls back to the
    /// URL without a host, which costs the auto-return and nothing else.
    public static func dictationURL(intent: KeyboardDictationIntent, hostId: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        var items = [URLQueryItem(name: "source", value: "keyboard")]
        if intent == .prepare {
            items.append(URLQueryItem(name: "intent", value: "prepare"))
        }
        if let hostId, !hostId.isEmpty {
            items.append(URLQueryItem(name: hostIdItem, value: hostId))
        }
        components.queryItems = items
        return components.url
    }
}
