// DictusCore/Tests/DictusCoreTests/Polish/PolishSummaryShapeTests.swift
// The Résumé bench's scorers, pinned (#571).
import XCTest
@testable import PolishFidelity

/// `PolishSummaryShape` decides what the committed numbers in
/// `docs/research/571-summary/` say, so each flag carries a positive and a negative
/// case. A scorer nobody can test is a scorer nobody should believe (#570).
final class PolishSummaryShapeTests: XCTestCase {

    private let frenchInput = "bon alors il faut que je rappelle le comptable avant vendredi et que je réserve la salle du deuxième étage"

    func testProseInTheInputLanguageRaisesNoFlag() {
        let score = PolishSummaryShape.score(
            output: "Je dois rappeler le comptable avant vendredi et réserver la salle.",
            input: frenchInput, expectedLanguage: "fr"
        )
        XCTAssertTrue(score.languageMatches)
        XCTAssertEqual(score.listLines, 0)
        XCTAssertFalse(score.firstPersonLost)
        XCTAssertFalse(score.opensOnInfinitive)
        XCTAssertFalse(score.preamble)
        XCTAssertTrue(score.reportFraming.isEmpty)
        XCTAssertTrue(score.exampleContent.isEmpty)
    }

    /// Bar L1's reading: the base code is compared, so a regional or script subtag
    /// on either side does not read as a different language.
    func testAnOutputInAnotherLanguageIsFlagged() {
        let score = PolishSummaryShape.score(
            output: "I need to call the accountant before Friday and book the second-floor room.",
            input: frenchInput, expectedLanguage: "fr"
        )
        XCTAssertFalse(score.languageMatches)
        XCTAssertEqual(score.outputLanguage, "en")
        XCTAssertEqual(PolishSummaryShape.baseCode("zh-Hans"), "zh")
    }

    /// Bar B: `List`'s shape in any of its forms, bullets, dashes, numbers, headings.
    func testEveryListShapeCounts() {
        let output = "À faire :\n- Rappeler le comptable\n• Réserver la salle\n2. Préparer le tableau\nEt une phrase."
        let score = PolishSummaryShape.score(output: output, input: frenchInput, expectedLanguage: "fr")
        XCTAssertEqual(score.listLines, 4)
    }

    /// Bar P, both of its failures: `List`'s infinitive task, and the minute-taker's
    /// third person.
    func testTheInfinitiveTaskAndTheReportAreBothFlagged() {
        let infinitive = PolishSummaryShape.score(
            output: "Rappeler le comptable avant vendredi et réserver la salle.",
            input: frenchInput, expectedLanguage: "fr"
        )
        XCTAssertTrue(infinitive.opensOnInfinitive)
        XCTAssertTrue(infinitive.firstPersonLost)

        let report = PolishSummaryShape.score(
            output: "Le locuteur explique qu'il doit rappeler le comptable.",
            input: frenchInput, expectedLanguage: "fr"
        )
        XCTAssertEqual(report.reportFraming, ["le locuteur"])
    }

    /// Round 2's device failure, `j'aimerais qu'on fasse un point` → `Nous devons
    /// aborder`: a collective obligation the speaker never voiced. A spoken `on`
    /// kept as `on` is not flagged, nor is a `nous` the speaker said.
    func testACollectiveObligationTheSpeakerNeverUsedIsFlagged() {
        let input = "j'aimerais qu'on fasse un point sur le budget"
        XCTAssertTrue(PolishSummaryShape.score(output: "Nous devons faire un point sur le budget.",
                                               input: input, expectedLanguage: "fr").collectiveSwitch)
        XCTAssertFalse(PolishSummaryShape.score(output: "J'aimerais qu'on fasse un point sur le budget.",
                                                input: input, expectedLanguage: "fr").collectiveSwitch)
        XCTAssertFalse(PolishSummaryShape.score(output: "Nous partons demain.",
                                                input: "nous partons demain matin", expectedLanguage: "fr").collectiveSwitch)
        XCTAssertTrue(PolishSummaryShape.score(output: "We must review the budget.",
                                               input: "I'd like us to go over the budget", expectedLanguage: "en").collectiveSwitch)
    }

    /// A report term the speaker used themselves is theirs, not the model's.
    func testAReportTermPresentInTheInputIsNotFlagged() {
        let input = "the speaker at the conference said I should call back"
        let score = PolishSummaryShape.score(output: "The speaker said I should call back.",
                                             input: input, expectedLanguage: "en")
        XCTAssertTrue(score.reportFraming.isEmpty)
    }

    /// Bar A, and bar F's two lexical halves: a preamble, the prompt's own example
    /// content (#414), and a figure the speaker never said.
    func testPreambleExampleContentAndNovelFiguresAreFlagged() {
        let score = PolishSummaryShape.score(
            output: "En résumé : le garagiste rappelle le comptable pour 150 euros.",
            input: frenchInput, expectedLanguage: "fr"
        )
        XCTAssertTrue(score.preamble)
        XCTAssertEqual(score.exampleContent, ["garagiste"])
        XCTAssertEqual(score.novelFigures, ["150"])
    }

    func testRatioIsOutputOverInput() {
        let score = PolishSummaryShape.score(output: "abcde", input: "abcdefghij", expectedLanguage: "fr")
        XCTAssertEqual(score.ratio, 0.5, accuracy: 0.0001)
    }
}
