// DictusCore/Sources/DictusCore/FirstDictationStage.swift
// The three states of the onboarding's first dictation (#678).
import Foundation

/// What the onboarding's first dictation shows, from what the app can see of the keyboard.
///
/// WHY THREE STATES (#649 decision 1.8, #678): the step teaches the globe long-press with the
/// real keyboards, and the app cannot draw over a system keyboard. So the hint changes with
/// what is on screen, and always sits above the keyboard:
/// 1. no keyboard yet: a drawn loop of the globe long-press under the field;
/// 2. Apple's keyboard up: a banner saying to long-press the globe and pick Dictus;
/// 3. Dictus's keyboard up: a banner pointing at the blue mic.
///
/// WHY IN DICTUSCORE: the mapping and the completion rule are rules, and the app target has
/// no test bundle.
public enum FirstDictationStage: Equatable, Sendable {
    /// The field has not been tapped: no keyboard on screen.
    case beforeTap
    /// The field is focused and a keyboard other than Dictus is up (Apple's, or any other).
    case otherKeyboard
    /// The field is focused and the Dictus keyboard is up.
    case dictusKeyboard

    /// The stage for a field that is or is not focused, under a keyboard that is or is not
    /// Dictus's.
    ///
    /// WHY FOCUS WINS: an unfocused field has no keyboard, whatever was last up. The input
    /// mode a text view reports after losing focus is the one it had, not one on screen.
    public init(isFieldFocused: Bool, isDictusKeyboard: Bool) {
        if !isFieldFocused {
            self = .beforeTap
        } else if isDictusKeyboard {
            self = .dictusKeyboard
        } else {
            self = .otherKeyboard
        }
    }

    /// Whether a text input mode identifier is the Dictus keyboard's.
    ///
    /// A third-party keyboard's input mode identifier is its extension's bundle identifier
    /// (`com.pivi.dictus.keyboard`). The test is the same prefix match `KeyboardSetupPage`
    /// uses to detect the installed keyboard, so the two steps agree on what Dictus is.
    /// A nil identifier (the key could not be read) is not Dictus.
    public static func isDictusInputMode(identifier: String?) -> Bool {
        guard let identifier else { return false }
        return identifier.contains(dictusBundlePrefix)
    }

    /// The prefix every Dictus bundle identifier shares.
    static let dictusBundlePrefix = "com.pivi.dictus"

    /// Shortest text that completes the step.
    ///
    /// WHY 3 CHARACTERS: a single keystroke should not count, and a dictation lands several
    /// characters at once. Three still lets a short dictation through ("oui", "non", "ok").
    public static let minimumTextLength = 3

    /// Whether the field's text completes the step.
    ///
    /// WHY "HAS SEEN" AND NOT THE CURRENT STAGE: the rule is the one the page had before
    /// #678. Text typed on Apple's keyboard before switching does not count, but once Dictus
    /// has been up, the text counts even if the user switches back before it lands.
    public static func completes(text: String, hasSeenDictusKeyboard: Bool) -> Bool {
        guard hasSeenDictusKeyboard else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumTextLength
    }
}
