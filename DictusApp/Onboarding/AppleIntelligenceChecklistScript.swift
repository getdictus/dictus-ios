// DictusApp/Onboarding/AppleIntelligenceChecklistScript.swift
// The Apple Intelligence step's checklist over Settings: its lines and its end (#706).
import SwiftUI
import DictusCore

/// What the Apple Intelligence step's checklist brings to `SettingsChecklistPlayer`: the
/// step's drawn path as three lines, for the running iOS (`AppleIntelligenceChecklist`),
/// and the one fact the app can observe, Apple Intelligence's availability
/// (`PolishAvailability.state`).
///
/// WHY IT STOPS BY ITSELF (`stopsWhenComplete`): unlike Full Access on the keyboard step,
/// nothing ends the app when Apple Intelligence turns on, so the window would stay over
/// Settings with nothing left to say. Once availability reads `available`, every line
/// ticks and the window goes a moment later. Coming back to Dictus stops it in every case,
/// as on the keyboard step, so a model that is still setting up never leaves it behind.
@MainActor
final class AppleIntelligenceChecklistScript: SettingsChecklistScript {
    private let lines = AppleIntelligenceChecklist.lines
    private var engineState = PolishAvailability.state

    let logComponent = "onboardingAppleIntelligenceChecklist"
    /// Availability changes on Apple's schedule (minutes to hours, #683), not on a tap: a
    /// read every two seconds is enough to end the window promptly.
    let backgroundPollInterval: TimeInterval = 2
    let stopsWhenComplete = true

    var factDetails: String {
        "state=\(String(describing: engineState))"
    }

    var titles: [Text] {
        lines.map(\.title)
    }

    func checkAlreadyComplete() -> Bool {
        engineState = PolishAvailability.state
        return AppleIntelligenceChecklist.isComplete(engineState: engineState)
    }

    func refreshFact() {
        engineState = PolishAvailability.state
    }

    /// Whether the backgrounded app sees Apple Intelligence turn available while the user
    /// is in Settings. A change that is not the end is logged too, so a device log shows
    /// what Apple reports on the way.
    func pollInBackground(sinceSettings: Int) -> SettingsChecklistPoll {
        let previous = engineState
        engineState = PolishAvailability.state
        if AppleIntelligenceChecklist.isComplete(engineState: engineState) {
            return .completed(action: "availableSeen", details: "background=true sinceSettings=\(sinceSettings)s")
        }
        guard engineState != previous else { return .unchanged }
        return .progressed(action: "stateChanged", details: "background=true sinceSettings=\(sinceSettings)s \(factDetails)")
    }

    func markComplete() {
        engineState = .available
    }

    /// Not reached on this step: the page never goes back from ready. Reads the state
    /// afresh all the same, so the fact in the log stays true.
    func markIncomplete() {
        engineState = PolishAvailability.state
    }

    func states(for phase: SettingsChecklistPhase) -> [SettingsChecklistLineState] {
        AppleIntelligenceChecklist.states(lineCount: lines.count, isComplete: phase == .complete)
    }
}

// MARK: - Copy

extension AppleIntelligenceChecklistLine {
    /// The line's text, in the user's language. One line each in a small window: the
    /// longest French line, on iOS 26, shrinks a little to fit.
    var title: Text {
        switch self {
        case .openSiri:
            return Text("Go back to Settings, tap Siri", comment: "Checklist line over iOS Settings during the Apple Intelligence step (#706), iOS 27 and later: Open Settings lands on Dictus's page, so go back to the main Settings screen and tap the Siri row. One line in a small window: keep it short.")
        case .openAppleIntelligenceAndSiri:
            return Text("Go back, tap Apple Intelligence & Siri", comment: "Checklist line over iOS Settings during the Apple Intelligence step (#706), iOS 26: go back to the main Settings screen and tap the Apple Intelligence & Siri row (its name in iOS). One line in a small window: keep it short.")
        case .tapLanguage:
            return Text("Tap Language", comment: "Checklist line over iOS Settings during the Apple Intelligence step (#706): tap the Language row of Siri's settings (its name in iOS).")
        case .chooseIPhoneLanguage:
            return Text("Choose \(AppleIntelligencePage.iPhoneLanguageName)", comment: "Checklist line over iOS Settings during the Apple Intelligence step (#706): pick the iPhone's language in Siri's language list. The argument is the language's name on its own, such as English or Français.")
        }
    }
}
