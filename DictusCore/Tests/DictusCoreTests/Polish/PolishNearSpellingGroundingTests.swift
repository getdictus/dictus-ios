// DictusCore/Tests/DictusCoreTests/Polish/PolishNearSpellingGroundingTests.swift
// A name the model respelled from the speaker's word is grounded; a name invented is not (#587).
import XCTest
@testable import DictusCore

/// `PolishGrounding`'s near-spelling rule: a letter or two added or dropped, bounded
/// by the anchor's length, never a changed letter, never on a name of five letters or
/// fewer. `PolishGroundingTests` pins the older decisions this rule must not reopen
/// (`Marc`/`Marco`, `Mülle`/`Müller`) and still passes unchanged.
final class PolishNearSpellingGroundingTests: XCTestCase {

    /// The device dictation of 2026-09-23 14:32:37Z, `Structuré`, English, verbatim. The
    /// speaker said *Hermes*, Parakeet wrote `airmes`, the model wrote `Airmesh`, and a
    /// faithful four-item list was refused on `check=grounding`.
    private let deviceRaw = "And now I will do the same thing in English. The other things I did uh this day, uh this morning, I had my first masterclass about uh the uh uh AI agents and uh how can you build this on your laptops lap laptop sorry uh like cloud code or codex and I show them I show my students the uh T3 code that uh is an app uh that allow you to uh uh control your agents uh from your uh smartphone easily and the second thing i show them i showed them is uh airmes agent on my uh vps uh VPS setup and I did uh also a little presentation in HTML and uh that's it."

    private let deviceOutput = "I will do the same thing in English.\n\nThe other things I did this morning:\n- I had my first masterclass about AI agents and how to build them on laptops\n- I showed my students the T3 code, an app that allows you to control your agents from your smartphone easily\n- I showed them Airmesh agent on my VPS setup\n- I did a little presentation in HTML\n\nThat's it."

    // MARK: - Pierre's case

    func testTheRespelledNameIsGrounded() {
        XCTAssertTrue(PolishGrounding.isGrounded("Airmesh", in: deviceRaw))
        XCTAssertTrue(PolishGrounding.isGrounded("AI", in: deviceRaw))
    }

    /// The refused output of the device round, now accepted by the whole pipeline.
    func testTheDeviceOutputIsNowAccepted() async {
        let result = await PolishPipeline.transform(
            preprocessed: deviceRaw,
            engine: FixedOutputEngine(output: deviceOutput),
            job: PolishJob(task: .smart(SmartModeCatalogue.structured),
                           promptLanguage: .english, languageAgnosticPath: false)
        )
        XCTAssertEqual(result.outcome, .success, "refused on \(result.rejectedCheck?.rawValue ?? "-")")
    }

    /// #523's one legitimate refusal: the recogniser split the name in two.
    func testASplitNameIsGroundedByItsTwoWordsJoined() {
        XCTAssertTrue(PolishGrounding.isGrounded("TypeLess", in: "comment se comporte type less vs mon application"))
    }

    // MARK: - Still refused

    /// A name invented from nothing: nothing in the input is near it.
    func testAnInventedNameIsStillRefused() {
        XCTAssertFalse(PolishGrounding.isGrounded("Nathalie", in: deviceRaw))
        XCTAssertFalse(PolishGrounding.isGrounded("Hermes", in: deviceRaw),
                       "the right name, but the speaker's words never came near it: two letters changed")
    }

    /// `W2-nom-prefixe` from #414's corpus: `Sophia` said, `Sophie` written. A changed
    /// letter is how one name becomes another, and the rule admits none.
    func testAChangedLetterIsNeverNearSpelling() {
        XCTAssertFalse(PolishGrounding.isGrounded("Sophie", in: "les chiffres auprès de Sophia avant la réunion"))
        XCTAssertFalse(PolishGrounding.isGrounded("Marie", in: "il faut appeler Maria demain"))
        XCTAssertFalse(PolishGrounding.isGrounded("Saul", in: "Paul arrive demain"))
    }

    /// The prefix hole the matcher was rewritten to close stays closed.
    func testAPrefixOfARealNameIsStillRefused() {
        XCTAssertFalse(PolishGrounding.isGrounded("Paul", in: "il faut appeler Pauline"))
    }

    /// Five letters or fewer: exact match only.
    func testAShortNameMatchesExactlyOrNotAtAll() {
        XCTAssertEqual(PolishGrounding.allowedDistance(forAnchorOfLength: 3), 0)
        XCTAssertEqual(PolishGrounding.allowedDistance(forAnchorOfLength: 5), 0)
        XCTAssertFalse(PolishGrounding.isGrounded("Ana", in: "on a vu Anna hier"))
        XCTAssertFalse(PolishGrounding.isGrounded("Tom", in: "on a vu Tim hier"))
        XCTAssertFalse(PolishGrounding.isGrounded("Marco", in: "il faut appeler Marc demain"))
        XCTAssertTrue(PolishGrounding.isGrounded("Tom", in: "on a vu Tom hier"))
    }

    /// The bounds, stated as numbers.
    func testTheBoundsFollowTheAnchorsLength() {
        XCTAssertEqual(PolishGrounding.allowedDistance(forAnchorOfLength: 6), 1)
        XCTAssertEqual(PolishGrounding.allowedDistance(forAnchorOfLength: 7), 2)
        XCTAssertTrue(PolishGrounding.isNearSpelling("martine", of: "martin"))
        XCTAssertFalse(PolishGrounding.isNearSpelling("martine", of: "mart"))
    }
}

/// Returns one fixed string. Repeated here rather than shared because every other
/// copy in this target is `private` to its file.
private struct FixedOutputEngine: PolishEngineProtocol {
    let identifier = "fixed-output"
    let output: String

    func polish(raw: String,
                targetLanguage: SupportedLanguage,
                task: PolishTask) async throws -> String {
        output
    }
}
