// DictusCore/Tests/DictusCoreTests/Polish/TranslationTargetLiveAuditTests.swift
// Every new Translate target, through the real framework and the real pipeline (issue #622).
import XCTest
@testable import DictusCore

/// The live half of the #622 measurement: what `TranslateRoutingPolishEngine` with the
/// **real** Translation framework (`TranslationFrameworkCall.live`, `.highFidelity`)
/// writes for a French dictation into each new target, and whether `PolishPipeline`'s
/// guardrail accepts it — the path the keyboard runs, minus the keyboard.
///
/// Off by default, like `ModelCatalogueSizeAuditTests`: it needs macOS 26.4+ with Apple
/// Intelligence on, which CI does not have, and it prints rather than pins because
/// the framework's wording is Apple's to change. Run it on a Mac:
///
///     DICTUS_TRANSLATION_LIVE_AUDIT=1 swift test --filter TranslationTargetLiveAuditTests
///
/// Each line reads `LIVE <code> <outcome> engine=<label> | <input> => <output>`.
/// The Apple FM side is replaced by an engine that throws, so a line that says
/// `success` can only have been written by the framework.
final class TranslationTargetLiveAuditTests: XCTestCase {

    private struct NoFallback: PolishEngineProtocol {
        struct Called: Error {}
        let identifier = "apple-fm"
        func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
            throw Called()
        }
    }

    private let inputs = [
        "Je suis en retard, j'arrive dans quinze minutes.",
        "Je t'envoie le document ce soir, on en reparle demain matin si tu veux."
    ]

    func testEveryNewTargetTranslatesAndPassesTheGuardrail() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["DICTUS_TRANSLATION_LIVE_AUDIT"] == "1",
            "Live audit — set DICTUS_TRANSLATION_LIVE_AUDIT=1 on a Mac with Apple Intelligence"
        )
        let engine = TranslateRoutingPolishEngine(wrapping: NoFallback(), budget: .keyboard,
                                                  appState: { "audit" }, framework: .live)
        var refused: [String] = []
        for target in TranslationTarget.additional {
            for input in inputs {
                let job = PolishJob(task: .smart(SmartModeCatalogue.translate(to: target)), promptLanguage: .french,
                                    languageAgnosticPath: false, transcriptLanguageCode: "fr")
                let result = await PolishPipeline.transform(preprocessed: input, engine: engine, job: job)
                let output = PolishPipeline.resolvedOutput(result, preprocessed: input, job: job) ?? "<nothing inserted>"
                print("LIVE \(target.code) \(result.outcome.rawValue) check=\(result.rejectedCheck?.rawValue ?? "-") engine=\(result.producedBy ?? "-") | \(input) => \(output)")
                if result.outcome != .success { refused.append("\(target.code): \(result.outcome.rawValue)") }
            }
        }
        XCTAssertTrue(refused.isEmpty, "not translated or refused: \(refused)")
    }
}
