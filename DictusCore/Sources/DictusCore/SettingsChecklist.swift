// DictusCore/Sources/DictusCore/SettingsChecklist.swift
// What every onboarding checklist over Settings shares: line states, and PiP or fallback
// (#682, #706).
import Foundation

/// How one line of a checklist over Settings is drawn: not reached yet, the one to do now,
/// or done (ticked).
///
/// Shared by the keyboard step's checklist (#682, `KeyboardSetupChecklist`) and the Apple
/// Intelligence step's (#706, `AppleIntelligenceChecklist`): one renderer draws both.
public enum SettingsChecklistLineState: Sendable, Equatable {
    case pending
    case current
    case done
}

/// The rules every checklist sent into Picture in Picture over Settings follows, whatever
/// its lines.
public enum SettingsChecklist {

    /// What tapping Open Settings does.
    public enum SettingsTrip: Equatable, Sendable {
        /// Start Picture in Picture from the tap, then open Settings once it is up.
        case pictureInPictureThenSettings
        /// The tap has only now borrowed the audio session (the keyboard step went back to
        /// "not detected", #713): start Picture in Picture as soon as the system says it
        /// can, then open Settings. The tap's own deadline still applies.
        case pictureInPictureOnceReady
        /// Open Settings straight away; the step's own fallback and its return-from-Settings
        /// detection do the rest. `reason` is logged.
        case settingsOnly(reason: String)
    }

    /// Picture in Picture when the device supports it and the system says it can start
    /// now, or may shortly because the tap has just prepared it; the fallback otherwise.
    ///
    /// - Parameters:
    ///   - isSupported: `AVPictureInPictureController.isPictureInPictureSupported()`.
    ///   - isPossible: the controller's `isPictureInPicturePossible` at the tap.
    ///   - isForcedOff: a debug switch that forces the fallback, so it can be tested on a
    ///     device that supports Picture in Picture.
    ///   - preparedByTheTap: the tap itself has just borrowed the audio session, so a
    ///     "not possible" may only mean the system has not caught up yet (#713). On first
    ///     arrival the session is borrowed when the step appears, long before the tap.
    public static func settingsTrip(
        isSupported: Bool,
        isPossible: Bool,
        isForcedOff: Bool,
        preparedByTheTap: Bool = false
    ) -> SettingsTrip {
        if isForcedOff { return .settingsOnly(reason: "forcedOff") }
        guard isSupported else { return .settingsOnly(reason: "unsupported") }
        if isPossible { return .pictureInPictureThenSettings }
        return preparedByTheTap ? .pictureInPictureOnceReady : .settingsOnly(reason: "notPossible")
    }
}
