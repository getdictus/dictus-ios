// DictusCore/Tests/DictusCoreTests/Polish/PolishGuardrailVerbatimSegmentTests.swift
// A segment the speaker said word for word is not refused by the language check (#861).
import XCTest
@testable import DictusCore

/// The device case of 2026-10-29: a French `smart.message` dictation holding the
/// code-switch `It's a folie.`, which the per-segment language check refused although
/// the transcript carries it word for word. The texts around it are rebuilt.
///
/// Whether `It's a folie.` alone reads as confident English depends on the OS's
/// recogniser: 0.964 on the Mac this was written on, under the 0.85 floor on the CI
/// runner. So the device segment pins the match itself, and the refusal is pinned on a
/// longer code-switch that reads English everywhere.
final class PolishGuardrailVerbatimSegmentTests: XCTestCase {

    // MARK: - The device segment

    /// The transcript's casing, a double space and a straight apostrophe on one side; the
    /// output's re-casing and typographic apostrophe on the other.
    func testTheDeviceSegmentMatchesItsTranscriptThroughCaseSpacesAndApostrophe() {
        let spoken = PolishGuardrail.verbatimKey("salut Marc, le devis est arrivé. it's  a folie. Je rappelle demain.")
        XCTAssertTrue(spoken.contains(PolishGuardrail.verbatimKey("It\u{2019}s a folie.")))
        XCTAssertTrue(spoken.contains(PolishGuardrail.verbatimKey("It's a\u{00A0}folie.")))
        XCTAssertFalse(spoken.contains(PolishGuardrail.verbatimKey("It's a real folie.")))
    }

    // MARK: - The check

    /// Parakeet's casing and a double space inside the code-switch.
    private let raw = "salut Marc, je viens de recevoir le devis du garage pour la voiture. "
        + "honestly,  it's a folie, I can't believe they want that much for it. "
        + "Je vais demander un deuxième avis avant de signer quoi que ce soit."

    /// One line per sentence; the code-switch re-cased with a typographic apostrophe.
    private let polished = """
    Salut Marc,
    Je viens de recevoir le devis du garage pour la voiture.
    Honestly, it\u{2019}s a folie, I can't believe they want that much for it.
    Je vais demander un deuxième avis avant de signer quoi que ce soit.
    """

    /// The same output with an English line the transcript does not hold.
    private let invented = """
    Salut Marc,
    Je viens de recevoir le devis du garage pour la voiture.
    Honestly, this quote is a complete disaster and I will not pay it.
    Je vais demander un deuxième avis avant de signer quoi que ce soit.
    """

    func testTheSegmentIsRefusedWhenTheCheckIsNotGivenTheTranscript() {
        XCTAssertFalse(
            PolishGuardrail.detectedLanguageMatches(polished: polished, inputLanguageCode: "fr"),
            "precondition: read alone, the code-switch is a confident English reading"
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

    // MARK: - Through the pipeline, on the device case's mode

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
