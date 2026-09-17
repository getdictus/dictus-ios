// DictusCore/Tests/DictusCoreTests/PolishFidelityScorerTests.swift
//
// Pins the #570 / #581 fidelity scorers.
//
// WHY these exist at all. The bench's numbers are about to be read as evidence for or
// against a prompt change, and #466 is the standing reminder of what a threshold
// nobody pinned costs: 10 legitimate repairs of 10 refused, at every value swept. A
// scorer nobody can test is a scorer nobody should believe, so axis 4 gets its two
// controls, axis 1 gets its alignment cases, axis 2 gets the two device defects the
// brief names by example, and the whole thing gets re-run against the committed
// device corpus so a silent regression in the lexicons cannot pass.
//
// Model-free, so they run on any machine, in CI, and on the iOS Simulator destination.
import XCTest
@testable import DictusCore
@testable import PolishFidelity

final class PolishFidelityScorerTests: XCTestCase {

    // MARK: - Axis 4, the two controls #581 declared

    /// The positive control, from the device on 2026-09-17 15:29:03Z.
    ///
    /// A 1 337-character dictation about the suggestion bar, whose output ends on a
    /// sentence the speaker never said — and which is a near-verbatim paraphrase of
    /// `SmartModeStructuredPrompt`'s own worked example. `segmentOverlap` refused the
    /// whole output, so the user lost the dictation instead (#580); the fabrication is
    /// in the refused text, which is why the bench scores the engine's output.
    func testAxis4FlagsTheDeviceFabrication() throws {
        let work = try deviceCase("D9-suggestion-bar")
        let score = PolishFidelityScorer.score(output: work.output, input: work.raw)

        XCTAssertEqual(score.speakerState, .fabricated,
                       "the output closes on `Il y a un autre truc, mais je ne me souviens pas.` "
                       + "and nothing in the 1337-character raw says anything of the kind")
        XCTAssertTrue(score.closesOnSpeakerState,
                      "#581's shape is a CLOSING sentence: rule 7's leak is a locally "
                      + "plausible completion, not a line inserted mid-text")
    }

    /// The negative control: rule 7 doing its job must never read as a fabrication.
    ///
    /// `longform-fr.json` fixture 5 ends on the speaker saying out loud that something
    /// is missing, and #523's decision 7 makes keeping it a hard bar — measured 5/5 in
    /// `docs/research/523-structured/findings.md`. A check that flagged every
    /// speaker-state sentence would refuse the one rule this mode carries against the
    /// reference competitor, which deletes it.
    func testAxis4DoesNotFlagRule7DoingItsJob() {
        let raw = "et puis le dernier truc à planifier c'est de préparer les questions pour "
            + "l'entretien de mardi voilà je crois que c'est tout ah non il y avait un "
            + "dernier truc ça m'échappe mais ça me reviendra"
        let output = "Il faut que je prépare les questions pour l'entretien de mardi. "
            + "Il y avait un dernier truc, ça m'échappe, mais ça me reviendra."

        XCTAssertEqual(PolishFidelityScorer.score(output: output, input: raw).speakerState,
                       .preserved,
                       "both sides carry one, so this is decision 7 holding, not #581")
    }

    /// The third verdict, which is decision 7's bar read from the other side: the
    /// speaker flagged an incompleteness and the model dropped it. That is the exact
    /// behaviour the reference competitor has and #523 refused to reproduce.
    func testAxis4FlagsADroppedIncompleteness() {
        let raw = "il faut que je rappelle le plombier ah non il y avait un autre truc ça m'échappe"
        let output = "Il faut que je rappelle le plombier."

        XCTAssertEqual(PolishFidelityScorer.score(output: output, input: raw).speakerState, .dropped)
    }

    func testAxis4SaysNothingWhenNeitherSideHasOne() {
        let score = PolishFidelityScorer.score(
            output: "La réunion est décalée à quinze heures.",
            input: "alors la réunion elle est décalée à quinze heures"
        )
        XCTAssertEqual(score.speakerState, .absent)
        XCTAssertFalse(score.closesOnSpeakerState)
    }

    /// The prompt's own line is the thing that leaks, so the detector has to match it
    /// verbatim. If `SmartModeStructuredPrompt`'s worked example is ever reworded, this
    /// test is the one that says the detector no longer covers it.
    func testAxis4MatchesThePromptsOwnWorkedExampleLine() {
        XCTAssertTrue(PolishSpeakerState.occurs(in: "Il y avait un autre truc, mais ça m'échappe."),
                      "SmartModeStructuredPrompt.swift's first worked example ends on this line, "
                      + "and #581 measured it reaching a user's output verbatim")
    }

    // MARK: - Axis 1, proposition recall

    /// The device deletion #570's first comment opens on. The sentence that carries the
    /// passage's point is gone from the output, negation included, and no shipped check
    /// can see it: deleting raises no length ratio, invents no name, and lowers no
    /// per-segment overlap on the segments that remain.
    func testAxis1FlagsTheDeviceDeletion() throws {
        let work = try deviceCase("D1-three-steps")
        let score = PolishFidelityScorer.score(output: work.output, input: work.raw)

        XCTAssertTrue(
            score.unrecalled.contains { $0.text.contains("ne coûtent pas du tout le même prix en calcul") },
            "expected the deleted proposition among \(score.unrecalled.map(\.text))"
        )
    }

    /// A pure reformulation must not read as a deletion: the mode is licensed to
    /// rewrite (#523, decision 3) and a bench that flagged every rewrite would be
    /// measuring the licence rather than fidelity.
    func testAxis1DoesNotFlagAFaithfulRewrite() {
        let raw = "alors euh le micro il enregistre le son et le système il découpe en petits morceaux"
        let output = "Le micro enregistre le son et le système découpe en petits morceaux."

        XCTAssertTrue(PolishFidelityScorer.score(output: output, input: raw).unrecalled.isEmpty)
    }

    /// A proposition whose words survive but are split across two output clauses has
    /// not been lost. `dispersed` is reported and never scored, because splitting a
    /// clause is rule 1 doing exactly what it was licensed to do.
    func testAxis1SeparatesDispersalFromDeletion() {
        let raw = "il faut que je rappelle le plombier pour le chauffe-eau et que je commande le bois avant l'hiver"
        let output = "Il faut que je rappelle le plombier. C'est pour le chauffe-eau. "
            + "Il faut aussi que je commande le bois. C'est avant l'hiver."
        let score = PolishFidelityScorer.score(output: output, input: raw)

        XCTAssertTrue(score.unrecalled.isEmpty, "every word is present; nothing was deleted")
    }

    /// A clause of nothing but function words is excluded rather than scored, so a
    /// spoken `Et donc.` and a deleted sentence never land in the same column.
    func testAxis1ExcludesAClauseWithNoContentWord() {
        let raw = "Et donc. Il faut que je rappelle le plombier."
        let score = PolishFidelityScorer.score(output: "Il faut que je rappelle le plombier.", input: raw)

        XCTAssertTrue(score.unrecalled.isEmpty, "got \(score.unrecalled.map(\.text))")
        XCTAssertLessThan(score.judgeablePropositions,
                          PolishPropositionCut.propositions(of: raw).count,
                          "`Et donc.` must be in the denominator of nothing")
    }

    // MARK: - Axis 2, person and stance

    /// The device defect #523's decision 5 measured 28/28 on the Mac corpus and the
    /// phone broke. A document-level person count cannot see it — the rest of that
    /// output is full of `je`.
    func testAxis2FlagsTheDevicePersonLoss() throws {
        let work = try deviceCase("D4-logs-polish")
        let score = PolishFidelityScorer.score(output: work.output, input: work.raw)

        XCTAssertTrue(
            score.stanceMisses.contains {
                $0.kind == .personLost && $0.input.contains("j'en ai fait une dizaine")
            },
            "expected `j'en ai fait une dizaine` -> `il y a une dizaine qui ont été créées`"
        )
    }

    /// The brief's own example of a stance edit: `assez surpris` is not `surpris`.
    func testAxis2FlagsTheDeviceHedgeLoss() throws {
        let work = try deviceCase("D4-logs-polish")
        let score = PolishFidelityScorer.score(output: work.output, input: work.raw)

        XCTAssertTrue(
            score.stanceMisses.contains { $0.kind == .hedgeLost && $0.input.contains("assez surpris") },
            "expected `je suis assez surpris` -> `je suis surpris`"
        )
    }

    /// The concessive-to-confirmatory move, which is why there are two lexicons rather
    /// than one: a hedge going missing and a booster arriving are different edits, and
    /// the second is the one that changes what the sentence claims.
    func testAxis2FlagsAHardenedStance() {
        let raw = "il coupe quand même pas mal de mots dans les transcriptions"
        let output = "Il enlève effectivement beaucoup de mots dans les transcriptions."
        let kinds = Set(PolishFidelityScorer.score(output: output, input: raw).stanceMisses.map(\.kind))

        XCTAssertTrue(kinds.contains(.stanceHardened))
        XCTAssertTrue(kinds.contains(.hedgeLost))
    }

    /// A booster the speaker already used is never counted as one the model added.
    /// `pas vraiment` is a hedge and it puts `vraiment` on the input side.
    func testAxis2DoesNotHardenOnABoosterTheSpeakerUsed() {
        let raw = "c'est vraiment pas naturel comme façon de parler"
        let output = "Ce n'est vraiment pas naturel comme façon de parler."

        XCTAssertFalse(PolishFidelityScorer.score(output: output, input: raw)
            .stanceMisses.contains { $0.kind == .stanceHardened })
    }

    /// The polarity observable, on the device output that carries one. `je ne sais pas
    /// pourquoi mais il enlève …` comes back without the speaker's admission.
    ///
    /// Reported, never scored: the brief names four axes and polarity is not one of
    /// them (`bars.md` §4). The second assertion is what keeps that true.
    func testAxis2ReportsADroppedNegation() throws {
        let work = try deviceCase("D4-logs-polish")
        let score = PolishFidelityScorer.score(output: work.output, input: work.raw)

        XCTAssertGreaterThan(score.negationDropped, 0)

        let onlyNegation = PolishFidelityScorer.score(
            output: "Il enlève beaucoup de mots dans les transcriptions.",
            input: "il enlève pas beaucoup de mots dans les transcriptions"
        )
        XCTAssertGreaterThan(onlyNegation.negationDropped, 0)
        XCTAssertFalse(onlyNegation.hasScoredDefect,
                       "a dropped negation must not, on its own, count as a scored defect — "
                       + "the brief names four axes and polarity is not one of them")
    }

    /// A MEASURED LIMIT, pinned so a later change surfaces it rather than discovering
    /// it again.
    ///
    /// #570's body opens on `c'est pas vraiment ma voix, c'est pas naturel` coming back
    /// as `ne reflètent pas vraiment ma voix, ce qui est naturel` — a negation dropped
    /// so the clause asserts the opposite. The bench does **not** flag it, and the
    /// reason is granularity rather than the lexicon: the output clause that reverses
    /// (`ce qui est naturel`) carries one content word, so the cut folds it into the
    /// clause before it, and that clause still carries the surviving `pas`.
    ///
    /// Cutting at one content word would catch it and was measured: it makes axis 3
    /// unusable (9 spurious inversions on `D1-three-steps`, where the device output
    /// reorders nothing) and costs axis 2 two true positives. `bars.md` §6.1 records
    /// that trade. What would fix it properly is a polarity check scoped to the
    /// SENTENCE rather than the clause, and that is not in this round's brief.
    func testAxis2MissesANegationInsideATooShortClause() {
        let score = PolishFidelityScorer.score(
            output: "Les autres tests ne reflètent pas vraiment ma voix, ce qui est naturel.",
            input: "les autres c'est pas vraiment ma voix, c'est pas naturel"
        )
        XCTAssertEqual(score.negationDropped, 0, "if this ever fires, the limit is gone — "
                       + "update findings.md and delete this test")
    }

    // MARK: - Axis 3, order

    /// The 65-character device run: 65 characters in, 66 out, the most innocent length
    /// ratio available, and the two ideas swapped. It is reported as a COUNT and called
    /// nothing, because #523's decision 3 ("reorder within a topic") and the prompt's
    /// rule 2 ("an idea never moves elsewhere") contradict each other and resolving
    /// that is Pierre's, not a measurement's.
    func testAxis3CountsTheDeviceSwapAndCallsItNothing() throws {
        let work = try deviceCase("D8-last-transcription")
        let score = PolishFidelityScorer.score(output: work.output, input: work.raw)

        XCTAssertEqual(score.inversions, 1)
        XCTAssertFalse(score.hasScoredDefect,
                       "order is an observable; an inversion must not make an output defective")
    }

    func testInversionsCountsBackwardPairs() {
        XCTAssertEqual(PolishFidelityScorer.inversions(in: [0, 1, 2]), 0)
        XCTAssertEqual(PolishFidelityScorer.inversions(in: [1, 0]), 1)
        XCTAssertEqual(PolishFidelityScorer.inversions(in: [2, 1, 0]), 3)
    }

    // MARK: - The cut

    /// The amendment recorded in `bars.md` §6.1: at three content words this sentence
    /// is one proposition and the device's swap is unrepresentable.
    func testTheCutSeparatesTheTwoClausesOfTheDeviceSwap() {
        let propositions = PolishPropositionCut.propositions(
            of: "Je te laisserai regarder, il s'agit de la dernière transcription."
        )
        XCTAssertEqual(propositions.count, 2, "got \(propositions.map(\.text))")
    }

    /// A tail too short to stand alone is folded back rather than left as a
    /// proposition nothing can recall.
    func testTheCutFoldsAShortTailBack() {
        let propositions = PolishPropositionCut.propositions(
            of: "Il faut que je rappelle le plombier pour le chauffe-eau, voilà."
        )
        XCTAssertEqual(propositions.count, 1, "got \(propositions.map(\.text))")
    }

    // MARK: - The committed corpus

    /// Every case in the corpus decodes and scores. Cheap, and it is what catches a
    /// corpus edit that breaks the file the whole calibration is read off.
    func testTheDeviceCorpusScores() throws {
        let cases = try deviceCorpus()
        XCTAssertEqual(cases.count, 9, "the nine Structuré runs of 2026-09-17")
        XCTAssertEqual(cases.count { !$0.accepted }, 3, "three refused on device")

        for work in cases {
            let score = PolishFidelityScorer.score(output: work.output, input: work.raw)
            XCTAssertGreaterThan(score.judgeablePropositions, 0, "\(work.id) has nothing to score")
        }
    }

    // MARK: - Reading the repo

    /// One hand-labelled device output. Mirrors the harness's `FidelityCase`, which
    /// lives in a macOS-only executable target a test cannot import (#301).
    private struct DeviceCase: Decodable {
        let id: String
        let accepted: Bool
        let labels: [String]
        let raw: String
        let output: String
    }

    /// Reached through `#filePath` rather than copied into test resources, for the
    /// reason `DictationErrorCopyTests` gives: a copy is a second source of truth and
    /// the calibration would then be read off a file nobody updates.
    private func deviceCorpus() throws -> [DeviceCase] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DictusCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // DictusCore
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("docs/research/570-structured-fidelity/device-corpus.json")
        return try JSONDecoder().decode([DeviceCase].self, from: try Data(contentsOf: url))
    }

    private func deviceCase(_ id: String) throws -> DeviceCase {
        guard let work = try deviceCorpus().first(where: { $0.id == id }) else {
            XCTFail("no case \(id) in device-corpus.json")
            throw CocoaError(.fileNoSuchFile)
        }
        return work
    }
}
