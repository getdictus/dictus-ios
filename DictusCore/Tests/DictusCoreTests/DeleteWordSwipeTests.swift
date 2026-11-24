import XCTest
@testable import DictusCore

/// The delete swipe (#609): slide left from backspace to delete word by word, back right to
/// get the words back, lift to keep what is deleted.
final class DeleteWordSwipeTests: XCTestCase {

    /// A host document seen through the proxy's mirror. `window` is how much of the text
    /// before the cursor the host shares; the mirror follows the keyboard's own edits at
    /// once and the host's view only on `hostCatchesUp()`, as a real proxy does.
    private final class HostDocument: TextDocumentEditing {
        private(set) var text: String
        private(set) var mirror: String
        let window: Int?
        var mirrorIgnoresDeletes = false

        init(_ text: String, window: Int? = nil) {
            self.text = text
            self.window = window
            mirror = window.map { String(text.suffix($0)) } ?? text
        }

        var contextBeforeInput: String? { mirror.isEmpty ? nil : mirror }

        func deleteBackward() {
            if !text.isEmpty { text.removeLast() }
            if !mirrorIgnoresDeletes, !mirror.isEmpty { mirror.removeLast() }
        }

        func insertText(_ inserted: String) {
            text += inserted
            mirror += inserted
        }

        func hostCatchesUp() {
            mirror = window.map { String(text.suffix($0)) } ?? text
        }
    }

    private let sentence = "Dictus est le clavier qui écrit vraiment comme je parle"
    private let key = 30.0
    private let start = 300.0

    private func swipe(_ document: HostDocument, mirror: MirrorSyncState? = nil, touchDown: String? = nil) -> DeleteWordSwipe {
        DeleteWordSwipe(editor: document, mirror: mirror, startX: start, step: key, touchDownDeletion: touchDown)
    }

    /// The x of a finger `words` key widths left of where it went down, mid-step.
    private func x(words: Int) -> Double { start - Double(words) * key - key / 2 }

    // MARK: - The gesture

    func testThePressAloneDoesNothing() {
        let document = HostDocument(sentence)
        let slide = swipe(document)
        XCTAssertNil(slide.move(toX: start - key + 1))
        XCTAssertNil(slide.move(toX: start + 3 * key))
        XCTAssertFalse(slide.isActive)
        XCTAssertEqual(document.text, sentence)
    }

    func testEachKeyWidthLeftDeletesOneMoreWord() {
        let document = HostDocument(sentence)
        let slide = swipe(document)
        XCTAssertEqual(slide.move(toX: x(words: 1)), DeleteWordSwipe.Change(deletedWords: 1))
        XCTAssertTrue(slide.isActive)
        XCTAssertEqual(document.text, "Dictus est le clavier qui écrit vraiment comme je ")
        XCTAssertEqual(slide.move(toX: x(words: 3)), DeleteWordSwipe.Change(deletedWords: 2))
        XCTAssertEqual(document.text, "Dictus est le clavier qui écrit vraiment ")
    }

    func testSlidingBackRightGivesTheWordsBack() {
        // Pierre's demo: three words away, two back, lift.
        let document = HostDocument(sentence)
        let slide = swipe(document)
        slide.move(toX: x(words: 3))
        XCTAssertEqual(slide.move(toX: x(words: 1)), DeleteWordSwipe.Change(restoredWords: 2))
        XCTAssertEqual(document.text, "Dictus est le clavier qui écrit vraiment comme je ")
        slide.finish()
        XCTAssertEqual(document.text, "Dictus est le clavier qui écrit vraiment comme je ")
    }

    func testLiftingKeepsWhatIsDeleted() {
        let document = HostDocument(sentence)
        let slide = swipe(document)
        slide.move(toX: x(words: 2))
        slide.finish()
        XCTAssertEqual(document.text, "Dictus est le clavier qui écrit vraiment comme ")
        XCTAssertEqual(slide.deletedWordCount, 0)
    }

    func testWiggleWithinAStepDoesNothingMore() {
        let document = HostDocument(sentence)
        let slide = swipe(document)
        slide.move(toX: x(words: 1))
        XCTAssertEqual(slide.move(toX: x(words: 1) + key / 3), DeleteWordSwipe.Change())
        XCTAssertEqual(slide.move(toX: x(words: 1) - key / 3), DeleteWordSwipe.Change())
        XCTAssertEqual(slide.deletedWordCount, 1)
    }

    func testSlidingAllTheWayBackGivesTheTouchDownCharacterBack() {
        // The touch-down deleted the "e" of "parle"; the first word takes "parl" and gives
        // back "parle", so the text is as it was before the finger went down.
        let document = HostDocument("comme je parl")
        let slide = swipe(document, touchDown: "e")
        slide.move(toX: x(words: 1))
        XCTAssertEqual(document.text, "comme je ")
        slide.move(toX: start)
        XCTAssertEqual(document.text, "comme je parle")
        // Away again: the "e" is in the text now, and is deleted with the word.
        slide.move(toX: x(words: 1))
        XCTAssertEqual(document.text, "comme je ")
        slide.move(toX: start)
        XCTAssertEqual(document.text, "comme je parle")
    }

    /// Delete right after a swiped word took back " world" on touch-down (#948): that is the
    /// slide's first word, so the first step deletes nothing more, the second deletes "two",
    /// and sliding all the way back gives the text exactly as it was before the touch.
    func testAWordTheTouchDownTookBackIsTheSlidesFirstWord() {
        let document = HostDocument("one two")
        let slide = DeleteWordSwipe(editor: document, mirror: nil, startX: start, step: key, touchDownWord: " world")
        XCTAssertEqual(slide.move(toX: x(words: 1)), DeleteWordSwipe.Change())
        XCTAssertTrue(slide.isActive)
        XCTAssertEqual(document.text, "one two")
        slide.move(toX: x(words: 2))
        XCTAssertEqual(document.text, "one ")
        slide.move(toX: start)
        XCTAssertEqual(document.text, "one two world")
    }

    func testARepeatBeforeTheSlideDropsTheTouchDownWord() {
        let document = HostDocument("one tw")
        let slide = DeleteWordSwipe(editor: document, mirror: nil, startX: start, step: key, touchDownWord: " world")
        slide.forgetTouchDownDeletion()
        slide.move(toX: x(words: 1))
        XCTAssertEqual(document.text, "one ")
        slide.move(toX: start)
        XCTAssertEqual(document.text, "one tw")
    }

    func testARepeatBeforeTheSlideDropsTheTouchDownCharacter() {
        let document = HostDocument("comme je pa")
        let slide = swipe(document, touchDown: "e")
        slide.forgetTouchDownDeletion()
        slide.move(toX: x(words: 1))
        slide.move(toX: start)
        XCTAssertEqual(document.text, "comme je pa")
    }

    func testTheSlideStopsAtTheStartOfTheText() {
        let document = HostDocument("un deux")
        let slide = swipe(document)
        XCTAssertEqual(slide.move(toX: x(words: 5)), DeleteWordSwipe.Change(deletedWords: 2))
        XCTAssertEqual(document.text, "")
        XCTAssertEqual(slide.move(toX: x(words: 1)), DeleteWordSwipe.Change(restoredWords: 1))
        XCTAssertEqual(document.text, "un ")
    }

    func testAnEmptyFieldDeletesNothing() {
        let document = HostDocument("")
        let slide = swipe(document)
        XCTAssertEqual(slide.move(toX: x(words: 2)), DeleteWordSwipe.Change())
        XCTAssertTrue(slide.isActive)
        XCTAssertEqual(document.text, "")
    }

    func testTheContextAtActivationIsReadBeforeTheFirstEdit() {
        let document = HostDocument("un deux")
        let slide = swipe(document)
        slide.move(toX: x(words: 1))
        XCTAssertEqual(slide.contextAtActivation, "un deux")
    }

    // MARK: - Truncated context

    func testAWordTheHostCutShortIsFinishedOnceItCatchesUp() {
        // The host shares 8 characters: "dinateur" of "ordinateur".
        let document = HostDocument("Il a un ordinateur", window: 8)
        let slide = swipe(document)
        slide.move(toX: x(words: 1))
        XCTAssertEqual(document.text, "Il a un or")
        // The host has not caught up: nothing is shared, so nothing more is deleted, even
        // for a finger asking for two more words.
        XCTAssertEqual(slide.move(toX: x(words: 3)), DeleteWordSwipe.Change())
        XCTAssertEqual(document.text, "Il a un or")
        // It caught up: the word is finished first, as part of the same step.
        document.hostCatchesUp()
        XCTAssertEqual(slide.move(toX: x(words: 1)), DeleteWordSwipe.Change())
        XCTAssertEqual(document.text, "Il a un ")
        XCTAssertEqual(slide.deletedWordCount, 1)
        // And comes back whole.
        slide.move(toX: start)
        XCTAssertEqual(document.text, "Il a un ordinateur")
    }

    func testTheNextWordsFollowOnceTheHostCaughtUp() {
        let document = HostDocument("Il a un ordinateur", window: 8)
        let slide = swipe(document)
        slide.move(toX: x(words: 1))
        document.hostCatchesUp()
        XCTAssertEqual(slide.move(toX: x(words: 2)), DeleteWordSwipe.Change(deletedWords: 1))
        XCTAssertEqual(document.text, "Il a ")
    }

    func testLiftingFinishesAWordTheHostCutShort() {
        let document = HostDocument("Il a un ordinateur", window: 8)
        let slide = swipe(document)
        slide.move(toX: x(words: 1))
        document.hostCatchesUp()
        slide.finish()
        XCTAssertEqual(document.text, "Il a un ")
    }

    func testAWordEndingRightAtTheCutIsNotExtended() {
        // The host shares "ordinateur" exactly; the space before it was not shared.
        let document = HostDocument("Il a un ordinateur", window: 10)
        let slide = swipe(document)
        slide.move(toX: x(words: 1))
        document.hostCatchesUp()
        slide.finish()
        XCTAssertEqual(document.text, "Il a un ")
    }

    // MARK: - Mirror (#530)

    func testConsistentEditsLeaveTheMirrorTrusted() {
        let document = HostDocument(sentence)
        let mirror = MirrorSyncState()
        let slide = swipe(document, mirror: mirror)
        slide.move(toX: x(words: 3))
        slide.move(toX: x(words: 1))
        XCTAssertFalse(mirror.isSuspect)
        XCTAssertFalse(slide.isFrozen)
    }

    func testAMirrorThatDoesNotMoveStopsTheSlide() {
        let document = HostDocument(sentence)
        document.mirrorIgnoresDeletes = true
        let mirror = MirrorSyncState()
        let slide = swipe(document, mirror: mirror)
        XCTAssertEqual(slide.move(toX: x(words: 1)), DeleteWordSwipe.Change(deletedWords: 1))
        XCTAssertTrue(slide.isFrozen)
        XCTAssertTrue(mirror.isSuspect)
        let afterFirst = document.text
        // Nothing more is deleted, and nothing is typed back: what the deletion removed is
        // no longer known for certain.
        XCTAssertEqual(slide.move(toX: x(words: 3)), DeleteWordSwipe.Change())
        XCTAssertEqual(slide.move(toX: start), DeleteWordSwipe.Change())
        XCTAssertEqual(document.text, afterFirst)
    }

    // MARK: - The touch-down's character

    func testTheTouchDownCharacterIsReadOffTheContext() {
        XCTAssertEqual(DeleteWordSwipe.touchDownDeletion(before: "je parle", after: "je parl"), "e")
        XCTAssertEqual(DeleteWordSwipe.touchDownDeletion(before: "a", after: nil), "a")
        XCTAssertEqual(DeleteWordSwipe.touchDownDeletion(before: "ok 👍🏽", after: "ok "), "👍🏽")
    }

    func testNoCharacterWhenTheContextDoesNotSaySoForCertain() {
        // A selection deleted: the text before the cursor did not change.
        XCTAssertNil(DeleteWordSwipe.touchDownDeletion(before: "je parle", after: "je parle"))
        // Nothing before the cursor, or no context at all.
        XCTAssertNil(DeleteWordSwipe.touchDownDeletion(before: nil, after: nil))
        XCTAssertNil(DeleteWordSwipe.touchDownDeletion(before: "", after: nil))
        // Something else moved: two characters gone, or not the last one.
        XCTAssertNil(DeleteWordSwipe.touchDownDeletion(before: "je parle", after: "je par"))
        XCTAssertNil(DeleteWordSwipe.touchDownDeletion(before: "je parle", after: "e parle"))
    }

    func testAKeyWidthIsNeverZero() {
        let document = HostDocument(sentence)
        let slide = DeleteWordSwipe(editor: document, mirror: nil, startX: 10, step: 0)
        XCTAssertEqual(slide.move(toX: 8.5), DeleteWordSwipe.Change(deletedWords: 1))
    }
}
