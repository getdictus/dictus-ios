// DictusCore/Tests/DictusCoreTests/Polish/MessageGroundingBlindSpotTests.swift
// The one mode #414's overlap guard could not see, and the bench that bounds the fix (#572).
import XCTest
@testable import DictusCore

/// The device round of 2026-09-17 (round 2) produced two fabricated outputs that
/// **every guardrail accepted**, and the one that exists to catch a fabrication did
/// not merely score them generously — it never read them.
///
/// ### The arithmetic, which is the whole finding
///
/// `PolishGrounding.worstSegmentOverlap` skips any segment carrying fewer than
/// `thresholds.minimumContentWords` content words, and `.default` sets that to 3.
/// Content words are what survives the `functionWords` list, which holds the French
/// pronouns, determiners, auxiliaries and light verbs. A two-word reply built out of
/// a greeting and a light verb therefore reduces to **one** content word — the
/// greeting — so every segment is skipped, `worst` comes back `nil`, and
/// `acceptsSegmentOverlap` returns `true` on its documented *"no judgeable segment
/// passes untested"* branch.
///
/// ### Why it lands on this mode and not the others
///
/// The 3-word floor was measured on #414's corpora, which are **`List` outputs**:
/// bullets synthesised from a long rambling dictation, where a segment under three
/// content words is a heading like `Actions :` and refusing a whole dictation over it
/// is the false rejection the floor was set to avoid. That reasoning is sound there
/// and it inverts here. **`Message` is the one mode in the catalogue whose input is
/// short by construction** — it serves what you send to a person — and its most
/// common input is a greeting, a name and one clause. So the mode most exposed to
/// fabrication is the one the fabrication guard structurally cannot protect, on
/// precisely its own bread-and-butter input.
///
/// That is a finding about the guard, not about the prompt: nothing a prompt says
/// changes which segments the check agrees to read.
final class MessageGroundingBlindSpotTests: XCTestCase {

    /// The two fabricated shapes, rebuilt off-domain — the device texts are private
    /// messages and this repository is public, so what is reproduced here is the
    /// *shape*: a short, almost entirely relational input, and an output that keeps a
    /// greeting and then states something the speaker never said.
    ///
    /// Both reduce to a single content word after the function-word filter, which is
    /// what makes them invisible rather than merely accepted.
    private let fabrications: [(name: String, raw: String, polished: String)] = [
        // The model ANSWERED the question instead of rewriting it, which the prompt's
        // own framing forbids in a line of its own.
        ("answered the question", "Hello chef, comment tu vas ?", "Bonjour, je vais bien"),
        // The model replaced a farewell with a presence statement roughly opposite in
        // sense to it.
        ("inverted the farewell", "Hello chef, à demain, à plus", "Bonjour, je suis là")
    ]

    /// The false-rejection bench: two legitimate short outputs from the same device
    /// round, rebuilt with the same shape and the same content-word counts. **If a
    /// fix refuses either of these, the fix is wrong** — they are the mode working.
    private let legitimate: [(name: String, raw: String, polished: String)] = [
        ("kept the address term", "Ok chef, je pense fort à ça.", "Ok chef, je pense fort à ça"),
        ("kept a colloquial clause",
         "Ouais non ça marche pas, tu vois là il a complètement changé ce que je voulais dire.",
         "Ouais non ça marche pas\n\nTu vois là il a complètement changé ce que je voulais dire")
    ]

    // MARK: - The hole

    /// Pins the mechanism rather than the verdict, so a later reader sees *why* it
    /// passed: the check returns no reading at all at the default threshold.
    func testTheDefaultThresholdNeverEvaluatesAFabricatedShortMessage() {
        for case let (name, raw, polished) in fabrications {
            XCTAssertNil(
                PolishGrounding.worstSegmentOverlap(ofOutput: polished, against: raw),
                "\(name): the default thresholds now read this output; the blind spot moved"
            )
            XCTAssertTrue(
                PolishGrounding.acceptsSegmentOverlap(polished: polished, raw: raw),
                "\(name): accepted untested, which is the documented branch"
            )
        }
    }

    /// And the reading that exists once the segment is judged at all: zero. Not a
    /// near miss — the output shares no content word with the input.
    func testTheSameOutputsScoreZeroAsSoonAsTheyAreJudged() throws {
        let judgeable = PolishSegmentOverlapThresholds(floor: 0.15, minimumContentWords: 1)
        for case let (name, raw, polished) in fabrications {
            let overlap = try XCTUnwrap(
                PolishGrounding.worstSegmentOverlap(ofOutput: polished, against: raw,
                                                    thresholds: judgeable),
                "\(name): still unjudgeable at a one-word floor"
            )
            XCTAssertEqual(overlap, 0.0, accuracy: 0.001, "\(name)")
        }
    }

    // MARK: - The fix, and the bench that bounds it

    /// The contract carries the thresholds, so `Message` judges a one-content-word
    /// segment while every other mode keeps the floor #414 measured.
    func testTheMessageContractJudgesSegmentsTheOtherModesSkip() {
        XCTAssertEqual(SmartModeCatalogue.message.contract.segmentOverlapThresholds.minimumContentWords, 1)
        for mode in SmartModeCatalogue.builtIns where mode.id != SmartModeCatalogue.messageIdentifier {
            XCTAssertEqual(mode.contract.segmentOverlapThresholds, .default, mode.id)
        }
        XCTAssertEqual(PolishAcceptanceContract.natural.segmentOverlapThresholds, .default)
        XCTAssertEqual(PolishAcceptanceContract.auto.segmentOverlapThresholds, .default)
        // The floor is NOT what moved: 0.15 is the measured number and a mode that
        // changed it would be re-opening a trade declined on 2026-09-07.
        XCTAssertEqual(SmartModeCatalogue.message.contract.segmentOverlapThresholds.floor,
                       PolishSegmentOverlapThresholds.default.floor)
    }

    /// Under the shipping contract, the two fabrications are refused.
    func testTheShippingMessageContractRefusesBothFabrications() {
        let thresholds = SmartModeCatalogue.message.contract.segmentOverlapThresholds
        for case let (name, raw, polished) in fabrications {
            XCTAssertFalse(
                PolishGrounding.acceptsSegmentOverlap(polished: polished, raw: raw,
                                                      thresholds: thresholds),
                "\(name): still accepted"
            )
        }
    }

    /// And the bench holds: the mode's own good short output is not collateral.
    ///
    /// **This pair is the whole measured bench, and saying so is the point.** The two
    /// shapes below are the legitimate short outputs of the 2026-09-17 device round
    /// rebuilt off-domain — the round's other outputs are long enough to clear the
    /// old floor and so cannot say anything about lowering it. A wider replay over
    /// `docs/research/572-message/corpus.json` at `minimumContentWords: 1` has **not**
    /// been run; if a false rejection ever shows up in the field, that replay is the
    /// first thing to do and this comment is the record that it is still owed.
    func testTheShippingMessageContractStillAcceptsLegitimateShortOutputs() {
        let thresholds = SmartModeCatalogue.message.contract.segmentOverlapThresholds
        for case let (name, raw, polished) in legitimate {
            XCTAssertTrue(
                PolishGrounding.acceptsSegmentOverlap(polished: polished, raw: raw,
                                                      thresholds: thresholds),
                "\(name): refused, which is the cost this threshold must not pay"
            )
        }
    }

    /// A contract written by a build that never heard of this field decodes to the
    /// measured pair, never to a stricter one: a snapshot crosses the App Group and an
    /// app update can land between the write and the read, and a rejection on a Smart
    /// Mode costs the user everything they said.
    func testAContractDecodedWithoutTheFieldKeepsTheMeasuredThresholds() throws {
        let json = """
        {"minimumLengthRatio":0.2,"maximumLengthRatio":1.1,"outputLanguage":"sameAsInput",
         "requiresGroundedNames":true,"requiresAlignedPrefix":false}
        """
        let decoded = try JSONDecoder().decode(PolishAcceptanceContract.self,
                                               from: Data(json.utf8))
        XCTAssertEqual(decoded.segmentOverlapThresholds, .default)
    }

    /// And a round trip keeps what the writing build meant.
    func testTheThresholdsSurviveTheAppGroupRoundTrip() throws {
        let data = try JSONEncoder().encode(SmartModeCatalogue.message.contract)
        let decoded = try JSONDecoder().decode(PolishAcceptanceContract.self, from: data)
        XCTAssertEqual(decoded.segmentOverlapThresholds.minimumContentWords, 1)
        XCTAssertEqual(decoded, SmartModeCatalogue.message.contract)
    }
}
