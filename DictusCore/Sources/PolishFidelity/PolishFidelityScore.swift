// DictusCore/Sources/PolishFidelity/PolishFidelityScore.swift
// The four axes of the #570 / #581 fidelity bench, scored over one output.
import Foundation
import DictusCore

/// One input proposition that did not survive, with enough text to be argued with.
///
/// Carried rather than counted because axis 1 is a **screen, not a verdict**: the mode
/// is licensed to drop dead weight (#523, decision 4) and to reformulate (decision 3),
/// so a low recall may be a deleted idea, a paraphrase, or a filler correctly cut, and
/// content-word overlap cannot tell the three apart. A count alone would have to be
/// believed. A count with its text can be read.
public struct PolishRecallMiss: Equatable, Sendable {
    public let text: String
    public let wholeRecall: Double
    public let bestRecall: Double
}

/// One aligned pair where the speaker's person or stance did not survive.
public struct PolishStanceMiss: Equatable, Sendable {

    public enum Kind: String, Equatable, Sendable {
        /// The input proposition is in the first person and its aligned output
        /// proposition is not. #523's decision 5, which the device broke.
        case personLost
        /// A hedge in, no hedge out.
        case hedgeLost
        /// A booster out that was not in. The concessive-to-confirmatory move.
        case stanceHardened
        /// A negation in, none out. Reported, never scored — `bars.md` §4.
        case negationDropped
    }

    public let kind: Kind
    public let input: String
    public let output: String
}

/// Everything the bench knows about one output.
public struct PolishFidelityScore: Equatable, Sendable {

    // MARK: Axis 1 — proposition recall

    /// Input propositions carrying at least one content word. Every axis-1 ratio's
    /// denominator.
    public let judgeablePropositions: Int
    public let unrecalled: [PolishRecallMiss]
    /// Words survive, no single output clause carries the proposition. Observable.
    public let dispersed: Int

    // MARK: Axis 2 — person and stance

    /// Aligned pairs the axis could be asked about: `bestRecall >= floor`. An
    /// unaligned proposition is axis 1's finding and must not be counted twice.
    public let alignedPairs: Int
    public let stanceMisses: [PolishStanceMiss]

    // MARK: Axis 3 — order (observable)

    /// Pairs of input propositions whose aligned output positions run backwards.
    /// **Never a defect** — #523's decision 3 and the prompt's rule 2 contradict each
    /// other and resolving that is Pierre's, not a measurement's (`bars.md` §1).
    public let inversions: Int
    /// The denominator inversions would be counted against if anyone wanted a rate.
    public let comparablePairs: Int

    // MARK: Axis 4 — speaker-state fabrication

    public let speakerState: PolishSpeakerStateVerdict
    /// Whether the *last* sentence carries the phrasing. #581's shape.
    public let closesOnSpeakerState: Bool

    // MARK: Read-outs

    public var personLost: Int { stanceMisses.count { $0.kind == .personLost } }
    public var hedgeLost: Int { stanceMisses.count { $0.kind == .hedgeLost } }
    public var stanceHardened: Int { stanceMisses.count { $0.kind == .stanceHardened } }
    public var negationDropped: Int { stanceMisses.count { $0.kind == .negationDropped } }

    /// Whether this output carries a defect on one of the three **scored** axes.
    ///
    /// Axis 3 is not in it, and neither is `negationDropped`: both are observables by
    /// declaration, and folding an observable into a defect count is how a bench
    /// pre-empts a decision it was told not to pre-empt.
    public var hasScoredDefect: Bool {
        !unrecalled.isEmpty
            || personLost > 0 || hedgeLost > 0 || stanceHardened > 0
            || speakerState == .fabricated || speakerState == .dropped
    }
}

/// Scoring an output against the input it came from.
public enum PolishFidelityScorer {

    /// The recall floor, calibrated on hand-labelled device outputs rather than
    /// chosen — `bars.md` §6 declares the sweep and `findings.md` prints the table it
    /// was read off.
    ///
    /// **It is the bench's threshold and not a product threshold.** Nothing in the
    /// app reads it. It decides which propositions a human is asked to look at, and
    /// #466 is the standing reminder of what happens when a threshold picked on
    /// reasoning meets real text: 10 legitimate repairs of 10 refused, at every value
    /// swept.
    public static let defaultFloor = 0.35

    /// Score `output` against `input`.
    ///
    /// The caller decides which text this is. The bench passes the **engine's**
    /// output, not the text that reached the document: a Smart Mode that fails its
    /// contract inserts nothing, so scoring the inserted text would score three of the
    /// nine device runs as defect-free — and one of those three is #581's positive
    /// control, whose only defect lives in the refused output. The guardrail verdict
    /// is reported beside the score, never folded into it.
    public static func score(output: String,
                             input: String,
                             floor: Double = defaultFloor) -> PolishFidelityScore {
        let alignments = PolishPropositionCut.align(input: input, output: output)
        let outputPropositions = PolishPropositionCut.propositions(of: output)
        // The booster check reads the WHOLE input, not the aligned clause. See
        // `stanceMisses(input:output:wholeInput:)`.
        let wholeInputWords = PolishLexicon.words(in: input)

        let judgeable = alignments.count { $0.proposition.isJudgeable }
        let unrecalled = alignments
            .filter { $0.isUnrecalled(floor: floor) }
            .map { PolishRecallMiss(text: $0.proposition.text,
                                    wholeRecall: $0.wholeRecall,
                                    bestRecall: $0.bestRecall) }
        let dispersed = alignments.count { $0.isDispersed(floor: floor) }

        // Axis 2 and axis 3 both read the aligned pairs, so they are resolved once.
        let aligned: [(PolishProposition, PolishProposition)] = alignments.compactMap { alignment in
            guard alignment.bestRecall >= floor,
                  let index = alignment.bestOutputIndex,
                  index < outputPropositions.count else { return nil }
            return (alignment.proposition, outputPropositions[index])
        }

        return PolishFidelityScore(
            judgeablePropositions: judgeable,
            unrecalled: unrecalled,
            dispersed: dispersed,
            alignedPairs: aligned.count,
            stanceMisses: aligned.flatMap {
                stanceMisses(input: $0.0, output: $0.1, wholeInput: wholeInputWords)
            },
            inversions: inversions(in: aligned.map { $0.1.index }),
            comparablePairs: max(0, aligned.count * (aligned.count - 1) / 2),
            speakerState: PolishSpeakerState.verdict(output: output, input: input),
            closesOnSpeakerState: PolishSpeakerState.closesOn(output)
        )
    }

    /// Axis 2 over one aligned pair.
    ///
    /// Every rule here is *present on the input side, absent on the output side*, and
    /// never the reverse — except `stanceHardened`, which is the one edit that damages
    /// by **adding**. The asymmetry is deliberate: a hedge the model adds makes the
    /// sentence claim less than the speaker did, which is a softening no user has ever
    /// complained about, while a booster it adds makes the sentence claim more.
    /// `wholeInput` is every word of the input, and only the booster check reads it.
    ///
    /// A short input clause aligns to whichever output clause carries most of its
    /// words, and that output clause is often much longer — so asking "is this booster
    /// new" against the input *clause* alone flags every intensifier the speaker used
    /// one clause earlier. Measured: `c'est pas vraiment ma voix, c'est pas naturel`
    /// against its rewrite reported a hardened stance on `vraiment`, a word the
    /// speaker had said himself. Against the whole input it reports nothing, and
    /// `effectivement` arriving where the speaker said `quand même` still does.
    ///
    /// Person is NOT widened the same way and must not be: the whole point of the
    /// device defect it exists for is that the rest of the output is full of `je`.
    static func stanceMisses(input: PolishProposition,
                             output: PolishProposition,
                             wholeInput: [String]) -> [PolishStanceMiss] {
        var misses: [PolishStanceMiss] = []

        func lost(_ kind: PolishStanceMiss.Kind) {
            misses.append(PolishStanceMiss(kind: kind, input: input.text, output: output.text))
        }

        let inPerson = PolishStanceLexicon.occurrences(of: PolishStanceLexicon.firstPerson, in: input.allWords)
        let outPerson = PolishStanceLexicon.occurrences(of: PolishStanceLexicon.firstPerson, in: output.allWords)
        if inPerson > 0, outPerson == 0 { lost(.personLost) }

        let inHedge = PolishStanceLexicon.occurrences(of: PolishStanceLexicon.hedges, in: input.allWords)
        let outHedge = PolishStanceLexicon.occurrences(of: PolishStanceLexicon.hedges, in: output.allWords)
        if inHedge > 0, outHedge == 0 { lost(.hedgeLost) }

        let inBooster = PolishStanceLexicon.occurrences(of: PolishStanceLexicon.boosters, in: wholeInput)
        let outBooster = PolishStanceLexicon.occurrences(of: PolishStanceLexicon.boosters, in: output.allWords)
        if inBooster == 0, outBooster > 0 { lost(.stanceHardened) }

        // Strictly fewer, where person and hedge ask for NONE left. The asymmetry is
        // the difference between a marker and a truth condition: a clause can carry
        // two hedges, lose one and still hedge, so only the last one going says the
        // stance moved — while every negation is a polarity, and losing one flips the
        // proposition it was in. #570's own opening example is the proof: `c'est pas
        // vraiment ma voix, c'est pas naturel` -> `ne reflètent pas vraiment ma voix,
        // ce qui est naturel` keeps one `pas` and reverses the second clause, so a
        // rule asking for zero left would miss the defect the issue is titled after.
        //
        // It over-flags a legitimate merge (`pas de problème, pas du tout` -> `aucun
        // problème`), and that is affordable here and nowhere else: this is an
        // OBSERVABLE (`bars.md` §4), every hit is printed with both texts, and a
        // reader decides. It is in no bar and in no `hasScoredDefect`.
        let inNegation = PolishStanceLexicon.occurrences(of: PolishStanceLexicon.negations, in: input.allWords)
        let outNegation = PolishStanceLexicon.occurrences(of: PolishStanceLexicon.negations, in: output.allWords)
        if inNegation > 0, outNegation < inNegation { lost(.negationDropped) }

        return misses
    }

    /// Axis 3: pairs `(i < j)` whose aligned output positions run backwards.
    ///
    /// The plain quadratic count rather than a rank correlation, because the number
    /// has to be readable in a committed capture: "1 inversion" is a sentence a human
    /// can check against the two clauses, and a tau of -0.33 is not. The corpus is nine
    /// dictations of at most a few dozen propositions, so the cost is nothing.
    static func inversions(in indices: [Int]) -> Int {
        var count = 0
        for i in indices.indices {
            for j in indices.indices where j > i && indices[i] > indices[j] {
                count += 1
            }
        }
        return count
    }
}
