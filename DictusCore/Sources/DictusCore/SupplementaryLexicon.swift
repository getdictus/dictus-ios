// DictusCore/Sources/DictusCore/SupplementaryLexicon.swift
// Contact names and iOS text replacements for autocorrect (issue #873).
//
// WHY: Apple's keyboard never corrects a contact name and expands the user's
// text replacements; Dictus corrected "Zofiak" to "Social" and "qqc" to "Sac".
// The keyboard extension reads the entries with
// `UIInputViewController.requestSupplementaryLexicon`, which needs neither
// Contacts permission nor Full Access, and hands the pairs to this type. Kept
// free of UIKit so the rules run under `swift test`.

import Foundation

public struct SupplementaryLexicon: Equatable {

    public enum Decision: Equatable {
        /// The word belongs to the user: insert it as typed, never correct it.
        case keep
        /// Insert this text instead of the typed word, through the autocorrect
        /// commit path (undo chip included).
        case replace(with: String)
    }

    public static let empty = SupplementaryLexicon(entries: [])

    /// Lowercased shortcut -> phrase, for entries whose shortcut differs from
    /// the phrase (`qqc` -> "quelque chose").
    private let shortcuts: [String: String]
    /// Lowercased word -> its lexicon casing, for every single-word phrase
    /// (contact first and last names, phrase-only replacements).
    private let words: [String: String]

    /// - Parameter entries: `UILexiconEntry` pairs. On duplicate keys the
    ///   first entry wins.
    public init(entries: [(userInput: String, documentText: String)]) {
        var shortcuts: [String: String] = [:]
        var words: [String: String] = [:]
        for entry in entries where !entry.userInput.isEmpty && !entry.documentText.isEmpty {
            let input = entry.userInput.lowercased()
            let text = entry.documentText
            if input != text.lowercased(), shortcuts[input] == nil {
                shortcuts[input] = text
            }
            // A typed word never holds whitespace, so a multi-word phrase can
            // only be reached through its shortcut.
            if !text.contains(where: { $0.isWhitespace }), words[text.lowercased()] == nil {
                words[text.lowercased()] = text
            }
        }
        self.shortcuts = shortcuts
        self.words = words
    }

    public var isEmpty: Bool { shortcuts.isEmpty && words.isEmpty }
    public var shortcutCount: Int { shortcuts.count }
    public var wordCount: Int { words.count }

    /// What autocorrect must do with `word`, or `nil` when the lexicon does
    /// not know it and the normal correction pipeline decides.
    ///
    /// - A shortcut is replaced by its phrase, even when it is a dictionary
    ///   word, as Apple does. A shortcut typed with a leading capital (sentence
    ///   autocap) capitalizes the phrase: `Qqc` -> "Quelque chose".
    /// - A lexicon word is kept. Typed all lowercase, it takes the lexicon
    ///   casing (`zofiak` -> "Zofiak"), unless the dictionary knows it: a
    ///   contact named "Pierre" must leave "une pierre" alone.
    public func decision(for word: String, isDictionaryWord: @autoclosure () -> Bool) -> Decision? {
        guard !word.isEmpty else { return nil }
        let key = word.lowercased()
        if let phrase = shortcuts[key] {
            let capitalize = word.first?.isUppercase == true
            return .replace(with: capitalize ? phrase.prefix(1).uppercased() + phrase.dropFirst() : phrase)
        }
        guard let casing = words[key] else { return nil }
        if word == key, casing != word, !isDictionaryWord() {
            return .replace(with: casing)
        }
        return .keep
    }
}
