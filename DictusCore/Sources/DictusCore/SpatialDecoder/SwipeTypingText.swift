// DictusCore/Sources/DictusCore/SpatialDecoder/SwipeTypingText.swift
//
// Ported from Hex (anomalyco/hex@b3a95517b7039e53591d640b5b461c2a62e35348:
// `SwipeTyping.needsSpace`, `slidTapReach`, `word(_:startsAndEndsWith:)` from
// ios/HEXShared/FullKeyboard/SwipeTyping.swift; `swipeJoiners`, the strip's order and the
// casing from ios/HEXShared/FullKeyboard/Engine/FullKeyboardEngine+SwipeTyping.swift) (#948).
//
// MIT License
//
// Copyright (c) 2026 Christopher Langton
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// What the port changed: Hex's engine methods are free functions on values here, so the
// keyboard's bridge and the tests call the same rules. The automatic capital the swipe's own
// space brings follows Dictus's autocapitalisation (`DictusKeyboardBridge
// .updateCapitalization`), not Hex's. Left out: Hex's rare-name ranking and name casing
// (they need Hex's dictionary check), its text-replacement readings, and `SwipeRetries`.
import CoreGraphics
import Foundation

/// The text rules of swipe typing: when a swipe begins, the space before a swiped word, its
/// capital, what goes against it, and how the bar offers its other readings.
public enum SwipeTypingText {

    // MARK: - Whether the keyboard swipes at all

    /// Why the keyboard does or does not build its swipe controller. Anything but `.on`
    /// leaves the keyboard exactly as it is without swipe typing: no controller, no stroke
    /// kept, a drag stays a slide to another key.
    public enum Availability: String, Sendable {
        /// The switch is off (its default).
        case off
        /// The switch is on, but this is the App Store build, or the app recorded no
        /// distribution: the Experiments page that set it does not exist here.
        case appStore
        /// No swipe model for the keyboard's language: only en and fr ship one (#1013).
        case language
        case on
    }

    /// The languages with a swipe model in the keyboard's bundle (`en.hextm`, `fr.hextm`).
    public static let languages: Set<SupportedLanguage> = [.english, .french]

    /// Whether swipe typing acts, from the switches as the keyboard reads them and the
    /// keyboard's language.
    public static func availability(_ settings: KeyboardFeatureSettings, language: SupportedLanguage) -> Availability {
        guard settings.swipeTyping else { return .off }
        guard settings.isSwipeTypingEffective else { return .appStore }
        guard languages.contains(language) else { return .language }
        return .on
    }

    // MARK: - The gesture

    /// Whether a letter touch that went down at `start` and is now at `point` is a swipe: it
    /// travelled more than one key pitch (`pitch`, a letter key's width and gap). Taps, holds
    /// and slides to the next key stay under it.
    public static func isSwipe(from start: CGPoint, to point: CGPoint, pitch: CGFloat) -> Bool {
        guard pitch > 0 else { return false }
        return hypot(point.x - start.x, point.y - start.y) > pitch
    }

    /// How far (key pitches) a swipe may go from where it went down and still be a tap that
    /// slid, when it lifts on the key it started on.
    public static let slidTapReach: CGFloat = 1.6

    /// Whether every point of a stroke stays within `slidTapReach` pitches of its first: with
    /// a lift on the starting key, a tap dragged a little too far and back ("a" read as "as").
    public static func staysNearStart(_ points: [CGPoint], pitch: CGFloat) -> Bool {
        guard let first = points.first, pitch > 0 else { return false }
        let reach = pitch * slidTapReach
        return points.allSatisfy { hypot($0.x - first.x, $0.y - first.y) <= reach }
    }

    /// Whether `word` begins and ends on `letter`'s key ("lol" on l, "pop" on p): a word a
    /// swipe that comes back to its key can mean.
    public static func word(_ word: String, startsAndEndsWith letter: String) -> Bool {
        func base(_ character: Character?) -> String? {
            character.map { String($0).lowercased().decomposedStringWithCanonicalMapping.unicodeScalars.first.map(String.init) ?? "" }
        }
        return word.count > 1 && base(word.first) == letter.lowercased() && base(word.last) == letter.lowercased()
    }

    // MARK: - Spacing

    /// Whether a swiped word needs a space before it, as Apple's keyboard adds one: unless
    /// the text before the cursor is empty or ends in a space, a line break, an attachment
    /// (U+FFFC) or opening punctuation (a bracket, an opening quote, ¿ or ¡, or a mark that
    /// starts a word such as @ # /). A straight quote opens when nothing or a space comes
    /// before it.
    public static func needsSpace(before: String?) -> Bool {
        guard let before, let last = before.last else { return false }
        if last.isWhitespace || last.isNewline || last == "\u{FFFC}" || opening.contains(last) { return false }
        if last == "\"" || last == "'" {
            guard let previous = before.dropLast().last else { return false }
            return !(previous.isWhitespace || previous.isNewline || opening.contains(previous))
        }
        return true
    }

    private static let opening: Set<Character> = ["(", "[", "{", "<", "«", "‹", "“", "‘", "„", "¿", "¡", "@", "#", "/"]

    /// What goes against a swiped word, as on Apple's keyboard: closing punctuation and
    /// brackets, an apostrophe, a hyphen and a slash. Anything else tapped right after a
    /// swipe starts the next word, after a space.
    public static let joiners: Set<Character> = [",", ".", "!", "?", ";", ":", ")", "]", "}", "'", "’", "-", "/"]

    /// Whether `typed`, tapped right after a swiped word, goes in after a space ("hello" then
    /// "w" types "hello w") rather than against the word ("hello,").
    public static func startsNextWord(_ typed: String) -> Bool {
        guard let first = typed.first else { return false }
        return !joiners.contains(first) && !first.isWhitespace && !first.isNewline
    }

    /// The word before a swipe's, lowercased as the model spells it, when only spaces (or the
    /// one the swipe will add) come between them: what the decoder weighs its pairs on. Nil
    /// after punctuation or a line break, where the swipe starts afresh.
    public static func previousWord(before: String?) -> String? {
        guard var text = before else { return nil }
        while text.last == " " { text.removeLast() }
        func inWord(_ character: Character) -> Bool { character.isLetter || character == "'" || character == "’" }
        guard let last = text.last, inWord(last) else { return nil }
        let word = String(text.reversed().prefix(while: inWord).reversed())
        return word.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    // MARK: - Capitals

    /// How the host field capitalises, as `UITextAutocapitalizationType` says it (no UIKit
    /// here, so the tests run on the Mac).
    public enum Autocapitalization: Sendable {
        case none, words, sentences, allCharacters
    }

    /// Whether the swiped word starts with a capital. `shifted` is the keyboard's shift as
    /// the finger lifts (manual, or the automatic capital the text before already earned).
    /// Without it, the space the swipe adds may bring one: "Hi." then a swipe types
    /// " There", as the keyboard would capitalise after "Hi. ".
    public static func startsWithCapital(
        shifted: Bool, before: String?, addsSpace: Bool, autocapitalization: Autocapitalization
    ) -> Bool {
        if shifted { return true }
        guard addsSpace else { return false }
        let text = (before ?? "") + " "
        switch autocapitalization {
        case .none:
            return false
        case .allCharacters, .words:
            return true
        case .sentences:
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard let last = trimmed.last else { return true }
            return ".!?".contains(last)
        }
    }

    /// A reading as it goes in: all capitals with caps lock, a capital first letter with
    /// `capital`, else as the model or the extra words spell it ("I'm" keeps its capital).
    public static func cased(_ word: String, capital: Bool, capsLock: Bool) -> String {
        if capsLock { return word.uppercased() }
        guard capital, let first = word.first else { return word }
        return first.uppercased() + word.dropFirst()
    }

    // MARK: - The bar

    /// The bar after a swipe: up to three of its other readings, the likeliest in the centre
    /// slot, where the bar puts its bold correction.
    public static func barOrder(_ alternatives: [String]) -> [String] {
        let items = Array(alternatives.prefix(3))
        return items.count >= 2 ? [items[1], items[0]] + items.dropFirst(2) : items
    }

    /// `readings` once each (ignoring case), the first kept: the decoder can read a model
    /// word and an extra word with the same letters.
    public static func unique(_ readings: [String]) -> [String] {
        var seen = Set<String>()
        return readings.filter { seen.insert($0.lowercased()).inserted }
    }
}
