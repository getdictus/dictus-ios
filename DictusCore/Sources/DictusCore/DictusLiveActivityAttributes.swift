#if os(iOS)
// DictusCore/Sources/DictusCore/DictusLiveActivityAttributes.swift
// Data model for Dictus Live Activity (Dynamic Island + Lock Screen).
import ActivityKit
import Foundation

/// Attributes for the Dictus Live Activity displayed in the Dynamic Island.
///
/// WHY in DictusCore (not DictusWidgets):
/// Both DictusApp (to start/update the activity) and DictusWidgets (to render it)
/// need access to this type. DictusCore is the shared framework imported by both.
///
/// WHY no mutable attributes (only ContentState):
/// ActivityAttributes properties are set at creation time and never change.
/// Dictus has no per-activity metadata — the same app, same branding, same behavior.
/// All dynamic data lives in ContentState, updated via Activity.update().
public struct DictusLiveActivityAttributes: ActivityAttributes {
    /// Phase of the Live Activity, as displayed by ActivityKit.
    ///
    /// WHY a sibling of ContentState rather than nested inside it: two levels of
    /// nesting is one more than the project lints for, and the type is the same
    /// type either way. Unqualified `Phase` still resolves from inside
    /// ContentState through the enclosing scope, and the raw values are unchanged,
    /// so the Codable wire format ActivityKit persists is identical.
    public enum Phase: String, Codable, Hashable {
        /// App is in background, ready to record. Static "On" display.
        case standby
        /// Actively recording audio. Shows waveform + timer.
        case recording
        /// Processing audio through WhisperKit/Parakeet. Shows pulsing animation.
        case transcribing
        /// Running the LLM stage on the transcript (#267). Distinct from
        /// `transcribing` because it is the longer of the two waits and the one
        /// the user is most likely to read as a hang.
        case processing
        /// Transcription result available. Shows preview + checkmark.
        case ready
        /// An error occurred during recording or transcription.
        case failed
    }

    public struct ContentState: Codable, Hashable {
        /// Current phase of the Live Activity.
        public var phase: Phase

        /// Recording start date for auto-updating timer display.
        /// WHY Date instead of TimeInterval: SwiftUI's `Text(date, style: .timer)`
        /// auto-increments without consuming ActivityKit's update budget (~1/sec cap).
        /// nil in standby mode, set when recording starts.
        public var recordingStartDate: Date?

        /// Audio waveform levels for Dynamic Island visualization.
        /// WHY 5 levels: Dynamic Island compact is ~36pt wide. More bars would be
        /// invisible. Also, ActivityKit has a 4KB payload limit per update —
        /// 5 Float values = 20 bytes, well within budget.
        /// Empty array in standby mode.
        public var waveformLevels: [Float]

        /// Short preview of the transcription result (~100 chars).
        /// nil except in .ready phase.
        public var transcriptionPreview: String?

        /// Preview of the last dictation, carried through standby so the expanded Dynamic
        /// Island can offer it back (#531). nil until a first dictation has happened, which
        /// is what keeps the bottom region empty on a fresh install.
        ///
        /// WHY a second preview field rather than reusing `transcriptionPreview`: that one is
        /// documented as nil outside `.ready` and both the expanded and the lock screen views
        /// branch on that. Widening its meaning would put the transcript on the lock screen
        /// banner, which decision 4 exists to prevent.
        ///
        /// The FULL text lives in the App Group under `LastTranscriptRecall` — this is a
        /// display value and is never what the copy button hands over.
        public var lastTranscriptPreview: String?

        /// Whether the copy button has just been tapped, which flips it to a checkmark (#531
        /// decision 5: a Live Activity cannot run a confirmation animation, so the
        /// confirmation is a state).
        ///
        /// WHY Optional for a Bool: ActivityKit persists this state and decodes it with
        /// whatever binary is running when the activity next renders, so an activity started
        /// before this field existed is decoded by code that has it. Swift's synthesised
        /// `init(from:)` calls `decodeIfPresent` for an Optional and `decode` for a
        /// non-Optional -- a plain `Bool` would throw on that missing key and the pill would
        /// stop rendering mid-flight. Read through `hasCopiedLastTranscript`, where nil and
        /// false are the same state.
        public var lastTranscriptCopied: Bool?

        /// The copy button's state, with nil folded into "not copied".
        public var hasCopiedLastTranscript: Bool { lastTranscriptCopied ?? false }

        public init(
            phase: Phase,
            recordingStartDate: Date? = nil,
            waveformLevels: [Float] = [],
            transcriptionPreview: String? = nil,
            lastTranscriptPreview: String? = nil,
            lastTranscriptCopied: Bool? = nil
        ) {
            self.phase = phase
            self.recordingStartDate = recordingStartDate
            self.waveformLevels = waveformLevels
            self.transcriptionPreview = transcriptionPreview
            self.lastTranscriptPreview = lastTranscriptPreview
            self.lastTranscriptCopied = lastTranscriptCopied
        }
    }

    public init() {}
}
#endif
