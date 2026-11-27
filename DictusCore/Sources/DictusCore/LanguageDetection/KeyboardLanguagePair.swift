// DictusCore/Sources/DictusCore/LanguageDetection/KeyboardLanguagePair.swift
// The two languages a bilingual keyboard types, and which pairs exist (#1009).
import Foundation

/// A primary keyboard language and the second language typed alongside it.
///
/// The primary keeps every meaning the single keyboard language has today: the layout,
/// the spacebar label, the transcription hint. The second language only adds a dictionary
/// that detection can pick for a word.
///
/// A monolingual keyboard has no pair: the initializer returns nil when the second
/// language is absent, equal to the primary, or not offered with it.
public struct KeyboardLanguagePair: Equatable, Sendable {
    public let primary: SupportedLanguage
    public let secondary: SupportedLanguage

    public init?(primary: SupportedLanguage, secondary: SupportedLanguage?) {
        guard let secondary, Self.secondaries(for: primary).contains(secondary) else { return nil }
        self.primary = primary
        self.secondary = secondary
    }

    /// The languages that can be typed alongside `primary`.
    ///
    /// WHY French and English only: they are the only pair the detection was measured on
    /// (#1007). Another pair joins once it has a mixed bench run of its own.
    public static func secondaries(for primary: SupportedLanguage) -> [SupportedLanguage] {
        switch primary {
        case .french: return [.english]
        case .english: return [.french]
        case .spanish, .german: return []
        }
    }

    /// The pair's other language. `language` must be one of the two.
    public func other(than language: SupportedLanguage) -> SupportedLanguage {
        language == primary ? secondary : primary
    }
}
