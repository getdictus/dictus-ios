// DictusCore/Tests/DictusCoreTests/Polish/PolishToggleOffJournalTests.swift
// Every dictation reaches the polish journal, polish on or off (#747).
import XCTest
@testable import DictusCore

/// With the polish toggle off, `PolishService` used to return the raw text before
/// writing anything, so a user who keeps polish off exported an empty journal. These
/// pin the event that path now writes, that the polish-on path is untouched, and that
/// no count over polish runs picks the new event up.
@MainActor
final class PolishToggleOffJournalTests: XCTestCase {

    private let policy = TranscriptionLanguagePolicy(
        mode: .explicit(.french), keyboardLanguage: .french,
        engine: .parakeet, modelIdentifier: "parakeet-tdt-0.6b-v3"
    )
    /// What the vocabulary pass handed the polish, and the engine's own words before it.
    private let corrected = "je déploie sur Kubernetes ce soir"
    private let engineText = "je déploie sur cubernetes ce soir"

    override func tearDown() {
        AppGroup.defaults.removeObject(forKey: SharedKeys.polishEnabled)
        super.tearDown()
    }

    private func makeService(sink: RecordingSink,
                             normalAnswer: String = "Je déploie sur Kubernetes ce soir.") -> (PolishService, ScriptedEngine) {
        let clock = FakeClock()
        let engine = ScriptedEngine(clock: clock, secondsPerCall: 1, listAnswer: "unused", normalAnswer: normalAnswer)
        return (PolishService(sink: sink, engine: engine, now: clock.now), engine)
    }

    // MARK: - Polish off

    /// The device case from the issue: polish off, the vocabulary replaced a word. One
    /// entry, the engine's words in `raw`, the replacement beside them, the skip reason
    /// as its own outcome, and the engine never asked.
    func testPolishOffWritesOneEntryWithTheSkipReasonAndTheCorrectedText() async throws {
        AppGroup.defaults.set(false, forKey: SharedKeys.polishEnabled)
        let sink = RecordingSink()
        let (service, engine) = makeService(sink: sink)

        let outcome = await service.polish(raw: corrected, languagePolicy: policy,
                                           recordingDuration: 5, engineRaw: engineText)

        XCTAssertEqual(outcome.text, corrected, "polish off still inserts the corrected text, untouched")
        XCTAssertNil(outcome.smartModeFailure)
        XCTAssertEqual(engine.calls, [], "the toggle stops the engine before it is asked")
        let entries = await sink.entries()
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.metrics.outcome, .skippedToggleOff)
        XCTAssertEqual(entry.raw, engineText, "`raw` is the speech engine's own output (#80)")
        XCTAssertEqual(entry.vocabularyCorrected, corrected)
        XCTAssertNil(entry.polished, "nil is what the entry already means by 'no engine output'")
        XCTAssertEqual(entry.metrics.rawCharCount, corrected.count)
        XCTAssertEqual(entry.metrics.polishedCharCount, corrected.count)
        XCTAssertNil(entry.metrics.mode, "no task was chosen")
        XCTAssertNil(entry.metrics.timings, "nothing ran, so nothing was timed")
        XCTAssertNil(entry.metrics.failureReason)
        XCTAssertNil(entry.metrics.guardrailCheck)
        XCTAssertEqual(entry.metrics.sttModelID, "parakeet-tdt-0.6b-v3")
        XCTAssertEqual(entry.metrics.languageResolution?.transcriptionMode, "explicit(fr)")
    }

    /// No vocabulary in play: the entry is shaped like every other one, with no
    /// `vocabularyCorrected`.
    func testPolishOffWithoutAVocabularyChangeCarriesTheRawAlone() async throws {
        AppGroup.defaults.set(false, forKey: SharedKeys.polishEnabled)
        let sink = RecordingSink()
        let (service, _) = makeService(sink: sink)

        _ = await service.polish(raw: engineText, languagePolicy: policy, recordingDuration: 5)

        let entries = await sink.entries()
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.metrics.outcome, .skippedToggleOff)
        XCTAssertEqual(entry.raw, engineText)
        XCTAssertNil(entry.vocabularyCorrected)
    }

    /// The skip reason survives the store's coding, which is what both processes write
    /// and the export reads.
    func testTheSkipReasonRoundTripsThroughTheStore() throws {
        let entry = PolishDebugEntry(
            raw: engineText, vocabularyCorrected: corrected, polished: nil,
            metrics: PolishMetrics(engine: "apple-fm", mode: nil, targetLanguage: nil, detectedLanguage: nil,
                                   rawCharCount: corrected.count, polishedCharCount: corrected.count,
                                   latencyMs: 0, outcome: .skippedToggleOff),
            writer: "<KBD>"
        )
        let data = try PolishEventStore.encoder.encode(entry)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"outcome\":\"skippedToggleOff\""))
        let decoded = try PolishEventStore.decoder.decode(PolishDebugEntry.self, from: data)
        XCTAssertEqual(decoded.metrics.outcome, .skippedToggleOff)
        XCTAssertEqual(decoded.vocabularyCorrected, corrected)
        XCTAssertNil(decoded.polished)
    }

    // MARK: - Polish on, and Smart Modes: unchanged

    /// Polish on: one entry, the engine ran, the outcome is the engine's own. Nothing
    /// about the toggle-off event leaks into this path.
    func testPolishOnIsUnchanged() async throws {
        AppGroup.defaults.set(true, forKey: SharedKeys.polishEnabled)
        let sink = RecordingSink()
        let (service, engine) = makeService(sink: sink)

        let outcome = await service.polish(raw: corrected, languagePolicy: policy,
                                           recordingDuration: 5, engineRaw: engineText)

        XCTAssertEqual(engine.calls, ["natural"])
        XCTAssertEqual(outcome.text, "Je déploie sur Kubernetes ce soir.")
        let entries = await sink.entries()
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.metrics.outcome, .success)
        XCTAssertEqual(entry.metrics.mode, "natural")
        XCTAssertNotNil(entry.metrics.timings)
        XCTAssertEqual(entry.raw, engineText)
        XCTAssertEqual(entry.vocabularyCorrected, corrected)
        XCTAssertEqual(entry.polished, "Je déploie sur Kubernetes ce soir.")
    }

    /// An armed mode runs despite the toggle (#79), so it writes its own event and no
    /// toggle-off one.
    func testAnArmedModeWithPolishOffRunsAndWritesNoToggleOffEvent() async {
        AppGroup.defaults.set(false, forKey: SharedKeys.polishEnabled)
        let clock = FakeClock()
        let engine = ScriptedEngine(clock: clock, secondsPerCall: 1,
                                    listAnswer: "I deploy on Kubernetes tonight.", normalAnswer: "unused")
        let sink = RecordingSink()
        let service = PolishService(sink: sink, engine: engine, now: clock.now)
        let mode = SmartModeCatalogue.translate(to: .english)

        _ = await service.polish(raw: corrected, languagePolicy: policy, smartMode: mode, recordingDuration: 5)

        XCTAssertEqual(engine.calls, [PolishTask.smart(mode).identifier])
        let outcomes = await sink.outcomes()
        XCTAssertEqual(outcomes.count, 1)
        XCTAssertFalse(outcomes.contains(.skippedToggleOff))
    }

    // MARK: - Counts over polish runs

    /// The export's aggregates: a toggle-off event counts under its own key and in
    /// nothing else, so every count a refusal rate is computed from is the same with
    /// or without them.
    func testTheTallyCountsToggleOffEventsUnderTheirOwnKeyOnly() {
        let runs = [
            Self.event(.success),
            Self.event(.engineFailed, reason: .rateLimited),
            Self.event(.rejectedGuardrail, check: .length)
        ]
        let toggleOff = Array(repeating: Self.event(.skippedToggleOff), count: 29)

        let withoutOff = PolishEventTally(entries: runs)
        let withOff = PolishEventTally(entries: runs + toggleOff)

        XCTAssertEqual(withOff.outcomes["skippedToggleOff"], 29)
        XCTAssertEqual(withoutOff.outcomes["skippedToggleOff"], 0, "seeded, so a zero reads as 'did not happen'")
        var expected = withoutOff.outcomes
        expected["skippedToggleOff"] = 29
        XCTAssertEqual(withOff.outcomes, expected, "no other outcome moves")
        XCTAssertEqual(withOff.failureReasons, withoutOff.failureReasons)
        XCTAssertEqual(withOff.failureReasonsByWriter, withoutOff.failureReasonsByWriter)
        XCTAssertEqual(withOff.guardrailChecks, withoutOff.guardrailChecks)
        XCTAssertEqual(withOff.smartModesSkippedForLength, withoutOff.smartModesSkippedForLength)
    }

    /// The one rate computed in code, the #315 refusal run, is not touched either: a
    /// toggle-off dictation between two refusals neither counts nor resets.
    func testAToggleOffEventLeavesTheRefusalRunAlone() {
        var gate = PolishAvailabilityGate()
        gate.record(outcome: .engineFailed, reason: .rateLimited, engine: "apple-fm")
        XCTAssertFalse(gate.record(outcome: .skippedToggleOff, reason: nil, engine: "apple-fm"))
        XCTAssertTrue(gate.record(outcome: .engineFailed, reason: .rateLimited, engine: "apple-fm"))
    }

    // MARK: - Seven days of older events

    /// A line written by a build before #747 still decodes: the change only adds an
    /// outcome, and the journal on a device holds a week of the old shape.
    func testAnEntryWrittenBeforeThisChangeStillDecodes() throws {
        let line = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","timestamp":"2026-10-17T09:12:44Z",\
        "raw":"bonjour","polished":"Bonjour.","writer":"<KBD>",\
        "metrics":{"engine":"apple-fm","mode":"natural","targetLanguage":"fr","detectedLanguage":"fr",\
        "rawCharCount":7,"polishedCharCount":8,"latencyMs":3120,"outcome":"success",\
        "sttEngine":"PK","sttModelID":"parakeet-tdt-0.6b-v3",\
        "timings":{"preprocessMs":4,"engineMs":3100,"postprocessMs":2}}}
        """
        let entry = try PolishEventStore.decoder.decode(PolishDebugEntry.self, from: Data(line.utf8))
        XCTAssertEqual(entry.metrics.outcome, .success)
        XCTAssertEqual(entry.polished, "Bonjour.")
        XCTAssertNil(entry.vocabularyCorrected)
    }

    private static func event(_ outcome: PolishMetrics.Outcome,
                              reason: PolishFailureReason? = nil,
                              check: PolishGuardrail.Check? = nil) -> PolishDebugEntry {
        PolishDebugEntry(
            raw: "bonjour", polished: nil,
            metrics: PolishMetrics(engine: "apple-fm", mode: nil, targetLanguage: nil, detectedLanguage: nil,
                                   rawCharCount: 7, polishedCharCount: 7, latencyMs: 0, outcome: outcome,
                                   failureReason: reason, guardrailCheck: check),
            writer: "<KBD>"
        )
    }
}
