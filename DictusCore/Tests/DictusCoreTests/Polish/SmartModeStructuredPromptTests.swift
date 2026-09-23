// DictusCore/Tests/DictusCoreTests/Polish/SmartModeStructuredPromptTests.swift
// What `Structuré`'s short prompt says, in every language it says it (#587).
import XCTest
@testable import DictusCore

/// The properties #587's decisions 3, 4, 5.1 and 7 make load-bearing, held against
/// **every** example set rather than against the French one.
///
/// `SmartModeCatalogueTests` pins the mode's contract and the rules a reader looks for;
/// this suite pins what the 16 translated sets must have in common, because a set that
/// quietly loses the contrast, gains a list on its prose example or grows a sentence
/// about the speaker's memory is a set nobody would read again.
final class SmartModeStructuredPromptTests: XCTestCase {

    /// Every prompt this mode can send: the fallback pair and the 16 localized sets.
    private var prompts: [(String, String)] {
        [("fallback", SmartModeStructuredPrompt.shortInstructions())]
            + SmartModeStructuredPrompt.localizedInstructions().map { ($0.key, $0.value) }
    }

    /// The 16 Apple FM languages, read from `SystemLanguageModel.default.supportedLanguages`
    /// on 2026-09-21 and written down here because the bench is scored per language: a set
    /// that disappears is a language that silently falls back to the French-and-English pair.
    func testEveryAppleFoundationModelsLanguageHasASet() {
        let expected: Set<String> = ["da", "de", "en", "es", "fr", "it", "ja", "ko", "nb",
                                     "nl", "pt", "sv", "tr", "vi", "zh-Hans", "zh-Hant"]
        XCTAssertEqual(Set(SmartModeStructuredExamples.byLanguage.keys), expected)
    }

    /// Decision 5.1: the rules are one English text and only the examples change, so
    /// every prompt shares the rule block byte for byte.
    func testEveryLanguageSharesTheSameRules() {
        let rules = SmartModeStructuredPrompt.shortInstructions()
            .components(separatedBy: "\n\nINPUT: ")[0]
        XCTAssertTrue(rules.contains("1. Write in the language of the transcript"))
        for (name, prompt) in prompts {
            XCTAssertTrue(prompt.hasPrefix(rules), "\(name) does not carry the shared rules")
        }
    }

    /// Decision 4: two examples, and the contrast is the demonstration — one dictation
    /// that stays prose, one that becomes a short list. The enumeration comes first
    /// since round 3; the prose example is the one the model reads last.
    func testEverySetShowsTheEnumerationFirstAndTheProseLast() {
        for (name, prompt) in prompts {
            let blocks = prompt.components(separatedBy: "\n\nINPUT: ")
            XCTAssertEqual(blocks.count, 3, "\(name) does not carry exactly two examples")
            XCTAssertTrue(blocks[1].contains("\n- "), "\(name)'s first example carries no list")
            XCTAssertFalse(blocks[2].contains("\n- "), "\(name)'s second example carries a list")
        }
    }

    /// Decision 4 again, and #581: no example acts out rule 7. A worked example that
    /// ends on the speaker's memory failing is the sentence the model was measured
    /// copying into seven device outputs.
    func testNoExampleCarriesASentenceAboutTheSpeakersMemory() {
        for (name, prompt) in prompts {
            XCTAssertFalse(PolishIncompleteness.reportsRecallFailing(prompt),
                           "\(name) shows a sentence the fabrication check would refuse")
        }
    }

    /// The #414 trap: an example's content can reach a user's output, so no example
    /// names a person, and the content is off-domain in every language.
    func testNoExampleNamesAPerson() {
        for (name, prompt) in prompts {
            for person in ["Sophie", "Julien", "Thomas", "Sarah", "Marie", "Paul", "Anna", "Lars"] {
                XCTAssertFalse(prompt.contains(person), "\(name) names \(person)")
            }
        }
    }

    /// Decision 3: ~3 000 characters. The budget is the point — this is the mode armed
    /// for the longest dictations, and every character here is taken off the speech that
    /// still fits.
    func testEveryPromptStaysUnderTheDeclaredSize() {
        for (name, prompt) in prompts {
            XCTAssertLessThan(prompt.count, 3200, "\(name) is \(prompt.count) characters")
        }
    }

    /// The inventory's rules (#536), applied to the strings that never reach its list:
    /// a localized prompt is a shipping prompt too.
    func testEveryLocalizedPromptObeysTheInventorysRules() {
        for (name, prompt) in prompts {
            XCTAssertTrue(prompt.contains("TEXT TRANSFORMATION FUNCTION"), "\(name)")
            XCTAssertFalse(prompt.contains("Spell these terms exactly as written"), "\(name)")
            XCTAssertFalse(prompt.contains("Domain vocabulary"), "\(name)")
        }
    }

    /// The genre trap (PR #388): the prompt names the transformation, never an artefact.
    func testNoPromptNamesAWrittenGenre() {
        for (name, prompt) in prompts {
            for noun in ["article", "report", "document", "essay", "memo"] {
                XCTAssertFalse(prompt.lowercased().contains(noun), "\(name) says \(noun)")
            }
        }
    }

    /// What the catalogue sends: the mode carries the table, and a transcript in one of
    /// the 16 languages gets that language's prompt rather than the fallback.
    func testTheCatalogueCarriesEverySetAndResolvesIt() {
        let prompt = SmartModeCatalogue.structured.prompt
        XCTAssertEqual(prompt.instructions, SmartModeStructuredPrompt.shortInstructions())
        XCTAssertEqual(prompt.localizedInstructions?.count, 16)
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "ja"),
                       SmartModeStructuredPrompt.localizedInstructions()["ja"])
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "no"),
                       SmartModeStructuredPrompt.localizedInstructions()["nb"])
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: "cs"), prompt.instructions)
        XCTAssertEqual(prompt.instructions(forTranscriptLanguage: nil), prompt.instructions)
    }
}
