// DictusCore/Sources/DictusCore/AdaptiveTouch/AdaptiveTouchLabels.swift
//
// Ported from Hex (github.com/anomalyco/hex, branch dev, commit be2f394,
// ios/HEXShared/FullKeyboard/AdaptiveTouchLabels.swift: `AdaptiveTouchTap` and
// `AdaptiveTouchSpans`), MIT, Copyright (c) 2026 Christopher Langton (#1014).
//
// Kept as Hex has it: a tap teaches only with evidence of the letter meant, and only once
// the next word shows the word stood; an autocorrection left in place teaches nothing;
// an erased tap retyped as a neighbour is labelled with the letter that replaced it.
// Adapted to Dictus: a word is compared with its taps on its letters alone, lowercase and
// without accents, so a vowel accented by the AZERTY accent key ("é" from the "e" tap) and
// an elision typed with it ("j'ai": the apostrophe has no tap) still teach; and an undo
// restores the word with its space, so it turns the word's pending span into a kept one
// instead of reopening it.
import CoreGraphics
import Foundation

/// One letter typed with a tap, for Adaptive touch: where the finger was (the decoder's
/// coordinates), the letter its key typed and, when it retyped a letter just erased at the
/// same place in the word, that erased tap.
public struct AdaptiveTouchTap: Equatable {
    public var x: Float
    public var y: Float
    public var letter: Character
    /// False when the touch slid onto its key: its point says nothing about where you aim.
    public var usable: Bool
    public var erasedX: Float = 0
    public var erasedY: Float = 0
    public var erasedLetter: Character?

    public init(x: Float, y: Float, letter: Character, usable: Bool) {
        self.x = x
        self.y = y
        self.letter = letter
        self.usable = usable
    }

    var point: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
    var erasedPoint: CGPoint { CGPoint(x: CGFloat(erasedX), y: CGFloat(erasedY)) }
}

/// What Adaptive touch keeps of what you type, in memory only: the word being typed and the
/// word finished before it, as taps and the letters they ended up as, until the next word
/// shows it stood (`finish`). Anything it can't follow (the host changed the text, a new
/// geometry, `timeout`) is forgotten, and a tap teaches only with evidence of the letter
/// you meant:
///
/// - a word left as typed (weak), but only letters the key under the finger typed;
/// - a suggestion of the same length picked in its place, changing at most two letters;
/// - a word kept as typed over an autocorrection, by undoing it or tapping it, and a letter
///   erased and retyped at the same place (strong): the erased tap is labelled with the
///   letter that replaced it.
///
/// An autocorrection left in place teaches nothing: a model can't confirm itself.
public struct AdaptiveTouchSpans: Equatable {
    public enum Outcome: Equatable {
        /// Left as typed.
        case typed
        /// Kept as typed over an autocorrection.
        case kept
        /// A suggestion of the same length went in its place.
        case picked
        /// Autocorrect replaced it: nothing to learn, kept only for its undo.
        case corrected
    }

    public struct Span: Equatable {
        public var taps: [AdaptiveTouchTap]
        /// The letters the word ended as, one per tap (the typed ones when corrected, for undo).
        public var labels: [Character]
        /// The correction's letters when autocorrect replaced it.
        public var correction: [Character] = []
        /// The letters of the last word the document shows for it when a text replacement
        /// expanded it (`qqc` → `Quelque chose`: `chose`), which is what shows it stood.
        /// Empty otherwise: the document shows `labels`.
        public var shown: [Character] = []
        public var outcome: Outcome
        public var geometry: UInt64
        public var at: TimeInterval
        /// The word was erased and retyped back to its length, changing at most two letters.
        public var retyped: Bool
    }

    static let wordLimit = 32
    static let erasedLimit = 8
    static let timeout: TimeInterval = 30
    static let changedLetterLimit = 2

    public private(set) var word: [AdaptiveTouchTap] = []
    public private(set) var pending: [Span] = []
    private var erased: [(position: Int, tap: AdaptiveTouchTap)] = []
    private var wordGeometry: UInt64 = 0
    private var wordKept = false
    private var wordBroken = false
    /// The word's length when the current run of erasing began.
    private var eraseBase: Int?
    private var lastAt: TimeInterval = 0

    public init() {
        word.reserveCapacity(Self.wordLimit)
        erased.reserveCapacity(Self.erasedLimit)
    }

    public static func == (a: AdaptiveTouchSpans, b: AdaptiveTouchSpans) -> Bool {
        a.word == b.word && a.pending == b.pending && a.wordGeometry == b.wordGeometry
    }

    public var isEmpty: Bool { word.isEmpty && pending.isEmpty }

    public mutating func forget() {
        word.removeAll(keepingCapacity: true)
        erased.removeAll(keepingCapacity: true)
        pending.removeAll(keepingCapacity: true)
        resetWordState()
    }

    private mutating func resetWordState() {
        wordKept = false
        wordBroken = false
        eraseBase = nil
    }

    /// A letter key typed its letter. No allocation: the word's storage is reserved.
    public mutating func typed(_ tap: AdaptiveTouchTap, geometry: UInt64, now: TimeInterval) {
        if !word.isEmpty, geometry != wordGeometry || now - lastAt > Self.timeout {
            word.removeAll(keepingCapacity: true)
            erased.removeAll(keepingCapacity: true)
            resetWordState()
        }
        if word.isEmpty { wordGeometry = geometry }
        lastAt = now
        guard word.count < Self.wordLimit else {
            wordBroken = true
            return
        }
        var tap = tap
        if let i = erased.lastIndex(where: { $0.position == word.count }) {
            let gone = erased[i].tap
            tap.erasedX = gone.x
            tap.erasedY = gone.y
            tap.erasedLetter = gone.letter
            erased.remove(at: i)
        }
        word.append(tap)
    }

    /// A character of the word was typed without a tap Adaptive touch can read (a popup
    /// accent, a swiped key): the word teaches nothing.
    public mutating func untracked() {
        wordBroken = true
    }

    /// Backspace is about to delete the last character of `before`.
    public mutating func willDelete(before: String?) {
        guard let last = before?.last else { return forget() }
        if last.isLetter {
            guard !word.isEmpty else { return forget() }
            if eraseBase == nil { eraseBase = word.count }
            var tap = word.removeLast()
            wordKept = false
            // A retyped letter erased again: its first attempt is the touch that meant it.
            if let letter = tap.erasedLetter {
                tap = AdaptiveTouchTap(x: tap.erasedX, y: tap.erasedY, letter: letter, usable: true)
            }
            guard tap.usable else { return }
            if erased.count == Self.erasedLimit { erased.remove(at: 0) }
            erased.append((word.count, tap))
        } else if last == " ", word.isEmpty, let span = pending.last,
                  span.outcome == .typed || span.outcome == .kept,
                  let before, Self.endsWithWord(Substring(before.dropLast()), span.labels) {
            // Back into the word just finished: it is being typed again.
            pending.removeLast()
            word.append(contentsOf: span.taps)
            wordGeometry = span.geometry
            erased.removeAll(keepingCapacity: true)
            resetWordState()
            wordKept = span.outcome == .kept
        } else {
            forget()
        }
    }

    /// Undo put `original` back in place of the autocorrection just applied, with its
    /// space: the word stands as typed, kept over the correction, once the next one does.
    public mutating func undone(original: String) {
        guard let i = pending.lastIndex(where: { $0.outcome == .corrected }),
              Self.matches(pending[i].taps, original) else { return forget() }
        pending[i].outcome = .kept
        pending[i].labels = pending[i].taps.map(\.letter)
    }

    /// The word being typed ended as `token` (the text after the last space; nil when it
    /// isn't a word) and, when autocorrect replaced it, `corrected`; or, with `picked`, a
    /// suggestion went in its place (`overCorrection`: you tapped what you typed over the fix
    /// space would apply); or, with `expanded`, a text replacement shortcut became its
    /// phrase. A shortcut is typed on purpose, so its taps teach like a word left as typed
    /// (#1031); only the check that it stood reads the phrase. Returns the earlier word this one shows stood: `before`, the text
    /// before the cursor still ending in this word, has it just before; none when autocorrect
    /// is revising the word before now (`previousRevised`, an elision across the space).
    public mutating func finish(
        token: String?, corrected: String? = nil, picked: String? = nil, overCorrection: Bool = false,
        expanded: String? = nil, previousRevised: Bool = false, before: String?, now: TimeInterval
    ) -> [Span] {
        guard !word.isEmpty else {
            // Nothing typed with taps here: the word before it no longer stands next to it.
            pending.removeAll(keepingCapacity: true)
            return []
        }
        let previous = Self.withoutLastWord(before ?? "")
        var stood: [Span] = []
        for span in pending where !previousRevised && now - span.at <= Self.timeout
            && Self.endsWithWord(previous, span.shown.isEmpty ? span.labels : span.shown) {
            stood.append(span)
        }
        pending.removeAll(keepingCapacity: true)
        if var span = span(token: token, corrected: corrected, picked: picked, overCorrection: overCorrection, now: now) {
            if corrected == nil, picked == nil, let expanded { span.shown = Self.lastWordLetters(expanded) }
            pending.append(span)
        }
        word.removeAll(keepingCapacity: true)
        erased.removeAll(keepingCapacity: true)
        resetWordState()
        return stood
    }

    /// The host changed the text or moved the cursor: what can't be followed any more goes.
    public mutating func hostChanged(before: String?, token: String?) {
        if !word.isEmpty {
            guard !wordBroken, let token, Self.matches(word, token) else { return forget() }
        } else if let span = pending.last {
            // Dictus hears its own edits here too: a word it just corrected stands as corrected.
            let text = Self.trailingSeparatorsRemoved(Substring(before ?? ""))
            if !Self.endsWithWord(text, span.labels), !Self.endsWithWord(text, span.correction),
               !Self.endsWithWord(text, span.shown) { forget() }
        }
    }

    private func span(token: String?, corrected: String?, picked: String?, overCorrection: Bool, now: TimeInterval) -> Span? {
        guard !wordBroken, let token, Self.matches(word, token) else { return nil }
        let typed = word.map(\.letter)
        var outcome: Outcome = wordKept ? .kept : .typed
        var labels = typed
        if corrected != nil {
            outcome = .corrected
        } else if let picked {
            let letters = Self.letters(picked)
            if letters == typed {
                if overCorrection { outcome = .kept }
            } else {
                let changed = zip(letters, typed).filter { $0 != $1 }.count
                guard letters.count == typed.count, changed <= Self.changedLetterLimit else { return nil }
                outcome = .picked
                labels = letters
            }
        }
        let changes = word.filter { $0.erasedLetter != nil && $0.erasedLetter != $0.letter }.count
        let retyped = eraseBase == word.count && changes <= Self.changedLetterLimit
        var span = Span(taps: word, labels: labels, outcome: outcome, geometry: wordGeometry, at: now, retyped: retyped)
        if let corrected { span.correction = Self.letters(corrected) }
        return span
    }

    /// A word's letters as its taps typed them: lowercase, without accents, letters only.
    public static func letters(_ text: String) -> [Character] {
        SpatialDecoder.withoutAccents(text.lowercased()).filter(\.isLetter).map { $0 }
    }

    /// Whether `taps` typed exactly `text`'s letters.
    static func matches(_ taps: [AdaptiveTouchTap], _ text: String) -> Bool {
        let letters = Self.letters(text)
        return !letters.isEmpty && letters == taps.map(\.letter)
    }

    /// `text` without its last space-separated token and the spaces before it.
    static func withoutLastWord(_ text: String) -> Substring {
        var s = Substring(text)
        while let last = s.last, !last.isWhitespace { s = s.dropLast() }
        while let last = s.last, last.isWhitespace { s = s.dropLast() }
        return s
    }

    static func trailingSeparatorsRemoved(_ text: Substring) -> Substring {
        var s = text
        while let last = s.last, !last.isLetter { s = s.dropLast() }
        return s
    }

    /// The letters of `text`'s last space-separated token.
    static func lastWordLetters(_ text: String) -> [Character] {
        letters(text.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? "")
    }

    /// Whether the last space-separated token of `text` is the word `letters`.
    static func endsWithWord(_ text: Substring, _ letters: [Character]) -> Bool {
        guard !letters.isEmpty else { return false }
        let token = text.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
        return Self.letters(token) == letters
    }
}
