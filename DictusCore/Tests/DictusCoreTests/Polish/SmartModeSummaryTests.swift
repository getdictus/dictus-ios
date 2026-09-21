// DictusCore/Tests/DictusCoreTests/Polish/SmartModeSummaryTests.swift
// The Summary Smart Mode, displayed `Résumé` (#571).
import XCTest
@testable import DictusCore

/// Kept apart from `SmartModeCatalogueTests` so the row and its prompt are pinned in
/// one place; the catalogue suite only counts it.
final class SmartModeSummaryTests: XCTestCase {

    private var instructions: String { SmartModeCatalogue.summary.prompt.instructions }

    // MARK: - The row

    /// A wire value from the day it ships: it keys the session cache, the metrics
    /// event and the per-dictation App Group snapshot.
    func testSummaryKeepsItsIdentifierNameAndIcon() {
        XCTAssertEqual(SmartModeCatalogue.summaryIdentifier, "summary")
        XCTAssertEqual(SmartModeCatalogue.summary.id, "summary")
        XCTAssertEqual(SmartModeCatalogue.summary.displayName, "Summary")
        XCTAssertEqual(SmartModeCatalogue.mode(withIdentifier: "summary")?.id, "summary")
        // An SF Symbols 2019 glyph: the mode list is shown on every iOS a Pro user runs.
        XCTAssertEqual(SmartModeCatalogue.summary.icon, "text.quote")
    }

    /// Appended after `Message`, so no row a user has already read moves; not in the
    /// seed, which is full.
    func testSummaryIsAppendedAndNotSeeded() {
        let ids = SmartModeCatalogue.builtIns.map(\.id)
        XCTAssertEqual(Array(ids.prefix(4)), ["structured", "notes", "message", "summary"])
        XCTAssertFalse(SmartModeCatalogue.defaultPinnedIdentifiers.contains("summary"))
    }

    // MARK: - The contract

    /// Decision 1: a band, `0.1 … 0.6`, never a sentence count. The floor is `List`'s,
    /// the mode that compresses comparably; the ceiling is the licence itself.
    func testSummaryBandIsDecisionOne() {
        let contract = SmartModeCatalogue.summary.contract
        XCTAssertEqual(contract.minimumLengthRatio, 0.1)
        XCTAssertEqual(contract.maximumLengthRatio, 0.6)
        XCTAssertEqual(contract.minimumLengthRatio, SmartModeCatalogue.notes.contract.minimumLengthRatio)
        // The only row whose ceiling sits below 1: it is the one mode that must shorten.
        for mode in SmartModeCatalogue.builtIns where mode.id != "summary" {
            XCTAssertGreaterThan(mode.contract.maximumLengthRatio, contract.maximumLengthRatio, mode.id)
        }
    }

    func testSummaryIsGroundedUnalignedAndFallsBackToTheRawText() {
        let contract = SmartModeCatalogue.summary.contract
        XCTAssertEqual(contract.outputLanguage, .sameAsInput)
        XCTAssertTrue(contract.requiresGroundedNames)
        XCTAssertFalse(contract.requiresAlignedPrefix)
        XCTAssertEqual(contract.segmentOverlapThresholds, .default)
        XCTAssertEqual(SmartModeCatalogue.summary.floorBehaviour, .insertRawText)
    }

    /// The band, end to end through the pipeline's own check: an output that keeps
    /// two thirds of its input is refused, a gist is accepted.
    func testTheBandRefusesATextThatIsNotAGist() {
        let raw = String(repeating: "je pense que le projet avance bien ", count: 10)
        let contract = SmartModeCatalogue.summary.contract
        XCTAssertFalse(PolishGuardrail.accepts(raw: raw, polished: String(raw.prefix(raw.count * 2 / 3)),
                                               contract: contract))
        XCTAssertTrue(PolishGuardrail.accepts(raw: raw, polished: String(raw.prefix(raw.count / 4)),
                                              contract: contract))
    }

    // MARK: - The prompt

    /// The genre prior (PR #388): naming the artefact pulls in its furniture, and a
    /// summary's furniture — a heading, a bullet per point, the minute-taker's third
    /// person — is what this mode's bars refuse. So the model never sees the word.
    func testThePromptNeverNamesItsOwnGenre() {
        let framing = PolishTask.smart(SmartModeCatalogue.summary).userTurn(raw: "x")
        for text in [instructions, framing] {
            for noun in ["summary", "summarise", "summarize", "résumé", "resume"] {
                XCTAssertFalse(text.lowercased().contains(noun), "the model is shown the word \(noun)")
            }
        }
    }

    /// #518: no label in front of the transcript, and the shape asked for in the
    /// user turn, the position #437 and #523 measured as the one that governs it.
    func testTheUserTurnAsksForProseAndLabelsNothing() {
        let framing = PolishTask.smart(SmartModeCatalogue.summary).userTurn(raw: "TRANSCRIPT")
        XCTAssertTrue(framing.contains("prose"))
        XCTAssertTrue(framing.lowercased().contains("output only"))
        XCTAssertFalse(framing.contains("Input:"))
        XCTAssertTrue(framing.contains("\n\nTRANSCRIPT\n\n"))
    }

    /// #587 decision 5, step 1: the rules are English and rule 1 is the language rule,
    /// naming the examples.
    func testRuleOneIsTheLanguageRuleAndNamesTheExamples() {
        guard let rule1 = instructions.components(separatedBy: "\n").first(where: { $0.hasPrefix("1. ") }) else {
            return XCTFail("no rule 1")
        }
        XCTAssertTrue(rule1.contains("language of the text you are given"))
        XCTAssertTrue(rule1.contains("never in the language of the examples"))
        XCTAssertTrue(instructions.contains("Never translate"))
    }

    /// #587 decision 4: two examples, two languages, no person named.
    func testTwoExamplesInTwoLanguagesNamingNobody() {
        let examples = SmartModeSummaryPrompt.defaultExamples
        XCTAssertEqual(examples.count, 2)
        let languages = Set(examples.compactMap { PolishPipeline.detectLanguageCode(in: $0.input) })
        XCTAssertEqual(languages.count, 2, "the two examples share a language: \(languages)")
        for name in ["Sophie", "Julien", "Thomas", "Sarah", "Marie", "Paul", "Marion"] {
            XCTAssertFalse(instructions.contains(name), "the prompt names \(name)")
        }
    }

    /// #587 decision 4's second half: no example acts out a risky rule. No list in an
    /// output, and no speaker-flagged incompleteness anywhere — decision 4 lets the
    /// mode drop one, and #581 is what an example of one costs.
    func testNoExampleActsOutARiskyRule() {
        for example in SmartModeSummaryPrompt.defaultExamples {
            XCTAssertFalse(example.output.contains("\n"), "an example output is laid out in lines")
            XCTAssertFalse(example.output.contains("- "))
            for phrase in ["m'échappe", "j'ai oublié", "I forgot", "something else"] {
                XCTAssertFalse(example.input.contains(phrase) || example.output.contains(phrase), phrase)
            }
            // Each example demonstrates the band it teaches.
            let ratio = Double(example.output.count) / Double(example.input.count)
            XCTAssertTrue(SmartModeCatalogue.summary.contract.lengthBand.contains(ratio), "example ratio \(ratio)")
        }
    }

    /// The seam for step 2: the rules are built around whichever example set is
    /// passed, so a per-language set swaps in without touching a rule.
    func testTheExampleSetSwapsWithoutTouchingARule() {
        let swapped = SmartModeSummaryPrompt.Example(input: "EXAMPLE-INPUT", output: "EXAMPLE-OUTPUT")
        let built = SmartModeSummaryPrompt.instructions(examples: [swapped])
        XCTAssertTrue(built.contains("INPUT: EXAMPLE-INPUT\nOUTPUT: EXAMPLE-OUTPUT"))
        for example in SmartModeSummaryPrompt.defaultExamples {
            XCTAssertFalse(built.contains(example.input))
        }
        func rules(_ prompt: String) -> String {
            prompt.components(separatedBy: "Examples.").first ?? ""
        }
        XCTAssertEqual(rules(built), rules(instructions))
    }

    /// Decisions 2 and 3, stated where the model reads them.
    func testProseOnlyAndThePersonKept() {
        XCTAssertTrue(instructions.contains("Never a bullet"))
        XCTAssertTrue(instructions.contains("Keep their grammatical person"))
    }

    /// Decision 5.
    func testItNeverAnswersTheText() {
        XCTAssertTrue(instructions.contains("Never answer the text"))
    }

    /// Decision 4: nothing about a speaker-flagged incompleteness, either way.
    func testThePromptSaysNothingAboutAnIncompleteness() {
        for phrase in ["missing or unfinished", "incomplete", "forgot"] {
            XCTAssertFalse(instructions.contains(phrase), phrase)
        }
    }

    /// Every character of a system prompt is taken off the dictation that still fits
    /// (`PolishContextBudget`), and this mode is armed for long dictations.
    func testThePromptStaysWithinItsBudget() {
        XCTAssertLessThan(instructions.count, 3_600)
    }
}
