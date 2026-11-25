// DictusCore/Tests/DictusCoreTests/SwipeDecoderTests.swift
//
// Ported from Hex (anomalyco/hex@b3a95517b7039e53591d640b5b461c2a62e35348,
// ios/HEXMobileTests/SwipeDecoderTests.swift) (#948).
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
// What the port changed: the models are the three the keyboard ships (en, fr, and de,
// Dictus's own; Hex's Spanish and Polish cases have no Dictus model and are left out, and
// Hex does not swipe German, so the German cases are Dictus's), the keys are
// Dictus's letter pages laid out by `KeyPlaneGeometry`, English's contractions are
// Dictus's own (`englishProfile`), and Hex's offensive-word cases became one test of the
// never-suggest hook, since no Hex word list is copied. French words were added.
import CoreGraphics
import XCTest
@testable import DictusCore

/// Swipe typing's decoder (`SwipeDecoder`, #948) on the models the keyboard ships, with
/// swipes drawn through the keys as the keyboard lays them out on an iPhone 17 held upright.
final class SwipeDecoderTests: XCTestCase {
    private static func modelPath(_ language: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusKeyboard/Resources/\(language).hextm").path
    }

    /// English's contractions as Dictus knows them (`englishProfile`), as you'd see them
    /// ("I'm", "don't"), each at Hex's cost of a common contraction.
    static func englishContractions() -> [String] {
        let forms = englishProfile.overrides.values.filter { $0.contains("'") }
            + englishProfile.contextualContractions.map(\.contraction)
        return Set(forms.map { $0.hasPrefix("i'") ? "I" + $0.dropFirst() : $0 }).sorted()
    }

    /// `language`'s decoder on its own letter page, or on `page`'s (German on QWERTY: "en").
    private func decoder(_ language: String, page: String? = nil) throws -> (SwipeDecoder, SpatialDecoder.Keys) {
        let model = try XCTUnwrap(SpatialDecoderModel(path: Self.modelPath(language)), "no \(language).hextm")
        var decoder = SwipeDecoder(model: model)
        if language == "en" {
            decoder.extraWords = SwipeDecoder.ExtraWords(
                Self.englishContractions(), cost: { _ in SwipeDecoder.contractionCost }, model: model, contractions: true
            )
        }
        return (decoder, SwipeKeys.letterPage(page ?? language))
    }

    private func read(
        _ word: String, _ decoder: SwipeDecoder, _ keys: SpatialDecoder.Keys, after previous: String? = nil, offset: CGVector = .zero
    ) -> [String] {
        decoder.decode(SwipePath.through(word, keys: keys, offset: offset), keys: keys, previous: previous).map(\.text)
    }

    func testCleanSwipesReadAsTheirWords() throws {
        let (en, keys) = try decoder("en")
        for word in ["hello", "the", "keyboard", "world", "typing", "people", "because", "quick", "with", "you", "and"] {
            XCTAssertEqual(read(word, en, keys).first, word)
        }
    }

    /// A finger that runs low all the way (as taps land below the keys' centres), or low and
    /// to the left.
    func testASwipeOffTheCentresStillReads() throws {
        let (en, keys) = try decoder("en")
        for off in [CGVector(dx: 0, dy: keys.pitch.height * 0.3), CGVector(dx: -keys.pitch.width / 4, dy: keys.pitch.height / 4)] {
            for word in ["hello", "keyboard", "people", "world", "typing", "because", "quick"] {
                XCTAssertEqual(read(word, en, keys, offset: off).first, word, "\(off)")
            }
        }
    }

    /// French on AZERTY: an accented letter is read on its base letter's key, and the
    /// apostrophe, which no swipe crosses, comes back for free ("aujourd'hui").
    func testFrenchSwipesReadTheirWords() throws {
        let (fr, keys) = try decoder("fr")
        for word in ["bonjour", "merci", "maison", "aujourd'hui", "français", "déjà", "être"] {
            XCTAssertEqual(read(word, fr, keys).first, word)
        }
        XCTAssertEqual(read("bonjour", fr, keys, offset: CGVector(dx: 0, dy: keys.pitch.height * 0.3)).first, "bonjour")
    }

    /// One path, both readings: the accent is not on the path, only the word model tells
    /// them apart.
    func testFrenchAccentsAreReadBesideTheirBaseLetters() throws {
        let (fr, keys) = try decoder("fr")
        XCTAssertTrue(read("tres", fr, keys).prefix(2).contains("très"))
        XCTAssertTrue(read("ete", fr, keys).prefix(4).contains("été"))
    }

    // MARK: - German (de.hextm, Dictus's, #948)

    /// German on QWERTZ, Dictus's default for it, which has keys for ä ö ü and none for ß.
    func testGermanModelLoadsAndKnowsItsLetters() throws {
        let model = try XCTUnwrap(SpatialDecoderModel(path: Self.modelPath("de")), "no de.hextm")
        XCTAssertEqual(model.language, "de")
        for word in ["straße", "groß", "weiß", "schön", "über", "mädchen", "haus", "gehen", "krankenversicherung"] {
            XCTAssertTrue(model.contains(word), word)
        }
        let page = SwipeKeys.letterPage("de")
        for umlaut: Character in ["ä", "ö", "ü"] { XCTAssertNotNil(page.centres[umlaut], "QWERTZ has an \(umlaut) key") }
        XCTAssertNil(page.centres["ß"], "no Dictus layout has an ß key")
        // The model gives ß the base s, so the decoder reads it on the s key.
        let sharp = try XCTUnwrap(model.encode("ß")?.first)
        XCTAssertEqual(model.characters[Int(model.baseCodes[Int(sharp)])], "s")
    }

    /// ß is held on s and swiped through it: s-t-r-a-s-e reads "straße".
    func testGermanßIsReadOnTheSKey() throws {
        let (de, keys) = try decoder("de")
        for word in ["straße", "groß", "weiß", "heißt", "fuß"] {
            XCTAssertEqual(read(word, de, keys).first, word)
        }
        XCTAssertEqual(read("strasse", de, keys).first, "straße", "a path through s, not ß")
    }

    /// On QWERTZ an umlaut is swiped through its own key; on QWERTY or AZERTY, which German
    /// may use, through its base letter's key.
    func testGermanUmlautsAreReadOnTheirKeysOrTheirBaseKeys() throws {
        let (qwertz, keys) = try decoder("de")
        for word in ["schön", "über", "mädchen", "für", "möglich", "grün", "gehen", "zeit"] {
            XCTAssertEqual(read(word, qwertz, keys).first, word, "QWERTZ")
        }
        XCTAssertNotEqual(read("schon", qwertz, keys).first, "schön", "through o, not ö")
        let (qwerty, plain) = try decoder("de", page: "en")
        for word in ["über", "für", "möglich", "grün"] {
            XCTAssertEqual(read(word, qwerty, plain).first, word, "QWERTY")
        }
        // m-a-d-c on QWERTY: the straight line from a to c already runs over d, so the path
        // is also the far commoner "machen", read first; "mädchen" waits in the bar.
        XCTAssertTrue(read("mädchen", qwerty, plain).prefix(4).contains("mädchen"))
        // One path for "schon" and "schön" without an ö key: both common, both offered.
        XCTAssertTrue(read("schon", qwerty, plain).prefix(4).contains("schön"))
    }

    /// A long compound swipes like any word: the decoder's only length limit is 64 keys
    /// (`scratch`), past the word list's longest (25 letters). A compound rarer than the
    /// model's 95,000 words can't be read ("geschwindigkeitsbegrenzung", 26 letters, is
    /// not in the list at all).
    func testGermanCompoundsRead() throws {
        let (de, keys) = try decoder("de")
        for word in ["krankenversicherung", "bundesregierung", "bundesverfassungsgericht", "selbstverständlichkeit"] {
            XCTAssertEqual(read(word, de, keys).first, word)
        }
        XCTAssertFalse(de.model.contains("geschwindigkeitsbegrenzung"))
    }

    /// Google Books splits "don't" into "do n't", so the model barely counts it: the decoder
    /// reads English's contractions as common words.
    func testContractionsReadAsCommonWords() throws {
        let (en, keys) = try decoder("en")
        XCTAssertEqual(read("dont", en, keys).first, "don't")
        XCTAssertEqual(read("im", en, keys).first, "I'm")
    }

    func testTheWordBeforePicksBetweenWordsOnOnePath() throws {
        let (en, keys) = try decoder("en")
        XCTAssertEqual(Array(read("to", en, keys).prefix(2)), ["to", "too"])
        XCTAssertEqual(read("too", en, keys, after: "far").first, "too")
    }

    /// Hex's never-suggest hook, which Hex fills with its offensive words: a blocked word is
    /// never read, and a blocked pair only after its first word.
    func testANeverSuggestedWordIsNeverRead() throws {
        var (en, keys) = try decoder("en")
        XCTAssertEqual(read("hello", en, keys).first, "hello")
        en.neverSuggest = SwipeDecoder.NeverSuggest(["hello", "far too"], model: en.model)
        XCTAssertFalse(read("hello", en, keys).contains("hello"))
        XCTAssertFalse(read("too", en, keys, after: "far").contains("too"))
        XCTAssertTrue(read("too", en, keys, after: "way").contains("too"))
    }

    /// A straight stroke runs over the letters between its ends: "tired" and "tied" draw one
    /// line from i to e, "wire" and "write" one from w to i and back to e. Only where the
    /// finger slowed tells them apart, so a pause on a letter the stroke crosses reads it,
    /// and the same stroke without one doesn't.
    func testAPauseOnALetterTheStrokeCrossesReadsIt() throws {
        let (en, keys) = try decoder("en")
        func read(_ word: String, pausingOn pauses: Set<Int>) -> String? {
            let (points, times) = SwipePath.timed(word, keys: keys, pausingOn: pauses)
            return en.decode(points, times: times, keys: keys).first?.text
        }
        // The pauses are on the letters' keys in order (t i r e d: r is 2).
        XCTAssertEqual(read("tired", pausingOn: [2]), "tired")
        XCTAssertEqual(read("tired", pausingOn: []), "tied", "the same path, no pause on r")
        XCTAssertEqual(read("tire", pausingOn: [2]), "tire")
        XCTAssertEqual(read("tie", pausingOn: []), "tie")
        XCTAssertEqual(read("wire", pausingOn: [2]), "wire")
        XCTAssertEqual(read("write", pausingOn: [1, 3]), "write")
        XCTAssertEqual(read("greet", pausingOn: [1]), "greet")
        XCTAssertEqual(read("get", pausingOn: []), "get")
    }

    /// A pause off the word's keys counts against it: p to t along the top row is "put" when
    /// the finger slows on u and "pit" on i; slowing on o and u offers the much rarer "pout".
    func testAPauseOffTheWordsKeysCountsAgainstIt() throws {
        let (en, keys) = try decoder("en")
        func read(_ word: String, pausingOn pauses: Set<Int>) -> [String] {
            let (points, times) = SwipePath.timed(word, keys: keys, pausingOn: pauses)
            return en.decode(points, times: times, keys: keys).map(\.text)
        }
        XCTAssertEqual(read("put", pausingOn: [1]).first, "put")
        XCTAssertEqual(read("pit", pausingOn: [1]).first, "pit")
        XCTAssertTrue(read("pout", pausingOn: [1, 2]).prefix(3).contains("pout"))
        XCTAssertFalse(read("put", pausingOn: [1]).prefix(3).contains("pout"), "no pause on o, no pout")
        // Touches that all arrive at once (a test's, or no clock) read as before.
        let (points, _) = SwipePath.timed("pout", keys: keys, pausingOn: [1, 2])
        let still = [TimeInterval](repeating: 0, count: points.count)
        XCTAssertEqual(en.decode(points, times: still, keys: keys).map(\.text), en.decode(points, keys: keys).map(\.text))
    }

    func testAPathTooShortReadsAsNothing() throws {
        let (en, keys) = try decoder("en")
        let h = try XCTUnwrap(keys.centres["h"])
        XCTAssertTrue(en.decode([h, CGPoint(x: h.x + 4, y: h.y)], keys: keys).isEmpty)
        XCTAssertTrue(en.decode([h], keys: keys).isEmpty)
    }

    /// Nothing is kept between swipes: a decoder reads the same after others.
    func testADecoderKeepsNothingBetweenSwipes() throws {
        let (en, keys) = try decoder("en")
        let first = read("keyboard", en, keys)
        for word in ["hello", "world", "people", "because"] { _ = read(word, en, keys) }
        XCTAssertEqual(read("keyboard", en, keys), first)
    }
}

/// Dictus's letter pages (`KeyboardLayouts.qwertyNormal`, `azertyNormal`, QWERTZ for de) on an iPhone 17
/// held upright (a 402 x 216 pt grid), laid out by `KeyPlaneGeometry`, and read as
/// `GiellaKeyboardView.spatialKeys()` reads them (#1011): each letter at its touch target's
/// centre, the key unit by the row's height, the bottom letter row, the space bar.
enum SwipeKeys {
    /// Each row's keys: a letter, or nil for another key (shift, delete, spacer, the AZERTY
    /// accent key, the bottom row's), with its width in key units.
    static func rows(_ language: String) -> [[(Character?, CGFloat)]] {
        let bottom: [(Character?, CGFloat)] = [(nil, 1.25), (nil, 1.25), (" ", 5.5), (nil, 2)]
        func letters(_ s: String) -> [(Character?, CGFloat)] { s.map { ($0, 1) } }
        if language == "fr" {
            return [letters("azertyuiop"), letters("qsdfghjklm"),
                    [(nil, 1.5)] + letters("wxcvbn") + [(nil, 1), (nil, 1.5)], bottom]
        }
        if language == "de" {
            // `QWERTZLayout`: eleven keys on the first two rows, shift and delete at 1.5.
            let rows = QWERTZLayout.lowercasedLettersRows.map { $0.joined() }
            return [letters(rows[0]), letters(rows[1]), [(nil, 1.5)] + letters(rows[2]) + [(nil, 1.5)], bottom]
        }
        return [letters("qwertyuiop"), [(nil, 0.5)] + letters("asdfghjkl") + [(nil, 0.5)],
                [(nil, 1.5)] + letters("zxcvbnm") + [(nil, 1.5)], bottom]
    }

    static func letterPage(_ language: String, width: CGFloat = 402, height: CGFloat = 216) -> SpatialDecoder.Keys {
        let page = rows(language)
        let geometry = KeyPlaneGeometry.apple(.standard, .portrait)
        guard let slots = geometry.layout(rows: page.map { $0.map(\.1) }, width: width, height: height) else {
            return SpatialDecoder.Keys(centres: [:], pitch: .zero, bottomRowY: 0, space: nil)
        }
        var centres: [Character: CGPoint] = [:]
        var bottom: CGFloat = 0
        var space: CGRect?
        var pitch = CGSize.zero
        for (row, rowSlots) in zip(page, slots) {
            let units = row.reduce(0) { $0 + $1.1 }
            let unitWidth = (width - 2 * geometry.sideInset + geometry.keyGap) / units
            for ((key, _), slot) in zip(row, rowSlots) {
                guard let key else { continue }
                if key == " " {
                    space = slot.hit
                    continue
                }
                centres[key] = CGPoint(x: slot.hit.midX, y: slot.hit.midY)
                bottom = max(bottom, slot.hit.midY)
                if pitch == .zero { pitch = CGSize(width: unitWidth, height: slot.hit.height) }
            }
        }
        return SpatialDecoder.Keys(centres: centres, pitch: pitch, bottomRowY: bottom, space: space)
    }
}

/// Swipes for tests: straight strokes through the centres of a word's keys.
enum SwipePath {
    /// The centres of `word`'s keys on `keys` (an accented letter on its base letter's key,
    /// ß on s, an apostrophe on none), repeats run together.
    private static func centres(_ word: String, keys: SpatialDecoder.Keys) -> [CGPoint] {
        var centres: [CGPoint] = []
        for letter in word.lowercased() where letter != "'" {
            let base = letter == "ß" ? "s" : String(letter).decomposedStringWithCanonicalMapping.unicodeScalars.first.map(Character.init)
            guard let centre = keys.centres[letter] ?? base.flatMap({ keys.centres[$0] }) else { continue }
            if centres.last != centre { centres.append(centre) }
        }
        return centres
    }

    /// Through the centres of `word`'s keys, a point every `step` points, moved by `offset`.
    static func through(_ word: String, keys: SpatialDecoder.Keys, offset: CGVector = .zero, step: CGFloat = 6) -> [CGPoint] {
        let centres = centres(word, keys: keys)
        guard let first = centres.first else { return [] }
        var points = [first]
        for (a, b) in zip(centres, centres.dropFirst()) {
            let count = max(1, Int((hypot(b.x - a.x, b.y - a.y) / step).rounded(.up)))
            for i in 1...count {
                let t = CGFloat(i) / CGFloat(count)
                points.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        return points.map { CGPoint(x: $0.x + offset.dx, y: $0.y + offset.dy) }
    }

    /// Through `word`'s keys as `through` does, at an even 750 points a second, with the
    /// touches' times: the finger stays `pause` seconds on the keys at `pausingOn` (indexes
    /// into the word's keys, repeats run together), sending nothing meanwhile, as a still
    /// finger does.
    static func timed(
        _ word: String, keys: SpatialDecoder.Keys, pausingOn pauses: Set<Int>, pause: TimeInterval = 0.15
    ) -> (points: [CGPoint], times: [TimeInterval]) {
        let centres = centres(word, keys: keys)
        guard let first = centres.first else { return ([], []) }
        var points = [first]
        var times: [TimeInterval] = [0]
        let step: CGFloat = 6, perStep: TimeInterval = 0.008
        for (index, (a, b)) in zip(centres, centres.dropFirst()).enumerated() {
            let count = max(1, Int((hypot(b.x - a.x, b.y - a.y) / step).rounded(.up)))
            for i in 1...count {
                let t = CGFloat(i) / CGFloat(count)
                points.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                // The first point after a paused key comes only once the finger moves on.
                times.append(times[times.count - 1] + perStep + (i == 1 && pauses.contains(index) ? pause : 0))
            }
        }
        return (points, times)
    }
}
