// DictusCore/Tests/DictusCoreTests/Polish/PolishPromptInventoryTests.swift
// What every shipping prompt must and must not carry (#536).
import XCTest
@testable import DictusCore

/// The eleven system prompts this build sends, walked together.
///
/// Per-prompt suites pin what one prompt says; this one pins what none of them may
/// say. #536 removed the domain term list from all eleven at once, and the failure it
/// guards against is a partial return — one prompt regaining a block the other ten
/// dropped is exactly the half-state that made the glossary impossible to measure.
final class PolishPromptInventoryTests: XCTestCase {

    /// Every prompt string this build can send, named for a readable failure.
    private var shippingPrompts: [(String, String)] {
        [
            ("auto", PolishAutoPrompt.instructions()),
            ("natural-fr", PolishNaturalPromptFR.instructions()),
            ("natural-en", PolishNaturalPromptEN.instructions()),
            ("natural-es", PolishNaturalPromptES.instructions()),
            ("natural-de", PolishNaturalPromptDE.instructions()),
            ("repair-fr", PolishRepairPromptFR.instructions()),
            ("repair-en", PolishRepairPromptEN.instructions()),
            ("repair-es", PolishRepairPromptES.instructions()),
            ("repair-de", PolishRepairPromptDE.instructions()),
            ("smart.notes", SmartModeNotesPrompt.instructions())
        ] + SupportedLanguage.allCases.map {
            ("smart.translate.\($0.rawValue)", SmartModeTranslatePrompt.instructions(target: $0))
        }
    }

    /// **The #536 acceptance criterion, executable.** No prompt carries a term list.
    ///
    /// Both wordings are checked because both were measured to do nothing: ours
    /// ("Spell these terms exactly as written") on two device captures, and the
    /// phonetic-repair framing a competitor ships at 0/5 on the same iPhone. A
    /// rewrite along either axis is the branch this issue did not take, so it comes
    /// back through a decision on the issue rather than through an edit here.
    func testNoShippingPromptCarriesATermList() {
        for (name, prompt) in shippingPrompts {
            XCTAssertFalse(prompt.contains("Spell these terms exactly as written"),
                           "\(name) grew a term list back")
            XCTAssertFalse(prompt.contains("Domain vocabulary"),
                           "\(name) grew a domain-vocabulary block back")
            XCTAssertFalse(prompt.contains("CUSTOM_VOCABULARY"),
                           "\(name) grew a tagged vocabulary block")
        }
    }

    /// The count is the point: eleven builders, and the fourteen strings they produce
    /// once Translate is expanded per target. A prompt added without a line here
    /// would sit outside every check above.
    func testTheInventoryCoversEveryPromptTheBuildSends() {
        XCTAssertEqual(shippingPrompts.count, 10 + SupportedLanguage.allCases.count)
        for (name, prompt) in shippingPrompts {
            XCTAssertTrue(prompt.contains("TEXT TRANSFORMATION FUNCTION"),
                          "\(name) no longer opens on the framing every prompt shares")
        }
    }
}
