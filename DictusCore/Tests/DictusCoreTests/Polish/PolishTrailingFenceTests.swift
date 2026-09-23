// DictusCore/Tests/DictusCoreTests/Polish/PolishTrailingFenceTests.swift
// A closing fence the model appended is dropped, and nothing else is (#587).
import XCTest
@testable import DictusCore

/// `PolishPostpass.stripTrailingFenceLines`: the short `Structuré` prompt closed 18 of
/// 354 Mac outputs on a line made of ```` ``` ```` or `---`, all 18 accepted. The pass
/// that drops it must never be able to drop a word.
final class PolishTrailingFenceTests: XCTestCase {

    /// The two shapes the bench captured, verbatim in their tail.
    func testTheCapturedClosingLinesAreDropped() {
        XCTAssertEqual(
            PolishPostpass.stripTrailingFenceLines("You can switch to plan mode.\n\n```"),
            "You can switch to plan mode."
        )
        XCTAssertEqual(
            PolishPostpass.stripTrailingFenceLines("Je validerai une fois le plan fait.\n\n---"),
            "Je validerai une fois le plan fait."
        )
    }

    func testSeveralClosingLinesAndTrailingSpaceAreDropped() {
        XCTAssertEqual(PolishPostpass.stripTrailingFenceLines("Texte.\n```\n  ---  \n\n"), "Texte.")
    }

    /// Nothing that carries a character besides the token, and no token that is not
    /// last, is touched.
    func testNothingElseIsTouched() {
        let untouched = [
            "Texte sans clôture.",
            "Première partie.\n\n---\n\nDeuxième partie.",
            "Le code est ```swift```",
            "Fin --- vraiment",
            "- une puce\n- une autre",
            "Texte.\n\n"
        ]
        for text in untouched {
            XCTAssertEqual(PolishPostpass.stripTrailingFenceLines(text), text, "changed: \(text.debugDescription)")
        }
    }

    /// Every word survives, whatever the input: the pass only ever removes lines that
    /// contain no letter or digit.
    func testNoWordIsEverRemoved() {
        let samples = ["a\n```", "a\n---\n```\n", "```\nb\n```", "x ---", "---"]
        for text in samples {
            let before = PolishLexicon.words(in: text)
            XCTAssertEqual(PolishLexicon.words(in: PolishPostpass.stripTrailingFenceLines(text)), before, text)
        }
    }

    /// In the pipeline, before the guardrails: the accepted output reaches the caller
    /// without its closing fence.
    func testThePipelineDeliversTheOutputWithoutItsClosingFence() async {
        let raw = "Je te laisse regarder, il s'agit de la dernière transcription."
        let result = await PolishPipeline.transform(
            preprocessed: raw,
            engine: FixedOutputEngine(output: "Je te laisse regarder : il s'agit de la dernière transcription.\n\n```"),
            job: PolishJob(task: .smart(SmartModeCatalogue.structured),
                           promptLanguage: .french, languageAgnosticPath: true)
        )
        XCTAssertEqual(result.outcome, .success)
        XCTAssertEqual(result.engineOutput, "Je te laisse regarder : il s'agit de la dernière transcription.")
    }
}

/// Returns one fixed string. Repeated here rather than shared because every other
/// copy in this target is `private` to its file.
private struct FixedOutputEngine: PolishEngineProtocol {
    let identifier = "fixed-output"
    let output: String

    func polish(raw: String,
                targetLanguage: SupportedLanguage,
                task: PolishTask) async throws -> String {
        output
    }
}

/// Round 2 of #587 left two more shapes in accepted outputs: a Swedish one ending on
/// three lone `-` lines, a Korean one on `...`. They join the list.
extension PolishTrailingFenceTests {

    func testTheRoundTwoArtefactsAreDropped() {
        XCTAssertEqual(PolishPostpass.stripTrailingFenceLines("Vi får se vad det ger.\n\n-\n-\n-"),
                       "Vi får se vad det ger.")
        XCTAssertEqual(PolishPostpass.stripTrailingFenceLines("한번 봐 줘, 이게 마지막 전사본이야.\n\n..."),
                       "한번 봐 줘, 이게 마지막 전사본이야.")
        XCTAssertEqual(PolishPostpass.stripTrailingFenceLines("Texte.\n\n…"), "Texte.")
    }

    /// A real last bullet is not a lone dash, and keeps its line.
    func testALastBulletWithWordsSurvives() {
        let list = "Pour le voyage :\n- les passeports\n- les billets"
        XCTAssertEqual(PolishPostpass.stripTrailingFenceLines(list), list)
    }
}
