// DictusCore/Tests/DictusCoreTests/LoneLetterCorrectionTests.swift
// A French lone letter is corrected to the neighbouring key that is a word, or kept (#977).

import XCTest
@testable import DictusCore

final class LoneLetterCorrectionTests: XCTestCase {

    private let french = frenchProfile

    /// The rule as `TextPredictionEngine.checkWord` asks it, on AZERTY unless told.
    private func decide(
        _ word: String, context: String? = nil, layout: LayoutType = .azerty,
        learned: Set<String> = []
    ) -> LoneLetterCorrection.Decision? {
        LoneLetterCorrection.decision(
            for: word, words: french.loneLetterWords, layout: layout, context: context,
            markers: french.loneLetterMarkers, homographs: french.contextualHomographs,
            isLearned: learned.contains
        )
    }

    // MARK: - Corrected

    /// The device report (2026-11-19): `vas avoir des problème z` kept the `z`.
    func testTheReportedSentenceGetsItsA() {
        XCTAssertEqual(decide("z", context: "vas avoir des problème z"), .correct("a"))
    }

    func testTheKeysNextToAAreCorrectedToA() {
        XCTAssertEqual(decide("z"), .correct("a"))
        XCTAssertEqual(decide("q"), .correct("a"))
    }

    func testTheKeysNextToYAreCorrectedToY() {
        for letter in ["t", "u", "g", "h"] {
            XCTAssertEqual(decide(letter), .correct("y"), letter)
        }
        XCTAssertEqual(decide("t", context: "il t"), .correct("y"))
    }

    /// The corrected `a` goes through the a/à rule (#501) as a typed one would.
    func testTheCorrectionTakesTheGraveAccentWhereTheSentenceCallsForIt() {
        XCTAssertEqual(decide("z", context: "je vais z"), .correct("\u{00E0}"))
        XCTAssertEqual(decide("q", context: "il q"), .correct("a"))
    }

    /// The neighbours come from the layout in use: on QWERTY `z` and `q` still touch `a`,
    /// and `w` does too.
    func testNeighboursFollowTheLayout() {
        XCTAssertEqual(decide("z", layout: .qwerty), .correct("a"))
        XCTAssertEqual(decide("q", layout: .qwerty), .correct("a"))
        XCTAssertEqual(decide("w", layout: .qwerty), .correct("a"))
        XCTAssertEqual(decide("w", layout: .azerty), .keep)
    }

    // MARK: - Kept

    /// `a`, `à` and `y` are words: the usual path decides them, the a/à rule included.
    func testTheLettersThatAreWordsAreNotTheRules() {
        for word in ["a", "\u{00E0}", "y", "A", "Y"] {
            XCTAssertNil(decide(word), word)
        }
    }

    /// A letter with no neighbouring word stays as typed: `l` is not `le`.
    func testALetterWithNoNeighbouringWordIsKept() {
        for letter in ["b", "c", "d", "e", "l", "m", "n", "s", "x"] {
            XCTAssertEqual(decide(letter), .keep, letter)
        }
    }

    /// `plan B`, `vitamine C`, and an initial at the start of a sentence.
    func testACapitalLetterIsKept() {
        XCTAssertEqual(decide("B", context: "on passe au plan B"), .keep)
        XCTAssertEqual(decide("Z", context: "la lettre Z"), .keep)
        XCTAssertEqual(decide("T", context: "T"), .keep)
        XCTAssertEqual(decide("H", context: "Merci. H"), .keep)
    }

    /// Titus's review of #1061: after a determiner or `lettre` the letter is the letter.
    /// `le h aspiré` was `le y aspiré` on develop too, through the trie.
    func testALetterNamedAsALetterIsKept() {
        XCTAssertEqual(decide("h", context: "le h"), .keep)
        XCTAssertEqual(decide("z", context: "un z"), .keep)
        XCTAssertEqual(decide("b", context: "la lettre b"), .keep)
        XCTAssertEqual(decide("z", context: "la lettre z"), .keep)
        XCTAssertEqual(decide("p", context: "du p"), .keep)
        XCTAssertEqual(decide("t", context: "Le t"), .keep)
        XCTAssertEqual(decide("q", context: "avec une q"), .keep)
        XCTAssertEqual(decide("u", context: "des u"), .keep)
        XCTAssertEqual(decide("z", context: "le mot d\u{2019} z"), .keep)
    }

    /// A marker counts only right before the letter, and `les` is not one: it is also the
    /// pronoun of `il les a vus`.
    func testOnlyTheWordRightBeforeMarksALetter() {
        XCTAssertEqual(decide("z", context: "le problème z"), .correct("a"))
        XCTAssertEqual(decide("t", context: "il t"), .correct("y"))
        XCTAssertEqual(decide("z", context: "il les z"), .correct("a"))
        // Nothing before it: the start of a sentence, where #501 writes `à` (`À demain`).
        XCTAssertEqual(decide("z", context: "z"), .correct("\u{00E0}"))
    }

    func testALearnedLetterIsKept() {
        XCTAssertEqual(decide("z", learned: ["z"]), .keep)
        XCTAssertEqual(decide("q", learned: ["z"]), .correct("a"))
    }

    /// `le mot commence par l'h`: develop wrote `l'y`, because the French dictionary has
    /// no `h` and the trie read it alone.
    func testALetterAfterAnApostropheIsKept() {
        XCTAssertEqual(decide("l'h", context: "le mot commence par l'h"), .keep)
        XCTAssertEqual(decide("l\u{2019}h"), .keep)
        XCTAssertEqual(decide("qu'z"), .keep)
        XCTAssertEqual(decide("L'H"), .keep)
    }

    /// An elided `a` or `y` (`l'a`, `j'y`), a longer word and a bare prefix are the usual
    /// path's.
    func testAnElidedWordIsNotTheRules() {
        for word in ["l'a", "j'y", "qu'\u{00E0}", "l'eau", "aujourd'hui", "l'", "l'1"] {
            XCTAssertNil(decide(word), word)
        }
    }

    func testOnlyLettersAreTheRules() {
        XCTAssertNil(decide(""))
        XCTAssertNil(decide("za"))
        XCTAssertNil(decide("-"))
        XCTAssertNil(decide("'"))
    }

    /// The other languages have no list yet (#977 asks for them separately).
    func testTheRuleIsOffWhereNoListWasWritten() {
        for profile in [englishProfile, spanishProfile, germanProfile] {
            XCTAssertNil(profile.loneLetterWords, profile.code)
            XCTAssertNil(LoneLetterCorrection.decision(
                for: "z", words: profile.loneLetterWords, layout: profile.defaultLayout, isLearned: { _ in false }
            ), profile.code)
        }
    }

    // MARK: - Lists, e-mail addresses and URLs, typed key by key

    /// A document whose mirror always agrees with it.
    private final class Document: TextDocumentEditing {
        var text = ""
        var contextBeforeInput: String? { text.isEmpty ? nil : text }
        func deleteBackward() { if !text.isEmpty { text.removeLast() } }
        func insertText(_ inserted: String) { text += inserted }
    }

    /// What the keyboard does for each key, in `DictusKeyboardBridge`'s order: put back a
    /// correction the key shows was inside an address, then correct the word before the
    /// space or a committing mark unless the token is an address, then insert the key.
    /// The lone-letter rule stands in for the spell checker.
    private func type(_ keys: String) -> String {
        let document = Document()
        let mirror = MirrorSyncState()
        var pendingUndo: (original: String, corrected: String)?
        for character in keys {
            let key = String(character)
            if let undo = pendingUndo, AddressCorrectionRevert.apply(
                editor: document, original: undo.original, corrected: undo.corrected, next: key, mirror: mirror
            ) {
                pendingUndo = nil
            }
            if AutocorrectTrigger.commitsWord(key) || key == " " {
                pendingUndo = nil
                if !AddressLikeToken.atCursor(document.text, followedBy: key),
                   let (_, word) = AutocorrectRejectionMemory.wordAtCursor(context: document.contextBeforeInput),
                   case .correct(let correction) = decide(word, context: document.text),
                   case .applied = AutocorrectCountingSite.apply(
                       editor: document, word: word, correction: correction, trailing: "", mirror: mirror
                   ) {
                    pendingUndo = key == " " ? nil : (word, correction)
                }
            }
            document.insertText(key)
        }
        return document.text
    }

    func testTheSpaceBarCorrectsTheReportedSentence() {
        XCTAssertEqual(type("vas avoir des problème z "), "vas avoir des problème a ")
        XCTAssertEqual(type("il t a "), "il y a ")
    }

    func testTheSpaceBarKeepsALetterNamedAsALetter() {
        XCTAssertEqual(type("le h aspiré "), "le h aspiré ")
        XCTAssertEqual(type("un z et la lettre b du p "), "un z et la lettre b du p ")
    }

    /// A closing parenthesis does not commit a word, and the space after it finds none.
    func testAListMarkerIsKept() {
        XCTAssertEqual(type("q) oui t) non "), "q) oui t) non ")
    }

    func testALetterInsideAnEmailAddressIsKept() {
        XCTAssertEqual(type("écris à t.martin@gmail.com "), "écris à t.martin@gmail.com ")
        XCTAssertEqual(type("z@exemple.fr "), "z@exemple.fr ")
        XCTAssertEqual(type("jean@q.fr "), "jean@q.fr ")
    }

    func testALetterInsideAUrlIsKept() {
        XCTAssertEqual(type("va sur https://z.fr "), "va sur https://z.fr ")
        XCTAssertEqual(type("va sur www.t.fr "), "va sur www.t.fr ")
        XCTAssertEqual(type("le site q.com "), "le site q.com ")
    }
}
