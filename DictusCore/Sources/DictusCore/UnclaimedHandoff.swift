// DictusCore/Sources/DictusCore/UnclaimedHandoff.swift
// A keyboard hand-off whose text no keyboard took in time, and what becomes of it (#881).

import Foundation

/// The raw DictusApp hands to the keyboard, while no keyboard has claimed it.
///
/// WHY THIS EXISTS: the hand-off writes the raw to the App Group and posts
/// `transcriptionReady`. When iOS kills the keyboard before the post arrives, nothing
/// records which field the dictation was for, and the raw stays there. The next keyboard
/// to appear, in any app, used to type it (`claimUnclaimedHandoff`), minutes later and in
/// a field the user never dictated into. That is #881.
///
/// With the paste pill on (`KeyboardFeatureSettings.isPasteTranscriptionEffective`) such a
/// raw is typed on its own only while it is seconds old, and offered as the pill
/// otherwise. Both ends apply it: the keyboard when it finds the raw, DictusApp when its
/// hand-off watchdog gives up on it first.
public enum UnclaimedHandoff {

    /// How old an unclaimed raw may be and still be typed on its own.
    ///
    /// The case worth keeping is a `transcriptionReady` dropped while the keyboard stayed
    /// in front of the field: it reappears within moments and the text is the one the user
    /// is waiting for. A raw older than this has no field recorded, and the user may be
    /// anywhere by now. Five seconds is a choice, not a measurement, and it is far below
    /// the thirty seconds `PendingDictation` allows, because that rule also checks the
    /// field and this one cannot.
    public static let autoTypeWindow: TimeInterval = 5

    /// What a keyboard does with an unclaimed raw it has just found.
    public enum Disposition: Equatable, Sendable {
        /// Type it, the way an unclaimed raw has always been typed.
        case type
        /// Never type it: offer it as the paste pill.
        case offer
    }

    /// - Parameters:
    ///   - handedOffAt: `SharedKeys.lastTranscriptionTimestamp`, nil when absent.
    ///   - pastes: `KeyboardFeatureSettings.isPasteTranscriptionEffective`. Off, every
    ///     unclaimed raw is typed, as before #881.
    public static func disposition(handedOffAt: Date?, now: Date = Date(), pastes: Bool) -> Disposition {
        guard pastes else { return .type }
        guard let handedOffAt else { return .offer }
        let age = now.timeIntervalSince(handedOffAt)
        // A negative age is a clock that moved: the raw's age is unknown, so it is not typed.
        return (0...autoTypeWindow).contains(age) ? .type : .offer
    }

    /// The hand-off time DictusApp wrote beside the raw.
    public static func handedOffAt(in defaults: UserDefaults = AppGroup.defaults) -> Date? {
        (defaults.object(forKey: SharedKeys.lastTranscriptionTimestamp) as? Double)
            .map(Date.init(timeIntervalSince1970:))
    }

    /// The raw of a hand-off still waiting for a keyboard, or nil.
    ///
    /// The policy blob is what marks a hand-off: a dictation finished inside DictusApp
    /// writes the raw without one, and `claimUnclaimedHandoff` has never touched those.
    public static func waitingRaw(in defaults: UserDefaults = AppGroup.defaults) -> String? {
        guard defaults.data(forKey: SharedKeys.lastTranscriptionPolicy) != nil,
              let raw = defaults.string(forKey: SharedKeys.lastTranscription),
              !raw.isEmpty else { return nil }
        return raw
    }

    /// Take the waiting raw off the hand-off and leave it for the paste pill.
    ///
    /// Called by DictusApp's hand-off watchdog when no keyboard claimed the raw: the app
    /// has told the user the dictation is over, so no keyboard may type it later. The
    /// whole hand-off goes, not only the raw, the way the keyboard's own claim takes it.
    ///
    /// - Returns: the raw moved to `RecoveredTranscriptionChannel`, nil when nothing was
    ///   waiting.
    @discardableResult
    public static func withdraw(in defaults: UserDefaults = AppGroup.defaults, now: Date = Date()) -> String? {
        guard let raw = waitingRaw(in: defaults) else { return nil }
        for key in [
            SharedKeys.lastTranscription,
            SharedKeys.lastTranscriptionPolicy,
            SharedKeys.lastTranscriptionEngineRaw,
            SharedKeys.lastTranscriptionDuration,
            SharedKeys.lastTranscriptionSmartMode,
            SharedKeys.lastTranscriptionSmartModeSkipped,
            SharedKeys.handoffToken
        ] {
            defaults.removeObject(forKey: key)
        }
        RecoveredTranscriptionChannel.note(.refused(raw), in: defaults, now: now)
        return raw
    }
}
