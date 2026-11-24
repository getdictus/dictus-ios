// Derived from Hex (github.com/anomalyco/hex, branch dev @ 35b6f3c,
// ios/HEXShared/FullKeyboard/DeleteWordSwipe.swift, `wordLength(before:)`), MIT,
// Copyright (c) 2026 Christopher Langton.
// Dictus's changes (#609): French joiners (an apostrophe or a hyphen between letters keeps
// "aujourd'hui" and "peut-être" whole), digits keep "12,5" and "12:30" whole, an emoji is a
// word on its own, a line break is a step of its own, and the scan says when it ran into the
// start of what the host shared, since `documentContextBeforeInput` can be truncated.

import Foundation

/// What one step of the delete swipe removes: the last word before the cursor, with the
/// spaces and punctuation after it, as Option-Delete counts them on a Mac
/// ("Bonjour, monde. " ends in "monde. ").
///
/// WHY this rule rather than the held backspace's (#419, `handleWordDelete`): that one
/// splits on spaces only, so "monde." went in one step and "monde. " in two, and a
/// paragraph break went with the word in front of it. Here the swipe is the user choosing
/// exactly how much goes, one step per key width, so each step has to land where a reader
/// would say a word ends. The held backspace keeps its own rule, which #419 measured.
///
/// French: the apostrophe of an elision is inside the word, so "l'homme" and "aujourd'hui"
/// are one step each, as they are one unit when spoken. Splitting "l'homme" would leave a
/// two-letter "l'" as a step of its own, which is a step nobody aims for.
public enum DeleteWordBoundary {

    /// Where a scan is in a step: still in the spaces and punctuation after the word, or
    /// inside the word.
    public enum Phase: Equatable {
        case separators
        case word
    }

    /// One step's extent.
    public struct Span: Equatable {
        /// Graphemes to delete: one `deleteBackward()` each.
        public let length: Int
        /// The scan reached the start of the context while still inside the step, in this
        /// phase: the host may hold more of the same word before what it shared. Nil when
        /// the step's start was seen.
        public let continuesIn: Phase?

        public init(length: Int, continuesIn: Phase?) {
            self.length = length
            self.continuesIn = continuesIn
        }
    }

    /// The step at the end of `before`, nil when nothing is before the cursor.
    public static func lastWord(in before: String) -> Span? {
        guard !before.isEmpty else { return nil }
        return scan(before, from: .separators, following: nil)
    }

    /// The rest of a step that ran into the start of the context: `before` is what the host
    /// shares now, `phase` the step's `continuesIn`, and `following` the first character the
    /// step already deleted. Length 0 when the step's start is right at the cursor.
    public static func continuation(in before: String, from phase: Phase, following: Character) -> Span {
        scan(before, from: phase, following: following)
    }

    // MARK: - Scan

    private static func scan(_ before: String, from start: Phase, following: Character?) -> Span {
        let chars = Array(before)
        let count = chars.count
        var index = count
        var phase = start

        // A line break is a step of its own: a paragraph does not vanish with the word in
        // front of it.
        if phase == .separators, following == nil, let last = chars.last, last.isNewline {
            return Span(length: 1, continuesIn: nil)
        }

        if phase == .separators {
            while index > 0, !startsWord(chars[index - 1]), !chars[index - 1].isNewline {
                index -= 1
            }
            if index == 0 { return Span(length: count, continuesIn: .separators) }
            if chars[index - 1].isNewline { return Span(length: count - index, continuesIn: nil) }
            phase = .word
        }

        // Continuing a word the previous read cut short: `following` is its first letter.
        let continuingWord = start == .word
        // An emoji is a word on its own, and never part of the letters around it.
        if continuingWord, let following, isEmoji(following) {
            return Span(length: 0, continuesIn: nil)
        }
        if !continuingWord, isEmoji(chars[safe: index - 1]) {
            return Span(length: count - index + 1, continuesIn: nil)
        }

        let wordEnd = index
        while index > 0 {
            let character = chars[index - 1]
            if isWordCharacter(character) {
                index -= 1
                continue
            }
            // Only between two parts of a word: a leading or trailing apostrophe is a quote.
            let after: Character? = index < count ? chars[index] : following
            if index < wordEnd || continuingWord, let after,
               isJoiner(character, before: chars[safe: index - 2], after: after, atStart: index == 1) {
                index -= 1
                continue
            }
            return Span(length: count - index, continuesIn: nil)
        }
        return Span(length: count, continuesIn: .word)
    }

    // MARK: - Characters

    /// Letters, digits and the underscore make up a word; an emoji does not join them.
    static func isWordCharacter(_ character: Character?) -> Bool {
        guard let character, !isEmoji(character) else { return false }
        return character.isLetter || character.isNumber || character == "_"
    }

    /// Whether `character` begins a word when met after spaces and punctuation.
    private static func startsWord(_ character: Character) -> Bool {
        isWordCharacter(character) || isEmoji(character)
    }

    /// An emoji as the user sees one: emoji presentation by default, or text presentation
    /// turned into an emoji by U+FE0F ("❤️", "1️⃣"). A bare digit or "©" is not one.
    static func isEmoji(_ character: Character?) -> Bool {
        guard let character else { return false }
        let scalars = character.unicodeScalars
        if scalars.contains(where: { $0.properties.isEmojiPresentation }) { return true }
        guard scalars.count > 1, let first = scalars.first, first.properties.isEmoji else { return false }
        return scalars.contains { $0.value == 0xFE0F }
    }

    private static let apostrophes: Set<Character> = ["'", "\u{2019}", "\u{02BC}"]
    private static let hyphens: Set<Character> = ["-", "\u{2010}", "\u{2011}"]
    private static let numberJoiners: Set<Character> = [",", ".", ":"]

    /// An apostrophe or a hyphen between letters ("aujourd'hui", "peut-être"), or a decimal
    /// or time separator between digits ("12,5", "12:30"). `atStart` is the character at the
    /// start of the context, whose letter before it the host may not have shared.
    private static func isJoiner(_ character: Character, before: Character?, after: Character, atStart: Bool) -> Bool {
        if apostrophes.contains(character) || hyphens.contains(character) {
            guard isWordCharacter(after) else { return false }
            return atStart || isWordCharacter(before)
        }
        if numberJoiners.contains(character) {
            guard let before, before.isNumber, after.isNumber, !isEmoji(before), !isEmoji(after) else { return false }
            return true
        }
        return false
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
