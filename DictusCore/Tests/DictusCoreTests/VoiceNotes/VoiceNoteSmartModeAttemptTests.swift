// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteSmartModeAttemptTests.swift
// A voice note's Smart Mode in the background: the log line, the fallback, the count (#627).
import XCTest
@testable import DictusCore

/// What #627 adds in DictusCore: the attempt line the device probe reads, which
/// refusals send the mode back to the card, when the queue tries at all, the Apple FM
/// call count, and the engine time `polish` now hands back.
///
/// The background run itself — the queue chaining the mode inside its background task,
/// Apple's budget refusing it — needs DictusApp, Apple Intelligence and a device, and is
/// on the PR's manual list.
final class VoiceNoteSmartModeAttemptTests: XCTestCase {

    private func failure(_ outcome: PolishMetrics.Outcome, reason: String = "-") -> SmartModeFailure {
        SmartModeFailure(modeIdentifier: "summary", modeDisplayName: "Résumé",
                         outcome: outcome.rawValue, reason: reason)
    }

    private func attempt(_ outcome: PolishOutcome,
                         trigger: VoiceNoteSmartModeTrigger = .background,
                         cancelReason: String? = nil) -> VoiceNoteSmartModeAttempt {
        VoiceNoteSmartModeAttempt(outcome: outcome, modeIdentifier: "summary", appState: "background",
                                  callIndex: 4, trigger: trigger, cancelReason: cancelReason)
    }

    // MARK: - The line

    /// Every field the probe on #627 names, in its order, on a success too.
    func testASuccessWritesTheFullLine() {
        let line = attempt(PolishOutcome(text: "Trois points.", engineMs: 3120))
        XCTAssertEqual(line.action, .success)
        XCTAssertEqual(line.logDetails,
                       "mode=summary outcome=success reason=- engineMs=3120 appState=background callIndex=4 trigger=background")
    }

    /// The device signature of #315: `engineFailed`, `rateLimited`, about ten milliseconds.
    func testARateLimitedRefusalNamesItsReasonAndTime() {
        let line = attempt(PolishOutcome(failure: failure(.engineFailed, reason: "rateLimited"), engineMs: 10))
        XCTAssertEqual(line.action, .failed)
        XCTAssertEqual(line.logDetails,
                       "mode=summary outcome=engineFailed reason=rateLimited engineMs=10 appState=background callIndex=4 trigger=background")
    }

    /// A blank success is not a result: the card says the summary could not be produced.
    func testABlankSuccessIsAFailure() {
        let line = attempt(PolishOutcome(text: "  \n"))
        XCTAssertEqual(line.action, .failed)
        XCTAssertEqual(line.outcome, "emptyOutput")
        XCTAssertEqual(line.engineMs, 0, "no engine time travelled, so none is invented")
    }

    /// `Liste`'s one-item output (#573) declines: its own action, as before #627.
    func testAListDeclineIsDeclined() {
        let declined = PolishOutcome(degradedTo: "un seul point",
                                     failure: failure(.smartModeSkippedShortInput, reason: "tooFewListItems"))
        XCTAssertEqual(attempt(declined).action, .declined)
        XCTAssertFalse(attempt(declined).defersToOpen)
    }

    /// The background task expiring is named, so the probe's "expired before the call"
    /// branch can be read off the log rather than guessed from `cancelled`.
    func testAnExpiryCancellationIsNamed() {
        let cancelled = PolishOutcome(failure: failure(.cancelled))
        let line = attempt(cancelled, cancelReason: VoiceNoteSmartModeAttempt.backgroundTimeExpiredReason)
        XCTAssertEqual(line.reason, "backgroundTimeExpired")
        XCTAssertEqual(attempt(cancelled).reason, "-", "a supersede keeps the pipeline's reason")
    }

    /// The expiry reason labels a cancellation and nothing else.
    func testTheExpiryReasonNeverLabelsAnotherOutcome() {
        let refused = PolishOutcome(failure: failure(.engineFailed, reason: "rateLimited"))
        XCTAssertEqual(attempt(refused, cancelReason: "backgroundTimeExpired").reason, "rateLimited")
    }

    // MARK: - The fallback

    /// Refusals that only mean "not in the background" send the mode back to the card.
    func testBackgroundOnlyRefusalsDeferToOpen() {
        XCTAssertTrue(attempt(PolishOutcome(failure: failure(.engineFailed, reason: "rateLimited"))).defersToOpen)
        XCTAssertTrue(attempt(PolishOutcome(failure: failure(.engineUnavailable))).defersToOpen,
                      "the background gate latched after two refusals")
        XCTAssertTrue(attempt(PolishOutcome(failure: failure(.cancelled)),
                              cancelReason: "backgroundTimeExpired").defersToOpen)
    }

    /// The mode's own answer to the transcript is not the fallback's business.
    func testTheModesOwnRefusalsDoNotDefer() {
        XCTAssertFalse(attempt(PolishOutcome(failure: failure(.rejectedGuardrail))).defersToOpen)
        XCTAssertFalse(attempt(PolishOutcome(failure: failure(.exceededContextBudget))).defersToOpen,
                       "a note too long for the window (#628) is too long in the foreground too")
        XCTAssertFalse(attempt(PolishOutcome(failure: failure(.engineFailed, reason: "guardrailViolation"))).defersToOpen)
        XCTAssertFalse(attempt(PolishOutcome(failure: failure(.unsupportedInputLanguage))).defersToOpen)
        XCTAssertFalse(attempt(PolishOutcome(text: "Trois points.")).defersToOpen)
    }

    // MARK: - When the queue tries

    func testTheQueueTriesWhenTheCardWould() {
        XCTAssertTrue(VoiceNoteSmartModeAttempt.runsInBackground(
            mode: SmartModeCatalogue.summary, transcriptLength: 900, unavailableReason: nil,
            isEntitled: true, hasStoredResult: false))
    }

    func testTheQueueDoesNotTryWhenTheCardWouldNot() {
        let summary = SmartModeCatalogue.summary
        XCTAssertFalse(VoiceNoteSmartModeAttempt.runsInBackground(
            mode: nil, transcriptLength: 900, unavailableReason: nil, isEntitled: true, hasStoredResult: false),
                       "Transcription seule")
        XCTAssertFalse(VoiceNoteSmartModeAttempt.runsInBackground(
            mode: summary, transcriptLength: 132, unavailableReason: nil, isEntitled: true, hasStoredResult: false),
                       "under Résumé's floor: the card records the decline on open")
        XCTAssertFalse(VoiceNoteSmartModeAttempt.runsInBackground(
            mode: summary, transcriptLength: 900, unavailableReason: .appleIntelligenceNotEnabled,
            isEntitled: true, hasStoredResult: false))
        XCTAssertFalse(VoiceNoteSmartModeAttempt.runsInBackground(
            mode: summary, transcriptLength: 900, unavailableReason: nil, isEntitled: false, hasStoredResult: false),
                       "Pro ended: nothing new is generated (#593)")
        XCTAssertFalse(VoiceNoteSmartModeAttempt.runsInBackground(
            mode: summary, transcriptLength: 900, unavailableReason: nil, isEntitled: true, hasStoredResult: true))
    }

    /// A short `→ EN` note still translates in the background: the floor is the mode's.
    func testAShortTranslationRunsInTheBackground() {
        XCTAssertTrue(VoiceNoteSmartModeAttempt.runsInBackground(
            mode: SmartModeCatalogue.translate(to: .english), transcriptLength: 20, unavailableReason: nil,
            isEntitled: true, hasStoredResult: false))
    }

    // MARK: - The count

    func testTheCounterCountsEveryRecordedCall() {
        let before = AppleFMCallCounter.current
        let first = AppleFMCallCounter.recordCall()
        let second = AppleFMCallCounter.recordCall()
        XCTAssertEqual(first, before + 1)
        XCTAssertEqual(second, first + 1)
        XCTAssertGreaterThanOrEqual(AppleFMCallCounter.current, second)
    }

    func testTheCounterHoldsUnderConcurrentCalls() async {
        let before = AppleFMCallCounter.current
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<200 { group.addTask { AppleFMCallCounter.recordCall() } }
        }
        XCTAssertGreaterThanOrEqual(AppleFMCallCounter.current - before, 200)
    }

    // MARK: - Engine time on the outcome

    /// `polish` now hands back the engine's time with its outcome, for the line above.
    @MainActor
    func testTheServiceHandsBackEngineTimeOnASuccess() async {
        let clock = FakeClock()
        let engine = ScriptedEngine(clock: clock, secondsPerCall: 1,
                                    listAnswer: "I will be ten minutes late.", normalAnswer: "unused")
        let service = PolishService(sink: RecordingSink(), engine: engine, now: clock.now)

        let outcome = await service.polish(raw: "je serai en retard de dix minutes", languagePolicy: frenchPolicy,
                                           smartMode: SmartModeCatalogue.translate(to: .english), recordingDuration: 3)

        XCTAssertNil(outcome.smartModeFailure)
        XCTAssertNotNil(outcome.engineMs)
    }

    /// And on a refusal, with the engine's reason on the failure the line reads.
    @MainActor
    func testTheServiceHandsBackEngineTimeOnARefusal() async {
        let service = PolishService(sink: RecordingSink(), engine: RateLimitedEngine(), now: Date.init)

        let outcome = await service.polish(raw: "je serai en retard de dix minutes", languagePolicy: frenchPolicy,
                                           smartMode: SmartModeCatalogue.translate(to: .english), recordingDuration: 3)

        XCTAssertEqual(outcome.smartModeFailure?.outcome, PolishMetrics.Outcome.engineFailed.rawValue)
        XCTAssertEqual(outcome.smartModeFailure?.reason, "rateLimited")
        XCTAssertNotNil(outcome.engineMs)
        let line = VoiceNoteSmartModeAttempt(outcome: outcome, modeIdentifier: "translate.en", appState: "background",
                                             callIndex: 1, trigger: .background)
        XCTAssertTrue(line.defersToOpen)
    }

    private var frenchPolicy: TranscriptionLanguagePolicy {
        TranscriptionLanguagePolicy(mode: .explicit(.french), keyboardLanguage: .french,
                                    engine: .parakeet, modelIdentifier: "parakeet-tdt-0.6b-v3")
    }
}

/// Refuses every call the way Apple's budget does in the background (#315).
private final class RateLimitedEngine: PolishEngineProtocol, @unchecked Sendable {
    struct Refusal: Error {}
    let identifier = "rate-limited"
    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        throw Refusal()
    }
    func failureReason(for error: Error) -> PolishFailureReason { .rateLimited }
}

/// The expiry state the coordinator reads before a background run calls the engine
/// (PR #689 review).
final class VoiceNoteBackgroundExpiryTests: XCTestCase {

    /// The review's window: requested, not yet started, and the task expires.
    func testAnExpiryBeforeTheRunStartsIsRecorded() {
        var expiry = VoiceNoteBackgroundExpiry()
        expiry.runRequested()
        XCTAssertTrue(expiry.expire())
        XCTAssertTrue(expiry.expired, "the run must see it before calling the engine")
    }

    /// Nothing pending: nothing to cancel, and nothing left to block a later run.
    func testAnExpiryWithNothingPendingIsIgnored() {
        var expiry = VoiceNoteBackgroundExpiry()
        XCTAssertFalse(expiry.expire())
        XCTAssertFalse(expiry.expired)
        expiry.runRequested()
        XCTAssertFalse(expiry.expired, "an earlier expiry never labels a later run")
    }

    /// The flag lasts until the last pending run has ended, then clears.
    func testTheFlagClearsWithTheLastPendingRun() {
        var expiry = VoiceNoteBackgroundExpiry()
        expiry.runRequested()
        expiry.runRequested()
        expiry.expire()
        expiry.runEnded()
        XCTAssertTrue(expiry.expired)
        expiry.runEnded()
        XCTAssertFalse(expiry.expired)
        XCTAssertEqual(expiry.pendingRuns, 0)
        expiry.runEnded()
        XCTAssertEqual(expiry.pendingRuns, 0, "never negative")
    }

    /// What the skipped run is logged as: a deferral to the card, not an error.
    func testAnExpiredRunDefersToOpen() {
        let outcome = PolishOutcome(failure: SmartModeFailure(
            modeIdentifier: "summary", modeDisplayName: "Résumé",
            outcome: PolishMetrics.Outcome.cancelled.rawValue, reason: "-"))
        let attempt = VoiceNoteSmartModeAttempt(
            outcome: outcome, modeIdentifier: "summary", appState: "background", callIndex: 3,
            trigger: .background, cancelReason: VoiceNoteSmartModeAttempt.backgroundTimeExpiredReason)
        XCTAssertEqual(attempt.reason, "backgroundTimeExpired")
        XCTAssertTrue(attempt.defersToOpen)
    }
}
