// DictusCore/Sources/PolishFidelity/PolishProposition.swift
// The unit the fidelity bench aligns, and the alignment itself (#570).
import Foundation
import DictusCore

/// One content proposition: a clause, with the content words a comparison is made of.
///
/// ### Why a clause and not a sentence
///
/// `Je te laisserai regarder, il s'agit de la dernière transcription.` is one
/// sentence carrying two ideas, and the device defect of 2026-09-17 14:47:31 is
/// *between* them — the output returns both, swapped. A sentence-level cut sees one
/// unit in and two units out and has nothing to say about the swap. Every axis this
/// bench scores therefore reads clauses.
public struct PolishProposition: Equatable, Sendable {

    /// The clause as it reads, separator included, for the capture a human reads.
    public let text: String

    /// Position in the text it was cut from, 0-based. Axis 3 is the comparison of two
    /// of these sequences and nothing else.
    public let index: Int

    /// Index of the sentence this clause came from, so a report can say "two clauses
    /// of one sentence" rather than implying the input had two sentences.
    public let sentenceIndex: Int

    /// The clause's words with the four supported languages' function words removed,
    /// folded, in order. Taken from `PolishGrounding.contentWords` and never from a
    /// second tokeniser — see that method's doc comment for why the bench borrows the
    /// guardrail's word set rather than defining its own.
    public let contentWords: [String]

    /// Every word, folded, in order — function words included.
    ///
    /// Separate from `contentWords` because axis 2 asks about words the content list
    /// deliberately throws away: `je`, `ne`, `pas`, `we`, `not` are all function words,
    /// and they are exactly what a person, a hedge and a negation are made of.
    public let allWords: [String]

    /// Whether a recall can be taken on this clause at all.
    ///
    /// A clause with no content word can only score 0 or 1, and scoring it would put
    /// `Voilà.` and a deleted sentence in the same column. It is excluded from axis 1
    /// and counted separately, the same way `PolishSegmentOverlapThresholds` lets a
    /// segment under three content words pass untested.
    public var isJudgeable: Bool { !contentWords.isEmpty }
}

/// Cutting a text into propositions, and aligning two such cuts.
///
/// Deterministic and model-free, like `guardrail` and `target` and for the same
/// reason: a number that decides whether a prompt changes has to be re-runnable by
/// anyone, on a machine with Apple Intelligence off.
public enum PolishPropositionCut {

    /// Fewest content words a clause must carry before the cut will make it one.
    ///
    /// Three, which is `PolishSegmentOverlapThresholds.default.minimumContentWords`,
    /// taken from there rather than chosen here: below three a unit can only score
    /// 0, 0.33, 0.67 or 1, so a single unmatched word decides a whole verdict. The
    /// two checks measure opposite directions over the same text and there is no
    /// reading under which they should disagree about how small a unit is too small.
    public static let minimumContentWords = PolishSegmentOverlapThresholds.default.minimumContentWords

    /// Separators a sentence may be cut at. Not `.` — that is the sentence cut's job,
    /// and `NLTokenizer` already knows not to cut on an abbreviation or a decimal.
    private static let clauseSeparators: Set<Character> = [",", ";", ":"]

    /// The text's propositions, in order.
    ///
    /// Sentences first (`PolishSegmentation.sentences`, the same `NLTokenizer` cut
    /// #456 uses on an input), then each sentence at its commas, semicolons and
    /// colons — and **only** where both sides of the cut carry at least
    /// `minimumContentWords`. A sentence that cannot be cut that way stays whole,
    /// which is the common case for a short one.
    public static func propositions(of text: String) -> [PolishProposition] {
        var result: [PolishProposition] = []
        for (sentenceIndex, sentence) in PolishSegmentation.sentences(of: text).enumerated() {
            for clause in clauses(in: sentence) {
                result.append(PolishProposition(
                    text: clause,
                    index: result.count,
                    sentenceIndex: sentenceIndex,
                    contentWords: PolishGrounding.contentWords(in: clause),
                    allWords: PolishLexicon.words(in: clause)
                ))
            }
        }
        return result
    }

    /// One sentence's clauses.
    ///
    /// The sentence is first broken at every separator into *atoms*, each keeping the
    /// separator that ended it so the clause still reads. The atoms are then merged
    /// left to right until each group clears `minimumContentWords`, and a trailing
    /// group that never clears it is folded back into the one before it.
    ///
    /// Merging rather than cutting is what makes the threshold a floor on both sides
    /// at once. A rule that cut at every separator carrying three content words to
    /// its left would happily leave `, voilà.` standing alone on the right, and that
    /// two-word tail would then read as an unrecalled proposition on every output
    /// that legitimately absorbed it.
    static func clauses(in sentence: String) -> [String] {
        let atoms = atomise(sentence)
        guard atoms.count > 1 else { return atoms }

        var groups: [String] = []
        var current = ""
        for atom in atoms {
            current += atom
            if PolishGrounding.contentWords(in: current).count >= minimumContentWords {
                groups.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            // The tail never reached the floor. It belongs to the clause before it —
            // there is no reading under which `, voilà.` is a proposition of its own.
            if groups.isEmpty {
                groups.append(current)
            } else {
                groups[groups.count - 1] += current
            }
        }
        return groups.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// The sentence split at its separators, each piece keeping the separator that
    /// ended it.
    private static func atomise(_ sentence: String) -> [String] {
        var atoms: [String] = []
        var buffer = ""
        for character in sentence {
            buffer.append(character)
            if clauseSeparators.contains(character) {
                atoms.append(buffer)
                buffer = ""
            }
        }
        if !buffer.isEmpty { atoms.append(buffer) }
        return atoms.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}

/// What one input proposition found in the output.
public struct PolishPropositionAlignment: Equatable, Sendable {

    public let proposition: PolishProposition

    /// Share of this proposition's content words found **anywhere** in the output.
    ///
    /// The axis-1 reading. Deliberately the forgiving one: a proposition the model
    /// split across two output clauses has not been lost, and a recall taken clause
    /// by clause would call it lost.
    public let wholeRecall: Double

    /// The highest share found in any single output proposition.
    public let bestRecall: Double

    /// Which output proposition scored `bestRecall`, or nil when the output has none
    /// to score. The axis-3 reading, and the pairing axis 2 is taken over.
    public let bestOutputIndex: Int?

    /// `wholeRecall` clears the floor but `bestRecall` does not: the words survive,
    /// no single output clause carries the proposition. Reported, never scored —
    /// splitting a clause is rule 1 doing exactly what #523 licensed.
    public func isDispersed(floor: Double) -> Bool {
        wholeRecall >= floor && bestRecall < floor
    }

    /// Nothing in the output supports this proposition. Axis 1's finding, and the one
    /// no shipped check can reach: deleting raises no length ratio, invents no name,
    /// and lowers no per-segment overlap on the segments that remain.
    public func isUnrecalled(floor: Double) -> Bool {
        proposition.isJudgeable && wholeRecall < floor
    }
}

extension PolishPropositionCut {

    /// Align every proposition of `input` against the propositions of `output`.
    ///
    /// ### This is #414's check run backwards
    ///
    /// `PolishGrounding.worstSegmentOverlap` asks, of each **output** segment, what
    /// share of its content words the input carries — precision, and it refuses a
    /// fabricated sentence. This asks, of each **input** proposition, what share of
    /// its content words the output carries — recall, and it sees a deleted one. They
    /// are the two halves of the same comparison and the pipeline only ever ran one.
    ///
    /// ### What a recall is not
    ///
    /// It is not a meaning comparison. `Structuré` is licensed to reformulate (#523,
    /// decision 3) and to drop dead weight (decision 4), so a low recall is *the model
    /// deleted an idea*, or *the model said it in other words*, or *the model correctly
    /// cut a filler*, and content-word overlap cannot tell the three apart. That is why
    /// `PolishFidelityScore` prints every unrecalled proposition's text rather than only
    /// its count: the number is a screen for a human read, never a verdict.
    public static func align(input: String, output: String) -> [PolishPropositionAlignment] {
        let inputPropositions = propositions(of: input)
        let outputPropositions = propositions(of: output)
        let everything = Set(outputPropositions.flatMap(\.contentWords))

        return inputPropositions.map { proposition in
            let wanted = Set(proposition.contentWords)
            guard !wanted.isEmpty else {
                // Nothing to recall. Scored 1 so it cannot read as a loss, and excluded
                // from every denominator by `isJudgeable`.
                return PolishPropositionAlignment(
                    proposition: proposition, wholeRecall: 1, bestRecall: 1,
                    bestOutputIndex: nil
                )
            }
            let whole = share(of: wanted, in: everything)
            var bestRecall = 0.0
            var bestIndex: Int?
            for candidate in outputPropositions {
                let found = share(of: wanted, in: Set(candidate.contentWords))
                if found > bestRecall {
                    bestRecall = found
                    bestIndex = candidate.index
                }
            }
            return PolishPropositionAlignment(
                proposition: proposition, wholeRecall: whole,
                bestRecall: bestRecall, bestOutputIndex: bestIndex
            )
        }
    }

    /// Share of `wanted` present in `available`. Sets rather than multisets on both
    /// sides: a word the speaker said three times and the model wrote once has not
    /// been two-thirds lost.
    private static func share(of wanted: Set<String>, in available: Set<String>) -> Double {
        guard !wanted.isEmpty else { return 1 }
        return Double(wanted.count { available.contains($0) }) / Double(wanted.count)
    }
}
