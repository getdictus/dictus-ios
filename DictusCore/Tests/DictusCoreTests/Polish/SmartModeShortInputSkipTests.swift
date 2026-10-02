// DictusCore/Tests/DictusCoreTests/Polish/SmartModeShortInputSkipTests.swift
// `Structuré` does not run on a sentence (#587, round 4).
import XCTest
@testable import DictusCore

/// Below its floor a mode is **skipped, not refused**: `PolishService.polish` drops the
/// armed mode and runs the dictation as if nothing were armed. The service's own branch
/// is a few lines over this predicate and is exercised on device (it needs the real
/// engine and the App Group); what is pinned here is the rule and where it applies.
final class SmartModeShortInputSkipTests: XCTestCase {

    /// The floor, and its boundary: 199 characters is a sentence, 200 is a dictation.
    func testStructuredSkipsBelowTwoHundredCharacters() {
        let mode = SmartModeCatalogue.structured
        XCTAssertEqual(mode.minimumInputCharacters, 200)
        XCTAssertFalse(mode.runs(onInputOfLength: 28), "`Comment tu vas aujourd'hui ?`, the device case")
        XCTAssertFalse(mode.runs(onInputOfLength: 199))
        XCTAssertTrue(mode.runs(onInputOfLength: 200))
        XCTAssertTrue(mode.runs(onInputOfLength: 1337))
    }

    /// Structuré only. `Message` exists for short text and must never skip it;
    /// `Résumé` bounds itself through its band; `Liste` checks its output instead
    /// (#573, decision 5 amended); `Traduction` has no reason to.
    func testNoOtherModeSkipsShortInput() {
        for mode in SmartModeCatalogue.builtIns where mode.id != SmartModeCatalogue.structuredIdentifier {
            XCTAssertNil(mode.minimumInputCharacters, mode.id)
            XCTAssertTrue(mode.runs(onInputOfLength: 1), mode.id)
        }
    }

    // MARK: - Liste's output check (#573, decision 5 amended)

    /// The device case that killed the 100-character floor: 64 characters, four items.
    /// `Liste` now runs on any length; `SmartModeListCheckTests` pins the output check.
    func testListRunsOnAnyLengthAndNeedsTwoItems() {
        let mode = SmartModeCatalogue.notes
        XCTAssertNil(mode.minimumInputCharacters)
        XCTAssertTrue(mode.runs(onInputOfLength: 64))
        XCTAssertEqual(mode.minimumListItems, 2)
    }

    /// No other mode checks its output's shape: a one-paragraph `Résumé` or a one-line
    /// `Message` is exactly what they exist to produce.
    func testNoOtherModeChecksItsOutputShape() {
        for mode in SmartModeCatalogue.builtIns where mode.id != SmartModeCatalogue.notesIdentifier {
            XCTAssertNil(mode.minimumListItems, mode.id)
        }
    }

    /// The check survives example resolution and the App Group round trip, and a
    /// snapshot written before it decodes to no check.
    func testTheOutputCheckSurvivesResolutionAndDecoding() throws {
        XCTAssertEqual(SmartModeCatalogue.notes.resolvingExamples(forTranscriptLanguage: "de").minimumListItems, 2)
        let data = try JSONEncoder().encode(SmartModeCatalogue.notes)
        XCTAssertEqual(try JSONDecoder().decode(SmartMode.self, from: data).minimumListItems, 2)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "minimumListItems")
        let old = try JSONDecoder().decode(SmartMode.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.minimumListItems)
        XCTAssertEqual(SmartModeListCheck.evaluate("Café :\n- Racheter du café", mode: old, engineIsModel: true),
                       .accept("Café :\n- Racheter du café"))
    }

    /// The decline is the same event as the input skip, with the numbers of its own
    /// rule in place of the floor, so an export says which rule fired.
    func testTheOutputDeclineIsTheSameEventWithItsOwnNumbers() throws {
        let metrics = PolishMetrics(
            engine: "apple-fm", mode: "smart.notes", targetLanguage: nil, detectedLanguage: "fr",
            rawCharCount: 38, polishedCharCount: 38, latencyMs: 0,
            outcome: .smartModeSkippedShortInput,
            smartModeLengthSkip: PolishMetrics.SmartModeLengthSkip(
                mode: "notes", characters: 38, listItems: 1, minimumListItems: 2
            )
        )
        let decoded = try JSONDecoder().decode(PolishMetrics.self, from: JSONEncoder().encode(metrics))
        XCTAssertEqual(decoded.outcome, .smartModeSkippedShortInput)
        XCTAssertEqual(decoded.smartModeLengthSkip?.mode, "notes")
        XCTAssertNil(decoded.smartModeLengthSkip?.floor)
        XCTAssertEqual(decoded.smartModeLengthSkip?.listItems, 1)
        XCTAssertEqual(decoded.smartModeLengthSkip?.minimumListItems, 2)
    }

    /// Resolving a mode's per-language examples keeps its floor: the pipeline sees the
    /// resolved record, and a copy that lost the field would run on a sentence again.
    func testTheFloorSurvivesExampleResolution() {
        let resolved = SmartModeCatalogue.structured.resolvingExamples(forTranscriptLanguage: "de")
        XCTAssertEqual(resolved.minimumInputCharacters, 200)
    }

    /// The record crosses the App Group inside the per-dictation snapshot: a snapshot
    /// written before this field decodes to no floor, and one written now keeps it.
    func testTheFloorDecodesWhenAbsentAndRoundTrips() throws {
        let data = try JSONEncoder().encode(SmartModeCatalogue.structured)
        XCTAssertEqual(try JSONDecoder().decode(SmartMode.self, from: data).minimumInputCharacters, 200)

        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "minimumInputCharacters")
        let old = try JSONDecoder().decode(SmartMode.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.minimumInputCharacters)
        XCTAssertTrue(old.runs(onInputOfLength: 28))
    }

    /// What an export carries: the skip is its own outcome, with the two numbers the
    /// decision was made on, so a reader can ask whether the floor is right.
    func testTheSkipIsItsOwnOutcomeWithItsNumbers() throws {
        let metrics = PolishMetrics(
            engine: "apple-fm", mode: "smart.structured", targetLanguage: nil, detectedLanguage: "fr",
            rawCharCount: 28, polishedCharCount: 28, latencyMs: 0,
            outcome: .smartModeSkippedShortInput,
            smartModeLengthSkip: PolishMetrics.SmartModeLengthSkip(
                mode: "structured", characters: 28, floor: 200
            )
        )
        let decoded = try JSONDecoder().decode(PolishMetrics.self, from: JSONEncoder().encode(metrics))
        XCTAssertEqual(decoded.outcome, .smartModeSkippedShortInput)
        XCTAssertEqual(decoded.smartModeLengthSkip?.mode, "structured")
        XCTAssertEqual(decoded.smartModeLengthSkip?.characters, 28)
        XCTAssertEqual(decoded.smartModeLengthSkip?.floor, 200)
        XCTAssertEqual(decoded.outcome.rawValue, "smartModeSkippedShortInput")
    }

    /// Every other outcome leaves the field empty, so a reader can key on its presence.
    func testNoOtherEventCarriesTheSkipDetail() throws {
        let metrics = PolishMetrics(
            engine: "apple-fm", mode: "natural", targetLanguage: .french, detectedLanguage: "fr",
            rawCharCount: 28, polishedCharCount: 28, latencyMs: 900, outcome: .success
        )
        let decoded = try JSONDecoder().decode(PolishMetrics.self, from: JSONEncoder().encode(metrics))
        XCTAssertNil(decoded.smartModeLengthSkip)
    }

    /// The user is told. The skip travels on the same `SmartModeFailure` channel as
    /// every other did-not-run sentence, with text inserted — which is what
    /// `isDegraded` means — so the keyboard raises its notice.
    func testTheSkipReachesTheToolbarAsADegradedOutcome() {
        let outcome = PolishOutcome(
            degradedTo: "Comment tu vas aujourd'hui ?",
            failure: SmartModeFailure(
                modeIdentifier: "structured", modeDisplayName: "Structured",
                outcome: PolishMetrics.Outcome.smartModeSkippedShortInput.rawValue,
                reason: "shortInput"
            )
        )
        XCTAssertTrue(outcome.isDegraded)
        XCTAssertEqual(outcome.text, "Comment tu vas aujourd'hui ?")
        XCTAssertEqual(outcome.smartModeFailure?.outcome, "smartModeSkippedShortInput")
    }

    /// The persistent log line an agent reads: the existing "ran Normal instead" event,
    /// with a reason that says why.
    func testTheLogLineSaysTheModeWasSkippedForLength() {
        let event = LogEvent.smartModeSkipped(mode: "structured", reason: "shortInput chars=28 floor=200",
                                              disarmed: false)
        XCTAssertEqual(event.name, "smartModeSkipped")
        XCTAssertTrue(event.message.contains("reason=shortInput chars=28 floor=200"))
    }
}
