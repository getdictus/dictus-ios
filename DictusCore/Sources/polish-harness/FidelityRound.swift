// DictusCore/Sources/polish-harness/FidelityRound.swift
//
// The #570 / #581 fidelity round. Scores `Structuré` outputs on the four axes
// declared in `docs/research/570-structured-fidelity/bars.md` before the first arm
// call: proposition recall, person and stance, order, and speaker-state fabrication.
//
// Two modes, and the split is the point.
//
//   `--replay <corpus.json>`  scores committed, hand-labelled outputs and drives NO
//                             model. That is how the recall floor is calibrated, and
//                             it is what makes the number behind it re-runnable by
//                             anyone — the same reason `guardrail` drives no model.
//   (no flag)                 runs the real pipeline over fixtures, three times each,
//                             on the shipping prompt plus every `--arm`.
//
// WHY the scorers are not in this file. They live in the `PolishFidelity` library so
// `swift test` can pin them: axis 4 has a positive and a negative control and a
// scorer nobody can test is a scorer nobody should believe. This file is the driver
// and the report, nothing else.
//
// WHY every axis reads the ENGINE's output and not the inserted text. A Smart Mode
// that fails its contract inserts nothing, so scoring what reached the document would
// score three of the nine device runs as defect-free — and one of those three is
// #581's positive control, whose only defect is in the refused output. The guardrail
// verdict is printed beside each run and never folded into it: a refusal and a
// fidelity defect are different findings, the same rule #550's round follows about
// parse failures.
//
// Lives in the `polish-harness` target only — macOS-only, excluded from every app
// target and from CI.

#if os(macOS)
import Foundation
import DictusCore
import PolishFidelity

// MARK: - The replay corpus

/// One hand-labelled output, committed with the input it came from.
///
/// Labels are in the JSON rather than in code for the reason
/// `docs/research/413-414-guardrail/` gives: they are judgements, and a judgement
/// that decides a threshold has to be disagreeable with in the open.
struct FidelityCase: Decodable {
    let id: String
    let source: String
    let timestamp: String?
    let lang: String
    /// Whether the device pipeline accepted the output. A refusal keeps its engine
    /// output here, which is what makes the case scoreable.
    let accepted: Bool
    let outcome: String?
    /// The defect names read off #570's comments. Never produced by the bench.
    let labels: [String]
    let note: String?
    let raw: String
    let output: String
}

enum FidelityCorpus {
    static func load(_ paths: [String]) -> [FidelityCase] {
        var all: [FidelityCase] = []
        for path in paths {
            guard let data = FileManager.default.contents(atPath: path) else {
                print("error: cannot read corpus at \(path)")
                exit(1)
            }
            do {
                all += try JSONDecoder().decode([FidelityCase].self, from: data)
            } catch {
                print("error: cannot decode corpus at \(path): \(error)")
                exit(1)
            }
        }
        return all
    }
}

// MARK: - One scored run

/// One output with its four axes and everything needed to argue with them.
struct FidelityRun {
    let fixture: String
    /// `shipping`, or the basename of the `--arm` prompt file.
    let arm: String
    let run: Int
    let milliseconds: Int
    let rawCharacters: Int
    let outputCharacters: Int
    /// `PolishMetrics.Outcome` raw value, or `replay` when no pipeline ran.
    let outcome: String
    /// Which of the five checks refused, when one did.
    let rejectedCheck: String?
    /// Hand labels, on a replay case. Empty on a live run.
    let labels: [String]
    let score: PolishFidelityScore
    /// What was scored, committed verbatim.
    let output: String
}

// MARK: - The round

enum FidelityRound {

    /// The floor sweep grid declared in `bars.md` §6: 0.10 to 0.60 in steps of 0.05.
    ///
    /// Built from integers rather than `stride(from: 0.10, through: 0.60, by: 0.05)`,
    /// which accumulates to 0.6000000000000001 on the last step and silently drops the
    /// top of the declared grid. A sweep that quietly sweeps a narrower range than the
    /// plan says it does is the same class of defect `numericOption` exists to prevent.
    static let sweepGrid: [Double] = (2...12).map { Double($0) * 0.05 }

    // MARK: Replay

    /// Score committed outputs. Drives no model.
    static func replay(_ cases: [FidelityCase], floor: Double, sweep: Bool) -> [FidelityRun] {
        let runs = cases.map { work in
            FidelityRun(
                fixture: work.id, arm: "device", run: 1, milliseconds: 0,
                rawCharacters: work.raw.count, outputCharacters: work.output.count,
                outcome: work.outcome ?? (work.accepted ? "success" : "rejectedGuardrail"),
                rejectedCheck: nil, labels: work.labels,
                score: PolishFidelityScorer.score(output: work.output, input: work.raw, floor: floor),
                output: work.output
            )
        }
        if sweep { printSweep(cases) }
        return runs
    }

    /// The floor sweep, held against the hand labels.
    ///
    /// Two columns, and the round is only worth running if they separate. `caught` is
    /// how many outputs labelled with a deletion the floor flags; `otherFlags` is how
    /// many propositions it calls unrecalled on outputs carrying **no** deletion label.
    /// If no floor separates them, `findings.md` says so rather than picking one —
    /// #414's own floor did not separate cleanly and that fact is written down instead
    /// of averaged away.
    static func printSweep(_ cases: [FidelityCase]) {
        let deletions = Set(["propositionDeleted"])
        print("\n════ AXIS 1 FLOOR SWEEP (bars.md §6) — hand labels vs the screen\n")
        print(pad("floor", 8) + pad("caught", 26) + pad("otherFlags", 14) + "flagged outputs")
        for floor in sweepGrid {
            var caught = 0
            var labelled = 0
            var otherFlags = 0
            var flagged: [String] = []
            for work in cases {
                let score = PolishFidelityScorer.score(output: work.output, input: work.raw, floor: floor)
                let isLabelled = !Set(work.labels).isDisjoint(with: deletions)
                if isLabelled { labelled += 1 }
                if score.unrecalled.isEmpty { continue }
                flagged.append("\(work.id)×\(score.unrecalled.count)")
                if isLabelled { caught += 1 } else { otherFlags += score.unrecalled.count }
            }
            print(pad(String(format: "%.2f", floor), 8)
                  + pad("\(caught)/\(labelled) labelled deletions", 26)
                  + pad("\(otherFlags)", 14)
                  + flagged.joined(separator: ", "))
        }
        print("\n  caught     = outputs labelled `propositionDeleted` in which the screen flags something.")
        print("  otherFlags = propositions flagged on outputs carrying NO deletion label. Not")
        print("               necessarily errors — the mode may legitimately drop dead weight")
        print("               (#523 decision 4) — which is why every flagged text is printed below.")
    }

    // MARK: Reporting

    /// One line per run, greppable in a committed capture rather than pretty.
    static func verdict(_ result: FidelityRun) -> String {
        let score = result.score
        var parts = ["\(result.rawCharacters)→\(result.outputCharacters)"]
        if result.milliseconds > 0 { parts.append("\(result.milliseconds)ms") }
        parts.append(result.outcome + (result.rejectedCheck.map { "(\($0))" } ?? ""))
        parts.append("recall=\(score.judgeablePropositions - score.unrecalled.count)/\(score.judgeablePropositions)")
        if !score.unrecalled.isEmpty { parts.append("UNRECALLED=\(score.unrecalled.count)") }
        if score.dispersed > 0 { parts.append("dispersed=\(score.dispersed)") }
        if score.personLost > 0 { parts.append("PERSON-LOST=\(score.personLost)") }
        if score.hedgeLost > 0 { parts.append("HEDGE-LOST=\(score.hedgeLost)") }
        if score.stanceHardened > 0 { parts.append("STANCE-HARDENED=\(score.stanceHardened)") }
        if score.negationDropped > 0 { parts.append("negationDropped=\(score.negationDropped)") }
        parts.append("inversions=\(score.inversions)/\(score.comparablePairs)")
        switch score.speakerState {
        case .fabricated: parts.append("SPEAKER-STATE-FABRICATED" + (score.closesOnSpeakerState ? "(closing)" : "(body)"))
        case .dropped: parts.append("SPEAKER-STATE-DROPPED")
        case .preserved: parts.append("speakerState=preserved")
        case .absent: break
        }
        return parts.joined(separator: " ")
    }

    /// Everything a human has to read to disagree with the numbers above.
    static func detail(_ result: FidelityRun) {
        for miss in result.score.unrecalled {
            print(String(format: "     UNRECALLED (whole %.2f, best %.2f): %@",
                         miss.wholeRecall, miss.bestRecall, miss.text))
        }
        for miss in result.score.stanceMisses {
            print("     \(miss.kind.rawValue.uppercased()): \(miss.input)")
            print("       → \(miss.output)")
        }
    }

    /// The bar table, per arm, over every run of the round.
    ///
    /// Per fixture and never pooled where it matters, for the reason #437's
    /// per-fixture table is the readable half of its findings: a defect concentrated
    /// on one input is a different finding from one spread evenly.
    static func summary(_ all: [FidelityRun], arms: [String]) {
        print("\n\n════ AXES, per arm (bars.md §4)\n")
        print(pad("arm", 22) + pad("outputs", 9)
              + ["unrecalled", "personLost", "hedgeLost", "hardened", "fabricated", "dropped", "clean"]
                  .map { pad($0, 12) }.joined())
        for arm in arms {
            let rows = all.filter { $0.arm == arm }
            guard !rows.isEmpty else { continue }
            let cells = [
                "\(rows.count { !$0.score.unrecalled.isEmpty })/\(rows.count)",
                "\(rows.count { $0.score.personLost > 0 })/\(rows.count)",
                "\(rows.count { $0.score.hedgeLost > 0 })/\(rows.count)",
                "\(rows.count { $0.score.stanceHardened > 0 })/\(rows.count)",
                "\(rows.count { $0.score.speakerState == .fabricated })/\(rows.count)",
                "\(rows.count { $0.score.speakerState == .dropped })/\(rows.count)",
                "\(rows.count { !$0.score.hasScoredDefect })/\(rows.count)"
            ]
            print(pad(arm, 22) + pad("\(rows.count)", 9) + cells.map { pad($0, 12) }.joined())
        }
        print("\n  Counts are OUTPUTS carrying at least one, not occurrences.")
        print("  `clean` = no defect on any of the three SCORED axes. Axis 3 and the negation")
        print("  count are observables by declaration (bars.md §1, §4) and are in no column here.")

        print("\n\n════ OBSERVABLES, per arm — reported, never barred\n")
        print(pad("arm", 22) + pad("inversions", 14) + pad("dispersed", 14) + pad("negDropped", 14) + "speakerState preserved")
        for arm in arms {
            let rows = all.filter { $0.arm == arm }
            guard !rows.isEmpty else { continue }
            print(pad(arm, 22)
                  + pad("\(rows.reduce(0) { $0 + $1.score.inversions })", 14)
                  + pad("\(rows.reduce(0) { $0 + $1.score.dispersed })", 14)
                  + pad("\(rows.count { $0.score.negationDropped > 0 })/\(rows.count)", 14)
                  + "\(rows.count { $0.score.speakerState == .preserved })/\(rows.count)")
        }

        print("\n\n════ PER FIXTURE, per arm (never pooled)\n")
        for arm in arms {
            let rows = all.filter { $0.arm == arm }
            guard !rows.isEmpty else { continue }
            print("── \(arm)")
            for fixture in orderedFixtures(rows) {
                let runs = rows.filter { $0.fixture == fixture }.sorted { $0.run < $1.run }
                let cells = runs.map { run -> String in
                    var flags = ""
                    if !run.score.unrecalled.isEmpty { flags += "U\(run.score.unrecalled.count)" }
                    if run.score.personLost > 0 { flags += "P" }
                    if run.score.hedgeLost > 0 { flags += "H" }
                    if run.score.stanceHardened > 0 { flags += "B" }
                    if run.score.speakerState == .fabricated { flags += "F" }
                    if run.score.speakerState == .dropped { flags += "D" }
                    if run.score.inversions > 0 { flags += "o\(run.score.inversions)" }
                    return flags.isEmpty ? "·" : flags
                }
                print("   " + pad(fixture, 24) + cells.joined(separator: "  "))
            }
        }
        print("\n   U<n> unrecalled propositions · P person lost · H hedge lost · B stance hardened")
        print("   F speaker-state fabricated · D speaker-state dropped · o<n> order inversions")
        print("   · no defect and no observable. Order is an OBSERVABLE: `o` is not a defect.")
    }

    /// Where the bench and the hand labels agree, and where they do not.
    ///
    /// ### Why this table decides whether any other number here is worth reading
    ///
    /// The labels are Pierre's reading of the device outputs, transcribed from #570's
    /// two comments before the scorer existed. They are the only ground truth this
    /// round has. A bench that flags nothing on an output he read as damaged is
    /// measuring its own lexicon; one that flags everything is a coin. Both failures
    /// are invisible in the per-arm table above, which is why the disagreements are
    /// printed by name rather than summarised into an accuracy.
    ///
    /// It is an **agreement** table and not a confusion matrix on purpose: a label and
    /// an axis are not the same object. `registerDropped` (a lost *"s'il te plaît"*) is
    /// a real defect with no axis in the brief, and it must show up here as a miss the
    /// bench cannot see rather than be quietly dropped from the denominator.
    static func labelAgreement(_ all: [FidelityRun]) {
        print("\n\n════ BENCH vs HAND LABELS (#570's two comments of 2026-09-17)\n")
        print(pad("fixture", 24) + pad("hand labels", 46) + "bench")
        for result in all {
            var found: [String] = []
            if !result.score.unrecalled.isEmpty { found.append("unrecalled×\(result.score.unrecalled.count)") }
            if result.score.personLost > 0 { found.append("personLost×\(result.score.personLost)") }
            if result.score.hedgeLost > 0 { found.append("hedgeLost×\(result.score.hedgeLost)") }
            if result.score.stanceHardened > 0 { found.append("hardened×\(result.score.stanceHardened)") }
            if result.score.negationDropped > 0 { found.append("negDropped×\(result.score.negationDropped)") }
            if result.score.inversions > 0 { found.append("inversions=\(result.score.inversions)") }
            if result.score.speakerState != .absent { found.append("speakerState=\(result.score.speakerState.rawValue)") }
            let labels = result.labels.isEmpty ? "—" : result.labels.joined(separator: ", ")
            print(pad(result.fixture, 24) + pad(labels, 46) + (found.isEmpty ? "— nothing" : found.joined(separator: ", ")))
        }
        print("\n  A label with no bench column is a defect class the four axes do not cover.")
        print("  A bench column with no label is either a real defect the hand read missed or a")
        print("  false flag, and only reading the printed text above tells them apart.")
    }

    /// Left-pad to a fixed column. `String(format: "%-20@")` does not honour a width
    /// for `%@` here, which silently produced an unreadable committed capture in #550.
    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }

    private static func orderedFixtures(_ rows: [FidelityRun]) -> [String] {
        var seen: Set<String> = []
        return rows.map(\.fixture).filter { seen.insert($0).inserted }
    }
}

// MARK: - The JSON sidecar

/// The shape committed next to the human capture, so a later analysis is a script over
/// data rather than a re-read of prose.
struct FidelityRunRecord: Encodable {
    let arm: String
    let fixture: String
    let run: Int
    let ms: Int
    let rawChars: Int
    let outputChars: Int
    let outcome: String
    let rejectedCheck: String?
    let labels: [String]
    let judgeablePropositions: Int
    let unrecalled: [String]
    let unrecalledWholeRecall: [Double]
    let dispersed: Int
    let alignedPairs: Int
    let personLost: Int
    let hedgeLost: Int
    let stanceHardened: Int
    let negationDropped: Int
    let inversions: Int
    let comparablePairs: Int
    let speakerState: String
    let closesOnSpeakerState: Bool
    let output: String

    init(_ run: FidelityRun) {
        arm = run.arm
        fixture = run.fixture
        self.run = run.run
        ms = run.milliseconds
        rawChars = run.rawCharacters
        outputChars = run.outputCharacters
        outcome = run.outcome
        rejectedCheck = run.rejectedCheck
        labels = run.labels
        judgeablePropositions = run.score.judgeablePropositions
        unrecalled = run.score.unrecalled.map(\.text)
        unrecalledWholeRecall = run.score.unrecalled.map(\.wholeRecall)
        dispersed = run.score.dispersed
        alignedPairs = run.score.alignedPairs
        personLost = run.score.personLost
        hedgeLost = run.score.hedgeLost
        stanceHardened = run.score.stanceHardened
        negationDropped = run.score.negationDropped
        inversions = run.score.inversions
        comparablePairs = run.score.comparablePairs
        speakerState = run.score.speakerState.rawValue
        closesOnSpeakerState = run.score.closesOnSpeakerState
        output = run.output
    }
}

// MARK: - Driving the live round

/// Run every arm over every fixture, `runs` times each, and print the capture that
/// gets committed under `docs/research/570-structured-fidelity/raw/`.
///
/// The baseline arm is always present and always first: every number here is read
/// against the shipping prompt, and an A/B with no A is not a measurement. `--arm`
/// adds a variant, which is a full system prompt in a file, run through
/// `--instructions` exactly as #523's rounds 5-10 ran theirs. **No arm lands** —
/// #414 measured what happens when a prompt edit is reasoned rather than benched.
/// What a round is run with, apart from the fixtures and the mode.
///
/// Grouped rather than passed loose for the reason `RunEvidence` is grouped: three of
/// these are numbers and paths with no type distinction between them, and a fixed
/// argument order is how the wrong one ends up in the wrong slot without a compiler
/// complaint.
struct FidelityRoundOptions {
    /// Prompt files, each a full system prompt run through `--instructions`. The
    /// shipping prompt is always the first arm and is not in this list.
    let armPaths: [String]
    let runs: Int
    let floor: Double
    let jsonOut: String?
}

@available(macOS 26.0, *)
func runFidelityRound(fixtures: [Fixture],
                      mode: SmartMode?,
                      options: FidelityRoundOptions) async {
    let (armPaths, runs, floor, jsonOut) = (options.armPaths, options.runs, options.floor, options.jsonOut)
    guard mode != nil else {
        print("error: fidelity needs --mode <id> (the axes are a Smart Mode's contract, "
              + "not the free polish's), e.g.\n"
              + "  swift run polish-harness fidelity Sources/polish-harness/fixtures/device-structured-fr.json "
              + "--mode structured --runs 3")
        exit(2)
    }
    // nil is the shipping prompt: `makeEngine(nil)` builds the engine with no
    // instructions override, which is the mode's own prompt.
    let arms: [(label: String, path: String?)] =
        [("shipping", nil)] + armPaths.map { (URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent, $0) }

    var all: [FidelityRun] = []
    for arm in arms {
        print("\n\n████ ARM \(arm.label) — \(runs) run(s) × \(fixtures.count) fixture(s), floor \(String(format: "%.2f", floor))")
        if let path = arm.path { print("     prompt: \(path)") }
        let engine = makeEngine(loadInstructions(arm.path))
        for fixture in fixtures {
            print("\n━━ [\(fixture.id)] \(fixture.raw.count) chars, lang=\(fixture.lang)")
            for index in 1...max(1, runs) {
                let outcome = await runOnce(fixture, engine: engine, mode: mode)
                // The ENGINE's output, not `final`. See this file's header.
                let scored = outcome.engineOutput ?? ""
                let result = FidelityRun(
                    fixture: fixture.id, arm: arm.label, run: index,
                    milliseconds: outcome.engineMs,
                    rawCharacters: fixture.raw.count, outputCharacters: scored.count,
                    outcome: outcome.outcome.rawValue,
                    rejectedCheck: outcome.rejectedCheck?.rawValue, labels: [],
                    score: PolishFidelityScorer.score(output: scored, input: fixture.raw, floor: floor),
                    output: scored
                )
                all.append(result)
                print("  #\(index) \(FidelityRound.verdict(result))")
                FidelityRound.detail(result)
                print("     engineOut: \(scored.replacingOccurrences(of: "\n", with: "⏎"))")
            }
        }
    }

    FidelityRound.summary(all, arms: arms.map(\.label))
    writeFidelityCapture(all, to: jsonOut)
}

func writeFidelityCapture(_ all: [FidelityRun], to path: String?) {
    guard let path else { return }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(all.map(FidelityRunRecord.init)) else {
        print("error: cannot encode the capture")
        exit(1)
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("\n── wrote \(all.count) runs to \(path)")
    } catch {
        print("error: cannot write \(path): \(error)")
        exit(1)
    }
}
#endif
