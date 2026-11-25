// DictusCore/Sources/DictusCore/ClipboardPasteOffer.swift
// Whether the keyboard toolbar offers a one-tap Paste for the current clipboard item (issue #634).
import Foundation

/// What the keyboard may know about the clipboard before the user taps anything.
///
/// Only presence and a counter, never the payload: `UIPasteboard.hasStrings`,
/// `hasURLs` and `changeCount` are documented as not fetching the item, so they
/// read nothing private and raise no paste banner.
public struct PasteboardSnapshot: Equatable, Sendable {
    /// `UIPasteboard.changeCount`: bumps on every copy, from any app.
    public let changeCount: Int

    /// Whether the item carries text or a URL, the two payloads a custom keyboard
    /// can insert through `UITextDocumentProxy`. An image-only item is `false`.
    public let hasInsertableContent: Bool

    public init(changeCount: Int, hasInsertableContent: Bool) {
        self.changeCount = changeCount
        self.hasInsertableContent = hasInsertableContent
    }
}

/// The Paste offer's policy: the toolbar shows Paste for a copy that is recent and
/// that the keyboard has not pasted yet.
///
/// The approach is Hex's `KeyboardClipboardTracker` (github.com/anomalyco/hex, branch
/// `dev`, `ios/HEXShared/FullKeyboard/KeyboardClipboard.swift`, MIT licence): remember
/// which copy the keyboard first noticed and when, and which copy it already pasted.
/// Dictus drops Hex's one-time-code offer and keeps the payload read out of this type.
///
/// WHY a freshness window: a copy from last week is not what the user is about to
/// paste, and an offer that never leaves would sit in the bar for good.
///
/// WHY the App Group: the keyboard process is torn down and relaunched between host
/// apps, which is exactly the copy-here-paste-there move this exists for. In memory,
/// every relaunch would see every copy as new and re-offer one already pasted. Only
/// two counters and a timestamp are stored, never clipboard contents.
public struct ClipboardPasteOffer {

    /// How long after the keyboard first notices a copy it keeps offering it.
    public static let freshness: TimeInterval = 3 * 60

    private enum Key {
        static let seenChange = "dictus.clipboardOffer.seenChange"
        static let seenAt = "dictus.clipboardOffer.seenAt"
        static let pastedChange = "dictus.clipboardOffer.pastedChange"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    /// Whether the toolbar should offer Paste now. Records the first sighting of a
    /// new copy, which is what starts its freshness window.
    ///
    /// The snapshot is an autoclosure so that without Full Access the pasteboard is
    /// never touched: a keyboard without it has no clipboard access at all.
    public func isOffered(hasFullAccess: Bool,
                          pasteboard: @autoclosure () -> PasteboardSnapshot,
                          now: Date = Date()) -> Bool {
        guard hasFullAccess else { return false }
        let snapshot = pasteboard()
        let change = snapshot.changeCount
        // Recorded even for an item that cannot be offered: a change count names one
        // item for good, so the caller's cheap "has it moved" check can stop there.
        if storedChange(Key.seenChange) != change {
            defaults.set(change, forKey: Key.seenChange)
            defaults.set(now.timeIntervalSince1970, forKey: Key.seenAt)
        }
        guard snapshot.hasInsertableContent, storedChange(Key.pastedChange) != change else { return false }
        return now.timeIntervalSince1970 - defaults.double(forKey: Key.seenAt) < Self.freshness
    }

    /// When the offer for the copy last seen runs out, so a keyboard left open can
    /// take Paste down on time. `nil` before any copy was seen.
    public func expiry() -> Date? {
        guard storedChange(Key.seenChange) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: Key.seenAt) + Self.freshness)
    }

    /// The change count of the copy last seen, so a caller can skip a full check
    /// while the clipboard has not moved.
    public var lastSeenChangeCount: Int? {
        storedChange(Key.seenChange)
    }

    /// Records that this copy was pasted, so it is not offered again.
    public func notePasted(changeCount: Int) {
        defaults.set(changeCount, forKey: Key.pastedChange)
    }

    /// `nil` when nothing was ever stored, so a first `changeCount` of 0 still
    /// counts as new rather than matching `integer(forKey:)`'s default.
    private func storedChange(_ key: String) -> Int? {
        defaults.object(forKey: key) as? Int
    }
}
