// DictusCore/Tests/DictusCoreTests/Polish/PolishGuardrailVerbatimSegmentTests.swift
// A segment the speaker said word for word is not refused by the language check (#861).
import XCTest
@testable import DictusCore

/// The device case of 2026-10-29: a French `smart.message` dictation holding the
/// code-switch `It's a folie.`, which the per-segment language check refused although
/// the transcript carries it word for word. The texts around it are rebuilt, the
/// segment is the device one.
final class PolishGuardrailVerbatimSegmentTests: XCTestCase {

    /// The transcript, cased and spaced the way Parakeet left it: lower-case opening
    /// and a double space inside the segment.
    private let raw = "salut Marc, je viens de recevoir le devis du garage pour la voiture. "
        + "it's  a folie. Je vais demander un deuxième avis avant de signer quoi que ce soit."

    /// The output: one line per sentence, the segment re-cased and given a typographic
    /// apostrophe.
    private let polished = """
    Salut Marc,
    Je viens de recevoir le devis du garage pour la voiture.
    It’s a folie.
    Je vais demander un deuxième avis avant de signer quoi que ce soit.
    """

    /// The same output with a line the transcript does not hold.
    private let invented = """
    Salut Marc,
    Je viens de recevoir le devis du garage pour la voiture.
    It's a real disaster.
    Je vais demander un deuxième avis avant de signer quoi que ce soit.
    """

    func testTheSegmentIsRefusedWhenTheCheckIsNotGivenTheTranscript() {
        XCTAssertFalse(
            PolishGuardrail.detectedLanguageMatches(polished: polished, inputLanguageCode: "fr"),
            "precondition: read alone, the segment is a confident English reading"
        )
    }

    func testASegmentFoundVerbatimInTheTranscriptIsAccepted() {
        XCTAssertTrue(PolishGuardrail.detectedLanguageMatches(polished: polished, inputLanguageCode: "fr", raw: raw))
        XCTAssertTrue(PolishGuardrail.detectedLanguageMatches(polished: polished, target: .french, raw: raw))
    }

    func testASegmentAbsentFromTheTranscriptIsStillRefused() {
        XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(polished: invented, inputLanguageCode: "fr", raw: raw))
        XCTAssertFalse(PolishGuardrail.detectedLanguageMatches(polished: invented, target: .french, raw: raw))
    }

    /// Wired through the pipeline on the mode the device case ran.
    func testTheMessageModeDeliversTheVerbatimSegment() async {
        let result = await PolishPipeline.transform(
            preprocessed: raw, engine: FixedOutputEngine(output: polished),
            job: PolishJob(task: .smart(SmartModeCatalogue.message), promptLanguage: .french,
                           languageAgnosticPath: false)
        )
        XCTAssertNil(result.rejectedCheck)
        XCTAssertEqual(result.outcome, .success)
    }

    func testTheMessageModeStillRefusesAnInventedEnglishLine() async {
        let result = await PolishPipeline.transform(
            preprocessed: raw, engine: FixedOutputEngine(output: invented),
            job: PolishJob(task: .smart(SmartModeCatalogue.message), promptLanguage: .french,
                           languageAgnosticPath: false)
        )
        XCTAssertEqual(result.outcome, .rejectedGuardrail)
        XCTAssertEqual(result.rejectedCheck, .language)
    }
}

/// Returns one fixed string. Repeated here rather than shared because the other
/// copies are `private` to their files.
private struct FixedOutputEngine: PolishEngineProtocol {
    let identifier = "fixed-output"
    let output: String

    func polish(raw: String,
                targetLanguage: SupportedLanguage,
                task: PolishTask) async throws -> String {
        output
    }
}
