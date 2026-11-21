// DictusCore/Sources/DictusCore/ReturnKeyStyle.swift
// What the return key draws for the host field's `returnKeyType` (#1023).
//
// The glyph-and-colour table is adapted from Hex, MIT licence,
// Copyright (c) 2026 Christopher Langton — `ios/HEXShared/FullKeyboard/ReturnKeyStyle.swift`
// at commit b5fa4bd (anomalyco/hex #2200), where it was observed on Apple's own keyboard.
// The licence is reproduced in DictusApp's Settings > Licences.
//
// WHY in DictusCore and keyed on the raw value: `UIReturnKeyType` only exists in UIKit, and
// the mapping is what needs tests, which run on the Mac (`swift test`). The keyboard passes
// `returnKeyType.rawValue`; the values are part of UIKit's ABI and have not moved since
// iOS 9 added the last two. Same split as `HostFieldPolicy` / `HostInputTraits` (#200).
import Foundation

/// The return key for one `UIReturnKeyType`, as Apple's keyboard draws it on iOS 26: a glyph,
/// no word. The types that act (send ↑, go / join / route →, search, done ✓, emergency call)
/// are on the blue key; return ↵, next and continue › are on a plain key. Measured on the
/// iOS 26.5 simulator for Safari's address bar (blue →, VoiceOver "accéder"); Hex measured
/// every type on iOS 27.2.
public struct ReturnKeyStyle: Equatable, Sendable {

    /// What the key does, once `google` and `yahoo` have been folded into `search`.
    public enum Role: Equatable, Sendable, CaseIterable {
        case newline
        case send
        case go
        case join
        case route
        case search
        case done
        case emergencyCall
        case next
        case `continue`
    }

    public let role: Role

    public init(role: Role) {
        self.role = role
    }

    /// - Parameter rawValue: `UITextDocumentProxy.returnKeyType?.rawValue`. Nil (a host
    ///   that does not answer) and any value UIKit adds later draw the plain return key.
    public init(returnKeyTypeRawValue rawValue: Int?) {
        switch rawValue {
        case 1: role = .go            // UIReturnKeyType.go
        case 2, 6, 8: role = .search  // .google, .search, .yahoo
        case 3: role = .join          // .join
        case 4: role = .next          // .next
        case 5: role = .route         // .route
        case 7: role = .send          // .send
        case 9: role = .done          // .done
        case 10: role = .emergencyCall // .emergencyCall
        case 11: role = .continue     // .continue
        default: role = .newline      // .default (0), nil, unknown
        }
    }

    public static let newline = ReturnKeyStyle(role: .newline)

    /// The SF Symbol drawn on the key.
    public var symbol: String {
        switch role {
        case .newline: return "return"
        case .send: return "arrow.up"
        case .go, .join, .route: return "arrow.right"
        case .search: return "magnifyingglass"
        case .done: return "checkmark"
        case .emergencyCall: return "phone"
        case .next, .continue: return "chevron.right"
        }
    }

    /// Whether the key is drawn blue. Next and continue move on without acting, and Apple
    /// keeps them on a plain key.
    public var isAction: Bool {
        switch role {
        case .newline, .next, .continue: return false
        case .send, .go, .join, .route, .search, .done, .emergencyCall: return true
        }
    }

    /// The key's name, for VoiceOver and wherever the key shows a word instead of a glyph.
    ///
    /// Lower case like the key captions Apple's keyboard used before iOS 26 and like
    /// `SupportedLanguage.returnName`, which the plain key reuses. French "accéder" is
    /// Apple's own label for Go (read from the simulator's accessibility tree, iOS 26.5).
    public func label(in language: SupportedLanguage) -> String {
        if role == .newline { return language.returnName }
        switch language {
        case .french: return Self.french[role] ?? language.returnName
        case .english: return Self.english[role] ?? language.returnName
        case .spanish: return Self.spanish[role] ?? language.returnName
        case .german: return Self.german[role] ?? language.returnName
        }
    }

    private static let english: [Role: String] = [
        .send: "send", .go: "go", .join: "join", .route: "route", .search: "search",
        .done: "done", .emergencyCall: "emergency call", .next: "next", .continue: "continue"
    ]

    private static let french: [Role: String] = [
        .send: "envoyer", .go: "accéder", .join: "rejoindre", .route: "itinéraire",
        .search: "rechercher", .done: "OK", .emergencyCall: "appel d’urgence",
        .next: "suivant", .continue: "continuer"
    ]

    private static let spanish: [Role: String] = [
        .send: "enviar", .go: "ir", .join: "unirse", .route: "ruta", .search: "buscar",
        .done: "OK", .emergencyCall: "llamada de emergencia", .next: "siguiente",
        .continue: "continuar"
    ]

    // German nouns and these imperatives are capitalised, as `returnName` ("Eingabe") is.
    private static let german: [Role: String] = [
        .send: "Senden", .go: "Öffnen", .join: "Beitreten", .route: "Route", .search: "Suchen",
        .done: "Fertig", .emergencyCall: "Notruf", .next: "Weiter", .continue: "Weiter"
    ]
}

/// The return key's style plus whether it can be tapped.
public struct ReturnKeyAppearance: Equatable, Sendable {
    public let style: ReturnKeyStyle
    public let isEnabled: Bool

    public init(style: ReturnKeyStyle, isEnabled: Bool) {
        self.style = style
        self.isEnabled = isEnabled
    }

    /// Reads the three traits the host sets.
    ///
    /// - Parameters:
    ///   - returnKeyTypeRawValue: `returnKeyType?.rawValue`.
    ///   - enablesReturnKeyAutomatically: the host's flag; nil (not answered) counts as off.
    ///   - hasText: `UIKeyInput.hasText` — the whole document, not the text before the caret.
    public init(returnKeyTypeRawValue: Int?, enablesReturnKeyAutomatically: Bool?, hasText: Bool) {
        self.init(
            style: ReturnKeyStyle(returnKeyTypeRawValue: returnKeyTypeRawValue),
            isEnabled: Self.isEnabled(automatically: enablesReturnKeyAutomatically, hasText: hasText)
        )
    }

    /// The plain return key, on. What the keyboard draws before it has read a field.
    public static let standard = ReturnKeyAppearance(style: .newline, isEnabled: true)

    /// Off only while the field is empty and the host asked for that
    /// (`enablesReturnKeyAutomatically`): Apple's key turns grey and a tap does nothing.
    public static func isEnabled(automatically: Bool?, hasText: Bool) -> Bool {
        !(automatically == true && !hasText)
    }
}
