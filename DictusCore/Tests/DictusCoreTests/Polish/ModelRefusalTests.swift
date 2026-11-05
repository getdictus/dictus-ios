// DictusCore/Tests/DictusCoreTests/Polish/ModelRefusalTests.swift
// An Apple Foundation Models refusal is its own case (#455): not a fault, and not
// our own guardrail rejecting an output.
import XCTest
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
}
#endif
