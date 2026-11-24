import XCTest
@testable import DictusCore

/// What one step of the delete swipe removes (#609).
final class DeleteWordBoundaryTests: XCTestCase {

    /// The text the step at the end of `before` deletes.
    private func step(_ before: String) -> String? {
        guard let span = DeleteWordBoundary.lastWord(in: before) else { return nil }
        return String(before.suffix(span.length))
    }

    /// The steps that empty `text`, last word first.
    private func steps(_ text: String) -> [String] {
        var text = text
        var result: [String] = []
        while let span = DeleteWordBoundary.lastWord(in: text), span.length > 0 {
            result.append(String(text.suffix(span.length)))
            text = String(text.dropLast(span.length))
        }
        return result
    }

    // MARK: - Hex's cases (its testDeleteSwipeWordsMatchOptionDelete)

    func testHexOptionDeleteCases() {
        XCTAssertNil(step(""))
        XCTAssertEqual(step("Hello, world. "), "world. ")
        XCTAssertEqual(step("it's don't"), "don't")
        XCTAssertEqual(step("Olá, você"), "você")
        XCTAssertEqual(step("?!"), "?!")
    }

    // MARK: - Words and their trailing spaces

    func testTheDemoSentenceGoesOneWordAtATime() {
        XCTAssertEqual(
            steps("Dictus est le clavier qui écrit vraiment comme je parle"),
            ["parle", "je ", "comme ", "vraiment ", "écrit ", "qui ", "clavier ", "le ", "est ", "Dictus "]
        )
    }

    func testTheSpacesAfterAWordGoWithIt() {
        XCTAssertEqual(step("Bonjour   "), "Bonjour   ")
        XCTAssertEqual(step("un deux "), "deux ")
    }

    func testPunctuationGoesWithTheWordBeforeIt() {
        XCTAssertEqual(steps("Bonjour, monde. "), ["monde. ", "Bonjour, "])
        XCTAssertEqual(step("Vraiment ?"), "Vraiment ?")
        XCTAssertEqual(step("« Oui »"), "Oui »")
        XCTAssertEqual(step("(voilà)"), "voilà)")
    }

    func testPunctuationAloneIsOneStep() {
        XCTAssertEqual(step("..."), "...")
        XCTAssertEqual(step("  "), "  ")
    }

    // MARK: - French

    func testAnElisionIsOneWord() {
        XCTAssertEqual(step("je vois l'homme"), "l'homme")
        XCTAssertEqual(step("C'est"), "C'est")
        XCTAssertEqual(step("jusqu'à"), "jusqu'à")
        XCTAssertEqual(step("l\u{2019}homme"), "l\u{2019}homme")
    }

    func testAujourdhuiIsOneWord() {
        XCTAssertEqual(step("C'est aujourd'hui"), "aujourd'hui")
        XCTAssertEqual(step("C'est aujourd\u{2019}hui."), "aujourd\u{2019}hui.")
    }

    func testAHyphenatedWordIsOneWord() {
        XCTAssertEqual(step("il est peut-être"), "peut-être")
        XCTAssertEqual(step("c'est-à-dire"), "c'est-à-dire")
        XCTAssertEqual(step("Jean-Pierre "), "Jean-Pierre ")
    }

    func testALooseApostropheOrDashIsPunctuation() {
        // "j'" typed, the next letter not yet: the apostrophe goes with "j".
        XCTAssertEqual(step("alors j'"), "j'")
        XCTAssertEqual(steps("oui - non"), ["non", "oui - "])
        XCTAssertEqual(step("il a dit 'cité'"), "cité'")
    }

    func testAccentsAndCombiningMarksStayInTheWord() {
        XCTAssertEqual(step("très"), "très")
        // "é" written as "e" + U+0301 is one grapheme, one deletion.
        let decomposed = "caf" + "e\u{301}"
        XCTAssertEqual(DeleteWordBoundary.lastWord(in: decomposed)?.length, 4)
    }

    // MARK: - Numbers

    func testNumbersKeepTheirSeparators() {
        XCTAssertEqual(step("ça coûte 12,5"), "12,5")
        XCTAssertEqual(step("rendez-vous à 12:30"), "12:30")
        XCTAssertEqual(step("il y en a 1."), "1.")
        XCTAssertEqual(step("19,99 €"), "19,99 €")
    }

    // MARK: - Emoji

    func testAnEmojiIsAWordOnItsOwn() {
        XCTAssertEqual(steps("Super 👍👍"), ["👍", "👍", "Super "])
        XCTAssertEqual(steps("cool😀"), ["😀", "cool"])
        XCTAssertEqual(step("Merci ❤️ "), "❤️ ")
        XCTAssertEqual(step("bravo 👍🏽"), "👍🏽")
        XCTAssertEqual(step("famille 👨‍👩‍👧"), "👨‍👩‍👧")
        XCTAssertEqual(step("🇫🇷"), "🇫🇷")
    }

    func testADigitIsNotAnEmoji() {
        XCTAssertEqual(step("page 1"), "1")
        XCTAssertEqual(step("© 2026"), "2026")
    }

    // MARK: - Line breaks and the start of the text

    func testALineBreakIsAStepOfItsOwn() {
        XCTAssertEqual(steps("Bonjour\nmonde"), ["monde", "\n", "Bonjour"])
        XCTAssertEqual(steps("Fin.\n\n"), ["\n", "\n", "Fin."])
    }

    func testPunctuationStopsAtALineBreak() {
        XCTAssertEqual(step("Bonjour\n, "), ", ")
    }

    func testTheStartOfTheText() {
        XCTAssertNil(DeleteWordBoundary.lastWord(in: ""))
        XCTAssertEqual(step("a"), "a")
        XCTAssertEqual(step(" "), " ")
    }

    // MARK: - Truncated context

    func testAWordThatFillsTheContextMayGoOn() {
        // The host shared "inateur" of "ordinateur": the scan cannot see the word's start.
        XCTAssertEqual(
            DeleteWordBoundary.lastWord(in: "inateur"),
            DeleteWordBoundary.Span(length: 7, continuesIn: .word)
        )
        XCTAssertEqual(
            DeleteWordBoundary.lastWord(in: "   "),
            DeleteWordBoundary.Span(length: 3, continuesIn: .separators)
        )
    }

    func testAWordWithASeenStartDoesNotGoOn() {
        XCTAssertEqual(
            DeleteWordBoundary.lastWord(in: "un ordinateur"),
            DeleteWordBoundary.Span(length: 10, continuesIn: nil)
        )
    }

    func testAnEmojiAtTheStartOfTheContextIsComplete() {
        XCTAssertEqual(DeleteWordBoundary.lastWord(in: "😀")?.continuesIn, nil)
    }

    func testTheContinuationFinishesTheWord() {
        XCTAssertEqual(
            DeleteWordBoundary.continuation(in: "C'est un ord", from: .word, following: "i"),
            DeleteWordBoundary.Span(length: 3, continuesIn: nil)
        )
        // Cut right at the word's start: nothing more to take.
        XCTAssertEqual(
            DeleteWordBoundary.continuation(in: "C'est un ", from: .word, following: "o").length,
            0
        )
        // Cut inside the spaces: the word before them is still this step's.
        XCTAssertEqual(
            DeleteWordBoundary.continuation(in: "le mot ", from: .separators, following: " "),
            DeleteWordBoundary.Span(length: 4, continuesIn: nil)
        )
    }

    func testTheContinuationCrossesAnApostropheAtTheCut() {
        // "aujourd'hui" shared from "'hui": the apostrophe at the cut is kept with the word.
        XCTAssertEqual(
            DeleteWordBoundary.lastWord(in: "'hui"),
            DeleteWordBoundary.Span(length: 4, continuesIn: .word)
        )
        XCTAssertEqual(
            DeleteWordBoundary.continuation(in: "C'est aujourd", from: .word, following: "'"),
            DeleteWordBoundary.Span(length: 7, continuesIn: nil)
        )
    }

    func testTheContinuationDoesNotGlueAnEmojiToLetters() {
        XCTAssertEqual(DeleteWordBoundary.continuation(in: "ok😀", from: .word, following: "a").length, 0)
        XCTAssertEqual(DeleteWordBoundary.continuation(in: "ok", from: .word, following: "😀").length, 0)
    }
}
