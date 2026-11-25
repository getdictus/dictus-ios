// DictusCore/Tests/DictusCoreTests/SwipeTypingTextTests.swift
// Swipe typing's text rules (#948): when a touch is a swipe, the space and capital of a
// swiped word, what goes against it, the bar, the record Delete and the bar act on, and the
// English contractions read beside the model. Hex's rules (MIT), Dictus's cases.
import CoreGraphics
import XCTest
@testable import DictusCore

final class SwipeTypingTextTests: XCTestCase {

    // MARK: - The gesture

    /// A key 40 pt across and a row 54 pt down, as an iPhone's letter page roughly is.
    private let pitch = CGSize(width: 40, height: 54)

    func testATouchBecomesASwipeOnlyPastTheNextKey() {
        let start = CGPoint(x: 100, y: 50)
        XCTAssertFalse(SwipeTypingText.isSwipe(from: start, to: start, pitch: pitch), "a tap")
        XCTAssertFalse(SwipeTypingText.isSwipe(from: start, to: CGPoint(x: 140, y: 50), pitch: pitch),
                       "a slide to the next key's centre stays a slide")
        XCTAssertFalse(SwipeTypingText.isSwipe(from: start, to: CGPoint(x: 100, y: 104), pitch: pitch),
                       "a slide to the key just below, a row (taller than a key is wide) down, stays a slide")
        XCTAssertFalse(SwipeTypingText.isSwipe(from: start, to: CGPoint(x: 120, y: 104), pitch: pitch),
                       "the staggered row's diagonal neighbour stays a slide")
        XCTAssertTrue(SwipeTypingText.isSwipe(from: start, to: CGPoint(x: 149, y: 50), pitch: pitch))
        XCTAssertTrue(SwipeTypingText.isSwipe(from: start, to: CGPoint(x: 100, y: 116), pitch: pitch))
        XCTAssertFalse(SwipeTypingText.isSwipe(from: start, to: CGPoint(x: 900, y: 50), pitch: .zero), "no geometry, no swipe")
    }

    func testATapThatSlidStaysNearItsStart() {
        let start = CGPoint(x: 100, y: 50)
        XCTAssertTrue(SwipeTypingText.staysNearStart([start, CGPoint(x: 150, y: 50), CGPoint(x: 102, y: 52)], pitch: pitch))
        XCTAssertTrue(SwipeTypingText.staysNearStart([start, CGPoint(x: 100, y: 130), start], pitch: pitch),
                      "measured in rows down, not key widths")
        XCTAssertFalse(SwipeTypingText.staysNearStart([start, CGPoint(x: 170, y: 50), start], pitch: pitch))
        XCTAssertFalse(SwipeTypingText.staysNearStart([], pitch: pitch))
    }

    func testAWordCanStartAndEndOnTheSameKey() {
        XCTAssertTrue(SwipeTypingText.word("pop", startsAndEndsWith: "p"))
        XCTAssertTrue(SwipeTypingText.word("Été", startsAndEndsWith: "e"), "an accent sits on its base letter's key")
        XCTAssertFalse(SwipeTypingText.word("as", startsAndEndsWith: "a"))
        XCTAssertFalse(SwipeTypingText.word("a", startsAndEndsWith: "a"), "one letter is a tap")
    }

    // MARK: - Spacing

    func testASwipedWordGetsASpaceAfterAWord() {
        XCTAssertTrue(SwipeTypingText.needsSpace(before: "hello"))
        XCTAssertTrue(SwipeTypingText.needsSpace(before: "Hi."))
        XCTAssertTrue(SwipeTypingText.needsSpace(before: "là,"))
    }

    func testNoSpaceAtTheStartOrAfterASpaceOrOpeningPunctuation() {
        for before in [nil, "", "hello ", "line\n", "(", "« ", "«", "¿", "@", "#", "/", "\u{FFFC}"] {
            XCTAssertFalse(SwipeTypingText.needsSpace(before: before), String(describing: before))
        }
    }

    func testAStraightQuoteOpensAfterNothingOrASpace() {
        XCTAssertFalse(SwipeTypingText.needsSpace(before: "\""))
        XCTAssertFalse(SwipeTypingText.needsSpace(before: "he said \""))
        XCTAssertTrue(SwipeTypingText.needsSpace(before: "\"quoted\""), "a closing quote")
        XCTAssertTrue(SwipeTypingText.needsSpace(before: "l'"), "an apostrophe after a letter")
    }

    func testPunctuationGoesAgainstTheSwipedWordAndEverythingElseStartsTheNext() {
        for mark in [",", ".", "!", "?", ";", ":", ")", "'", "’", "-", "/"] {
            XCTAssertFalse(SwipeTypingText.startsNextWord(mark), mark)
        }
        for typed in ["w", "W", "1", "(", "\"", "@", "é"] {
            XCTAssertTrue(SwipeTypingText.startsNextWord(typed), typed)
        }
        XCTAssertFalse(SwipeTypingText.startsNextWord(" "))
        XCTAssertFalse(SwipeTypingText.startsNextWord(""))
    }

    func testTheWordBeforeTheSwipe() {
        XCTAssertEqual(SwipeTypingText.previousWord(before: "I want "), "want")
        XCTAssertEqual(SwipeTypingText.previousWord(before: "I want"), "want", "the swipe adds the space")
        XCTAssertEqual(SwipeTypingText.previousWord(before: "Je suis   "), "suis")
        XCTAssertEqual(SwipeTypingText.previousWord(before: "aujourd’hui "), "aujourd'hui")
        XCTAssertNil(SwipeTypingText.previousWord(before: "Done. "), "a new sentence")
        XCTAssertNil(SwipeTypingText.previousWord(before: "line\n"))
        XCTAssertNil(SwipeTypingText.previousWord(before: ""))
        XCTAssertNil(SwipeTypingText.previousWord(before: nil))
    }

    // MARK: - Capitals

    func testShiftCapitalisesTheWord() {
        XCTAssertTrue(SwipeTypingText.startsWithCapital(shifted: true, before: "and", addsSpace: true, autocapitalization: .none))
    }

    /// "Hi." then a swipe: the swipe's own space ends the sentence, so the word takes the
    /// capital the keyboard would give after "Hi. ".
    func testTheSwipesOwnSpaceCanEndASentence() {
        XCTAssertTrue(SwipeTypingText.startsWithCapital(shifted: false, before: "Hi.", addsSpace: true, autocapitalization: .sentences))
        XCTAssertTrue(SwipeTypingText.startsWithCapital(shifted: false, before: "Quoi ?", addsSpace: true, autocapitalization: .sentences))
        XCTAssertFalse(SwipeTypingText.startsWithCapital(shifted: false, before: "Hi,", addsSpace: true, autocapitalization: .sentences))
        XCTAssertFalse(SwipeTypingText.startsWithCapital(shifted: false, before: "hello", addsSpace: true, autocapitalization: .sentences))
        XCTAssertFalse(SwipeTypingText.startsWithCapital(shifted: false, before: "Hi.", addsSpace: false, autocapitalization: .sentences))
        XCTAssertFalse(SwipeTypingText.startsWithCapital(shifted: false, before: "Hi.", addsSpace: true, autocapitalization: .none))
        XCTAssertTrue(SwipeTypingText.startsWithCapital(shifted: false, before: "New", addsSpace: true, autocapitalization: .words))
    }

    func testCasing() {
        XCTAssertEqual(SwipeTypingText.cased("bonjour", capital: true, capsLock: false), "Bonjour")
        XCTAssertEqual(SwipeTypingText.cased("été", capital: true, capsLock: false), "Été")
        XCTAssertEqual(SwipeTypingText.cased("bonjour", capital: false, capsLock: false), "bonjour")
        XCTAssertEqual(SwipeTypingText.cased("I'm", capital: false, capsLock: false), "I'm", "the extra word's own capital stays")
        XCTAssertEqual(SwipeTypingText.cased("déjà", capital: false, capsLock: true), "DÉJÀ")
    }

    // MARK: - The bar

    func testTheLikeliestOtherReadingTakesTheCentreSlot() {
        XCTAssertEqual(SwipeTypingText.barOrder(["two", "three", "four", "five"]), ["three", "two", "four"])
        XCTAssertEqual(SwipeTypingText.barOrder(["two", "three"]), ["three", "two"])
        XCTAssertEqual(SwipeTypingText.barOrder(["two"]), ["two"])
        XCTAssertEqual(SwipeTypingText.barOrder([]), [])
    }

    func testReadingsAreOfferedOnce() {
        XCTAssertEqual(SwipeTypingText.unique(["its", "it's", "Its", "is"]), ["its", "it's", "is"])
    }

    // MARK: - The swiped word

    func testDeleteTakesBackTheWordAndTheSpaceItAdded() {
        let swiped = SwipedWord(word: "world", addedSpace: true, alternatives: ["word", "would"])
        XCTAssertEqual(swiped.inserted, " world")
        XCTAssertEqual(swiped.deletionCount(before: "hello world"), 6)
        XCTAssertEqual(SwipedWord(word: "Bonjour", addedSpace: false, alternatives: []).deletionCount(before: "Bonjour"), 7)
    }

    func testAStaleRecordDeletesNothingWhole() {
        let swiped = SwipedWord(word: "world", addedSpace: true, alternatives: [])
        XCTAssertNil(swiped.deletionCount(before: "hello world!"), "something was typed since")
        XCTAssertNil(swiped.deletionCount(before: "helloworld"), "the space it added is gone")
        XCTAssertNil(swiped.deletionCount(before: nil))
    }

    func testAnotherReadingTakesTheWordsPlace() throws {
        let swiped = SwipedWord(word: "two", addedSpace: true, alternatives: ["yep", "tip", "typo", "toe"])
        XCTAssertEqual(swiped.alternatives, ["yep", "tip", "typo"], "three at most")
        let replaced = try XCTUnwrap(swiped.replacing(with: "yep", before: "ok two"))
        XCTAssertEqual(replaced.deleteCount, 3, "the word only: the space stays")
        XCTAssertEqual(replaced.insert, "yep")
        XCTAssertEqual(replaced.record.word, "yep")
        XCTAssertEqual(replaced.record.inserted, " yep")
        XCTAssertEqual(replaced.record.alternatives, ["two", "tip", "typo"], "the word it replaced is offered back")
        XCTAssertEqual(replaced.record.deletionCount(before: "ok yep"), 4)
        XCTAssertNil(swiped.replacing(with: "yep", before: "ok tw"), "the word is no longer there")
        XCTAssertNil(swiped.replacing(with: "yep", before: "oktwo"), "the space the swipe added is gone")
        XCTAssertNil(swiped.replacing(with: "two", before: "ok two"), "the same word changes nothing")
    }

    func testTheRecordNeverOffersItsOwnWord() {
        XCTAssertEqual(SwipedWord(word: "the", addedSpace: false, alternatives: ["the", "they"]).alternatives, ["they"])
    }

    // MARK: - English contractions

    func testTheSwipeContractionsAddTheCommonOnesAutocorrectLeavesAlone() {
        let words = SwipeExtraWords.englishContractions
        for word in ["won't", "let's", "we'll", "I'll", "it's", "don't", "I'm"] {
            XCTAssertTrue(words.contains(word), word)
        }
        XCTAssertFalse(words.contains("i'm"), "written as you'd see it")
        XCTAssertEqual(words.count, Set(words).count)
        // Autocorrect's own map is not touched: "wont" is still not an override.
        XCTAssertNil(englishProfile.overrides["wont"])
    }

    /// Bench of #1050: "won't" read as "wont" on Hex's paths. With the swipe list the decoder
    /// offers it.
    func testASwipeThroughWontOffersWont() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DictusKeyboard/Resources/en.hextm").path
        let model = try XCTUnwrap(SpatialDecoderModel(path: path))
        var decoder = SwipeDecoder(model: model)
        decoder.extraWords = SwipeDecoder.ExtraWords(
            SwipeExtraWords.englishContractions, cost: { _ in SwipeDecoder.contractionCost }, model: model, contractions: true
        )
        let keys = SwipeKeys.letterPage("en")
        let readings = decoder.decode(SwipePath.through("wont", keys: keys), keys: keys, previous: "i").map(\.text)
        XCTAssertTrue(readings.prefix(4).contains("won't"), "\(readings)")
    }
}
