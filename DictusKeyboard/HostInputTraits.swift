// DictusKeyboard/HostInputTraits.swift
// Maps the host text field's UITextInputTraits (read from UITextDocumentProxy)
// to the pure HostFieldPolicy decision in DictusCore (issue #200).
//
// WHY this split: UIKeyboardType/UITextContentType only exist in UIKit, but the
// policy logic must be unit-testable in DictusCoreTests (no UIKit on macOS).
// This file is the thin, untestable UIKit shim; the tested logic is in DictusCore.

import UIKit
import DictusCore

enum HostInputTraits {

    /// Reads the proxy's traits. The policy is decided from successive readings by
    /// `HostFieldPolicyTracker` (#1004), which `SuggestionState` owns.
    ///
    /// NOTE: traits are only accurate once the host connection exists
    /// (viewWillAppear onward) — same caveat as needsInputModeSwitchKey.
    /// UITextInputTraits members are optional ObjC requirements, hence the
    /// optional chaining with permissive defaults (missing trait = normal field).
    static func traits(for proxy: UITextDocumentProxy) -> HostFieldTraits {
        #if DEBUG
        // Every read of the traits feeds the typing journal's gate (#1001), so the
        // journal sees each field change and stops at once in a secure one.
        observeJournalField(proxy)
        #endif
        return HostFieldTraits(
            keyboard: keyboardKind(proxy.keyboardType),
            content: contentKind(proxy.textContentType),
            autocorrectionDisabled: proxy.autocorrectionType == .no,
            spellCheckingDisabled: proxy.spellCheckingType == .no,
            isSecureEntry: proxy.isSecureTextEntry ?? false
        )
    }

    private static func keyboardKind(_ type: UIKeyboardType?) -> HostFieldPolicy.KeyboardKind {
        switch type {
        case .URL: return .url
        case .emailAddress: return .email
        case .webSearch: return .webSearch
        case .twitter: return .twitter
        case .numberPad, .decimalPad, .asciiCapableNumberPad: return .numeric
        case .phonePad: return .phone
        case .namePhonePad: return .namePhone
        case .asciiCapable: return .asciiCapable
        default: return .standard
        }
    }

    #if DEBUG
    private static func observeJournalField(_ proxy: UITextDocumentProxy) {
        TypingJournal.observeField(
            isSecureEntry: proxy.isSecureTextEntry ?? false,
            content: journalContent(proxy.textContentType),
            document: DictusTextProxyIdentity.documentIdentifier(of: proxy)?.uuidString,
            keyboard: "\(SupportedLanguage.active.rawValue)-\(LayoutType.active.rawValue)"
        )
    }

    /// What the typing journal's field gate reads (#1001): the content types that
    /// hold a secret. Every other one, and none, records.
    private static func journalContent(_ type: UITextContentType?) -> TypingJournalFieldGate.Content? {
        guard let type = type else { return nil }
        switch type {
        case .password: return .password
        case .newPassword: return .newPassword
        case .oneTimeCode: return .oneTimeCode
        case .creditCardNumber, .creditCardSecurityCode, .creditCardExpiration,
             .creditCardExpirationMonth, .creditCardExpirationYear: return .creditCard
        default: return .other
        }
    }
    #endif

    private static func contentKind(_ type: UITextContentType?) -> HostFieldPolicy.ContentKind {
        guard let type = type else { return .none }
        switch type {
        case .username: return .username
        case .password, .newPassword: return .password
        case .URL: return .url
        case .emailAddress: return .email
        case .oneTimeCode: return .oneTimeCode
        default: return .other
        }
    }
}
