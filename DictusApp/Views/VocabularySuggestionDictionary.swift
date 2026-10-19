// DictusApp/Views/VocabularySuggestionDictionary.swift
// What counts as an ordinary word for the vocabulary suggestions (#512 trial).
import UIKit
import DictusCore

/// The `isKnownWord` predicate `VocabularySuggestionMiner` is built with.
///
/// ### Why `UITextChecker`
///
/// The keyboard's tries ship inside the extension and need its C++ engine to read.
/// The app process has the system spell checker, which covers every language Dictus
/// ships and is already the keyboard's completion source.
///
/// ### Which languages
///
/// The languages the History was dictated in, the active one, and English always.
/// English because a French or German speaker dictates English technical words
/// (`meeting`, `build`) that are not misrecognitions. Not every language Dictus
/// ships: a German dictionary would accept a garbled French word that happens to be
/// German, and every word it accepts is a suggestion lost.
///
/// ### Words the user typed
///
/// A word the keyboard learned (`UserDictionary`) is one the user wrote themselves
/// twice: its spelling is theirs, so seeing it in a dictation is not a mistake. It
/// never surfaces as an unknown word; the paired path uses it as the correct spelling
/// instead (`VocabularySuggestionMiner.pairedSuggestions`).
@MainActor
struct VocabularySuggestionDictionary {

    private let checker = UITextChecker()
    private let checkerLanguages: [String]

    init(records: [TranscriptionRecord]) {
        var languages: Set<SupportedLanguage> = [.english, .active]
        for record in records {
            if let language = record.supportedLanguage {
                languages.insert(language)
            } else if record.language == TranscriptionRecord.autoDetectedCode {
                // Auto-detect gives no single language: every one Dictus ships may
                // have been spoken.
                languages.formUnion(SupportedLanguage.allCases)
            }
        }
        let available = UITextChecker.availableLanguages
        checkerLanguages = languages
            .sorted { $0.rawValue < $1.rawValue }
            .compactMap { language in available.first { $0.hasPrefix(language.rawValue) } }
    }

    /// Known as written or in lowercase (a capital at the start of a sentence is not
    /// part of the word), in any of the languages, or learned by the keyboard.
    func isKnown(_ word: String) -> Bool {
        if UserDictionary.shared.isLearned(word) { return true }
        let candidates = word == word.lowercased() ? [word] : [word, word.lowercased()]
        for candidate in candidates {
            let range = NSRange(location: 0, length: (candidate as NSString).length)
            for language in checkerLanguages {
                let misspelled = checker.rangeOfMisspelledWord(
                    in: candidate, range: range, startingAt: 0, wrap: false, language: language
                )
                if misspelled.location == NSNotFound { return true }
            }
        }
        return false
    }
}
