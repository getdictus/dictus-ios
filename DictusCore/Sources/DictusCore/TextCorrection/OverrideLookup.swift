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
///
/// `profile.misspellings` is read the same way: a word removed from the word
/// list as a known misspelling (`teh`) goes to its listed target (`the`), not to
/// whatever the trie finds nearby (`ten`, #995).
public func applyOverride(profile: LanguageProfile, word: String) -> String? {
    let lowered = word.lowercased()
    guard let override = profile.overrides[lowered] ?? profile.misspellings[lowered] else { return nil }
    let isCapitalized = word.first?.isUppercase == true
    return isCapitalized ? override.capitalized : override
}
