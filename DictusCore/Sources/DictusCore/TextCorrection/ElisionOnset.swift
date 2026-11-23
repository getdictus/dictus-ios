// DictusCore/Sources/DictusCore/TextCorrection/ElisionOnset.swift
// The letters a word may start with after an elision prefix.
import Foundation

/// What may follow an elision prefix: French elides before a vowel or a mute h only,
/// so `d'accord`, `l'homme`, `j'y` are words and `d'votre` never is.
///
/// The corrector checks the part after the apostrophe on its own and puts the prefix
/// back afterwards, so without this rule a typo like `d'cirre` came back as `d'votre`
/// (device report, 2026-11-23). Every place that reassembles a prefix and a word asks
/// `allows` before proposing the result.
///
/// The rule only rejects: a candidate starting with a letter outside `initials`, after
/// one of `prefixes`. Anything else passes, so a language without this value, a prefix
/// that is not listed (English `don'`, `it'`, `I'`) and a word with no apostrophe are
/// left exactly as they were.
public struct ElisionOnset: Sendable {

    /// The elision prefixes, lowercase, each ending with its apostrophe: `d'`, `qu'`.
    public let prefixes: Set<String>

    /// The lowercase letters an elided word may start with: the vowels, accented or
    /// not, and `h`.
    public let initials: Set<Character>

    public init(prefixes: Set<String>, initials: Set<Character>) {
        self.prefixes = prefixes
        self.initials = initials
    }

    /// Whether `word` may follow `prefix`. True when `prefix` is nil or not an elision
    /// prefix, or when `word` starts with anything but a letter outside `initials`.
    public func allows(_ word: String, after prefix: String?) -> Bool {
        guard let prefix, prefixes.contains(Self.normalized(prefix)),
              let first = word.lowercased().first, first.isLetter else { return true }
        return initials.contains(first)
    }

    /// Whether a whole word, prefix included, is allowed: `l'homme` is, `d'votre` is
    /// not. The prefix is everything up to the last apostrophe, as the corrector splits it.
    public func allows(_ word: String) -> Bool {
        let normalized = Self.normalized(word)
        guard let apostrophe = normalized.lastIndex(of: "'") else { return true }
        return allows(String(normalized[normalized.index(after: apostrophe)...]),
                      after: String(normalized[...apostrophe]))
    }

    /// Lowercase, with the typographic apostrophe read as the straight one.
    private static func normalized(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
    }
}

extension LanguageProfile {
    /// Whether `word` may follow `prefix` in this language. Always true for a language
    /// without `elisionOnset`.
    public func allowsElided(_ word: String, after prefix: String?) -> Bool {
        elisionOnset?.allows(word, after: prefix) ?? true
    }

    /// Whether a whole word, prefix included, is allowed in this language: `d'votre` is
    /// not in French. Always true for a language without `elisionOnset`.
    public func allowsElision(_ word: String) -> Bool {
        elisionOnset?.allows(word) ?? true
    }
}
