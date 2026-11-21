// DictusCore/Sources/DictusCore/SpatialDecoder/SpatialTouchBuffer.swift
import CoreGraphics
import Foundation

/// Where the finger landed for each character of the token in front of the cursor (#1011).
///
/// The keyboard tells the buffer what the token reads after each keystroke, and the
/// buffer keeps a tap only while its characters are exactly that token. Anything it did
/// not see (a cursor move, a suggestion tap, a paste, a long-press accent) makes the two
/// disagree, and the buffer starts over at the next word instead of guessing.
///
/// WHY it checks against the document rather than tracking every edit: the bridge has a
/// dozen ways to change the text, and an edit the buffer missed would hand the decoder
/// taps that belong to other letters. Comparing with the document makes a missed edit
/// cost one undecoded word, never a wrong one.
public struct SpatialTouchBuffer: Equatable {
    public private(set) var text: [Character] = []
    public private(set) var points: [CGPoint] = []
    /// The letter keys the taps were made on, from the word's first tap.
    public private(set) var keys: SpatialDecoder.Keys?

    public init() {}

    /// The token in front of the cursor: what follows the last whitespace in `context`.
    public static func token(before context: String?) -> String {
        guard let context else { return "" }
        guard let space = context.lastIndex(where: { $0.isWhitespace }) else { return context }
        return String(context[context.index(after: space)...])
    }

    /// A key typed `typed` (one character) at `point`, and the token now reads `token`.
    /// `replacing` is the French accent key putting `typed` in place of the vowel before
    /// it ("e" -> "é"): the vowel keeps its own tap, the accent key's is not a letter's.
    public mutating func typed(
        _ typed: String, at point: CGPoint?, keys: SpatialDecoder.Keys?, token: String, replacing: Bool = false
    ) {
        let now = Array(token)
        guard let point, typed.count == 1 else { return reset(now) }
        if replacing {
            guard now.count == text.count, !text.isEmpty, Array(now.dropLast()) == Array(text.dropLast()),
                  now.last.map(String.init) == typed else { return reset(now) }
            text = now
        } else if now.count == text.count + 1, Array(now.dropLast()) == text, now.last.map(String.init) == typed {
            text = now
            points.append(point)
        } else if now == Array(typed) {
            text = now
            points = [point]
            self.keys = keys
        } else {
            return reset(now)
        }
        if self.keys == nil { self.keys = keys }
    }

    /// A backspace, after which the token reads `token`.
    public mutating func deleted(token: String) {
        let now = Array(token)
        if now.count + 1 == text.count, Array(text.dropLast()) == now, !points.isEmpty {
            text = now
            points.removeLast()
        } else {
            reset(now)
        }
    }

    /// The taps of `word` when the buffer ends with it (case-insensitive) and holds a tap
    /// for each of its characters; nil otherwise.
    public func taps(for word: String) -> [CGPoint]? {
        let w = Array(word.lowercased())
        guard !w.isEmpty, points.count == text.count, text.count >= w.count,
              Array(text.suffix(w.count)).map({ Character($0.lowercased()) }) == w else { return nil }
        return Array(points.suffix(w.count))
    }

    public mutating func clear() { reset([]) }

    /// Starts over. A token the buffer did not see being typed is marked by text without
    /// points, so nothing typed after it in the same token is decoded either.
    private mutating func reset(_ now: [Character]) {
        text = now
        points = []
        keys = nil
    }
}
