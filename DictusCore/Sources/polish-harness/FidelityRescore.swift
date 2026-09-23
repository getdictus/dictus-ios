// DictusCore/Sources/polish-harness/FidelityRescore.swift
//
// `fidelity --rescore`: score a committed live capture again, with the current
// scorers, without calling the model.
//
// WHY this exists. Every live capture already stores what the engine returned for
// every run. When a scorer is corrected — as it was after CodeRabbit's review of
// PR #583 — the outputs are the evidence and they have not changed; only the
// reading of them has. Re-running a round would answer a different question: Apple FM
// samples, so a second round is a second sample, and a number that moved would no
// longer say whether the scorer or the model moved it. Rescoring keeps the samples
// fixed, so every number that moves in findings.md moves because the scorer changed.
//
// The capture carries no transcript, only the fixture id, so the fixture file the
// round was run on is required: `--fixtures <fixtures.json>`. A fixture id the file
// does not carry is refused rather than skipped, because a rescore that silently drops
// runs would print a denominator that reads like a result.

#if os(macOS)
import Foundation
import DictusCore
import PolishFidelity

enum FidelityRescore {

    /// Outcomes that come with an engine output even when the pipeline refused it.
    /// Anything else in a capture written before `hasEngineOutput` existed was a run
    /// whose output was stored as "" because there was none.
    private static let outcomesWithOutput: Set<String> = [
        PolishMetrics.Outcome.success.rawValue,
        PolishMetrics.Outcome.rejectedGuardrail.rawValue
    ]

    static func rescore(capturePath: String, fixturesPath: String, floor: Double) -> [FidelityRun] {
        guard let data = FileManager.default.contents(atPath: capturePath),
              let records = try? JSONDecoder().decode([FidelityRunRecord].self, from: data) else {
            print("error: cannot read capture at \(capturePath)")
            exit(1)
        }
        let fixtures: [Fixture]
        do {
            fixtures = try FixtureLoader.load(fixturesPath)
        } catch {
            print("error: cannot load fixtures at \(fixturesPath): \(error)")
            exit(1)
        }
        let raws = Dictionary(fixtures.map { ($0.id, $0.raw) }, uniquingKeysWith: { first, _ in first })

        return records.map { record in
            guard let raw = raws[record.fixture] else {
                print("error: capture run \(record.arm)/\(record.fixture)#\(record.run) has no fixture "
                      + "in \(fixturesPath) — refusing to rescore a partial capture")
                exit(1)
            }
            let hasOutput = record.hasEngineOutput
                ?? (outcomesWithOutput.contains(record.outcome) || !record.output.isEmpty)
            return FidelityRun(
                fixture: record.fixture, arm: record.arm, run: record.run,
                milliseconds: record.ms, rawCharacters: raw.count,
                outputCharacters: record.output.count, outcome: record.outcome,
                rejectedCheck: record.rejectedCheck, labels: record.labels,
                score: PolishFidelityScorer.score(output: record.output, input: raw, floor: floor),
                output: record.output, hasEngineOutput: hasOutput
            )
        }
    }
}
#endif
