// DictusCore/Tests/DictusCoreTests/Polish/MessageShortLayoutTests.swift
// A short message keeps its beats on separate lines, without the blank line (#572).
import XCTest
@testable import DictusCore

/// The maintainer's device verdict of 2026-09-18 on a 60-character message split
/// into three blocks: *"un peu trop d'espace"*. His choice: the beats on separate
/// lines, no blank line between them — and only on short messages, because his own
/// 184-character target keeps its blank lines. See `SmartModePrompt.shortOutputBlockLimit`.
///
/// The texts are rebuilt off-domain: the device dictations are private.
final class MessageShortLayoutTests: XCTestCase {

    // MARK: - The pass

    func testShortTextLosesItsBlankLinesAndNothingElse() {
        let blocked = "Salut toi, je rentre tard ce soir\n\nGarde-moi une part\n\nÀ plus"
        XCTAssertEqual(
            PolishPostpass.tightenBlocks(blocked, whenShorterThan: 100),
            "Salut toi, je rentre tard ce soir\nGarde-moi une part\nÀ plus"
        )
    }

    /// The maintainer's own target is 184 characters in three blocks, and it is the
    /// layout decision 6 was written from. It must come through untouched.
    func testTextAtOrAboveTheLimitKeepsItsBlankLines() {
        let long = String(repeating: "a", count: 60) + "\n\n" + String(repeating: "b", count: 60)
        XCTAssertEqual(PolishPostpass.tightenBlocks(long, whenShorterThan: 100), long)
        let exact = String(repeating: "a", count: 49) + "\n\n" + String(repeating: "b", count: 49)
        XCTAssertEqual(exact.count, 100)
        XCTAssertEqual(PolishPostpass.tightenBlocks(exact, whenShorterThan: 100), exact)
    }

    /// Several blank lines, or a blank line carrying stray spaces, still collapse to
    /// exactly one break: the model does not always emit a clean `\n\n`.
    func testRunsOfBlankLinesCollapseToOneBreak() {
        XCTAssertEqual(
            PolishPostpass.tightenBlocks("Un\n \n\nDeux\n\t\nTrois", whenShorterThan: 100),
            "Un\nDeux\nTrois"
        )
    }

    /// A single line break is already the wanted layout, and a one-block message has
    /// nothing to tighten.
    func testTextWithoutBlankLinesIsUnchanged() {
        XCTAssertEqual(PolishPostpass.tightenBlocks("Un\nDeux", whenShorterThan: 100), "Un\nDeux")
        XCTAssertEqual(PolishPostpass.tightenBlocks("Hello toi, ça va ?", whenShorterThan: 100),
                       "Hello toi, ça va ?")
    }

    // MARK: - In the pipeline

    /// End to end through `PolishPipeline.transform`: the model's blocks are accepted
    /// by every check, and what `Message` delivers has them on single lines.
    func testMessageDeliversAShortAcceptedOutputOnSingleLines() async {
        let result = await PolishPipeline.transform(
            preprocessed: "Salut toi, je rentre tard ce soir, garde-moi une part, à plus.",
            engine: FixedOutputEngine(output: "Salut toi, je rentre tard ce soir\n\nGarde-moi une part\n\nÀ plus"),
            job: PolishJob(task: .smart(SmartModeCatalogue.message),
                           promptLanguage: .french, languageAgnosticPath: false)
        )
        XCTAssertEqual(result.outcome, .success)
        XCTAssertEqual(result.engineOutput, "Salut toi, je rentre tard ce soir\nGarde-moi une part\nÀ plus")
    }

    /// The same blocks through a mode with no limit keep their blank lines: the pass
    /// is `Message`'s, not the pipeline's.
    func testAModeWithoutALimitKeepsTheBlankLines() async {
        let blocked = "Salut toi, je rentre tard ce soir\n\nGarde-moi une part\n\nÀ plus"
        let result = await PolishPipeline.transform(
            preprocessed: "Salut toi, je rentre tard ce soir, garde-moi une part, à plus.",
            engine: FixedOutputEngine(output: blocked),
            job: PolishJob(task: .smart(SmartModeCatalogue.structured),
                           promptLanguage: .french, languageAgnosticPath: false)
        )
        // `engineOutput` is also set on a refusal, so the outcome is what proves the
        // blank lines reached the user rather than being refused with the output.
        XCTAssertEqual(result.outcome, .success)
        XCTAssertEqual(result.engineOutput, blocked)
    }

    // MARK: - Where it applies

    func testOnlyMessageCarriesALimit() {
        XCTAssertEqual(SmartModeCatalogue.message.prompt.shortOutputBlockLimit, 100)
        for mode in SmartModeCatalogue.builtIns where mode.id != SmartModeCatalogue.messageIdentifier {
            XCTAssertNil(mode.prompt.shortOutputBlockLimit, mode.id)
        }
    }

    /// A prompt written by a build that never heard of the field decodes to `nil` —
    /// the layout before #572 — and a round trip keeps what the writer meant.
    func testThePromptDecodesWithoutTheFieldAndRoundTripsWithIt() throws {
        let json = #"{"instructions":"i","userInstruction":"u","outputMarker":"m"}"#
        let old = try JSONDecoder().decode(SmartModePrompt.self, from: Data(json.utf8))
        XCTAssertNil(old.shortOutputBlockLimit)

        let data = try JSONEncoder().encode(SmartModeCatalogue.message.prompt)
        let decoded = try JSONDecoder().decode(SmartModePrompt.self, from: data)
        XCTAssertEqual(decoded, SmartModeCatalogue.message.prompt)
    }
}

/// Returns one fixed string, the way `PolishPipelineTests`' own stub does. Repeated
/// here rather than shared because that one is `private` to its file.
private struct FixedOutputEngine: PolishEngineProtocol {
    let identifier = "fixed-output"
    let output: String

    func polish(raw: String,
                targetLanguage: SupportedLanguage,
                task: PolishTask) async throws -> String {
        output
    }
}
