// DictusCore/Sources/DictusCore/Stats/DictationTally.swift
// How much the user dictated, per day, for every user (#726).
import Foundation

/// Words dictated and seconds of audio spoken, one entry per local day.
///
/// The end-of-trial recap (#593) leads with these, and the free Home figure planned
/// for 2.1 (#728) reads the same store. Before this nothing counted dictated words:
/// the word count reached the debug log only, and History stores nothing without
/// Pro, so no free user had any past to show.
///
/// ### Privacy
///
/// Two integers per day in the App Group. No text, no timestamp finer than the day,
/// nothing that leaves the iPhone.
///
/// ### Why it is not gated by Pro or the trial
///
/// Unlike `ProTrialUsage`, which describes the trial and only counts while it runs,
/// this counts for everyone from the first dictation on 2.0.0, whatever
/// `PremiumFlags.paywallVisible` says (#726, 2026-10-13). The 2.1 Home figure needs
/// data from launch day, and a counter switched on later would start it at zero.
///
/// ### Why per day
///
/// A day is the finest grain the 2.1 stats need (per day, streaks), and the coarsest
/// that still lets the recap sum a fourteen-day window. The cost is at the window's
/// edges: the trial's first and last days count whole, including what was dictated
/// before it started or after it ended on those two days.
///
/// ### Who writes it
///
/// Every transcription completes in DictusApp, keyboard dictations included: the
/// keyboard only receives the text. So in practice one process writes, from two
/// sites (`DictationCoordinator` for dictations, `VoiceNoteProcessor` for voice
/// notes). The read-modify-write is still not atomic across processes, for
/// `ProTrialUsage`'s reason: losing one increment in a rare race costs a recap less
/// than a cross-process lock would.
///
/// ### Size
///
/// One small entry per day the user dictated, about 15 KB after a year of daily use.
/// Nothing is pruned: the stats are the history.
public enum DictationTally {

    /// What one or several days add up to.
    public struct Totals: Equatable, Sendable {
        public let words: Int
        public let audioSeconds: Int

        public init(words: Int, audioSeconds: Int) {
            self.words = words
            self.audioSeconds = audioSeconds
        }

        public static let zero = Totals(words: 0, audioSeconds: 0)
    }

    static let wordsField = "words"
    static let audioSecondsField = "audioSeconds"

    /// A transcription completed. Called by the app wherever one does.
    ///
    /// - Parameters:
    ///   - text: the transcript, only to count its words. It is not stored.
    ///   - audioDuration: seconds of audio the transcript came from.
    public static func record(_ text: String, audioDuration: TimeInterval) {
        record(words: wordCount(of: text), audioSeconds: Int(audioDuration.rounded()),
               in: AppGroup.defaults, now: Date(), calendar: .current)
    }

    static func record(words: Int,
                       audioSeconds: Int,
                       in defaults: UserDefaults,
                       now: Date,
                       calendar: Calendar) {
        guard words > 0 else { return }
        let key = dayKey(for: now, calendar: calendar)
        var days = storedDays(in: defaults)
        let day = days[key] ?? [:]
        days[key] = [
            wordsField: (day[wordsField] ?? 0) + words,
            audioSecondsField: (day[audioSecondsField] ?? 0) + max(0, audioSeconds)
        ]
        defaults.set(days, forKey: SharedKeys.dictationTally)
    }

    /// The days from `start`'s through `end`'s, both included, summed.
    public static func totals(from start: Date,
                              through end: Date,
                              in defaults: UserDefaults = AppGroup.defaults,
                              calendar: Calendar = .current) -> Totals {
        let first = dayKey(for: start, calendar: calendar)
        let last = dayKey(for: end, calendar: calendar)
        // Zero-padded ISO days compare as strings in calendar order.
        let inRange = storedDays(in: defaults).filter { $0.key >= first && $0.key <= last }.values
        return Totals(
            words: inRange.reduce(0) { $0 + ($1[wordsField] ?? 0) },
            audioSeconds: inRange.reduce(0) { $0 + ($1[audioSecondsField] ?? 0) }
        )
    }

    /// Words in a transcript, by the system's word boundaries.
    ///
    /// WHY not a split on spaces, which is what the log's `words=` uses: Mandarin
    /// writes no spaces, so a whole sentence would count as one word. The system's
    /// boundaries split it into words, and skip punctuation in every language.
    public static func wordCount(of text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in
            count += 1
        }
        return count
    }

    /// `"2026-10-20"` in `calendar`'s time zone: the day the user lived it in.
    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func storedDays(in defaults: UserDefaults) -> [String: [String: Int]] {
        defaults.dictionary(forKey: SharedKeys.dictationTally) as? [String: [String: Int]] ?? [:]
    }
}
