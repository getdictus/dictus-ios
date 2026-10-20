// DictusCore/Sources/DictusCore/ModelPreparationCountdown.swift
// Turns the time already spent on a first preparation into what the preparation screen
// says is left of it. Issue #533.
import Foundation

/// The coarse "time left" line shown above the cycling phrases while a model compiles.
///
/// WHY A COUNTDOWN AND NOT A BAR (decided on #533, 2026-09-09):
/// the download phase already ends on a full bar, and a second bar starting again at 0 %
/// reads as "you were not as far along as you thought" — the very feeling the tester wrote
/// in about. Both shapes would run on the same clock against the same measurement; what
/// differs is the claim. A bar asserts measured progress. "About 3 minutes left" asserts an
/// estimate, and the word "about" carries it.
///
/// WHY IT IS HERE AND NOT IN THE VIEW: the rules below — round up, never print 1, never
/// print 0, hold at the floor — are the part of the issue with a right and a wrong answer,
/// and a SwiftUI view cannot be held still by a test. Same reasoning as
/// `ModelPreparationWait`, which this deliberately agrees with at the first second.
public enum ModelPreparationCountdown: Equatable, Sendable {

    /// Rounded up, like the notice under it. Never below `ModelPreparationWait.minimumNamedMinutes`.
    case minutesLeft(Int)

    /// The floor, held for as long as the compile overruns the measurement.
    ///
    /// WHY HOLD AND NOT EXPIRE: the measurement is an iPhone 15 Pro Max reading, so on
    /// slower supported hardware the clock runs out while the compile is still going, and
    /// that is the expected case. "Less than a minute left" held indefinitely stays
    /// literally true of every second it is shown, never contradicts itself, and never
    /// says "almost ready" — the phrase #432 deleted from this screen and which must not
    /// come back through here.
    case underAMinute

    /// What to show after `elapsedSeconds` of a preparation measured at `measuredSeconds`.
    ///
    /// - Returns: nil when there is nothing honest to count down from: no measurement, a
    ///   non-positive one (a typo, not a compile), or one short enough to be `.brief`,
    ///   where "less than a minute left" would only repeat the notice underneath it.
    public static func at(elapsedSeconds: Int, measuredSeconds: Int?) -> ModelPreparationCountdown? {
        guard let measuredSeconds,
              measuredSeconds >= ModelPreparationWait.briefThresholdSeconds else {
            return nil
        }
        // A clock that moved backwards (the user changed the time) is not time remaining
        // on top of the measurement; it is the start.
        let elapsed = max(0, elapsedSeconds)
        let remaining = measuredSeconds - elapsed
        guard remaining > 0 else { return .underAMinute }
        // Integer ceiling, as in `ModelPreparationWait`, so the boundaries are exact and
        // the figure at second 0 is the notice's figure.
        let roundedUpMinutes = (remaining + 59) / 60
        // WHY NEVER 1: the catalogue carries no plural rule for "About %lld minutes left",
        // so a 1 would ship "About 1 minutes left". Going straight from 2 to the floor
        // removes the case instead of adding a plural variation to translate.
        guard roundedUpMinutes >= ModelPreparationWait.minimumNamedMinutes else {
            return .underAMinute
        }
        return .minutesLeft(roundedUpMinutes)
    }
}
