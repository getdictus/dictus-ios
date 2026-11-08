// DictusCore/Sources/DictusCore/Vocabulary/VocabularySuggestionIgnoreList.swift
// The spellings the user said "Ignore" to in the vocabulary suggestions (#512 trial).
import Foundation

/// What **Ignore** remembers, so a dismissed word does not come back.
///
/// Stored as folded spellings (`VocabularySuggestionMiner.fold`), every form of the
/// suggestion at once: ignoring `parakit` also ignores `Parakít`, and the miner drops
/// a token whose folded form is listed before it groups anything. A new spelling near
/// an ignored one is a new word and can still appear: the ignore is per spelling, not
/// per neighbourhood, which keeps it predictable.
///
/// ### Why App Group `UserDefaults` and not a file
///
/// The vocabulary is a file because a corrupted one would keep rewriting the user's
/// text with no way out (#428). This list only hides suggestions: at worst a word
/// stays hidden. A short array of strings is what `UserDefaults` is for.
public struct VocabularySuggestionIgnoreList {

    private let defaults: UserDefaults

    /// - Parameter defaults: the App Group's by default; the tests pass their own suite.
    public init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    /// Every ignored spelling, folded.
    public var keys: Set<String> {
        Set(defaults.stringArray(forKey: SharedKeys.vocabularySuggestionsIgnored) ?? [])
    }

    /// Remember every form of a suggestion as ignored.
    public func ignore(_ suggestion: VocabularySuggestion) {
        let added = suggestion.forms.map(VocabularySuggestionMiner.fold) + [suggestion.id]
        let stored = keys.union(added)
        defaults.set(stored.sorted(), forKey: SharedKeys.vocabularySuggestionsIgnored)
    }

    /// Remember a step 2 pair as ignored (#512): its id only, so the span can still
    /// be offered for another term, and the term keeps its other suggestions.
    public func ignore(_ pair: VocabularyPair) {
        let stored = keys.union([pair.id])
        defaults.set(stored.sorted(), forKey: SharedKeys.vocabularySuggestionsIgnored)
    }
}
