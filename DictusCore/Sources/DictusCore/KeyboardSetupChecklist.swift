// DictusCore/Sources/DictusCore/KeyboardSetupChecklist.swift
// What the keyboard step's checklist shows, line by line (#682).
import Foundation

/// One line of the checklist the keyboard step plays inline and in Picture in Picture
/// over Settings (#649 decision 10, #682).
///
/// The order is the order of the taps in iOS Settings, from the app's own Settings page
/// (`openSettingsURLString` lands on Settings > Apps > Dictus).
public enum KeyboardSetupChecklistLine: Int, CaseIterable, Sendable {
    /// "Tap Keyboards": the row on the app's Settings page.
    case tapKeyboards
    /// "Turn on Dictus": the keyboard switch.
    case turnOnDictus
    /// "Turn on Full Access, then Allow": the second switch and iOS's confirmation alert.
    ///
    /// WHY ONE LINE FOR BOTH (decided by Pierre after the device test of 2026-10-10): the
    /// alert follows the switch at once, and the app is terminated on Allow, so a separate
    /// "come back" line was never reachable and only made the window taller.
    case turnOnFullAccessAndAllow
}

/// How one line is drawn: not reached yet, the one to do now, or done (ticked).
public enum KeyboardSetupChecklistLineState: Sendable, Equatable {
    case pending
    case current
    case done
}

/// The rules behind the checklist: which line is ticked when.
///
/// WHY IN DICTUSCORE: the same states are drawn by two renderers (the inline SwiftUI card
/// and the frames sent to Picture in Picture), and the app target has no test bundle.
public enum KeyboardSetupChecklist {

    /// What drives the lines.
    public enum Phase: Equatable, Sendable {
        /// Before the user has gone to Settings: a loop that walks the three lines in time
        /// with the drawn Settings page above it. `elapsed` is the time since the loop
        /// started; it wraps every `demoCycle`.
        case demo(elapsed: TimeInterval)
        /// After the tap on Open Settings: the lines follow what the app can observe.
        ///
        /// WHY ONLY ONE FACT: the app can see whether the Dictus keyboard has been added
        /// (`UITextInputMode.activeInputModes`), and nothing else. The Keyboards row has
        /// no trace, and Full Access is visible only to the keyboard extension itself; the
        /// app learns it by being terminated by iOS, which is also what ends the Picture
        /// in Picture (measured on device, 2026-10-10). So adding the keyboard ticks the
        /// first two lines and lights the third, which is never ticked live.
        case guide(keyboardAdded: Bool)
        /// The page has detected the keyboard on return: everything ticked, the same final
        /// state the drawn Settings page shows (both switches on).
        case complete
    }

    /// Length of one demo loop, the same as the drawn Settings loop on the keyboard step.
    public static let demoCycle: TimeInterval = 6

    /// When each line becomes the current one inside a demo loop, then (last entry) when
    /// every line is ticked. Line `i - 1` is ticked at the moment line `i` lights.
    ///
    /// WHY THESE TIMES: they are the drawn Settings loop's (`KeyboardSetupPage`): the
    /// Keyboards row lights at 0.8 s, the Dictus switch at 2.0 s, the Full Access switch
    /// at 3.2 s, and the drawing holds its final state, both switches on, from 4.6 s. The
    /// checklist lights the matching line at the same instant and is all ticked during the
    /// hold, so the two read as one animation.
    public static let demoSchedule: [TimeInterval] = [0.8, 2.0, 3.2, 4.6]

    /// The state of every line, in `KeyboardSetupChecklistLine.allCases` order.
    public static func states(for phase: Phase) -> [KeyboardSetupChecklistLineState] {
        let lineCount = KeyboardSetupChecklistLine.allCases.count
        switch phase {
        case .demo(let elapsed):
            return states(currentIndex: demoCurrentIndex(elapsed: elapsed), count: lineCount)
        case .guide(let keyboardAdded):
            let current = keyboardAdded
                ? KeyboardSetupChecklistLine.turnOnFullAccessAndAllow.rawValue
                : KeyboardSetupChecklistLine.tapKeyboards.rawValue
            return states(currentIndex: current, count: lineCount)
        case .complete:
            return Array(repeating: .done, count: lineCount)
        }
    }

    /// The state of one line.
    public static func state(of line: KeyboardSetupChecklistLine, in phase: Phase) -> KeyboardSetupChecklistLineState {
        states(for: phase)[line.rawValue]
    }

    /// The index of the current line in a demo loop, or nil before the first one lights
    /// (the loop's reset, where every line is pending). An index equal to the line count
    /// means every line is ticked.
    static func demoCurrentIndex(elapsed: TimeInterval) -> Int? {
        // A negative elapsed (a clock read before the loop's start) is the reset.
        guard elapsed >= 0 else { return nil }
        let inCycle = elapsed.truncatingRemainder(dividingBy: demoCycle)
        return demoSchedule.lastIndex(where: { $0 <= inCycle })
    }

    /// Lines before `currentIndex` done, the line at it current, the rest pending. An index
    /// past the last line ticks them all.
    private static func states(currentIndex: Int?, count: Int) -> [KeyboardSetupChecklistLineState] {
        (0..<count).map { index in
            guard let currentIndex else { return .pending }
            if index < currentIndex { return .done }
            if index == currentIndex { return .current }
            return .pending
        }
    }

    // MARK: - The trip to Settings

    /// What tapping Open Settings does.
    public enum SettingsTrip: Equatable, Sendable {
        /// Start Picture in Picture from the tap, then open Settings once it is up.
        case pictureInPictureThenSettings
        /// Open Settings straight away; the checklist stays in the app (the fallback) and
        /// the page's return-from-Settings detection does the rest. `reason` is logged.
        case settingsOnly(reason: String)
    }

    /// Picture in Picture when the device supports it and the system says it can start
    /// now; the fallback otherwise.
    ///
    /// - Parameters:
    ///   - isSupported: `AVPictureInPictureController.isPictureInPictureSupported()`.
    ///   - isPossible: the controller's `isPictureInPicturePossible` at the tap.
    ///   - isForcedOff: a debug switch that forces the fallback, so it can be tested on a
    ///     device that supports Picture in Picture.
    public static func settingsTrip(isSupported: Bool, isPossible: Bool, isForcedOff: Bool) -> SettingsTrip {
        if isForcedOff { return .settingsOnly(reason: "forcedOff") }
        guard isSupported else { return .settingsOnly(reason: "unsupported") }
        guard isPossible else { return .settingsOnly(reason: "notPossible") }
        return .pictureInPictureThenSettings
    }
}
