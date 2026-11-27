// DictusCore/Sources/DictusCore/TypingJournal/TypingJournalFieldGate.swift
// The typing journal's field rule (#1001), outside `#if DEBUG`: Adaptive touch (#1014) asks
// it in every build, TestFlight and the App Store included, which are Release builds.
import Foundation

/// The rule that keeps the journal out of fields holding secrets: secure text entry,
/// passwords, one-time codes and card numbers. Pure, so it is tested without UIKit.
public enum TypingJournalFieldGate {
    /// The host's `textContentType`, reduced to what the rule reads. `HostInputTraits`
    /// maps the UIKit values in the keyboard.
    public enum Content: Equatable, Sendable {
        case password
        case newPassword
        case oneTimeCode
        case creditCard
        case other
    }

    /// Why the field must not be recorded, or nil when it may be.
    public static func skipReason(isSecureEntry: Bool, content: Content?) -> String? {
        if isSecureEntry { return "secureTextEntry" }
        switch content {
        case .password?: return "password"
        case .newPassword?: return "newPassword"
        case .oneTimeCode?: return "oneTimeCode"
        case .creditCard?: return "creditCard"
        case .other?, nil: return nil
        }
    }
}
