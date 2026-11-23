// DictusCore/Tests/DictusCoreTests/Polish/TranslationTargetRoutingTests.swift
// Where a translation into a new target runs, and what happens when it cannot (issue #622).
import XCTest
@testable import DictusCore

/// The three routing rules the #622 brief asks to be tested:
///
/// 1. a target goes to the Translation framework;
/// 2. a framework decline falls back to Apple FM for a language Apple FM writes;
/// 3. a target Apple FM cannot write gets the "translation unavailable" outcome, and
///    **the source text is never inserted** — checked through the pipeline, where the
///    floor is decided, not only at the engine.
///
/// The framework is scripted (`TranslationFrameworkCall`), as in
/// `TranslateRoutingPolishEngineTests`, so this runs without Apple Intelligence.
final class TranslationTargetRoutingTests: XCTestCase {

    private final class InnerEngine: PolishEngineProtocol, @unchecked Sendable {
        let identifier = "apple-fm"
        private(set) var calls = 0
        private(set) var prewarms = 0
        func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
            calls += 1
            return "FM(\(raw))"
        }
        func prewarm(task: PolishTask, targetLanguage: SupportedLanguage) async { prewarms += 1 }
    }

    private final class ScriptedFramework: @unchecked Sendable {
        var status: TranslationPairStatus = .installed
        var error: Error?
        var echo = false
        var secondsPerChunk: Double = 0
        private(set) var pairs: [TranslationLanguagePair] = []

        var call: TranslationFrameworkCall {
            TranslationFrameworkCall(
                status: { _ in self.status },
                session: { pair in
                    TranslationChunkSession(
                        translate: { chunk in
                            if self.secondsPerChunk > 0 {
                                try await Task.sleep(nanoseconds: UInt64(self.secondsPerChunk * 1_000_000_000))
                            }
                            if let error = self.error { throw error }
                            self.pairs.append(pair)
                            return self.echo ? chunk : "TR[\(pair.target.code)](\(chunk))"
                        },
                        cancel: {}
                    )
                }
            )
        }
    }

    private func target(_ code: String) throws -> TranslationTarget {
        try XCTUnwrap(TranslationTarget(code: code))
    }

    private func task(_ code: String) throws -> PolishTask {
        .smart(SmartModeCatalogue.translate(to: try target(code)))
    }

    private func engine(_ inner: InnerEngine, _ framework: ScriptedFramework,
                        budget: TranslationTimeBudget = .keyboard) -> TranslateRoutingPolishEngine {
        TranslateRoutingPolishEngine(wrapping: inner, budget: budget, appState: { "test" }, framework: framework.call)
    }

    // MARK: - 1. A target goes to the framework

    func testEveryTargetRunsOnTheFrameworkWithItsOwnLocale() async throws {
        for target in TranslationTarget.all where target != .french {
            let inner = InnerEngine(), framework = ScriptedFramework()
            let output = try await engine(inner, framework).polishLabelled(
                raw: "bonjour", targetLanguage: .french, task: .smart(SmartModeCatalogue.translate(to: target)),
                sourceLanguageCode: "fr"
            )
            XCTAssertEqual(output, PolishEngineOutput(text: "TR[\(target.code)](bonjour)", engine: "translation.highFidelity"))
            XCTAssertEqual(framework.pairs.first?.target, target)
            XCTAssertEqual(framework.pairs.first?.source, "fr")
            XCTAssertEqual(inner.calls, 0, "\(target.code) reached Apple FM although the framework translated")
        }
    }

    // MARK: - 2. A decline falls back to Apple FM where Apple FM writes the language

    /// Every way the framework declines, for every target that has a fallback.
    private func declines() -> [(String, String?, (ScriptedFramework) -> Void)] {
        struct Thrown: Error {}
        return [
            ("notInstalled", "fr", { $0.status = .notInstalled }),
            ("unsupported", "fr", { $0.status = .unsupported }),
            ("osBelow26.4", "fr", { $0.status = .unknown }),
            ("error", "fr", { $0.error = Thrown() }),
            ("untranslated", "fr", { $0.echo = true }),
            ("noSourceLanguage", nil, { _ in })
        ]
    }

    func testAFrameworkDeclineFallsBackToAppleFMForAnFMLanguage() async throws {
        for target in TranslationTarget.all where target.hasModelFallback && target != .french {
            for (name, source, configure) in declines() {
                let inner = InnerEngine(), framework = ScriptedFramework()
                configure(framework)
                let output = try await engine(inner, framework).polishLabelled(
                    raw: "texte", targetLanguage: .french, task: .smart(SmartModeCatalogue.translate(to: target)),
                    sourceLanguageCode: source
                )
                XCTAssertEqual(output, PolishEngineOutput(text: "FM(texte)", engine: "apple-fm"),
                               "\(target.code) on \(name)")
                XCTAssertEqual(inner.calls, 1, "\(target.code) on \(name)")
            }
        }
    }

    func testTheKeyboardDeadlineFallsBackToAppleFMForAnFMLanguage() async throws {
        let inner = InnerEngine(), framework = ScriptedFramework()
        framework.secondsPerChunk = 3
        let budget = TranslationTimeBudget(chunkCharacters: 400, perChunkSeconds: 1, overallFloorSeconds: 1,
                                           overallSecondsPerCharacter: 0, overallCeilingSeconds: 1,
                                           fallsBackOnTimeout: true)
        let output = try await engine(inner, framework, budget: budget).polishLabelled(
            raw: "texte", targetLanguage: .french, task: try task("pt"), sourceLanguageCode: "fr"
        )
        XCTAssertEqual(output.text, "FM(texte)")
    }

    // MARK: - 3. No fallback: a clear outcome, never the source text

    func testEveryDeclineOnANoFallbackTargetThrowsTranslationUnavailableAndNeverCallsAppleFM() async throws {
        let noFallback = TranslationTarget.all.filter { !$0.hasModelFallback }
        XCTAssertEqual(noFallback.count, 9)
        for target in noFallback {
            for (name, source, configure) in declines() + [("sameLanguage", target.code, { _ in })] {
                let inner = InnerEngine(), framework = ScriptedFramework()
                configure(framework)
                let routing = engine(inner, framework)
                do {
                    let output = try await routing.polishLabelled(
                        raw: "texte", targetLanguage: .french, task: .smart(SmartModeCatalogue.translate(to: target)),
                        sourceLanguageCode: source
                    )
                    XCTFail("\(target.code) on \(name) returned \(output.text) instead of failing")
                } catch let error as TranslateRoutingPolishEngine.TranslationUnavailable {
                    XCTAssertFalse(error.decline.isEmpty)
                    XCTAssertEqual(routing.failureReason(for: error), .translationUnavailable)
                }
                XCTAssertEqual(inner.calls, 0, "\(target.code) on \(name) asked Apple FM for a language it cannot write")
            }
        }
    }

    /// The deadline, both ways it is reached: the keyboard falls back on a timeout and
    /// DictusApp fails the mode. With no fallback, both are "translation unavailable".
    func testADeadlineOnANoFallbackTargetIsTranslationUnavailableInBothProcesses() async throws {
        for fallsBack in [true, false] {
            let inner = InnerEngine(), framework = ScriptedFramework()
            framework.secondsPerChunk = 3
            let budget = TranslationTimeBudget(chunkCharacters: 400, perChunkSeconds: 1, overallFloorSeconds: 1,
                                               overallSecondsPerCharacter: 0, overallCeilingSeconds: 1,
                                               fallsBackOnTimeout: fallsBack)
            do {
                _ = try await engine(inner, framework, budget: budget).polishLabelled(
                    raw: "texte", targetLanguage: .french, task: try task("ru"), sourceLanguageCode: "fr"
                )
                XCTFail("a deadline on → RU inserted something")
            } catch let error as TranslateRoutingPolishEngine.TranslationUnavailable {
                XCTAssertEqual(error.decline, "deadline1s")
            }
            XCTAssertEqual(inner.calls, 0)
        }
    }

    /// Where it matters: through the pipeline, the outcome is a failed mode, the
    /// reason names the cause, and what the user gets inserted is nothing.
    func testThroughThePipelineANoFallbackDeclineInsertsNothingAndSaysWhy() async throws {
        for code in ["ru", "th", "ar"] {
            let inner = InnerEngine(), framework = ScriptedFramework()
            framework.status = .notInstalled
            let raw = "Je suis en retard, j'arrive dans quinze minutes."
            let job = PolishJob(task: try task(code), promptLanguage: .french, languageAgnosticPath: false,
                                transcriptLanguageCode: "fr")
            let result = await PolishPipeline.transform(preprocessed: raw, engine: engine(inner, framework), job: job)
            XCTAssertEqual(result.outcome, .engineFailed, code)
            XCTAssertEqual(result.failureReason, .translationUnavailable, code)
            XCTAssertNil(result.engineOutput, code)
            XCTAssertNil(PolishPipeline.resolvedOutput(result, preprocessed: raw, job: job),
                         "→ \(code) inserted text after the framework declined")
            XCTAssertEqual(inner.calls, 0)

            let failure = SmartModeFailure(modeIdentifier: "translate.\(code)", modeDisplayName: "→ \(code)",
                                           outcome: result.outcome.rawValue,
                                           reason: result.failureReason?.slug ?? "-")
            XCTAssertTrue(failure.isTranslationUnavailable, "the surfaces would show the generic sentence")
            XCTAssertFalse(failure.isModelRefusal)
        }
    }

    /// A target with a fallback does not get the notice: the same decline polishes
    /// through Apple FM instead.
    func testTheNoticeIsForNoFallbackTargetsOnly() async throws {
        let inner = InnerEngine(), framework = ScriptedFramework()
        framework.status = .notInstalled
        let raw = "Je suis en retard, j'arrive dans quinze minutes."
        let job = PolishJob(task: try task("it"), promptLanguage: .french, languageAgnosticPath: false,
                            transcriptLanguageCode: "fr")
        let result = await PolishPipeline.transform(preprocessed: raw, engine: engine(inner, framework), job: job)
        XCTAssertNotEqual(result.failureReason, .translationUnavailable)
        XCTAssertEqual(inner.calls, 1)
    }

    func testNoAppleFMSessionIsWarmedForANoFallbackTarget() async throws {
        let inner = InnerEngine(), framework = ScriptedFramework()
        let routing = engine(inner, framework)
        await routing.prewarm(task: try task("ru"), targetLanguage: .french)
        XCTAssertEqual(inner.prewarms, 0)
        await routing.prewarm(task: try task("pt"), targetLanguage: .french)
        XCTAssertEqual(inner.prewarms, 1)
    }

    /// Translation's framework path has no context window, for any target.
    func testANewTargetFitsBecauseTheFrameworkHasNoWindow() throws {
        let routing = engine(InnerEngine(), ScriptedFramework())
        XCTAssertEqual(routing.contextFit(input: String(repeating: "mot ", count: 5_000),
                                          targetLanguage: .french, task: try task("ja")), .fits)
    }
}
