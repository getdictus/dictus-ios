// DictusCore/Tests/DictusCoreTests/AutocorrectRejectionMemoryTests.swift
// A refused autocorrection is not made again at the same place (#872).
//
// Each test feeds the memory the contexts the keyboard bridge passes it, in the
// order a user produces them. The scenario numbers are the ones of the Apple vs
// Dictus comparison on the iOS 27 simulator, recorded on the issue.

import XCTest
@testable import DictusCore

final class AutocorrectRejectionMemoryTests: XCTestCase {

    private var memory: AutocorrectRejectionMemory!

    override func setUp() {
        super.setUp()
        memory = AutocorrectRejectionMemory()
        memory.enter(document: "doc-A")
    }

    /// The keyboard commits `word` at the end of `context` and the corrector
    /// proposes `correction`.
    private func commit(
        _ context: String, proposing correction: String?
    ) -> AutocorrectRejectionMemory.Decision {
        guard let (prefix, word) = AutocorrectRejectionMemory.wordAtCursor(context: context) else {
            XCTFail("no word at the end of \"\(context)\"")
            return .keep(countUsage: false)
        }
        return memory.commit(prefix: prefix, word: word, proposedCorrection: correction)
    }

    /// Dictus applies `typed` → `corrected` at the end of `context`, which ends with `typed`.
    private func applyCorrection(_ context: String, to corrected: String) {
        guard let (prefix, _) = AutocorrectRejectionMemory.wordAtCursor(context: context) else {
            return XCTFail("no word at the end of \"\(context)\"")
        }
        XCTAssertEqual(memory.commit(prefix: prefix, word: String(context[prefix.endIndex...]),
                                     proposedCorrection: corrected), .correct)
        memory.correctionApplied(prefix: prefix, corrected: corrected)
    }

    /// Backspaces from `start` down to `end`, one character at a time, as the bridge
    /// reports them.
    private func erase(from start: String, to end: String) {
        var text = start
        while text.count > end.count {
            let before = text
            text.removeLast()
            memory.textDeleted(before: before, after: text)
        }
        XCTAssertEqual(text, end)
    }

    // MARK: - Erasing a correction and typing again at the same place

    func testRetypingTheSameWordAfterErasingTheCorrectionKeepsAndLearnsIt() {
        // Scenario 3: `la montagnr` → montagne, word erased, `montagnr` typed again.
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la ")

        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .keepAndLearn)
    }

    func testRetypingANearbyWordAfterErasingTheCorrectionKeepsAndLearnsIt() {
        // Scenario 4: `le soleik` → soleil, word erased, `soleiq` typed instead.
        applyCorrection("le soleik", to: "soleil")
        erase(from: "le soleil ", to: "le ")

        XCTAssertEqual(commit("le soleiq", proposing: "soleil"), .keepAndLearn)
    }

    func testErasingOneLetterOfTheCorrectionIsARefusal() {
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la montagn")

        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .keepAndLearn)
    }

    func testErasingOnlyTheSpaceAfterTheCorrectionIsNotARefusal() {
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la montagne")

        XCTAssertNil(memory.textDeleted(before: "la montagne ", after: "la montagne"))
        XCTAssertFalse(memory.isRejected(prefix: "la "))
    }

    func testErasingOnlyTheSpaceBeforeTheCorrectionIsNotARefusal() {
        // Review of #874: the caret is moved back to just after `la `, in front of
        // the corrected word, and the space is erased. No letter of `montagne` went,
        // so nothing was refused, and a typo typed at that place later is corrected.
        applyCorrection("la montagnr", to: "montagne")

        XCTAssertNil(memory.textDeleted(before: "la ", after: "la"))
        XCTAssertFalse(memory.isRejected(prefix: "la "))
        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .correct)
    }

    func testErasingTheWholeCorrectionAtOnceIsARefusal() {
        // A held backspace deletes `montagne ` in one step: letters went.
        applyCorrection("la montagnr", to: "montagne")

        XCTAssertEqual(memory.textDeleted(before: "la montagne ", after: "la "), "montagne")
        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .keepAndLearn)
    }

    func testTheMemorySurvivesErasingTheSpaceBeforeTheWord() {
        // Scenario 21: `la plagr` → plage, word AND preceding space erased, ` plagr` typed.
        applyCorrection("la plagr", to: "plage")
        erase(from: "la plage ", to: "la")

        XCTAssertEqual(commit("la plagr", proposing: "plage"), .keepAndLearn)
    }

    func testTheMemorySurvivesTheNextWords() {
        // `rejectedWords` was emptied at the start of the next word; this is not.
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la ")
        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .keepAndLearn)
        XCTAssertEqual(commit("la montagnr est", proposing: nil), .keep(countUsage: true))
        XCTAssertEqual(commit("la montagnr est haute", proposing: nil), .keep(countUsage: true))

        XCTAssertTrue(memory.isRejected(prefix: "la "))
    }

    func testAnotherPositionIsStillCorrected() {
        // The refusal is a place, not a word: elsewhere the learned word protects it,
        // and an unrelated typo there is still corrected.
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la ")

        XCTAssertEqual(commit("la montagnr. Une montagnr", proposing: "montagne"), .correct)
    }

    func testTheMemoryIsLimitedToTheDocument() {
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la ")

        memory.enter(document: "doc-B")
        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .correct)

        memory.enter(document: "doc-A")
        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .correct,
                       "coming back to a document does not bring its refusals back")
    }

    func testErasingPastThePositionForgetsIt() {
        // Measured on the simulator: `Le batrau` refused by Undo, the field erased,
        // then a new message starting `Le soleik` was kept and `soleik` learned,
        // because the new word sat after the same `Le`. Once the text before a
        // refused word is erased, that position no longer exists.
        applyCorrection("Le batrau", to: "bateau")
        memory.correctionUndone(prefix: "Le ", original: "batrau")
        erase(from: "Le batrau ", to: "")

        XCTAssertEqual(commit("Le soleik", proposing: "soleil"), .correct)
        XCTAssertNil(memory.movingOn(context: "Le batrau "), "the restored word is gone too")
    }

    func testErasingPastAnAppliedCorrectionStopsWatchingIt() {
        applyCorrection("Le batrau", to: "bateau")
        erase(from: "Le bateau ", to: "")

        // A new `Le` followed by a backspace into a word is not a refusal of `bateau`.
        XCTAssertNil(memory.textDeleted(before: "Le bate", after: "Le bat"))
        XCTAssertEqual(commit("Le batrau", proposing: "bateau"), .correct)
    }

    func testWithoutADocumentIdentifierTwoFieldsDoNotShareRefusals() {
        // Review of #874: a host may give no `documentIdentifier`. Two such fields
        // looked like one document, so a refusal in the first one kept, and
        // learned, a typo typed after the same text in the second.
        memory.enter(document: nil)
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la ")

        memory.enter(document: nil)  // the next event, maybe in another field
        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .correct)
        XCTAssertFalse(memory.remembersRefusals)
        memory.enter(document: "doc-B")
        XCTAssertTrue(memory.remembersRefusals)
    }

    func testTheSameDocumentKeepsItsMemory() {
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la ")

        memory.enter(document: "doc-A")
        XCTAssertEqual(commit("la montagnr", proposing: "montagne"), .keepAndLearn)
    }

    func testAKeyIsTheEndOfTheTextBeforeTheWord() {
        // A host may give a window that ends at the cursor: the key only reads its end.
        let long = String(repeating: "x", count: 100) + " le "
        XCTAssertEqual(AutocorrectRejectionMemory.positionKey(prefix: Substring(long)),
                       String(long.dropLast().suffix(AutocorrectRejectionMemory.keyLength)))
        XCTAssertEqual(AutocorrectRejectionMemory.positionKey(prefix: "la  \n"), "la")
    }

    // MARK: - The suggestion bar

    func testTheBarHidesTheCorrectionOnlyAtTheRefusedPosition() {
        // Review of #874: the bar kept refused spellings in one global set, so the
        // same typo typed elsewhere showed no correction, while space still made it.
        applyCorrection("la montagnr", to: "montagne")
        erase(from: "la montagne ", to: "la ")

        XCTAssertFalse(memory.previewsCorrection(context: "la montagnr"))
        XCTAssertTrue(memory.previewsCorrection(context: "la montagnr. Une montagnr"))
        XCTAssertEqual(commit("la montagnr. Une montagnr", proposing: "montagne"), .correct,
                       "the bar previews what space does")
    }

    // MARK: - Undo

    func testUndoThenMovingOnLearnsTheRestoredWord() {
        // Scenario 2: `le batrau` → bateau, Undo restores `batrau ` with its space,
        // the user types the next word.
        applyCorrection("le batrau", to: "bateau")
        memory.correctionUndone(prefix: "le ", original: "batrau")

        XCTAssertEqual(memory.movingOn(context: "le batrau "), "batrau")
        XCTAssertNil(memory.movingOn(context: "le batrau "), "learned once")
    }

    func testUndoThenAPredictionTapStillLearnsTheRestoredWord() {
        // Review of #874: after Undo, tapping a prediction inserts `est ` in one go.
        // The next keystroke then sees `est` at the caret, not `batrau`, and the
        // restored word was never learned.
        applyCorrection("le batrau", to: "bateau")
        memory.correctionUndone(prefix: "le ", original: "batrau")

        XCTAssertEqual(memory.movingOn(context: "le batrau est "), "batrau")
    }

    func testUndoBeforeAPunctuationMarkThenMovingOnLearnsTheRestoredWord() {
        // Review of #874: Undo of `cuisinr,` → `cuisine,` restores `cuisinr,`, and
        // `cuisinr, ` does not end with the restored word.
        applyCorrection("la cuisinr", to: "cuisine")
        memory.correctionUndone(prefix: "la ", original: "cuisinr")

        XCTAssertEqual(memory.movingOn(context: "la cuisinr, "), "cuisinr")
    }

    func testUndoAloneLearnsNothing() {
        applyCorrection("le batrau", to: "bateau")
        memory.correctionUndone(prefix: "le ", original: "batrau")

        // Still on the word: nothing has been validated yet.
        XCTAssertNil(memory.movingOn(context: "le batrau"))
    }

    func testUndoThenEditingLearnsTheEditNotTheTypo() {
        // Scenario 5: `crayin` → crayon, Undo, erase the space and `n`, type `m`.
        applyCorrection("un crayin", to: "crayon")
        memory.correctionUndone(prefix: "un ", original: "crayin")

        XCTAssertEqual(commit("un crayim", proposing: "crayon"), .keepAndLearn)
        // `crayin` is never handed back to be learned: moving on past `crayim` is
        // not moving on past the restored word.
        XCTAssertNil(memory.movingOn(context: "un crayim "))
        // Further on, the typo is corrected again.
        XCTAssertEqual(commit("un crayim et un crayin", proposing: "crayon"), .correct)
    }

    func testUndoThenCommittingTheRestoredWordLearnsIt() {
        // Erase the restored space and press space again: the same word, validated.
        applyCorrection("le batrau", to: "bateau")
        memory.correctionUndone(prefix: "le ", original: "batrau")

        XCTAssertEqual(commit("le batrau", proposing: "bateau"), .keepAndLearn)
        XCTAssertNil(memory.movingOn(context: "le batrau "), "already learned at the commit")
    }

    func testUndoThenEditingIntoAValidWordLearnsNothing() {
        applyCorrection("un crayin", to: "crayon")
        memory.correctionUndone(prefix: "un ", original: "crayin")

        XCTAssertEqual(commit("un crayon", proposing: nil), .keep(countUsage: true))
        XCTAssertNil(memory.movingOn(context: "un crayon "))
    }

    // MARK: - The typed word, quoted in slot 0

    func testTappingTheTypedWordRefusesThePosition() {
        // Scenario 8: `La musiqur`, tap «musiqur». The bridge learns it on the tap;
        // the position is remembered as refused too.
        memory.typedWordKept(prefix: "La ")
        XCTAssertTrue(memory.isRejected(prefix: "La "))
        XCTAssertEqual(commit("La musiqur", proposing: "musique"), .keepAndLearn)
    }

    // MARK: - #287: no learning without a refused correction

    func testAWordNeverCorrectedIsNeverLearnedHere() {
        XCTAssertEqual(commit("le blorpa", proposing: nil), .keep(countUsage: true))
        XCTAssertEqual(commit("le blorpa et", proposing: "est"), .correct)
        XCTAssertNil(memory.movingOn(context: "le blorpa "))
    }

    func testACorrectionTheUserKeepsLearnsNothing() {
        applyCorrection("le batrau", to: "bateau")
        XCTAssertNil(memory.movingOn(context: "le bateau "))
        XCTAssertEqual(commit("le bateau", proposing: nil), .keep(countUsage: true))
    }

    func testTheSameWordCommittedTwiceAtTheSamePlaceIsCountedOnce() {
        // Scenario 13: `ECOLR ` then backspace over the space and `.` committed the
        // same word again, and `recordUsage` reached its threshold of 2 on one word.
        XCTAssertEqual(commit("une ECOLR", proposing: nil), .keep(countUsage: true))
        XCTAssertEqual(commit("une ECOLR", proposing: nil), .keep(countUsage: false))
        XCTAssertEqual(commit("une ECOLR. Une ECOLR", proposing: nil), .keep(countUsage: true))
    }

    // MARK: - Word at cursor

    func testWordAtCursorNeedsTheContextToEndWithTheWord() {
        XCTAssertEqual(AutocorrectRejectionMemory.wordAtCursor(context: "la cuisinr")?.word, "cuisinr")
        XCTAssertEqual(AutocorrectRejectionMemory.wordAtCursor(context: "la cuisinr")?.prefix, "la ")
        XCTAssertNil(AutocorrectRejectionMemory.wordAtCursor(context: "la cuisine,"))
        XCTAssertNil(AutocorrectRejectionMemory.wordAtCursor(context: "la cuisine "))
        XCTAssertNil(AutocorrectRejectionMemory.wordAtCursor(context: ""))
        XCTAssertNil(AutocorrectRejectionMemory.wordAtCursor(context: nil))
    }
}
