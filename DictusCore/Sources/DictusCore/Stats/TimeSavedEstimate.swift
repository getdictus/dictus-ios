// DictusCore/Sources/DictusCore/Stats/TimeSavedEstimate.swift
// The time dictation saved over typing, and the formula behind it (#726).
import Foundation

/// How long typing the dictated words would have taken, minus the time spent saying
/// them.
///
/// ### The typing baseline
///
/// Ruan, Wobbrock, Liou, Ng and Landay, "Comparing Speech and Keyboard Text Entry for
/// Short Messages in Two Languages on Touchscreen Phones", IMWUT 1(4), article 159,
/// 2017 (arXiv:1608.07323, first circulated as "Speech Is 3x Faster than Typing for
/// English and Mandarin Text Entry on Mobile Devices"). On an iPhone, with Apple's
/// built-in QWERTY keyboard, participants typed English at **52.24 words per
/// minute**, against 152.86 for speech: 2.93 times faster (section 5, Table 3).
///
/// ### What the number is not
///
/// - **Measured in English only.** The paper's other language is Mandarin through
///   Pinyin (42.83 WPM), which is not how Dictus users type. The same English rate
///   is used for every language (#726, 2026-10-13), which is why every figure built
///   on it is worded as an estimate ("about").
/// - **The paper's words are five characters**, the text-entry convention, while
///   `DictationTally` counts real words. An English word plus its space is close to
///   that; the estimate does not try to be closer than the paper's own spread.
/// - **Measured on proficient typists copying short messages.** Composing is slower
///   than copying, so the baseline errs on the side of claiming less.
public enum TimeSavedEstimate {

    /// Ruan et al. 2017, iOS keyboard, English, final text (see the type comment).
    public static let keyboardWordsPerMinute = 52.24

    /// Seconds saved, never negative.
    ///
    /// Negative is possible: long pauses make the audio outlast the typing estimate
    /// for a few words. That is not time lost to report, so it reads as nothing saved.
    public static func seconds(words: Int, audioSeconds: Int) -> Int {
        let typingSeconds = Double(max(0, words)) / keyboardWordsPerMinute * 60
        return max(0, Int((typingSeconds - Double(max(0, audioSeconds))).rounded(.down)))
    }

    /// The figure as the user reads it, rounded down: minutes under an hour, then
    /// hours and minutes. Rounded down so the estimate never claims more than the
    /// formula gave.
    ///
    /// WHY not whole hours from one hour on: 1 h 58 min would read "about 1 h", less
    /// than the "about 59 min" just under it. Hours and minutes grow with the time
    /// saved, every minute of the way.
    public enum Rounded: Equatable, Sendable {
        case minutes(Int)
        /// `minutes` is 0 to 59; 0 reads as whole hours.
        case hours(Int, minutes: Int)
    }

    /// Nil under one minute: "about 0 min" would tell the user nothing was saved,
    /// which is the reproach the recap exists to avoid.
    public static func rounded(seconds: Int) -> Rounded? {
        let minutes = seconds / 60
        guard minutes > 0 else { return nil }
        return minutes < 60 ? .minutes(minutes) : .hours(minutes / 60, minutes: minutes % 60)
    }
}
