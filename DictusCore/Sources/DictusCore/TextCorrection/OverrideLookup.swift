// DictusCore/Sources/DictusCore/TextCorrection/OverrideLookup.swift
// Pure-data autocorrect step: forces a hardcoded correction when the input
// matches a known must-correct word in the active language.
import Foundation

/// Looks up `word` in `profile.overrides` and returns the forced correction
/// with case preserved (uppercase first letter if the input was capitalized).
///
/// Returns `nil` if no override applies. Empty override maps (per ADR 0001 for
/// languages onboarded without native-speaker curation) always return `nil`.
///
/// WHY this exists:
/// Some words are *never* valid in a language without their accent or
/// contraction (French `ca` is always a misspelling of `ça`; English `dont`
/// is always `don't`). Edit-distance correction would also pick these up,
/// but the override map runs first because:
///   1. It's deterministic — guaranteed correction for known cases.
///   2. It overrides the user dictionary — if the user accidentally taught
///      `dont` as a word, we still correct it.
///   3. It's checked before the trie loads, so corrections are available
///      during keyboard cold start.
public func applyOverride(profile: LanguageProfile, word: String) -> String? {
    let lowered = word.lowercased()
    guard let override = profile.overrides[lowered] else { return nil }
    let isCapitalized = word.first?.isUppercase == true
    return isCapitalized ? override.capitalized : override
}

/// Looks up `word` in `profile.contextOverrides` for `previousWord` and returns the
/// forced correction with case preserved, or `nil` when no override applies.
///
/// The previous word is matched on its part after the last apostrophe, so
/// `qu'il ma` and `s'il ma` read as `il ma`.
///
/// WHY a table and not the n-grams: the bigram store keeps the 16 most frequent
/// followers of each word, so a zero score says "rare", not "impossible". After
/// `il`, `ma` and `la` both score zero, and only one of them is wrong (#500).
public func applyContextOverride(profile: LanguageProfile, previousWord: String, word: String) -> String? {
    let previous = previousWord.lowercased()
    let key = previous.lastIndex(of: "'").map { String(previous[previous.index(after: $0)...]) } ?? previous
    guard let override = profile.contextOverrides[key]?[word.lowercased()] else { return nil }
    let isCapitalized = word.first?.isUppercase == true
    return isCapitalized ? override.prefix(1).uppercased() + override.dropFirst() : override
}
