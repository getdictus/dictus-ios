// DictusCore/Sources/polish-harness/SummaryRound.swift
// `summary` — the Résumé bench, scored against bars declared before it ran (#571).
//
// Runs a Smart Mode over a fixture file through the real pipeline and scores every
// run on the bars of `docs/research/571-summary/bars.md`: output language, list
// lines, length ratio, the speaker's person, preambles, example content and novel
// figures. The scorers are `PolishSummaryShape`, in the PolishFidelity library, so
// `swift test` pins them.
//
// WHY the ENGINE's output is scored and not the inserted text, for the reason
// `fidelity` gives: a refusal inserts the speaker's raw transcript, which is in the
// right language, has no bullet and keeps the person, so scoring what reaches the
// document would count every refusal as a perfect summary. The guardrail verdict is
// printed beside each run and never folded into it.
#if os(macOS)
import Foundation
import DictusCore
import PolishFidelity

struct SummaryRun: Codable {
    let arm: String
    let fixture: String
    let lang: String
    let run: Int
    let ms: Int
    let rawChars: Int
    let outputChars: Int
    let outcome: String
    let rejectedCheck: String?
    let outputLanguage: String?
    let languageMatches: Bool
    let listLines: Int
    let ratio: Double
    let reportFraming: [String]
    let opensOnInfinitive: Bool
    let firstPersonLost: Bool
    let preamble: Bool
    let exampleContent: [String]
    let novelFigures: [String]
    let output: String
    let hasEngineOutput: Bool

    var accepted: Bool { outcome == PolishMetrics.Outcome.success.rawValue }

    /// Every flag a reader has to look at, in one line.
    var flags: [String] {
        var flags: [String] = []
        if !languageMatches { flags.append("LANG=\(outputLanguage ?? "?")") }
        if listLines > 0 { flags.append("LIST×\(listLines)") }
        if !reportFraming.isEmpty { flags.append("REPORT[\(reportFraming.joined(separator: ","))]") }
        if opensOnInfinitive { flags.append("INFINITIVE") }
        if firstPersonLost { flags.append("PERSON-LOST") }
        if preamble { flags.append("PREAMBLE") }
        if !exampleContent.isEmpty { flags.append("EXAMPLE[\(exampleContent.joined(separator: ","))]") }
        if !novelFigures.isEmpty { flags.append("FIGURE[\(novelFigures.joined(separator: ","))]") }
        return flags
    }
}

@available(macOS 26.0, *)
func runSummaryRound(fixtures: [Fixture], mode: SmartMode?, armPaths: [String],
                     runs: Int, jsonOut: String?) async {
    // No mode runs the free polish, scored the same way: bar D of bars.md compares
    // `Summary` with `List` and with Normal polish on the same dictations.
    let contract = mode?.contract ?? .natural
    let band = contract.minimumLengthRatio...contract.maximumLengthRatio
    let arms: [(label: String, path: String?)] =
        [("shipping", nil)] + armPaths.map { (URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent, $0) }

    var all: [SummaryRun] = []
    for arm in arms {
        print("\n\n████ ARM \(arm.label) — \(mode.map { "mode \($0.id)" } ?? "free polish"), \(runs) run(s) × \(fixtures.count) fixture(s)")
        if let path = arm.path { print("     prompt: \(path)") }
        let engine = makeEngine(loadInstructions(arm.path))
        for fixture in fixtures {
            print("\n━━ [\(fixture.id)] \(fixture.raw.count) chars, lang=\(fixture.lang)")
            print("  raw: \(fixture.raw)")
            for index in 1...max(1, runs) {
                let outcome = await runOnce(fixture, engine: engine, mode: mode)
                let output = outcome.engineOutput ?? ""
                let score = PolishSummaryShape.score(output: output, input: fixture.raw,
                                                     expectedLanguage: fixture.lang)
                let run = SummaryRun(
                    arm: arm.label, fixture: fixture.id, lang: fixture.lang, run: index,
                    ms: outcome.engineMs, rawChars: fixture.raw.count, outputChars: output.count,
                    outcome: outcome.outcome.rawValue, rejectedCheck: outcome.rejectedCheck?.rawValue,
                    outputLanguage: score.outputLanguage, languageMatches: score.languageMatches,
                    listLines: score.listLines, ratio: score.ratio, reportFraming: score.reportFraming,
                    opensOnInfinitive: score.opensOnInfinitive, firstPersonLost: score.firstPersonLost,
                    preamble: score.preamble, exampleContent: score.exampleContent,
                    novelFigures: score.novelFigures, output: output,
                    hasEngineOutput: outcome.engineOutput != nil
                )
                all.append(run)
                let verdict = run.rejectedCheck.map { "\(run.outcome)/\($0)" } ?? run.outcome
                let inBand = band.contains(run.ratio) ? "" : " OUT-OF-BAND"
                let flags = run.flags.isEmpty ? "" : "  ⚑ " + run.flags.joined(separator: " ")
                print(String(format: "  #%d %@ ratio=%.2f%@ %dms%@", index, verdict, run.ratio, inBand, run.ms, flags))
                print("     out: \(output.replacingOccurrences(of: "\n", with: "⏎"))")
            }
        }
    }
    printSummaryTable(all, arms: arms.map(\.label), band: band)
    writeSummaryCapture(all, to: jsonOut)
}

/// One row per arm and language: the numbers each bar is read off.
func printSummaryTable(_ all: [SummaryRun], arms: [String], band: ClosedRange<Double>) {
    print("\n\n══ bars (engine outputs; `acc` = accepted by the pipeline)")
    print("arm | lang | runs | wrong-lang (acc) | refused on language | list lines | in band | report/infinitive/person-lost | preamble | example | figure | accepted")
    for arm in arms {
        let rows = all.filter { $0.arm == arm && $0.hasEngineOutput }
        let languages = Array(Set(rows.map(\.lang))).sorted()
        for lang in languages + ["ALL"] {
            let set = lang == "ALL" ? rows : rows.filter { $0.lang == lang }
            let count = set.count
            guard count > 0 else { continue }
            let wrong = set.filter { !$0.languageMatches }
            let refusedOnLanguage = all.filter {
                $0.arm == arm && (lang == "ALL" || $0.lang == lang) && $0.rejectedCheck == "language"
            }.count
            let lists = set.filter { $0.listLines > 0 }.count
            let inBand = set.filter { band.contains($0.ratio) }.count
            let person = set.filter { !$0.reportFraming.isEmpty || $0.opensOnInfinitive || $0.firstPersonLost }.count
            let cells = [
                arm, lang, "\(count)",
                "\(wrong.count) (\(wrong.filter(\.accepted).count))",
                "\(refusedOnLanguage) (\(percent(refusedOnLanguage, count)))",
                "\(lists)",
                "\(inBand)/\(count) (\(percent(inBand, count)))",
                "\(person)",
                "\(set.filter(\.preamble).count)",
                "\(set.filter { !$0.exampleContent.isEmpty }.count)",
                "\(set.filter { !$0.novelFigures.isEmpty }.count)",
                "\(set.filter(\.accepted).count)/\(count)"
            ]
            print(cells.joined(separator: " | "))
        }
        let refusals = Dictionary(grouping: all.filter { $0.arm == arm && !$0.accepted },
                                  by: { $0.rejectedCheck ?? $0.outcome })
        let line = refusals.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value.count)" }.joined(separator: ", ")
        print("   refusals, \(arm): \(line.isEmpty ? "none" : line)")
        let missing = all.filter { $0.arm == arm && !$0.hasEngineOutput }.count
        if missing > 0 { print("   no engine output (engine failed, excluded above): \(missing)") }
    }
}

private func percent(_ part: Int, _ whole: Int) -> String {
    whole == 0 ? "–" : String(format: "%.0f%%", Double(part) / Double(whole) * 100)
}

func writeSummaryCapture(_ all: [SummaryRun], to path: String?) {
    guard let path else { return }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(all) else {
        print("error: cannot encode the capture")
        return
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("\ncapture written: \(path)")
    } catch {
        print("error: cannot write \(path): \(error)")
    }
}
#endif
