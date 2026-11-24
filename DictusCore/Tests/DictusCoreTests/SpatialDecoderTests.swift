// DictusCore/Tests/DictusCoreTests/SpatialDecoderTests.swift
import CoreGraphics
import XCTest
@testable import DictusCore

/// The spatial decoder (#1011) on the models the keyboard ships, on a QWERTY or AZERTY
/// grid of 40 x 54 pt keys.
final class SpatialDecoderTests: XCTestCase {
    private static func modelPath(_ language: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusKeyboard/Resources/\(language).hextm").path
    }

    private static func decoder(_ language: String) throws -> SpatialDecoder {
        let model = try XCTUnwrap(SpatialDecoderModel(path: modelPath(language)), "no \(language).hextm")
        return SpatialDecoder(model: model)
    }

    static let qwerty = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    static let azerty = ["azertyuiop", "qsdfghjklm", "wxcvbn"]

    /// Rows offset as on the iPhone: the second row half a key in, the third a key and a half.
    static func keys(_ rows: [String]) -> SpatialDecoder.Keys {
        var centres: [Character: CGPoint] = [:]
        let offsets: [CGFloat] = rows[1].count == 10 ? [0, 0, 1.5] : [0, 0.5, 1.5]
        for (r, row) in rows.enumerated() {
            for (i, c) in row.enumerated() {
                centres[c] = CGPoint(x: (offsets[r] + CGFloat(i) + 0.5) * 40, y: (CGFloat(r) + 0.5) * 54)
            }
        }
        return SpatialDecoder.Keys(centres: centres, pitch: CGSize(width: 40, height: 54), bottomRowY: 2.5 * 54,
                                   space: CGRect(x: 100, y: 3 * 54, width: 200, height: 54))
    }

    /// Taps on the keys' centres, nudged by `offsets` (in key units) by index.
    static func taps(_ word: String, on keys: SpatialDecoder.Keys, offsets: [Int: CGVector] = [:]) -> [CGPoint] {
        word.enumerated().map { i, c in
            let centre = keys.centres[Character(c.lowercased())] ?? .zero
            let o = offsets[i] ?? .zero
            return CGPoint(x: centre.x + o.dx * 40, y: centre.y + o.dy * 54)
        }
    }

    func testAWordTypedOnItsKeysIsKept() throws {
        let decoder = try Self.decoder("en")
        let keys = Self.keys(Self.qwerty)
        for word in ["think", "will", "sent", "table", "can", "am", "do"] {
            let decision = try XCTUnwrap(decoder.decide(taps: Self.taps(word, on: keys), typed: word, previous: "i",
                                                        literalIsValid: true, keys: keys))
            XCTAssertNil(decision.replacement, "\(word) -> \(decision.readings)")
        }
    }

    func testANeighbourKeyIsReadAsTheWord() throws {
        let decoder = try Self.decoder("en")
        let keys = Self.keys(Self.qwerty)
        // "thinl": the l tapped on its left edge, next to k.
        let taps = Self.taps("thinl", on: keys, offsets: [4: CGVector(dx: -0.45, dy: 0)])
        let decision = try XCTUnwrap(decoder.decide(taps: taps, typed: "thinl", previous: "i",
                                                    literalIsValid: false, keys: keys))
        XCTAssertEqual(decision.replacement, "think")
    }

    // MARK: - Word-level correction

    private static func correct(
        _ word: String, previous: String?, offsets: [Int: CGVector] = [:], language: String = "en",
        rows: [String] = qwerty, isKnown: Bool = false, isLearned: Bool = false
    ) throws -> SpatialCorrection.Result? {
        let keys = Self.keys(rows)
        // An apostrophe is typed on a key the grid does not have: any point will do.
        let taps = word.enumerated().map { i, c -> CGPoint in
            guard c != "'" else { return CGPoint(x: 380, y: 140) }
            let centre = keys.centres[Character(c.lowercased())] ?? .zero
            let o = offsets[i] ?? .zero
            return CGPoint(x: centre.x + o.dx * 40, y: centre.y + o.dy * 54)
        }
        return SpatialCorrection.correct(
            word, previousWord: previous, input: SpatialCorrection.Input(taps: taps, keys: keys),
            with: try Self.decoder(language), facts: SpatialCorrection.Facts(isKnown: isKnown, isLearned: isLearned)
        )
    }

    func testTheCorrectionKeepsTheCapitalOfTheTypedWord() throws {
        let result = try Self.correct("Thinl", previous: nil, offsets: [4: CGVector(dx: -0.45, dy: 0)])
        XCTAssertEqual(result?.correction, "Think")
    }

    func testALearnedWordIsNeverAskedAbout() throws {
        XCTAssertNil(try Self.correct("thinl", previous: "i", offsets: [4: CGVector(dx: -0.45, dy: 0)], isLearned: true))
    }

    func testACapitalInsideTheWordIsLeftAlone() throws {
        XCTAssertNil(try Self.correct("tHinl", previous: "i", offsets: [4: CGVector(dx: -0.45, dy: 0)]))
    }

    func testAMissingApostropheIsPutBackForFree() throws {
        XCTAssertEqual(try Self.correct("dont", previous: "i")?.correction, "don't")
    }

    func testTapsThatDoNotMatchTheWordAreNotRead() throws {
        let keys = Self.keys(Self.qwerty)
        let result = SpatialCorrection.correct(
            "thinl", previousWord: "i", input: SpatialCorrection.Input(taps: Self.taps("thin", on: keys), keys: keys),
            with: try Self.decoder("en"), facts: SpatialCorrection.Facts(isKnown: false, isLearned: false)
        )
        XCTAssertNil(result)
    }

    func testATrieCorrectionTheDecoderCannotScoreStaysTheTries() throws {
        let keys = Self.keys(Self.qwerty)
        let taps = Self.taps("thinl", on: keys, offsets: [4: CGVector(dx: -0.45, dy: 0)])
        let result = SpatialCorrection.correct(
            "thinl", previousWord: "i", input: SpatialCorrection.Input(taps: taps, keys: keys), with: try Self.decoder("en"),
            facts: SpatialCorrection.Facts(isKnown: false, isLearned: false, trieCorrection: "xylophone")
        )
        XCTAssertNil(result)
    }

    func testTheDecoderBeatsATrieCorrectionItScoresHigher() throws {
        let keys = Self.keys(Self.qwerty)
        let taps = Self.taps("thinl", on: keys, offsets: [4: CGVector(dx: -0.45, dy: 0)])
        // "thin" drops the l tap, an edit; "think" reads it as the key it touches.
        let result = SpatialCorrection.correct(
            "thinl", previousWord: "i", input: SpatialCorrection.Input(taps: taps, keys: keys), with: try Self.decoder("en"),
            facts: SpatialCorrection.Facts(isKnown: false, isLearned: false, trieCorrection: "thin")
        )
        XCTAssertEqual(result?.correction, "think")
    }

    /// Pierre's taps of "J'ai hâte" typed without its space (device session of 2026-11-23,
    /// `TJ TAP` offsets in key units), with and without the apostrophe.
    private static let jaihate: [CGVector] = [
        CGVector(dx: -0.0737, dy: 0.1190), CGVector(dx: 0.1422, dy: -0.1012), CGVector(dx: -0.0571, dy: 0.1905),
        CGVector(dx: 0.1068, dy: 0.0536), CGVector(dx: 0.0713, dy: -0.0417), CGVector(dx: 0.2715, dy: 0.3274),
        CGVector(dx: 0.0729, dy: -0.1786)
    ]

    private static func correctAgainstTrie(_ word: String, offsets: [CGVector], trie: String) throws -> String? {
        let keys = Self.keys(Self.azerty)
        let letters = word.filter { $0 != "'" }
        var taps = Self.taps(letters, on: keys, offsets: Dictionary(uniqueKeysWithValues: offsets.enumerated().map { ($0, $1) }))
        if let apostrophe = word.firstIndex(of: "'") {
            taps.insert(CGPoint(x: 380, y: 140), at: word.distance(from: word.startIndex, to: apostrophe))
        }
        return SpatialCorrection.correct(
            word, previousWord: nil, input: SpatialCorrection.Input(taps: taps, keys: keys), with: try Self.decoder("fr"),
            facts: SpatialCorrection.Facts(isKnown: false, isLearned: false, trieCorrection: trie)
        )?.correction
    }

    func testAReadingThatKeepsEveryLetterBeatsATrieCorrectionThatChangesThem() throws {
        // The trie changed three letters ("Lainage", "J'acheté"); the decoder only puts the
        // space, the apostrophe and the accent back. It cannot score the trie's word, and
        // needs not.
        XCTAssertEqual(try Self.correctAgainstTrie("Jaihate", offsets: Self.jaihate, trie: "Lainage"), "J'ai hâte")
        XCTAssertEqual(try Self.correctAgainstTrie("J'aihate", offsets: Self.jaihate, trie: "J'acheté"), "J'ai hâte")
    }

    func testReadingsThatKeepTheLetters() {
        XCTAssertTrue(SpatialCorrection.keepsTheLetters("j'ai hâte", typed: "jaihate"))
        XCTAssertTrue(SpatialCorrection.keepsTheLetters("j'ai hâte", typed: "j'aihate"))
        // The n between the two words read as the space.
        XCTAssertTrue(SpatialCorrection.keepsTheLetters("j'ai hâte", typed: "jainhate"))
        XCTAssertTrue(SpatialCorrection.keepsTheLetters("don't", typed: "dont"))
        XCTAssertFalse(SpatialCorrection.keepsTheLetters("think", typed: "thinl"))
        XCTAssertFalse(SpatialCorrection.keepsTheLetters("lainage", typed: "jaihate"))
        // A letter dropped inside a word is a change, not a space.
        XCTAssertFalse(SpatialCorrection.keepsTheLetters("thin", typed: "thinl"))
    }

    func testAChangeOfAccentsAloneIsLeftToTheAccentRules() throws {
        // "tres" reads best as "très", which only adds an accent: the accent rules of the
        // trie (#1000) own that call, so the decoder leaves the word to them.
        let keys = Self.keys(Self.azerty)
        let decision = try Self.decoder("fr").decide(taps: Self.taps("tres", on: keys), typed: "tres", previous: "est",
                                                     literalIsValid: false, keys: keys)
        XCTAssertEqual(decision?.replacement, "très", "the decoder alone would add the accent")
        XCTAssertNil(try Self.correct("tres", previous: "est", language: "fr", rows: Self.azerty))
    }

    func testAFrenchElisionIsReadWhole() throws {
        // "j'ao": the i landed on the left edge of o. Google Books keeps "j'ai" as one
        // word, so the token is read whole, its apostrophe put back for free.
        let result = try Self.correct("J'ao", previous: nil, offsets: [3: CGVector(dx: -0.45, dy: 0)],
                                      language: "fr", rows: Self.azerty)
        XCTAssertEqual(result?.correction, "J'ai")
    }

    func testAMissedSpaceIsSplit() throws {
        XCTAssertEqual(try Self.correct("inthe", previous: "was")?.correction, "in the")
    }

    // MARK: - Touch buffer

    private static let point = CGPoint(x: 1, y: 2)

    func testTheBufferHoldsOneTapPerCharacterOfTheToken() {
        var buffer = SpatialTouchBuffer()
        let keys = Self.keys(Self.qwerty)
        var text = "Je "
        for (i, c) in "trouce".enumerated() {
            text.append(c)
            buffer.typed(String(c), at: CGPoint(x: i, y: 0), keys: keys, token: SpatialTouchBuffer.token(before: text))
        }
        XCTAssertEqual(buffer.taps(for: "trouce")?.map(\.x), [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(buffer.keys, keys)
    }

    func testABackspaceDropsTheLastTap() {
        var buffer = SpatialTouchBuffer()
        buffer.typed("a", at: Self.point, keys: nil, token: "a")
        buffer.typed("b", at: Self.point, keys: nil, token: "ab")
        buffer.deleted(token: "a")
        buffer.typed("c", at: CGPoint(x: 9, y: 9), keys: nil, token: "ac")
        XCTAssertEqual(buffer.taps(for: "ac"), [Self.point, CGPoint(x: 9, y: 9)])
    }

    func testANewWordStartsANewBuffer() {
        var buffer = SpatialTouchBuffer()
        buffer.typed("I", at: Self.point, keys: nil, token: "I")
        // After the space, "a" is a word of its own, not the accent key replacing "I".
        buffer.typed("a", at: CGPoint(x: 5, y: 5), keys: nil, token: "a")
        buffer.typed("m", at: CGPoint(x: 6, y: 6), keys: nil, token: "am")
        XCTAssertEqual(buffer.taps(for: "am"), [CGPoint(x: 5, y: 5), CGPoint(x: 6, y: 6)])
    }

    func testTheAccentKeyKeepsTheVowelsTap() {
        var buffer = SpatialTouchBuffer()
        buffer.typed("t", at: CGPoint(x: 1, y: 1), keys: nil, token: "t")
        buffer.typed("e", at: CGPoint(x: 2, y: 2), keys: nil, token: "te")
        buffer.typed("é", at: CGPoint(x: 9, y: 9), keys: nil, token: "té", replacing: true)
        XCTAssertEqual(buffer.taps(for: "té"), [CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 2)])
    }

    func testAnEditTheBufferDidNotSeeLeavesTheWordUnread() {
        var buffer = SpatialTouchBuffer()
        buffer.typed("a", at: Self.point, keys: nil, token: "a")
        // A suggestion was tapped, or the cursor moved: the token is not what was typed.
        buffer.typed("b", at: Self.point, keys: nil, token: "xyzb")
        buffer.typed("c", at: Self.point, keys: nil, token: "xyzbc")
        XCTAssertNil(buffer.taps(for: "xyzbc"))
        XCTAssertNil(buffer.taps(for: "bc"))
    }

    func testAKeyPickedInAPopupLeavesTheWordUnread() {
        var buffer = SpatialTouchBuffer()
        buffer.typed("a", at: Self.point, keys: nil, token: "a")
        buffer.typed("é", at: nil, keys: nil, token: "aé")
        buffer.typed("b", at: Self.point, keys: nil, token: "aéb")
        XCTAssertNil(buffer.taps(for: "aéb"))
    }

    func testTheTokenIsWhatFollowsTheLastSpace() {
        XCTAssertEqual(SpatialTouchBuffer.token(before: "Je ne sais"), "sais")
        XCTAssertEqual(SpatialTouchBuffer.token(before: "Salut\nJ'aa"), "J'aa")
        XCTAssertEqual(SpatialTouchBuffer.token(before: "fin "), "")
        XCTAssertEqual(SpatialTouchBuffer.token(before: nil), "")
    }
}
