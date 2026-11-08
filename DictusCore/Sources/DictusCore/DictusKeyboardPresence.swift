// DictusCore/Sources/DictusCore/DictusKeyboardPresence.swift
// Whether the Dictus keyboard is in the user's keyboard list, as the app reads it (#713).
import Foundation

/// What the app can tell about the Dictus keyboard from the user's keyboard list
/// (`UITextInputMode.activeInputModes`, one identifier per enabled keyboard).
///
/// WHY THREE CASES AND NOT A BOOL (#713): the onboarding keyboard step now goes back to its
/// not-detected state when Dictus is no longer listed. An empty list is not proof of that:
/// iOS never lets the user remove every keyboard, so an empty list only means it could not
/// be read (the API is unstable during the scene transitions of a return from Settings).
/// Reverting on it would flash the step back to "not detected" for nothing.
///
/// WHY IN DICTUSCORE: the page's detection and the checklist's background poll use the same
/// test, and the app target has no test bundle.
public enum DictusKeyboardPresence: Equatable, Sendable {
    /// Dictus is in the list, under this identifier.
    case listed(identifier: String)
    /// The list was read and Dictus is not in it.
    case notListed
    /// The list came back empty: nothing can be concluded.
    case unreadable

    /// The fragment every Dictus keyboard identifier contains (`com.pivi.dictus.keyboard`).
    public static let identifierFragment = "com.pivi.dictus"

    /// Reads the presence from the identifiers of the active input modes.
    public init(inputModeIdentifiers identifiers: [String]) {
        guard !identifiers.isEmpty else {
            self = .unreadable
            return
        }
        if let identifier = identifiers.first(where: { $0.contains(Self.identifierFragment) }) {
            self = .listed(identifier: identifier)
        } else {
            self = .notListed
        }
    }

    /// Whether Dictus is in the list.
    public var isListed: Bool {
        if case .listed = self { return true }
        return false
    }
}
