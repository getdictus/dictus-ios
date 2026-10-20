// DictusCore/Tests/DictusCoreTests/Polish/SmartModeListCheckTests.swift
// Liste's output check and what replaces a declined output (#573, PR #629 review).
import XCTest
@testable import DictusCore

/// The three defects the code review of PR #629 found, each pinned:
///
/// 1. a second model call that could overrun the keyboard's watchdog and lose the text;
/// 2. "Trop court pour une liste" shown when nothing was too short (no list at all, a
///    fallback engine, another bullet style);
/// 3. a discarded `Liste` output recorded as a `success` event.
final class SmartModeListCheckTests: XCTestCase {

    private let liste = SmartModeCatalogue.notes

    // MARK: - The verdict (finding 2)

    func testAOneItemListIsDeclined() {
        XCTAssertEqual(SmartModeListCheck.evaluate("Café :\n- Racheter du café demain matin", mode: liste, engineIsModel: true),
                       .decline(items: 1, minimum: 2))
    }

    func testATwoItemListIsAcceptedUnchanged() {
        let output = "Garage, facture :\n- Rappeler le garage\n- Payer la facture"
        XCTAssertEqual(SmartModeListCheck.evaluate(output, mode: liste, engineIsModel: true), .accept(output))
    }

    /// Other bullet styles are lists too, and reach the document as `- `.
    func testOtherBulletStylesAreCountedAndNormalised() {
        for marker in ["•", "*", "–", "1.", "2)"] {
            let output = "Courses :\n\(marker) Tomates\n\(marker) Riz"
            XCTAssertEqual(SmartModeListCheck.evaluate(output, mode: liste, engineIsModel: true),
                           .accept("Courses :\n- Tomates\n- Riz"), marker)
        }
        XCTAssertEqual(SmartModeListCheck.evaluate("Café :\n• Racheter du café", mode: liste, engineIsModel: true),
                       .decline(items: 1, minimum: 2), "a one-item list in another style is still one item")
    }

    /// No list line at all is not "too short": it keeps the path it had before the check.
    func testAnOutputWithNoListIsAcceptedAsItCame() {
        let paragraphs = "On a parlé du budget pendant une heure.\n\nLa décision est reportée à jeudi."
        XCTAssertEqual(SmartModeListCheck.evaluate(paragraphs, mode: liste, engineIsModel: true), .accept(paragraphs))
    }

    /// The passthrough returns the transcript unchanged; it is never judged, even when
    /// the transcript happens to hold one dash line.
    func testAnEngineThatDoesNotGenerateIsNeverJudged() {
        let raw = "- une seule ligne dictée avec un tiret"
        XCTAssertEqual(SmartModeListCheck.evaluate(raw, mode: liste, engineIsModel: false), .accept(raw))
    }

    func testOnlyListeIsJudged() {
        for mode in SmartModeCatalogue.builtIns where mode.id != SmartModeCatalogue.notesIdentifier {
            XCTAssertEqual(SmartModeListCheck.evaluate("Titre :\n- un", mode: mode, engineIsModel: true),
                           .accept("Titre :\n- un"), mode.id)
        }
    }

    func testMarkersInsideALineAreLeftAlone() {
        XCTAssertEqual(SmartModeListCheck.normalisingListMarkers("Vide-grenier - dimanche :\nIl reste 2. Pas plus"),
                       "Vide-grenier - dimanche :\nIl reste 2. Pas plus")
        XCTAssertEqual(SmartModeListCheck.listItemCount(in: "Titre :\n  - un\n- deux"), 2)
    }

    // MARK: - The budget (finding 1)

    /// A long dictation whose first call was slow leaves no room for a second call.
    func testALongInputAfterASlowFirstCallLeavesNoRoomForASecondCall() {
        // 600 characters: the watchdog allows 24 s, a Normal polish may cost 18.6 s.
        XCTAssertFalse(SmartModeListCheck.secondCallFits(elapsed: 8, characters: 600))
        XCTAssertFalse(SmartModeListCheck.secondCallFits(elapsed: 4, characters: 600))
    }

    func testAShortInputAfterAQuickFirstCallLeavesRoom() {
        // 40 characters: the 15 s floor, a Normal polish of about 1.2 s.
        XCTAssertTrue(SmartModeListCheck.secondCallFits(elapsed: 2, characters: 40))
        XCTAssertFalse(SmartModeListCheck.secondCallFits(elapsed: 13, characters: 40))
    }

    /// The re-review's counter-example: a short dictation on a throttled device. The
    /// first call took 9 s, so the second is assumed to take 9 s too: 9 + 9 + 2 > 15.
    func testAShortInputAfterASlowFirstCallLeavesNoRoom() {
        XCTAssertFalse(SmartModeListCheck.secondCallFits(elapsed: 9, characters: 100))
        XCTAssertFalse(SmartModeListCheck.secondCallFits(elapsed: 6.6, characters: 100))
        XCTAssertTrue(SmartModeListCheck.secondCallFits(elapsed: 6, characters: 100))
    }

    // MARK: - The service, end to end on a fake engine and clock (findings 1 and 3)

    private let policy = TranscriptionLanguagePolicy(
        mode: .explicit(.french), keyboardLanguage: .french,
        engine: .parakeet, modelIdentifier: "parakeet-tdt-0.6b-v3"
    )

    override func setUp() {
        super.setUp()
        AppGroup.defaults.set(true, forKey: SharedKeys.polishEnabled)
    }

    override func tearDown() {
        AppGroup.defaults.removeObject(forKey: SharedKeys.polishEnabled)
        super.tearDown()
    }

    /// Short dictation, quick first call: the one-item list is replaced by a Normal
    /// polish, the user is told, and the export never records the list as a success.
    @MainActor
    func testADeclinedListIsReplacedByNormalPolishAndNeverRecordedAsSuccess() async {
        let clock = FakeClock()
        let engine = ScriptedEngine(clock: clock, secondsPerCall: 1,
                                    listAnswer: "Café :\n- Racheter du café demain matin",
                                    normalAnswer: "Pense à racheter du café demain matin.")
        let sink = RecordingSink()
        let service = PolishService(sink: sink, engine: engine, now: clock.now)

        let outcome = await service.polish(raw: "pense à racheter du café demain matin", languagePolicy: policy,
                                           smartMode: liste, recordingDuration: 5)

        XCTAssertEqual(outcome.text, "Pense à racheter du café demain matin.")
        XCTAssertEqual(outcome.smartModeFailure?.outcome, PolishMetrics.Outcome.smartModeSkippedShortInput.rawValue)
        XCTAssertTrue(outcome.isDegraded)
        XCTAssertEqual(engine.calls, ["smart.notes", "natural"])
        // Two events: the Liste call recorded as declined, then the Normal polish that
        // replaced it. Never a `success` for the discarded list.
        let outcomes = await sink.outcomes()
        XCTAssertEqual(outcomes, [.smartModeSkippedShortInput, .success])
        let skip = await sink.entries().first?.metrics.smartModeLengthSkip
        XCTAssertEqual(skip?.listItems, 1)
        XCTAssertEqual(skip?.minimumListItems, 2)
    }

    /// Long dictation, slow first call: no second call, the deterministic floor goes in.
    @MainActor
    func testALongInputWithASlowFirstCallInsertsTheFloorWithoutASecondCall() async {
        let clock = FakeClock()
        let engine = ScriptedEngine(clock: clock, secondsPerCall: 9,
                                    // Long enough to clear the 0.1 length floor, so the
                                    // list check, not a guardrail, is what declines it.
                                    listAnswer: "Réunion :\n- Le budget est validé pour l'année prochaine et on avance bien",
                                    normalAnswer: "unused")
        let service = PolishService(sink: RecordingSink(), engine: engine, now: clock.now)
        let raw = String(repeating: "alors le budget est validé pour l'année prochaine et on avance ", count: 10)

        let outcome = await service.polish(raw: raw, languagePolicy: policy, smartMode: liste, recordingDuration: 40)

        XCTAssertEqual(engine.calls, ["smart.notes"], "a second call could overrun the keyboard's watchdog")
        XCTAssertEqual(outcome.smartModeFailure?.outcome, PolishMetrics.Outcome.smartModeSkippedShortInput.rawValue)
        XCTAssertNotNil(outcome.text, "the floor is inserted: less polish beats lost text")
        XCTAssertTrue(outcome.text?.contains("budget est validé") == true)
    }

    /// The same counter-example end to end: 100 characters, a 9 s Liste call. No second
    /// call, the punctuated transcript goes in, the notice is kept.
    @MainActor
    func testAShortInputWithASlowFirstCallInsertsTheFloorWithoutASecondCall() async {
        let clock = FakeClock()
        let engine = ScriptedEngine(clock: clock, secondsPerCall: 9,
                                    listAnswer: "Café :\n- Racheter du café demain matin",
                                    normalAnswer: "unused")
        let service = PolishService(sink: RecordingSink(), engine: engine, now: clock.now)
        let raw = "pense à racheter du café demain matin parce qu'il n'y en a plus du tout à la maison ce soir"

        let outcome = await service.polish(raw: raw, languagePolicy: policy, smartMode: liste, recordingDuration: 6)

        XCTAssertEqual(engine.calls, ["smart.notes"], "a 9 s second call would pass the 15 s watchdog")
        XCTAssertEqual(outcome.smartModeFailure?.outcome, PolishMetrics.Outcome.smartModeSkippedShortInput.rawValue)
        XCTAssertTrue(outcome.text?.contains("racheter du café") == true, "the punctuated transcript is inserted")
    }

    /// Apple Intelligence unavailable: the passthrough returns the dictation unchanged.
    /// Before #573's check that showed no message, and it still shows none.
    @MainActor
    func testTheFallbackEngineNeverShowsTooShort() async {
        let clock = FakeClock()
        let service = PolishService(sink: RecordingSink(), engine: PassthroughPolishEngine(), now: clock.now)
        let raw = String(repeating: "on a fait le point sur le projet et tout avance comme prévu ", count: 7)

        let outcome = await service.polish(raw: raw, languagePolicy: policy, smartMode: liste, recordingDuration: 30)

        XCTAssertNotEqual(outcome.smartModeFailure?.outcome, PolishMetrics.Outcome.smartModeSkippedShortInput.rawValue)
        XCTAssertNotNil(outcome.text)
    }

    /// An accepted list is untouched by the check: one call, a success event, the text.
    @MainActor
    func testAnAcceptedListTakesTheSamePathAsBefore() async {
        let clock = FakeClock()
        let list = "Liste de courses pour ce soir :\n- Tomates\n- Riz\n- Oignons\n- Yaourts"
        let engine = ScriptedEngine(clock: clock, secondsPerCall: 1, listAnswer: list, normalAnswer: "unused")
        let sink = RecordingSink()
        let service = PolishService(sink: sink, engine: engine, now: clock.now)

        let outcome = await service.polish(raw: "liste de courses pour ce soir tomates riz oignons et yaourts",
                                           languagePolicy: policy, smartMode: liste, recordingDuration: 4)

        // The engine's text, with only the French typography the per-language post-pass
        // has always applied (a no-break space before the colon).
        XCTAssertEqual(outcome.text, list.replacingOccurrences(of: " :", with: "\u{00A0}:"))
        XCTAssertNil(outcome.smartModeFailure)
        XCTAssertEqual(engine.calls, ["smart.notes"])
        let outcomes = await sink.outcomes()
        XCTAssertEqual(outcomes, [.success])
    }
}
