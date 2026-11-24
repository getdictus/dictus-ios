// DictusCore/Sources/DictusCore/SpatialDecoder/SwipedWord.swift
//
// After Hex's `FullKeyboardEngine.SwipedWord` and `replaceSwipedWord`
// (anomalyco/hex@b3a95517b7039e53591d640b5b461c2a62e35348,
// ios/HEXShared/FullKeyboard/Engine/FullKeyboardEngine+SwipeTyping.swift and
// Engine/FullKeyboardEngine.swift; MIT, Copyright (c) 2026 Christopher Langton, full
// notice in SwipeTypingText.swift) (#948). Reduced to the values: Hex's host-echo
// check and its retries are left out, and the document is read by the caller.
import Foundation

/// The word a swipe just typed, until anything else edits the text: Delete takes it back
/// whole, space and punctuation never autocorrect it, and the bar offers its other readings,
/// any of which takes its place.
public struct SwipedWord: Equatable, Sendable {
    /// What the swipe put in: a space when one was needed, then the word.
    public private(set) var inserted: String
    public private(set) var word: String
    /// Its other readings, cased as the word is, best first; at most three.
    public private(set) var alternatives: [String]

    public init(word: String, addedSpace: Bool, alternatives: [String]) {
        self.word = word
        inserted = (addedSpace ? " " : "") + word
        self.alternatives = Array(alternatives.filter { $0 != word }.prefix(3))
    }

    /// Whether the text before the cursor still ends with what the swipe put in. Anything
    /// else (a cursor moved, a host that changed the text) leaves the record stale.
    public func isBeforeCursor(_ before: String?) -> Bool {
        guard let before else { return false }
        return before.hasSuffix(inserted)
    }

    /// The characters Delete removes to take the swipe back: the word and the space it
    /// added. Nil when the text no longer ends with them, so Delete deletes one character.
    public func deletionCount(before: String?) -> Int? {
        isBeforeCursor(before) ? inserted.count : nil
    }

    /// Another reading in the word's place.
    public struct Replacement: Equatable, Sendable {
        /// Characters to delete before the cursor: the word, not the space before it.
        public let deleteCount: Int
        public let insert: String
        /// The record afterwards, whose readings now include the word it replaced.
        public let record: SwipedWord
    }

    /// `reading` in the word's place; nil when the text no longer ends with the word.
    public func replacing(with reading: String, before: String?) -> Replacement? {
        guard let before, before.hasSuffix(word), reading != word else { return nil }
        var record = self
        record.inserted = String(inserted.dropLast(word.count)) + reading
        record.alternatives = Array(([word] + alternatives.filter { $0 != reading }).prefix(3))
        record.word = reading
        return Replacement(deleteCount: word.count, insert: reading, record: record)
    }
}

/// The words swipe typing reads beside the model's.
public enum SwipeExtraWords {
    /// English contractions, as you'd see them. Google Books splits "don't" into "do n't",
    /// so the model barely counts them: they are read as extra words at
    /// `SwipeDecoder.contractionCost`.
    ///
    /// Dictus's own list, for swipe only: `englishProfile`'s contractions (what autocorrect
    /// restores) plus the common ones autocorrect leaves alone because the bare spelling is a
    /// word too ("wont", "lets", "well"). A swipe offers several readings and the word before
    /// picks between them, so the ambiguity that keeps them out of autocorrect does not
    /// apply. Nothing here reaches autocorrect: `englishProfile` is unchanged.
    public static var englishContractions: [String] {
        let profile = englishProfile.overrides.values.filter { $0.contains("'") }
            + englishProfile.contextualContractions.map(\.contraction)
        let forms = profile + swipeOnlyEnglish
        return Set(forms.map { $0.hasPrefix("i'") ? "I" + $0.dropFirst() : $0 }).sorted()
    }

    /// The common contractions `englishProfile` leaves out (bench of #1050: "won't" read as
    /// "wont" 18 times on Hex's test paths).
    static let swipeOnlyEnglish = [
        "won't", "let's", "we'll", "we'd", "we're", "he'd", "she'd", "he'll", "she'll",
        "i'll", "i'd", "it's", "it'd", "ain't", "where's", "how's", "who'd", "there'll",
        "mustn't", "needn't", "y'all"
    ]
}
