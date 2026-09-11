// DictusCore/Tests/DictusCoreTests/Polish/PolishPromptParityTests.swift
// What the four Natural prompts, and the four Repair prompts, must say in common (#439).
import XCTest
@testable import DictusCore

/// Cross-language parity on the two clauses that are supposed to be identical
/// everywhere: the ADR 0003 deletion ban (amendment of 2026-08-27) and the ADR 0002
/// Repair substitution licence.
///
/// `PolishNaturalPromptFRTests` pins the French wording, and `PolishPromptInventoryTests`
/// pins what no prompt may say. Neither could see the failure this suite exists for: the
/// amendment shipped to French and to `PolishAutoPrompt` on 2026-08-29 and stayed there,
/// and the English Repair prompt had quietly lost a sentence its three siblings carry.
/// Both were found by reading the five files side by side, twelve days apart, which is
/// not a mechanism. This is.
final class PolishPromptParityTests: XCTestCase {

    private var naturalPrompts: [(String, String)] {
        [
            ("natural-fr", PolishNaturalPromptFR.instructions()),
            ("natural-en", PolishNaturalPromptEN.instructions()),
            ("natural-es", PolishNaturalPromptES.instructions()),
            ("natural-de", PolishNaturalPromptDE.instructions())
        ]
    }

    private var repairPrompts: [(String, String)] {
        [
            ("repair-fr", PolishRepairPromptFR.instructions()),
            ("repair-en", PolishRepairPromptEN.instructions()),
            ("repair-es", PolishRepairPromptES.instructions()),
            ("repair-de", PolishRepairPromptDE.instructions())
        ]
    }

    /// The numbered rule that opens with `n.`, or nil if the prompt has no such rule.
    private func rule(_ number: Int, in prompt: String) -> String? {
        prompt.split(separator: "\n").first { $0.hasPrefix("\(number). ") }.map(String.init)
    }

    // MARK: - Natural

    /// ADR 0003's Forbidden list, propagated. The ban is what makes a mid-sentence
    /// deletion a contract violation rather than an unstated expectation — the measured
    /// run that opened #439 dropped `en calcul` and passed every gate.
    func testEveryNaturalPromptBansDeletingDictatedWords() {
        for (name, prompt) in naturalPrompts {
            XCTAssertTrue(prompt.contains("Do NOT delete words that carry meaning"),
                          "\(name) has no deletion ban")
            XCTAssertTrue(prompt.contains("the speaker DICTATED appears in the output"),
                          "\(name) does not scope the ban to what was dictated")
            XCTAssertTrue(prompt.contains("rule 4 removes a spoken punctuation command"),
                          "\(name) does not except the verbal-punctuation rule")
            XCTAssertTrue(prompt.contains("rule 8 the only licence to change one"),
                          "\(name) does not name rule 8 as the licence to change a word")
        }
    }

    /// **A wrong number here is worse than no sentence**, because it points the model at
    /// the wrong licence. The four Natural prompts happen to share one numbering today;
    /// `PolishAutoPrompt` does not (it says *"Rules 4, 5 and 6"*), which is why the ban
    /// is hand-numbered per file rather than copy-pasted. This check reads each file's
    /// own rules and asserts the cited numbers are the rules the sentence describes.
    func testTheDeletionBanCitesEachPromptsOwnRuleNumbers() {
        for (name, prompt) in naturalPrompts {
            XCTAssertTrue(prompt.contains("Rules 4, 6 and 7 are the only licence to remove a word"),
                          "\(name) cites a different rule set")
            XCTAssertEqual(rule(4, in: prompt)?.contains("Verbal punctuation"), true,
                           "\(name) rule 4 is not the verbal-punctuation rule")
            XCTAssertEqual(rule(6, in: prompt)?.contains("duplicates"), true,
                           "\(name) rule 6 is not the stutter rule")
            XCTAssertEqual(rule(7, in: prompt)?.contains("fillers"), true,
                           "\(name) rule 7 is not the filler rule")
            XCTAssertEqual(rule(8, in: prompt)?.contains("ASR error repair"), true,
                           "\(name) rule 8 is not the ASR-repair rule")
        }
    }

    /// The Preserve entry #439 measured: `machin` came back `machine`. Each language
    /// names its own placeholders — a translated French example would teach nothing,
    /// since the failure is a placeholder colliding with a real word in that language.
    func testEveryNaturalPromptNamesPlaceholderWordsInItsOwnLanguage() {
        let placeholders: [String: [String]] = [
            "natural-fr": ["`machin`", "`truc`", "`bidule`"],
            "natural-en": ["`thingy`", "`thingamajig`", "`whatsit`"],
            "natural-es": ["`chisme`", "`cacharro`", "`coso`"],
            "natural-de": ["`Dings`", "`Dingsbums`", "`Dingsda`"]
        ]
        for (name, prompt) in naturalPrompts {
            XCTAssertTrue(prompt.contains("Placeholder words are word choice too"),
                          "\(name) has no placeholder clause")
            for word in placeholders[name] ?? [] {
                XCTAssertTrue(prompt.contains(word), "\(name) does not name \(word)")
            }
        }
    }

    /// #437, measured and rejected: the `<<NL>>` ban stays, on all five free-polish
    /// prompts.
    ///
    /// The ban is what makes a long dictation come back as one block, and #437 exists
    /// to lift it at a change of subject. The licence was written five ways — as a
    /// permission, as an imperative, with three worked examples, restated in the GOAL
    /// line at the top, and asking for an ordinary newline instead of the marker — and
    /// produced **not one line break in 144 outputs** across both prompt routes. The
    /// same instruction moved into the user turn puts a break in 21 outputs of 168,
    /// unstably, and 3 of those 21 break after every sentence rather than at a section. Numbers in `docs/research/437-longform-breaks/findings.md`.
    ///
    /// So the ban is a measurement now, not an oversight — the footing
    /// `testAutoPromptDoesNotCarryASRRepair` put rule 8's absence on. A future round is
    /// welcome to lift it; this is what makes that a decision rather than a drift.
    func testEveryFreePolishPromptStillBansAddingMarkers() {
        for (name, prompt) in naturalPrompts + [("auto", PolishAutoPrompt.instructions())] {
            XCTAssertTrue(prompt.contains("Do NOT add `<<NL>>` markers where none existed"),
                          "\(name) no longer bans the model from adding a line break (#437)")
            XCTAssertTrue(prompt.contains("Do NOT split or alter existing markers"),
                          "\(name) no longer protects the markers the speaker dictated")
        }
    }

    /// The English read-across of the measurement above (#439 Part 2). The question was
    /// put in French, where `point` is a common noun; `period` is the same shape in
    /// English (`a period of time`, `period drama`) and `PolishNaturalPromptEN` is the
    /// only other prompt teaching it. The French result was clean, so it stays — and if
    /// a future round ever removes it from French, this test is what stops English
    /// keeping it by inattention. `full stop` is a separate case and unambiguous: the
    /// pre-pass already substitutes it in code.
    func testEnglishNaturalRuleFourKeepsThePeriodWordAlongsideFrench() {
        XCTAssertEqual(PolishNaturalPromptEN.instructions().contains("`period`/`full stop` → `.`"),
                       PolishNaturalPromptFR.instructions().contains("`point` → `.`"),
                       "FR and EN must make the same call on the bare period word (#185, #439)")
    }

    // MARK: - Repair

    /// ADR 0002's controlled exception. English had the first sentence and not the
    /// second, and nothing anywhere documented a narrower Repair licence for English —
    /// a Repair prompt that may not substitute words cannot do the one job it exists for.
    func testEveryRepairPromptGrantsTheSubstitutionLicence() {
        for (name, prompt) in repairPrompts {
            XCTAssertTrue(prompt.contains("You MAY substitute words and rephrase syntax to recover that intent"),
                          "\(name) lost the substitution licence")
            // `Light` was renamed `Natural` by ADR 0003; French was the file still
            // pointing the model at a mode name this build no longer has.
            XCTAssertTrue(prompt.contains("controlled exception to Natural mode's word-preserving rule"),
                          "\(name) names the wrong mode in the exception")
            XCTAssertFalse(prompt.contains("Light mode"), "\(name) still says Light mode")
        }
    }

    /// The examples are the other half of the licence: they are what stops "substitute
    /// words" reaching a brand name. English lost them along with the sentence.
    func testEveryRepairPromptShowsProperNounExamples() {
        for (name, prompt) in repairPrompts {
            XCTAssertTrue(prompt.contains("Proper nouns: company, product, person, place names (Apple, GitHub"),
                          "\(name) states the proper-noun rule without examples")
        }
    }
}
