// DictusWidgets/CopyLastTranscriptIntent.swift
// LiveActivityIntent that puts the last transcription on the clipboard (#531).
//
// WHY LiveActivityIntent (not AppIntent):
// Button(intent:) inside a Live Activity requires a LiveActivityIntent. A regular
// AppIntent opens the app, which is the navigation this feature exists to avoid.
//
// WHY IN BOTH DictusApp AND DictusWidgets TARGETS:
// LiveActivityIntent.perform() executes in the HOST APP process, not the widget
// extension. A type compiled only into DictusWidgets cannot be found at runtime and
// the button does nothing, silently -- there is no build error and no log line. This
// file therefore carries membership in both targets, exactly like StopStandbyIntent.swift.
// If you add another intent, check its membership before believing a green build.
//
// Measured before any of this was written (probe branch, iPhone 17 Pro simulator, iOS 26.5):
// a LiveActivityIntent's UIPasteboard write lands while DictusApp is backgrounded.
import AppIntents
import ActivityKit
import Foundation
import UIKit
import DictusCore

struct CopyLastTranscriptIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Copy last transcription"
    static var description = IntentDescription("Copy the last Dictus transcription to the clipboard")

    func perform() async throws -> some IntentResult {
        // The FULL text, never the preview the island renders. The whole point of the
        // button is that the user gets the dictation back, not the first hundred
        // characters of it.
        guard let text = LastTranscriptRecall.fullText(), !text.isEmpty else {
            // Nothing has been dictated yet, so the button is not on screen -- unless the
            // pill outlived the store. Writing an empty string here would replace whatever
            // the user had on their clipboard with nothing, which is worse than a no-op.
            DictusLogger.app.info("Copy last transcript: nothing stored, pasteboard untouched")
            return .result()
        }

        await MainActor.run {
            UIPasteboard.general.string = text
        }
        DictusLogger.app.info("Last transcript copied from the Dynamic Island (\(text.count, privacy: .public) chars)")

        // Confirmation is a state, not an animation: a Live Activity re-renders from its
        // ContentState and cannot run one (#531 decision 5). Flip the button to a checkmark,
        // hold it long enough to be read, then flip it back.
        //
        // WHY the wait is awaited here rather than left to a detached task: awaiting inside
        // perform() is what keeps this process alive to run the second half. If iOS suspends
        // it anyway, the checkmark simply survives until the next standby rebuild -- the
        // failure is cosmetic and self-healing.
        await setCopiedFlag(true)
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
        await setCopiedFlag(false)

        return .result()
    }

    /// Flip the copy button's state on every standby pill.
    ///
    /// WHY it goes through ActivityKit directly instead of LiveActivityManager: this file is
    /// compiled into DictusWidgets too, and the manager only exists in DictusApp. The same
    /// reason StopStandbyIntent ends its activities here rather than calling
    /// `stopStandbyActivity()`.
    ///
    /// WHY only `.standby`: any other phase means a dictation started while the checkmark was
    /// up, and pushing a stale ContentState over it would put the Island back on a screen the
    /// dictation had already left (#42).
    private func setCopiedFlag(_ copied: Bool) async {
        for activity in Activity<DictusLiveActivityAttributes>.activities
        where activity.content.state.phase == .standby {
            var state = activity.content.state
            state.lastTranscriptCopied = copied
            // The staleDate is carried over rather than refreshed: standby sits stale by
            // design (nothing updates it and staleInterval is 30s), and extending it from
            // here would hide a genuinely dead pill from the manager's own liveness checks.
            await activity.update(.init(state: state, staleDate: activity.content.staleDate))
        }
    }
}
