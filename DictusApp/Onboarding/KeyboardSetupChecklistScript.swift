// DictusApp/Onboarding/KeyboardSetupChecklistScript.swift
// The keyboard step's checklist over Settings: its lines and the keyboard it watches (#682).
import SwiftUI
import UIKit
import DictusCore

/// What the keyboard step's checklist brings to `SettingsChecklistPlayer`: the three taps
/// in Settings, and the one fact the app can observe, whether the Dictus keyboard has been
/// added (`KeyboardSetupChecklist`).
///
/// The window never stops on its own here (`stopsWhenComplete` false): enabling Full
/// Access is the end, and iOS ends the app, and the window with it, when that permission
/// changes (measured on device, 2026-10-10).
@MainActor
final class KeyboardSetupChecklistScript: SettingsChecklistScript {
    private var keyboardAdded = false

    let logComponent = "onboardingChecklist"
    /// The backgrounded app looks for the keyboard once a second.
    let backgroundPollInterval: TimeInterval = 1
    let stopsWhenComplete = false

    var factDetails: String {
        "keyboardAdded=\(keyboardAdded)"
    }

    var titles: [Text] {
        KeyboardSetupChecklistLine.allCases.map(\.title)
    }

    func checkAlreadyComplete() -> Bool {
        guard Self.isDictusKeyboardActive() else { return false }
        keyboardAdded = true
        return true
    }

    func refreshFact() {
        keyboardAdded = Self.isDictusKeyboardActive()
    }

    /// The spike's measurement: can the backgrounded app see the keyboard being added?
    /// Adding it ticks the first two lines; Full Access stays the current one.
    func pollInBackground(sinceSettings: Int) -> SettingsChecklistPoll {
        guard !keyboardAdded, Self.isDictusKeyboardActive() else { return .unchanged }
        keyboardAdded = true
        return .progressed(action: "keyboardAddedSeen", details: "background=true sinceSettings=\(sinceSettings)s")
    }

    func markComplete() {
        keyboardAdded = true
    }

    func markIncomplete() {
        keyboardAdded = false
    }

    func states(for phase: SettingsChecklistPhase) -> [SettingsChecklistLineState] {
        switch phase {
        case .idle(let elapsed): return KeyboardSetupChecklist.states(for: .demo(elapsed: elapsed))
        case .guide: return KeyboardSetupChecklist.states(for: .guide(keyboardAdded: keyboardAdded))
        case .complete: return KeyboardSetupChecklist.states(for: .complete)
        }
    }

    /// Whether the Dictus keyboard is in the user's keyboard list. Same test as the page's
    /// detection (`KeyboardSetupPage.checkKeyboardInstalled`), without its logging, which
    /// would write a line a second here.
    static func isDictusKeyboardActive() -> Bool {
        // value(forKey:) is KVO; anything but a String is ignored.
        DictusKeyboardPresence(inputModeIdentifiers: UITextInputMode.activeInputModes.compactMap {
            $0.value(forKey: "identifier") as? String
        }).isListed
    }
}
