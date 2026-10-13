// DictusCore/Sources/DictusCore/AppleIntelligenceChecklist.swift
// What the Apple Intelligence step's checklist over Settings shows, and when it ends (#706).
import Foundation

/// One line of the checklist the Apple Intelligence step sends into Picture in Picture over
/// Settings (#706). The lines are the step's drawn Settings path, numbered the same way.
public enum AppleIntelligenceChecklistLine: Equatable, Sendable {
    /// iOS 27 and later: back to the Settings root, then the *Siri* row.
    case openSiri
    /// iOS 26: back to the Settings root, then the *Apple Intelligence & Siri* row.
    case openAppleIntelligenceAndSiri
    /// The *Language* row of that page.
    case tapLanguage
    /// The iPhone's language in Siri's list.
    case chooseIPhoneLanguage
}

/// The rules behind the Apple Intelligence step's checklist.
///
/// WHY NO LINE TICKS ON ITS OWN: an app cannot read Siri's language, nor see which Settings
/// page is open. The keyboard step's checklist can tick because adding a keyboard is
/// visible to the app; here the only observable fact is Apple Intelligence's availability
/// (`PolishAvailability.state`), and it turns `available` only at the very end, sometimes
/// long after the language was fixed. So until then every line is drawn as one to do:
/// pointing at the first would keep saying "tap Siri" while the language list is in front
/// of the user, the very trap the keyboard checklist fell into before it showed all its
/// lines (device test of 2026-10-10, #682). `available` ticks them all and ends it.
///
/// WHY IN DICTUSCORE: the lines follow the iOS version, which is a rule, and the app target
/// has no test bundle.
public enum AppleIntelligenceChecklist {

    /// The lines for a Settings route, in the order of the taps. The first follows the
    /// step's drawn root row (`AppleIntelligenceOnboarding.settingsRoute`), so the window
    /// and the drawing name the same row.
    public static func lines(for route: AppleIntelligenceOnboarding.SettingsRoute) -> [AppleIntelligenceChecklistLine] {
        let first: AppleIntelligenceChecklistLine
        switch route {
        case .siri: first = .openSiri
        case .appleIntelligenceAndSiri: first = .openAppleIntelligenceAndSiri
        }
        return [first, .tapLanguage, .chooseIPhoneLanguage]
    }

    /// `lines(for:)` on this device.
    public static var lines: [AppleIntelligenceChecklistLine] {
        lines(for: AppleIntelligenceOnboarding.settingsRoute)
    }

    /// Whether the checklist has done its job: Apple Intelligence is available. The only
    /// end the app can observe; the window stops on it.
    public static func isComplete(engineState: PolishAvailabilityState) -> Bool {
        engineState == .available
    }

    /// The state of every line: all to do until the end, all ticked once complete.
    public static func states(lineCount: Int, isComplete: Bool) -> [SettingsChecklistLineState] {
        Array(repeating: isComplete ? .done : .current, count: lineCount)
    }
}
