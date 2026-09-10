// DictusCore/Sources/DictusCore/LastTranscriptRecall.swift
// The last dictation, kept reachable from the Dynamic Island (#531).

import Foundation

/// The text of the dictation that just happened, held so the user can get it back.
///
/// WHY THIS EXISTS: the transcript of a dictation whose insertion went wrong is not lost,
/// but it is out of reach. The Dynamic Island shows it for one second in `.ready` and then
/// returns to standby with an empty state, and `HistoryView` — the other place it survives —
/// is Pro-gated and costs a navigation. #531 puts it under the long press instead, which
/// needs somewhere durable to read it from.
///
/// WHY NOT ONE OF THE EXISTING KEYS: `SharedKeys.lastTranscription` and
/// `lastPolishedTranscription` are hand-off channels. They exist to be *claimed* — the
/// keyboard reads them and DictusApp clears them as it hands the next dictation over — so
/// their absence is a normal, frequent state and says nothing about whether a dictation
/// happened. This one is written and never claimed: it is replaced by the next dictation and
/// by nothing else, which is decision 2 of #531 ("no expiry window") expressed in storage.
///
/// WHY NOT `TranscriptionHistoryStore`: that store is Pro-gated and does not record a
/// non-subscriber's dictation at all. The escape hatch has to work for everyone.
///
/// WHY THE FULL TEXT IS STORED AND THE PREVIEW DERIVED: the Live Activity carries a ~100
/// character preview in its `ContentState`, and that preview must never be what the user
/// gets when they tap Copy. One key holding the whole text, and a pure function deriving
/// what is shown, is what makes those two impossible to confuse.
public enum LastTranscriptRecall {

    /// How much of the transcript the Dynamic Island's standby row carries.
    ///
    /// The same number the `.ready` preview has always used. It is a display budget, not a
    /// storage one — ActivityKit caps a `ContentState` payload at 4 KB and two lines of an
    /// expanded island cannot show more than this anyway.
    public static let previewLimit = 100

    /// Remember this dictation's text.
    ///
    /// WHY blank input is ignored rather than clearing: a dictation that produced nothing —
    /// an armed mode that failed, a watchdog that cancelled a generation — has not *replaced*
    /// the previous one, and decision 2 says the transcript stays available until the next
    /// dictation replaces it. Erasing it here would make the island's bottom region blink out
    /// for a reason the user cannot see, which is the state the decision exists to prevent.
    public static func record(_ text: String?, in defaults: UserDefaults = AppGroup.defaults) {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        defaults.set(text, forKey: SharedKeys.lastTranscriptRecall)
        defaults.synchronize()
    }

    /// The whole text, which is what the copy button puts on the pasteboard.
    public static func fullText(from defaults: UserDefaults = AppGroup.defaults) -> String? {
        defaults.string(forKey: SharedKeys.lastTranscriptRecall)
    }

    /// What the Dynamic Island's standby row shows, or nil when no dictation has happened yet.
    ///
    /// Nil is the marker for "empty bottom region", which is the screen as it is today.
    public static func preview(from defaults: UserDefaults = AppGroup.defaults) -> String? {
        fullText(from: defaults).map(preview(of:))
    }

    /// Reduce a transcript to the one or two lines an expanded island can hold.
    ///
    /// WHY newlines collapse into spaces: since #141 a polished transcript can carry paragraph
    /// breaks, and the row is capped at two lines. A leading break would spend one of them on
    /// nothing.
    ///
    /// WHY an ellipsis when it is cut: the copy button hands over the full text, so the row has
    /// to say that it is showing less than there is. SwiftUI's own truncation only appears when
    /// the text overflows the line — a transcript cut at exactly the limit would otherwise read
    /// as complete.
    public static func preview(of text: String) -> String {
        let flattened = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard flattened.count > previewLimit else { return flattened }
        return String(flattened.prefix(previewLimit)) + "…"
    }

    /// Forget it. Nothing in the product calls this — the next dictation overwrites the key —
    /// but the tests need a defined empty state, and so does anyone reasoning about the
    /// App Group's contents.
    public static func clear(in defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: SharedKeys.lastTranscriptRecall)
        defaults.synchronize()
    }
}
