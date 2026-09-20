// DictusCore/Tests/DictusCoreTests/Polish/SmartModeOverflowTests.swift
// What an armed mode inserts when the context guard refuses it (#79, block B decision)
// and, since #580, when a guardrail does.
import XCTest
@testable import DictusCore

final class SmartModeOverflowTests: XCTestCase {

    private func job(_ mode: SmartMode) -> PolishJob {
        PolishJob(task: .smart(mode), promptLanguage: .french, languageAgnosticPath: false)
    }

    private func result(_ outcome: PolishMetrics.Outcome) -> PolishPipeline.Result {
        PolishPipeline.Result(engineOutput: nil, outcome: outcome, engineMs: 0, postprocessMs: 0)
    }

    // MARK: - The catalogue's answers

    func testNotesDegradesToTheRawText() {
        XCTAssertEqual(SmartModeCatalogue.notes.floorBehaviour, .insertRawText)
    }

    /// Translation cannot degrade: the floor is the input language, which is the one
    /// thing the mode exists to change.
    func testEveryTranslateModeRefuses() {
        for language in SupportedLanguage.allCases {
            XCTAssertEqual(
                SmartModeCatalogue.translate(to: language).floorBehaviour,
                .insertNothing,
                "translate.\(language.rawValue) must not fall back to the input language"
            )
        }
    }

    // MARK: - What the pipeline does with them

    func testNotesInsertsTheDeterministicFloorOnOverflow() {
        let out = PolishPipeline.resolvedOutput(
            result(.exceededContextBudget),
            preprocessed: "Ok, petit test ?",
            job: job(SmartModeCatalogue.notes)
        )
        XCTAssertEqual(
            out, "Ok, petit test\u{00A0}?",
            "the floor is the pre-pass output with typography, never the literal raw (#185)"
        )
    }

    func testTranslateInsertsNothingOnOverflow() {
        XCTAssertNil(PolishPipeline.resolvedOutput(
            result(.exceededContextBudget),
            preprocessed: "Ok, petit test ?",
            job: job(SmartModeCatalogue.translate(to: .english))
        ))
    }

    // MARK: - A guardrail rejection (#580)

    /// The floor after a rejection is `preprocessed`, not anything the engine wrote:
    /// the output was discarded whole, so the words inserted are the speaker's own.
    func testListInsertsTheDeterministicFloorOnAGuardrailRejection() {
        let out = PolishPipeline.resolvedOutput(
            result(.rejectedGuardrail),
            preprocessed: "Ok, petit test ?",
            job: job(SmartModeCatalogue.notes)
        )
        XCTAssertEqual(
            out, "Ok, petit test\u{00A0}?",
            "the floor is the pre-pass output with typography, never the engine's rejected answer"
        )
        XCTAssertTrue(
            PolishPipeline.degradesToFloor(SmartModeCatalogue.notes, outcome: .rejectedGuardrail)
        )
    }

    /// The mode #580 measured: three rejections in nine device runs, one of them
    /// 1,337 characters that reached an empty field.
    func testStructuredDegradesOnAGuardrailRejection() {
        XCTAssertTrue(
            PolishPipeline.degradesToFloor(
                SmartModeCatalogue.structured, outcome: .rejectedGuardrail
            )
        )
        XCTAssertEqual(
            PolishPipeline.resolvedOutput(
                result(.rejectedGuardrail),
                preprocessed: "Ok, petit test ?",
                job: job(SmartModeCatalogue.structured)
            ),
            "Ok, petit test\u{00A0}?"
        )
    }

    /// `Message` (#572) landed on `develop` while #580 was on device, so it was never
    /// exercised there. Its overflow branch is close to unreachable — the input is
    /// short by construction — and a guardrail rejection is the branch this answer
    /// actually serves: what goes in the field is then what the speaker said.
    func testMessageDegradesOnAGuardrailRejection() {
        XCTAssertTrue(
            PolishPipeline.degradesToFloor(
                SmartModeCatalogue.message, outcome: .rejectedGuardrail
            )
        )
        XCTAssertEqual(
            PolishPipeline.resolvedOutput(
                result(.rejectedGuardrail),
                preprocessed: "Ok, petit test ?",
                job: job(SmartModeCatalogue.message)
            ),
            "Ok, petit test\u{00A0}?"
        )
    }

    /// The negative case, and the one the change must not take with it: the gate is
    /// still the mode's own declared behaviour, and Translate's floor is the input
    /// language — the one thing the mode exists to change.
    func testTranslateInsertsNothingOnAGuardrailRejection() {
        for language in SupportedLanguage.allCases {
            let mode = SmartModeCatalogue.translate(to: language)
            XCTAssertFalse(
                PolishPipeline.degradesToFloor(mode, outcome: .rejectedGuardrail),
                "translate.\(language.rawValue) must not fall back to the input language"
            )
            XCTAssertNil(PolishPipeline.resolvedOutput(
                result(.rejectedGuardrail),
                preprocessed: "Ok, petit test ?",
                job: job(mode)
            ))
        }
    }

    /// The exceptions stay as narrow as the argument for them. These four either
    /// attempted a transformation that may have half-happened, describe a process
    /// that will not call the engine again (#315), or would degrade to text in a
    /// language the model cannot read (#490) — so fail-closed still applies to List
    /// as much as to Translate.
    func testEveryOtherFailureStaysClosedEvenForADegradingMode() {
        let others: [PolishMetrics.Outcome] = [
            .engineFailed, .cancelled, .engineUnavailable, .skipped
        ]
        for outcome in others {
            XCTAssertNil(
                PolishPipeline.resolvedOutput(
                    result(outcome), preprocessed: "Ok", job: job(SmartModeCatalogue.notes)
                ),
                "\(outcome.rawValue) must not degrade — a transformation was attempted"
            )
            XCTAssertFalse(
                PolishPipeline.degradesToFloor(SmartModeCatalogue.notes, outcome: outcome)
            )
        }
    }

    func testSuccessIsUnaffected() {
        let succeeded = PolishPipeline.Result(
            engineOutput: "• un point", outcome: .success, engineMs: 1, postprocessMs: 0
        )
        XCTAssertEqual(
            PolishPipeline.resolvedOutput(
                succeeded, preprocessed: "un point", job: job(SmartModeCatalogue.notes)
            ),
            "• un point"
        )
    }

    /// The free polish never changed: it falls back on everything, mode or no mode.
    func testFreePolishStillFallsBackOnOverflow() {
        XCTAssertEqual(
            PolishPipeline.resolvedOutput(
                result(.exceededContextBudget),
                preprocessed: "Ok, petit test ?",
                job: PolishJob(task: .natural, promptLanguage: .french, languageAgnosticPath: false)
            ),
            "Ok, petit test\u{00A0}?"
        )
    }

    // MARK: - Crossing the App Group

    func testBehaviourSurvivesAnEncodeDecodeRoundTrip() throws {
        let encoded = try JSONEncoder().encode(SmartModeCatalogue.notes)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertEqual(
            object["overflowBehaviour"] as? String, "insertRawText",
            "the wire key predates the #580 rename and is pinned, so a record written "
                + "by this build is still readable by one that predates it"
        )
        let decoded = try JSONDecoder().decode(SmartMode.self, from: encoded)
        XCTAssertEqual(decoded.floorBehaviour, .insertRawText)
        XCTAssertEqual(decoded, SmartModeCatalogue.notes)
    }

    /// A record written by a build that predates the field — an app update landing
    /// between the snapshot and the read. It must decode, and it must decode to the
    /// safe half: losing one Notes dictation across one upgrade is recoverable,
    /// sending French to an American client is not.
    func testARecordWithoutTheFieldDecodesAsRefusing() throws {
        var json = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: try JSONEncoder().encode(SmartModeCatalogue.notes)
            ) as? [String: Any]
        )
        // The key is still `overflowBehaviour` after the #580 rename, pinned by
        // `SmartMode.CodingKeys` — a snapshot written by a build that shipped the old
        // name must keep decoding to `.insertRawText`, not fall through to the default.
        json.removeValue(forKey: "overflowBehaviour")
        let stripped = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(SmartMode.self, from: stripped)
        XCTAssertEqual(decoded.id, SmartModeCatalogue.notesIdentifier)
        XCTAssertEqual(decoded.floorBehaviour, .insertNothing)
    }
}
