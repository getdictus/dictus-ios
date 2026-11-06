// DictusCore/Tests/DictusCoreTests/Polish/ModelRefusalTests.swift
// An Apple Foundation Models refusal is its own case (#455): not a fault, and not
// our own guardrail rejecting an output.
import XCTest
#if canImport(FoundationModels)
import FoundationModels
#endif
@testable import DictusCore

final class ModelRefusalTests: XCTestCase {

    private let preprocessed = "Ok, petit test ?"
    private let floor = "Ok, petit test\u{00A0}?"

    private func job(_ task: PolishTask) -> PolishJob {
        PolishJob(task: task, promptLanguage: .french, languageAgnosticPath: false)
    }

    private func failure(_ outcome: PolishMetrics.Outcome, reason: String) -> SmartModeFailure {
        SmartModeFailure(modeIdentifier: "translate.en", modeDisplayName: "→ EN",
                         outcome: outcome.rawValue, reason: reason)
    }

    // MARK: - Classification

    /// Apple's two refusals are refusals; nothing else Apple throws is.
    func testOnlyApplesTwoRefusalsAreModelRefusals() {
        XCTAssertTrue(PolishFailureReason.safetyRefusal.isModelRefusal)
        XCTAssertTrue(PolishFailureReason.refusal.isModelRefusal)
        let others: [PolishFailureReason] = [
            .exceededContextWindowSize, .assetsUnavailable, .unsupportedGuide,
            .unsupportedLanguageOrLocale, .decodingFailure, .rateLimited,
            .concurrentRequests, .other(UnrecognisedFailure())
        ]
        for reason in others {
            XCTAssertFalse(reason.isModelRefusal, "\(reason.slug) is a fault, not a refusal")
        }
    }

    /// The acceptance criterion of #455: our name for Apple's safety refusal no
    /// longer says "guardrail", which is the word for our own output check.
    func testNoReasonSlugSaysGuardrail() {
        XCTAssertEqual(PolishFailureReason.safetyRefusal.slug, "safetyRefusal")
        XCTAssertFalse(PolishFailureReason.safetyRefusal.slug.lowercased().contains("guardrail"))
    }

    /// The three cases a surface has to tell apart, from the failure value alone.
    func testSmartModeFailureTellsARefusalFromAGuardrailRejectionAndAFault() {
        XCTAssertTrue(failure(.engineFailed, reason: "safetyRefusal").isModelRefusal, "Apple's safety filter")
        XCTAssertTrue(failure(.engineFailed, reason: "refusal").isModelRefusal, "the model declining")
        XCTAssertFalse(failure(.rejectedGuardrail, reason: "-").isModelRefusal, "our own guardrail")
        XCTAssertFalse(failure(.engineFailed, reason: "rateLimited").isModelRefusal, "a fault")
        XCTAssertFalse(failure(.engineFailed, reason: "other:URLError").isModelRefusal, "a fault")
        XCTAssertFalse(failure(.unsupportedInputLanguage, reason: "-").isModelRefusal, "our pre-flight")
    }

    // MARK: - What the user receives

    /// The issue's own capture: Translate → EN, Apple's safety filter. The user keeps
    /// the dictated text rather than an empty field.
    func testTranslateKeepsTheFloorWhenTheModelRefuses() async {
        let mode = SmartModeCatalogue.translate(to: .english)
        for reason in [PolishFailureReason.safetyRefusal, .refusal] {
            let result = await PolishPipeline.transform(
                preprocessed: preprocessed,
                engine: RefusingStubEngine(reason: reason),
                job: job(.smart(mode))
            )
            XCTAssertEqual(result.outcome, .engineFailed)
            XCTAssertEqual(result.failureReason, reason)
            XCTAssertTrue(PolishPipeline.degradesToFloor(mode, outcome: .engineFailed, failureReason: reason))
            // The floor in the mode's own typography, never an empty field.
            XCTAssertEqual(
                PolishPipeline.resolvedOutput(result, preprocessed: preprocessed, job: job(.smart(mode))),
                PolishPipeline.deterministicFloor(preprocessed: preprocessed, job: job(.smart(mode)))
            )
        }
    }

    /// Every other throw keeps its behaviour: Translate still inserts nothing.
    func testTranslateStillInsertsNothingOnAFault() async {
        let mode = SmartModeCatalogue.translate(to: .english)
        let result = await PolishPipeline.transform(
            preprocessed: preprocessed,
            engine: RefusingStubEngine(reason: .rateLimited),
            job: job(.smart(mode))
        )
        XCTAssertEqual(result.failureReason, .rateLimited)
        XCTAssertFalse(PolishPipeline.degradesToFloor(mode, outcome: .engineFailed, failureReason: .rateLimited))
        XCTAssertNil(PolishPipeline.resolvedOutput(result, preprocessed: preprocessed, job: job(.smart(mode))))
    }

    /// A refusal reason only counts on an engine throw. Our guardrail rejection and the
    /// fail-closed outcomes keep the mode's own answer.
    func testARefusalReasonDoesNotOpenAnyOtherOutcome() {
        let mode = SmartModeCatalogue.translate(to: .english)
        for outcome in [PolishMetrics.Outcome.rejectedGuardrail, .cancelled, .engineUnavailable,
                        .unsupportedInputLanguage, .exceededContextBudget] {
            XCTAssertFalse(
                PolishPipeline.degradesToFloor(mode, outcome: outcome, failureReason: .safetyRefusal),
                "\(outcome.rawValue) must not degrade on Translate"
            )
        }
    }

    /// The last criterion of #455: Normal polish still returns the deterministic floor.
    func testNormalPolishStillReturnsTheFloorOnARefusal() async {
        let result = await PolishPipeline.transform(
            preprocessed: preprocessed,
            engine: RefusingStubEngine(reason: .safetyRefusal),
            job: job(.natural)
        )
        XCTAssertEqual(result.outcome, .engineFailed)
        XCTAssertEqual(result.failureReason, .safetyRefusal)
        XCTAssertEqual(PolishPipeline.resolvedOutput(result, preprocessed: preprocessed, job: job(.natural)), floor)
    }
}

#if canImport(FoundationModels) && compiler(>=6.4)
/// iOS 27's `LanguageModelError` (#826), which deprecates `GenerationError`. Only
/// compiled where the SDK declares it (Xcode 27), only run where the OS has it.
final class LanguageModelErrorMappingTests: XCTestCase {

    @available(iOS 27.0, macOS 27.0, *)
    private func everyCase(debugDescription: String) -> [(LanguageModelError, PolishFailureReason)] {
        [
            (.contextSizeExceeded(.init(contextSize: 4096, tokenCount: 5000, debugDescription: debugDescription)),
             .exceededContextWindowSize),
            (.rateLimited(.init(resetDate: nil, debugDescription: debugDescription)), .rateLimited),
            (.guardrailViolation(.init(debugDescription: debugDescription)), .safetyRefusal),
            (.refusal(.init(explanation: "", debugDescription: debugDescription)), .refusal),
            (.unsupportedCapability(.init(capability: .reasoning, debugDescription: debugDescription)),
             .unsupportedCapability),
            (.unsupportedTranscriptContent(.init(unsupportedContent: [], debugDescription: debugDescription)),
             .unsupportedTranscriptContent),
            (.unsupportedGenerationGuide(.init(schemaName: nil, debugDescription: debugDescription)),
             .unsupportedGuide),
            (.unsupportedLanguageOrLocale(.init(languageCode: .french, debugDescription: debugDescription)),
             .unsupportedLanguageOrLocale),
            (.timeout(.init(debugDescription: debugDescription)), .timeout)
        ]
    }

    /// Each case reaches its slug through the engine's entry point, the one the
    /// pipeline calls with an untyped `Error`, and no two cases share one.
    func testEveryLanguageModelErrorCaseMapsToItsOwnSlug() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("LanguageModelError requires iOS/macOS 27")
        }
        let engine = AppleFoundationModelsPolishEngine()
        let expected = everyCase(debugDescription: "test")
        for (error, reason) in expected {
            XCTAssertEqual(engine.failureReason(for: error as Error), reason)
        }
        XCTAssertEqual(Set(expected.map { engine.failureReason(for: $0.0) }).count, expected.count,
                       "two LanguageModelError cases collapsed into one slug")
    }

    /// The risk #826 names: a refusal arriving as the new type must still be a
    /// refusal, never `other:LanguageModelError`.
    func testApplesTwoRefusalsStayRefusalsAndNothingElseIs() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("LanguageModelError requires iOS/macOS 27")
        }
        for (error, _) in everyCase(debugDescription: "test") {
            let reason = AppleFoundationModelsPolishEngine.failureReason(for: error)
            XCTAssertFalse(reason.slug.hasPrefix("other:"), "\(reason.slug) fell into the catch-all")
            switch error {
            case .guardrailViolation, .refusal:
                XCTAssertTrue(reason.isModelRefusal, "\(reason.slug) must keep #455's refusal path")
            default:
                XCTAssertFalse(reason.isModelRefusal, "\(reason.slug) is a fault, not a refusal")
            }
        }
    }

    /// A slug carries the case and nothing else: `debugDescription` can quote the
    /// user's dictation, and the reason travels into a shared export.
    func testSlugDoesNotLeakTheErrorDescription() throws {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("LanguageModelError requires iOS/macOS 27")
        }
        let secret = "rendez-vous chez le docteur mardi à quinze heures"
        for (error, _) in everyCase(debugDescription: secret) {
            XCTAssertFalse(AppleFoundationModelsPolishEngine.failureReason(for: error).slug.contains("docteur"))
        }
    }

    /// End to end through the pipeline: Translate keeps the dictated text when the
    /// refusal is iOS 27's safety filter, as it did for `GenerationError`.
    func testTranslateKeepsTheFloorOnALanguageModelErrorRefusal() async throws {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("LanguageModelError requires iOS/macOS 27")
        }
        let mode = SmartModeCatalogue.translate(to: .english)
        let job = PolishJob(task: .smart(mode), promptLanguage: .french, languageAgnosticPath: false)
        let result = await PolishPipeline.transform(
            preprocessed: "Ok, petit test ?",
            engine: LanguageModelErrorStubEngine(error: .guardrailViolation(.init(debugDescription: "test"))),
            job: job
        )
        XCTAssertEqual(result.outcome, .engineFailed)
        XCTAssertEqual(result.failureReason, .safetyRefusal)
        XCTAssertEqual(
            PolishPipeline.resolvedOutput(result, preprocessed: "Ok, petit test ?", job: job),
            PolishPipeline.deterministicFloor(preprocessed: "Ok, petit test ?", job: job)
        )
    }
}

/// Throws a given `LanguageModelError` and classifies it the way the shipping
/// Apple FM engine does.
@available(iOS 27.0, macOS 27.0, *)
private struct LanguageModelErrorStubEngine: PolishEngineProtocol {
    let identifier = "language-model-error-stub"
    let error: LanguageModelError

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        throw error
    }

    func failureReason(for error: Error) -> PolishFailureReason {
        AppleFoundationModelsPolishEngine.failureReason(for: error)
    }
}
#endif

// MARK: - Stubs

private struct UnrecognisedFailure: Error {}

/// Stands in for Apple FM, which cannot run in a test process, let alone refuse on
/// command: it always throws, and classifies the throw as the reason it was given.
private struct RefusingStubEngine: PolishEngineProtocol {
    let identifier = "refusing-stub"
    let reason: PolishFailureReason

    struct Failure: Error {}

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        throw Failure()
    }

    func failureReason(for error: Error) -> PolishFailureReason { reason }
}

#if DEBUG
/// The Debug-only switch the #455 simulator capture runs on.
final class DebugRefusingPolishEngineTests: XCTestCase {

    func testItRefusesWithApplesSafetyRefusal() async {
        let result = await PolishPipeline.transform(
            preprocessed: "Ok, petit test ?",
            engine: DebugRefusingPolishEngine(),
            job: PolishJob(task: .natural, promptLanguage: .french, languageAgnosticPath: false)
        )
        XCTAssertEqual(result.outcome, .engineFailed)
        XCTAssertEqual(result.failureReason, .safetyRefusal)
        XCTAssertEqual(SharedKeys.debugPolishRefusalForced, "dictus.debugPolishRefusalForced")
    }

    #if canImport(FoundationModels) && compiler(>=6.4)
    /// On iOS 27 the Debug switch throws Apple's own `LanguageModelError` (#826), so
    /// the capture also proves the new type reaches the refusal path.
    func testOnIOS27ItThrowsApplesLanguageModelError() async throws {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw XCTSkip("LanguageModelError requires iOS/macOS 27")
        }
        let engine = DebugRefusingPolishEngine()
        do {
            _ = try await engine.polish(raw: "Ok", targetLanguage: .french, task: .natural)
            XCTFail("the Debug engine must always throw")
        } catch {
            XCTAssertTrue(error is LanguageModelError)
            XCTAssertEqual(engine.failureReason(for: error), .safetyRefusal)
        }
    }
    #endif
}
#endif
