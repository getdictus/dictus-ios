// DictusCore/Tests/DictusCoreTests/AdaptiveTouchTests.swift
import CoreGraphics
import XCTest
@testable import DictusCore

/// Adaptive touch (#1014), Hex's personal key centres, on the QWERTY grid of
/// `SpatialDecoderTests` (40 x 54 pt keys).
final class AdaptiveTouchTests: XCTestCase {
    private static let keys = SpatialDecoderTests.keys(SpatialDecoderTests.qwerty)

    private static func decoder(_ language: String) throws -> SpatialDecoder {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusKeyboard/Resources/\(language).hextm").path
        let model = try XCTUnwrap(SpatialDecoderModel(path: path), "no \(language).hextm")
        return SpatialDecoder(model: model)
    }

    /// Types `word` on its keys, each tap `bias` keycaps from the centre, then a space; `before`
    /// is the text in front of it.
    private func type(_ word: String, bias: CGVector, into text: inout String, with touch: AdaptiveTouch,
                      corrected: String? = nil) {
        for c in word {
            text.append(c)
            let centre = Self.keys.centres[c] ?? .zero
            touch.typed(String(c), at: CGPoint(x: centre.x + bias.dx * 40, y: centre.y + bias.dy * 54),
                        slid: false, keys: Self.keys)
        }
        // As `autocorrectBeforeCursor`: the text before the cursor as it was, still ending in the word.
        touch.finish(corrected: corrected, before: text)
        if let corrected {
            text.removeLast(word.count)
            text += corrected
        }
        text += " "
    }

    /// `count` sentences of the same words in `count` sessions, all taps `bias` off.
    private func learn(_ touch: AdaptiveTouch, sessions: Int, bias: CGVector) {
        for _ in 0..<sessions {
            touch.beginSession()
            var text = ""
            for word in ["the", "quick", "brown", "fox", "jumps", "over", "lazy", "dogs", "with", "might"] {
                type(word, bias: bias, into: &text, with: touch)
            }
        }
    }

    // MARK: - Model

    func testTheFileIsFixedSizeAndRoundTrips() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        learn(touch, sessions: 2, bias: CGVector(dx: 0, dy: 0.2))
        let data = touch.model.serialized()
        XCTAssertEqual(data.count, AdaptiveTouchModel.byteCount)
        XCTAssertEqual(AdaptiveTouchModel(data: data), touch.model)
        var broken = data
        broken[100] ^= 0xFF
        XCTAssertNil(AdaptiveTouchModel(data: broken), "a changed byte fails the checksum")
        XCTAssertNil(AdaptiveTouchModel(data: data.dropLast()))
    }

    func testOffsetsAreShrunkBoundedAndStepped() {
        var model = AdaptiveTouchModel()
        let c = model.ensureContext(geometry: 7, regime: 0)
        for _ in 0..<200 { model.add(context: c, slot: 0, x: 0.2, y: -0.2, weight: 1) }
        model.promote(context: c, groups: [0, 0, 1])
        // One promotion moves an axis by `step` at most, toward the shrunk mean.
        XCTAssertEqual(model.offset(context: c, slot: 0).x, AdaptiveTouchModel.step, accuracy: 1e-6)
        XCTAssertEqual(model.offset(context: c, slot: 0).y, -AdaptiveTouchModel.step, accuracy: 1e-6)
        for _ in 0..<20 { model.promote(context: c, groups: [0, 0, 1]) }
        let own = model.offset(context: c, slot: 0).x
        XCTAssertLessThan(own, 0.2, "shrunk toward the row and the keyboard")
        // A key with no taps borrows from its row and the keyboard, less than the one it shares with.
        let neighbour = model.offset(context: c, slot: 1).x
        XCTAssertGreaterThan(neighbour, 0)
        XCTAssertLessThan(neighbour, own)
        XCTAssertLessThan(model.offset(context: c, slot: 2).x, neighbour, "another row borrows less")

        // A mean past the bound stops at it.
        var far = AdaptiveTouchModel()
        let f = far.ensureContext(geometry: 8, regime: 0)
        for _ in 0..<200 { far.add(context: f, slot: 0, x: 0.8, y: 0, weight: 1) }
        for _ in 0..<20 { far.promote(context: f, groups: [0]) }
        XCTAssertEqual(far.offset(context: f, slot: 0).x, AdaptiveTouchModel.bound, accuracy: 1e-6)
    }

    // MARK: - Labels

    func testAWordTeachesOnlyOnceTheNextOneShowsItStood() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        touch.beginSession()
        var text = ""
        type("the", bias: .zero, into: &text, with: touch)
        XCTAssertEqual(touch.model.contexts.map(\.accepted).max(), 0, "the last word may still change")
        type("dog", bias: .zero, into: &text, with: touch)
        XCTAssertEqual(touch.model.contexts.map(\.accepted).max(), 3)
    }

    func testAnAutocorrectionLeftInPlaceTeachesNothing() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        touch.beginSession()
        var text = ""
        type("teh", bias: .zero, into: &text, with: touch, corrected: "the")
        type("dog", bias: .zero, into: &text, with: touch)
        XCTAssertEqual(touch.model.contexts.map(\.accepted).max(), 0)
    }

    func testAnUndoneCorrectionTeachesWhatWasTyped() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        touch.beginSession()
        var text = ""
        type("teh", bias: .zero, into: &text, with: touch, corrected: "the")
        // Undo puts "teh " back over "the ".
        text = "teh "
        touch.undone(original: "teh")
        type("dog", bias: .zero, into: &text, with: touch)
        let c = touch.model.contexts.firstIndex { $0.accepted > 0 }
        XCTAssertEqual(c.map { touch.model.contexts[$0].strong }, 3, "kept over a correction: strong")
    }

    func testAnErasedNeighbourIsLabelledWithTheLetterThatReplacedIt() throws {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        touch.beginSession()
        var text = ""
        // "tje", "je" erased and retyped as "he": the erased j meant h.
        for c in "tje" {
            text.append(c)
            touch.typed(String(c), at: Self.keys.centres[c], slid: false, keys: Self.keys)
        }
        for _ in 0..<2 {
            touch.willDelete(before: text)
            text.removeLast()
        }
        for c in "he" {
            text.append(c)
            touch.typed(String(c), at: Self.keys.centres[c], slid: false, keys: Self.keys)
        }
        touch.finish(before: text)
        text += " "
        type("dog", bias: .zero, into: &text, with: touch)
        let c = try XCTUnwrap(touch.model.contexts.firstIndex { $0.accepted > 0 })
        XCTAssertEqual(touch.model.contexts[c].strong, 1)
        XCTAssertEqual(touch.model.contexts[c].weak, 3)
    }

    func testAnAccentKeyVowelAndAnElisionStillTeach() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        touch.beginSession()
        // "j'ai" then "été": the apostrophe and the accents have no tap of their own.
        var text = ""
        for (letter, shown) in [("j", "j"), (nil, "'"), ("a", "a"), ("i", "i")] as [(String?, String)] {
            text += shown
            if let letter {
                touch.typed(letter, at: Self.keys.centres[Character(letter)], slid: false, keys: Self.keys)
            }
        }
        touch.finish(before: text)
        text += " "
        for c in "ete" { touch.typed(String(c), at: Self.keys.centres[c], slid: false, keys: Self.keys) }
        text += "été"
        touch.finish(before: text)
        XCTAssertEqual(touch.model.contexts.map(\.accepted).max(), 3)
    }

    /// #1031: `qqc` → `Quelque chose` is a shortcut typed on purpose, not a mistyped word
    /// autocorrect fixed, so its taps teach like a word left as typed.
    func testAnExpandedTextReplacementIsLearnedLikeAWordTypedRight() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        touch.beginSession()
        var text = ""
        for c in "qqc" {
            text.append(c)
            touch.typed(String(c), at: Self.keys.centres[c], slid: false, keys: Self.keys)
        }
        touch.finish(expanded: "Quelque chose", before: text)
        text.removeLast(3)
        text += "Quelque chose "
        // The keyboard hears its own expansion as a host change.
        touch.hostChanged(before: text)
        type("dog", bias: .zero, into: &text, with: touch)
        XCTAssertEqual(touch.model.contexts.map(\.accepted).max(), 3, "the shortcut's three taps teach")
    }

    func testAnExpansionTheDocumentNoLongerShowsTeachesNothing() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        touch.beginSession()
        var text = ""
        for c in "qqc" {
            text.append(c)
            touch.typed(String(c), at: Self.keys.centres[c], slid: false, keys: Self.keys)
        }
        touch.finish(expanded: "Quelque chose", before: text)
        // Something else ended up there (the expansion undone, the host's own edit).
        text = "autre "
        type("dog", bias: .zero, into: &text, with: touch)
        XCTAssertEqual(touch.model.contexts.map(\.accepted).max(), 0)
    }

    func testASlideAndAPopupTeachNothing() {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        touch.beginSession()
        var text = "the"
        touch.typed("t", at: Self.keys.centres["t"], slid: true, keys: Self.keys)
        touch.typed("h", at: Self.keys.centres["h"], slid: false, keys: Self.keys)
        touch.typed("e", at: nil, slid: false, keys: Self.keys)
        touch.finish(before: text)
        text += " "
        type("dog", bias: .zero, into: &text, with: touch)
        XCTAssertEqual(touch.model.contexts.map(\.accepted).max(), 0)
    }

    // MARK: - Activation and reset

    func testPersonalCentresWaitForHexsEvidenceThenFollowTheBias() throws {
        let touch = AdaptiveTouch(storage: .memory, defaults: nil)
        let bias = CGVector(dx: 0, dy: 0.25)
        learn(touch, sessions: 2, bias: bias)
        XCTAssertNil(touch.personalKeys(for: Self.keys), "under 400 labels and 3 sessions")
        learn(touch, sessions: 10, bias: bias)
        let personal = try XCTUnwrap(touch.personalKeys(for: Self.keys))
        let moved = try XCTUnwrap(personal.centres["e"]).y - (Self.keys.centres["e"]?.y ?? 0)
        XCTAssertGreaterThan(moved, 0.1 * 54, "e's centre moved down toward where the taps land")
        XCTAssertLessThanOrEqual(moved, CGFloat(AdaptiveTouchModel.bound) * 54 + 0.001)
    }

    func testAResetDropsTheProfileFromMemoryAndDisk() throws {
        let suite = "AdaptiveTouchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("adaptive-touch.bin")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let touch = AdaptiveTouch(storage: .file(url), defaults: defaults)
        learn(touch, sessions: 12, bias: CGVector(dx: 0, dy: 0.25))
        touch.save()
        AdaptiveTouch.waitForWrites()
        XCTAssertNotNil(touch.personalKeys(for: Self.keys))
        XCTAssertNotNil(AdaptiveTouch(storage: .file(url), defaults: defaults).personalKeys(for: Self.keys),
                        "a new keyboard process reads the file")

        AdaptiveTouchStore.requestReset(defaults: defaults, url: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        touch.beginSession()
        XCTAssertNil(touch.personalKeys(for: Self.keys), "the running keyboard drops its copy")
        XCTAssertEqual(touch.model.contexts.map(\.accepted).max(), 0)
    }

    // MARK: - The decoder's baseline

    func testPersonalCentresNeverMakeACorrectionTheStockOnesWouldNot() throws {
        let decoder = try Self.decoder("en")
        // "fine" typed on its keys. Personal centres that put s where the e tap landed (far
        // past anything Adaptive touch learns) read it as "fins".
        let taps = SpatialDecoderTests.taps("fine", on: Self.keys)
        var personal = Self.keys
        personal.centres["s"] = taps[3]
        personal.centres["e"] = CGPoint(x: 900, y: 900)
        let facts = SpatialCorrection.Facts(isKnown: true, isLearned: false)
        let alone = SpatialCorrection.correct("fine", previousWord: "is", input: .init(taps: taps, keys: personal),
                                              with: decoder, facts: facts)
        XCTAssertEqual(alone?.correction, "fins", "the personal centres alone would change it")
        let gated = SpatialCorrection.correct("fine", previousWord: "is",
                                              input: .init(taps: taps, keys: personal, baseline: Self.keys),
                                              with: decoder, facts: facts)
        XCTAssertNil(gated, "the stock centres keep a word typed on its keys")
    }

    func testABaselineEqualToTheKeysChangesNothing() throws {
        let decoder = try Self.decoder("en")
        let taps = SpatialDecoderTests.taps("thinl", on: Self.keys, offsets: [4: CGVector(dx: -0.45, dy: 0)])
        let facts = SpatialCorrection.Facts(isKnown: false, isLearned: false)
        let plain = SpatialCorrection.correct("thinl", previousWord: "i", input: .init(taps: taps, keys: Self.keys),
                                              with: decoder, facts: facts)
        let gated = SpatialCorrection.correct("thinl", previousWord: "i",
                                              input: .init(taps: taps, keys: Self.keys, baseline: Self.keys),
                                              with: decoder, facts: facts)
        XCTAssertEqual(plain, gated)
        XCTAssertEqual(gated?.correction, "think")
    }
}
