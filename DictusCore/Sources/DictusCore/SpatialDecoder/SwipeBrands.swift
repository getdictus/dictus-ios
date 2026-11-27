// DictusCore/Sources/DictusCore/SpatialDecoder/SwipeBrands.swift
import Foundation

/// Well-known brand names a swipe reads in their casing (#1090): « Apple », « Samsung »,
/// « GitHub » mid-sentence, before the user has typed them twice.
///
/// WHY a list per language, not `CuratedNames`: each name is also a word somewhere
/// (« apple » in English, « google » the verb), so tap typing cannot recase it everywhere.
/// A language reads a name only where its swipe model lacks the word: where the model has
/// it, the model decides, and a swipe of that word reads as it did before.
///
/// WHY filtered offline: a name the language's model lacks can still take the place of a
/// dictionary word on the same path (« Android » over « androïde » in French). The rule
/// that drops those (v3, in `SwipeBrandList.swift`'s header) runs on the swipe bench before
/// the list is written, so the keyboard reads only the names that passed it and decides
/// nothing at run time.
public enum SwipeBrands {

    /// The brand names `language`'s swipe reads, in their casing; empty for a language
    /// with no list.
    public static func names(for language: String) -> [String] {
        byLanguage[language] ?? []
    }
}
