// DictusCore/Sources/polish-harness/ParagraphRound.swift
//
// The #550 paragraph-placement round. Drives Apple FM on light, committed prompt
// "arms" whose only job is to split an already-polished French text into
// paragraphs, and scores the four bars declared in
// `docs/research/550-paragraph-placement/bars.md` before the first arm call.
//
// WHY this is not `show --instructions --framing`. Two of the arms do not return
// text at all: they return the INDEX of each sentence that starts a paragraph, and
// the text is reassembled here, in code, from the same sentence cut the model was
// shown. That is the whole point of them — a model that emits only integers cannot
// delete a word, reorder, invent or produce a list, so the fidelity half of the
// contract becomes structurally impossible to violate rather than measured. No
// `--framing` override can express that, and no acceptance contract can score it:
// every band necessarily rejects a list of integers.
//
// WHY no `PolishPipeline`. Declared in bars.md §5 and repeated here because it
// bounds what the numbers mean. The question this round asks is a CAPABILITY
// question — can the model place breaks at all — and a guardrail rejection and a
// model failure are different findings that must not be summed. The inputs carry no
// `<<NL>>` markers (they are single blocks), so removing the pipeline removes no
// confound. The consequence is stated in findings.md: a design that holds these bars
// still has to be re-measured inside the pipeline before it could ship.
//
// Lives in the `polish-harness` target only — macOS-only, excluded from every app
// target and from CI.

#if os(macOS)
import Foundation
import DictusCore
#if canImport(FoundationModels)
import FoundationModels

// MARK: - The arm

/// One committed prompt arm. Read from JSON so it exists as a file before it is run
/// and stays re-runnable after — the same discipline `docs/research/437-longform-breaks/prompts/`
/// follows.
///
/// Placeholders the round substitutes:
/// - `{{INPUT}}` — the text as one block.
/// - `{{SENTENCES}}` — the text as one numbered sentence per line.
/// - `{{N}}` — the break count the fit supplies (bars.md §4).
/// - `{{N_PARA}}` — `{{N}} + 1`, for an arm phrased in paragraphs rather than breaks.
struct ParagraphArm: Decodable {
    let id: String
    /// `text` — the model returns the split text. `index` — it returns integers and
    /// the text is reassembled here.
    let kind: String
    let note: String?
    let instructions: String
    let framing: String

    var returnsIndices: Bool { kind == "index" || kind == "index-ranked" }

    /// The model returns the boundaries in order of confidence and the caller keeps
    /// the first N. Round 1's finding made this arm worth writing: telling the model
    /// the count moves it from "one break per sentence" to within one break of N, but
    /// not to N. Ranking moves the count out of the model's hands entirely, the same
    /// way returning integers moved fidelity out of them.
    var truncatesToN: Bool { kind == "index-ranked" }
}

/// One fixture, resolved once: the text, the sentence cut every arm and every bar is
/// scored against, and the break count the fit supplies for it.
///
/// It exists so the cut is computed once per fixture rather than once per run — two
/// runs of the same arm on the same fixture must be scored against the same
/// boundaries, or the numbers are not comparable.
struct ParagraphCase {
    let fixture: Fixture
    let sentences: [String]
    let targetN: Int

    @available(macOS 26.0, *)
    init(_ fixture: Fixture) {
        self.fixture = fixture
        sentences = PolishSegmentation.sentences(of: fixture.raw)
        targetN = ParagraphRound.targetBreaks(for: fixture.raw)
    }
}

// MARK: - One scored run

struct ParagraphRun {
    let fixture: String
    let arm: String
    let run: Int
    let milliseconds: Int
    /// What the model actually returned, before any reassembly. Committed verbatim.
    let engineOutput: String
    /// What would reach the document: the model's text, or the reassembly of its
    /// indices. Nil when an index arm returned something unparseable.
    let output: String?
    /// Sentence numbers (1-based) that start a paragraph, excluding the first.
    let starts: [Int]
    let breaks: Int
    let targetN: Int
    let sentenceCount: Int
    /// Bar 1. Nil on an index arm, where it holds by construction.
    let fidelity: Bool?
    /// Bar 2. Nil when bar 1 failed, because "inside a sentence" then has no referent.
    let boundaryViolations: Int?
    /// Bar 4.
    let listSyntax: Bool
    /// Index arms only: the output was not a usable list of sentence numbers.
    let parseFailure: String?
    /// Set when Apple FM threw. Such a run is excluded from every bar and reported on
    /// its own line: a model that never answered has not violated a contract, and
    /// counting it as a fidelity failure would put two different findings in one
    /// number. Round 1 hit one in 245.
    let engineError: String?
}

// MARK: - The round

@available(macOS 26.0, *)
enum ParagraphRound {

    /// A leading ordinal or bullet on any line — bars.md §6, bar 4. None of the seven
    /// probe texts dictates a list, so any hit is a violation.
    static let listMarker = #"(?m)^[ \t]*(?:\d+[ \t]*[.)]|[-*•‣▪])[ \t]+"#

    /// The break count the fit supplies: `max(1, round(chars / 400))`.
    ///
    /// Fitted on five reference points in bars.md §4 and reported there with its
    /// residuals — it misses fixture 3 by one break and is untested outside
    /// 246–1 150 characters. It lives here as one line because the arms need a
    /// number to obey, not because 400 is a constant.
    static func targetBreaks(for text: String) -> Int {
        max(1, Int((Double(text.count) / 400).rounded()))
    }

    /// The text as one numbered sentence per line, which is what arms 5, 6 and 6b are
    /// handed instead of a block.
    static func numbered(_ sentences: [String]) -> String {
        sentences.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
    }

    static func resolve(_ template: String, case work: ParagraphCase) -> String {
        template
            .replacingOccurrences(of: "{{SENTENCES}}", with: numbered(work.sentences))
            .replacingOccurrences(of: "{{INPUT}}", with: work.fixture.raw)
            .replacingOccurrences(of: "{{N_PARA}}", with: String(work.targetN + 1))
            .replacingOccurrences(of: "{{N}}", with: String(work.targetN))
    }

    // MARK: Running one call

    static func run(_ arm: ParagraphArm,
                    case work: ParagraphCase,
                    run index: Int) async -> ParagraphRun {
        let instructions = resolve(arm.instructions, case: work)
        let framing = resolve(arm.framing, case: work)

        let started = Date()
        var engineOutput = ""
        var engineError: String?
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: framing)
            engineOutput = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            engineError = "\(error)"
        }
        let milliseconds = Int(Date().timeIntervalSince(started) * 1000)

        return score(arm: arm, case: work, run: index, engineOutput: engineOutput,
                     engineError: engineError, milliseconds: milliseconds)
    }

    // MARK: Scoring

    static func score(arm: ParagraphArm,
                      case work: ParagraphCase,
                      run index: Int,
                      engineOutput: String,
                      engineError: String? = nil,
                      milliseconds: Int) -> ParagraphRun {
        let text = work.fixture.raw
        let sentences = work.sentences
        var output: String?
        var starts: [Int] = []
        var parseFailure: String?
        var fidelity: Bool?

        if engineError != nil {
            // Nothing to score. Left entirely out of the bars by the nil fields.
        } else if arm.returnsIndices {
            switch parseIndices(engineOutput, sentenceCount: sentences.count) {
            case .success(let parsed):
                starts = (arm.truncatesToN ? Array(parsed.prefix(work.targetN)) : parsed).sorted()
                let reassembled = reassemble(sentences, startingAt: starts)
                output = reassembled
                // Structurally true, and measured anyway: it is the sentence cut that
                // is being trusted here, not the model, and a cut that dropped a
                // character would make every other number in this round wrong.
                fidelity = strip(reassembled) == strip(text)
            case .failure(let reason):
                parseFailure = reason
            }
        } else {
            // Newline runs collapse to one, because that is what
            // `PolishPostpass.decodeNewlines` does to anything the model emits, so a
            // blank line between paragraphs and a single newline reach the document
            // identically.
            let collapsed = PolishPostpass.decodeNewlines(engineOutput)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            output = collapsed
            fidelity = strip(collapsed) == strip(text)
            starts = startIndices(of: collapsed, sentences: sentences)
        }

        let breaks = output.map { $0.filter { $0 == "\n" }.count } ?? 0
        let boundaryViolations: Int?
        if engineError != nil {
            boundaryViolations = nil
        } else if arm.returnsIndices {
            // Structural: a start index is a sentence number, so there is no offset at
            // which a break could land inside a sentence.
            boundaryViolations = parseFailure == nil ? 0 : nil
        } else if fidelity == true, let output {
            boundaryViolations = interiorBreaks(in: output, sentences: sentences)
        } else {
            boundaryViolations = nil
        }

        let listSyntax = output?.range(of: listMarker, options: .regularExpression) != nil

        return ParagraphRun(
            fixture: work.fixture.id, arm: arm.id, run: index, milliseconds: milliseconds,
            engineOutput: engineOutput, output: output, starts: starts, breaks: breaks,
            targetN: work.targetN, sentenceCount: sentences.count, fidelity: fidelity,
            boundaryViolations: boundaryViolations, listSyntax: listSyntax,
            parseFailure: parseFailure, engineError: engineError
        )
    }

    /// Every non-whitespace character, in order. Bar 1's predicate and #437's
    /// second-pass predicate, unchanged, so the 30/30 that probe holds today is
    /// directly comparable.
    static func strip(_ text: String) -> String {
        String(text.filter { !$0.isWhitespace })
    }

    /// Bar 2. Every break offset, measured in whitespace-stripped characters, must
    /// coincide with the end of one of the input's sentences.
    ///
    /// Only meaningful when bar 1 holds, which the caller enforces: if the words
    /// moved, "inside a sentence" has no referent.
    static func interiorBreaks(in output: String, sentences: [String]) -> Int {
        var ends: Set<Int> = []
        var accumulated = 0
        for sentence in sentences {
            accumulated += strip(sentence).count
            ends.insert(accumulated)
        }
        var violations = 0
        var offset = 0
        for character in output {
            if character == "\n" {
                if !ends.contains(offset) { violations += 1 }
            } else if !character.isWhitespace {
                offset += 1
            }
        }
        return violations
    }

    /// Which sentence numbers a text-arm output starts a paragraph on, for the
    /// placement table. Best effort: a break that does not sit on a sentence
    /// boundary contributes nothing, which is exactly what bar 2 counts separately.
    static func startIndices(of output: String, sentences: [String]) -> [Int] {
        var endToIndex: [Int: Int] = [:]
        var accumulated = 0
        for (index, sentence) in sentences.enumerated() {
            accumulated += strip(sentence).count
            endToIndex[accumulated] = index + 2   // the sentence AFTER this one starts
        }
        var found: [Int] = []
        var offset = 0
        for character in output {
            if character == "\n" {
                if let index = endToIndex[offset] { found.append(index) }
            } else if !character.isWhitespace {
                offset += 1
            }
        }
        return found
    }

    // MARK: Index arms

    enum IndexParse {
        case success([Int])
        case failure(String)
    }

    /// The integers in an index arm's answer, validated against the sentence cut it
    /// was shown.
    ///
    /// Refuses rather than repairs. A parse failure is a product failure too, and
    /// bars.md counts it as its own number precisely so it cannot hide inside a
    /// fidelity result that is true by construction. `1` is dropped rather than
    /// refused: the prompt says sentence 1 does not count, and a model restating it
    /// is answering the question, not failing to.
    static func parseIndices(_ output: String, sentenceCount: Int) -> IndexParse {
        let letters = output.filter { $0.isLetter }
        if letters.count > 12 {
            return .failure("prose, not indices (\(letters.count) letters)")
        }
        let numbers = output
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        guard !numbers.isEmpty else { return .failure("no integer in the output") }
        if let outOfRange = numbers.first(where: { $0 < 1 || $0 > sentenceCount }) {
            return .failure("sentence \(outOfRange) does not exist (cut has \(sentenceCount))")
        }
        // First-occurrence order, NOT sorted: the ranked arm's whole design is that
        // the ORDER is the model's answer, and sorting here would throw it away.
        var seen: Set<Int> = []
        return .success(numbers.filter { $0 > 1 && seen.insert($0).inserted })
    }

    /// The deterministic reassembly. This is the half of arm 6 that is not the model:
    /// the sentences are the harness's own cut, joined with a space or a newline and
    /// nothing else, so no word can move.
    static func reassemble(_ sentences: [String], startingAt starts: [Int]) -> String {
        let breakBefore = Set(starts)
        var out = ""
        for (offset, sentence) in sentences.enumerated() {
            if offset > 0 { out += breakBefore.contains(offset + 1) ? "\n" : " " }
            out += sentence
        }
        return out
    }
}

// MARK: - Driving the round and printing the capture

/// Run every arm over every fixture and print the capture that gets committed under
/// `docs/research/550-paragraph-placement/raw/`, plus a JSON sidecar for the
/// placement analysis.
///
/// Per fixture, never pooled: bars.md §7, and the reason #437's per-fixture table is
/// the readable part of its findings. Apple FM samples, so a single call is not a
/// result.
@available(macOS 26.0, *)
func runParagraphRound(fixtures: [Fixture], armPaths: [String], runs: Int, jsonOut: String?) async {
    guard !armPaths.isEmpty else {
        print("error: paragraph needs at least one --arm, e.g.\n"
              + "  swift run polish-harness paragraph Sources/polish-harness/fixtures/paragraph-fr.json \\\n"
              + "    --arm ../docs/research/550-paragraph-placement/arms/6-index.json --runs 5")
        exit(2)
    }
    var arms: [ParagraphArm] = []
    for path in armPaths {
        guard let data = FileManager.default.contents(atPath: path),
              let arm = try? JSONDecoder().decode(ParagraphArm.self, from: data) else {
            print("error: cannot read arm at \(path)")
            exit(1)
        }
        arms.append(arm)
    }

    var all: [ParagraphRun] = []
    var printedCut: Set<String> = []
    for arm in arms {
        print("\n\n████ ARM \(arm.id) — kind=\(arm.kind), \(runs) run(s) × \(fixtures.count) fixture(s)")
        if let note = arm.note { print("     \(note)") }
        for work in fixtures.map(ParagraphCase.init) {
            print("\n━━ [\(work.fixture.id)] \(work.fixture.raw.count) chars, "
                  + "\(work.sentences.count) sentences, N=\(work.targetN)")
            if !printedCut.contains(work.fixture.id) {
                printedCut.insert(work.fixture.id)
                // The cut decides what a boundary IS for arms 5, 6, 6b and 7, and for
                // bar 2 on every arm. bars.md §9 names it as a risk, so it is printed
                // rather than assumed.
                print("   cut: " + ParagraphRound.numbered(work.sentences)
                        .replacingOccurrences(of: "\n", with: "\n        "))
            }
            for index in 1...max(1, runs) {
                let result = await ParagraphRound.run(arm, case: work, run: index)
                all.append(result)
                print("  #\(index) \(ParagraphRound.verdict(result))")
                print("     engineOut: \(result.engineOutput.replacingOccurrences(of: "\n", with: "⏎"))")
            }
        }
    }

    ParagraphRound.summary(all, arms: arms)

    guard let jsonOut else { return }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(all.map(ParagraphRunRecord.init)) else {
        print("error: cannot encode the capture")
        exit(1)
    }
    do {
        try data.write(to: URL(fileURLWithPath: jsonOut))
        print("\n── wrote \(all.count) runs to \(jsonOut)")
    } catch {
        print("error: cannot write \(jsonOut): \(error)")
        exit(1)
    }
}

/// The JSON shape committed next to the human capture, so the placement analysis is
/// a script over data rather than a re-read of prose.
struct ParagraphRunRecord: Encodable {
    let arm: String
    let fixture: String
    let run: Int
    let ms: Int
    let targetN: Int
    let breaks: Int
    let sentenceCount: Int
    let starts: [Int]
    let fidelity: Bool?
    let boundaryViolations: Int?
    let listSyntax: Bool
    let parseFailure: String?
    let engineError: String?
    let engineOutput: String
    let output: String?

    init(_ run: ParagraphRun) {
        arm = run.arm
        fixture = run.fixture
        self.run = run.run
        ms = run.milliseconds
        targetN = run.targetN
        breaks = run.breaks
        sentenceCount = run.sentenceCount
        starts = run.starts
        fidelity = run.fidelity
        boundaryViolations = run.boundaryViolations
        listSyntax = run.listSyntax
        parseFailure = run.parseFailure
        engineError = run.engineError
        engineOutput = run.engineOutput
        output = run.output
    }
}

@available(macOS 26.0, *)
extension ParagraphRound {

    /// One line per run, carrying every bar. Written to be greppable in a committed
    /// capture rather than pretty.
    static func verdict(_ result: ParagraphRun) -> String {
        var parts: [String] = ["\(result.milliseconds)ms",
                               "breaks=\(result.breaks)/N=\(result.targetN)"]
        if let failure = result.engineError {
            parts.append("ENGINE-ERROR(\(failure.prefix(60)))")
            return parts.joined(separator: " ")
        }
        if let failure = result.parseFailure {
            parts.append("PARSE-FAIL(\(failure))")
            return parts.joined(separator: " ")
        }
        parts.append("starts=\(result.starts.map(String.init).joined(separator: ","))")
        switch result.fidelity {
        case true: parts.append("fidelity=ok")
        case false: parts.append("FIDELITY-FAIL")
        case nil: parts.append("fidelity=structural")
        }
        switch result.boundaryViolations {
        case .some(0): parts.append("inSentence=0")
        case .some(let count): parts.append("IN-SENTENCE=\(count)")
        case nil: parts.append("inSentence=n/a")
        }
        if result.listSyntax { parts.append("LIST-SYNTAX") }
        return parts.joined(separator: " ")
    }

    /// The bar table, per arm, over every run of the round.
    static func summary(_ all: [ParagraphRun], arms: [ParagraphArm]) {
        print("\n\n════ BARS, per arm (bars.md §6)\n")
        print(pad("arm", 20) + pad("runs", 6)
              + ["fidelity", "inSentence", "listSyntax", "parseFail", "countHit", "median ms", "engineErr"]
                  .map { pad($0, 12) }.joined())
        for arm in arms {
            let errors = all.filter { $0.arm == arm.id && $0.engineError != nil }.count
            let rows = all.filter { $0.arm == arm.id && $0.engineError == nil }
            guard !rows.isEmpty else { continue }
            let fidelityFails = rows.filter { $0.fidelity == false }.count
            let interior = rows.compactMap(\.boundaryViolations).filter { $0 > 0 }.count
            let lists = rows.filter(\.listSyntax).count
            let parseFails = rows.filter { $0.parseFailure != nil }.count
            let countHits = rows.filter { $0.parseFailure == nil && $0.breaks == $0.targetN }.count
            let times = rows.map(\.milliseconds).sorted()
            let median = times[times.count / 2]
            let cells = ["\(fidelityFails)/\(rows.count)", "\(interior)/\(rows.count)",
                         "\(lists)/\(rows.count)", "\(parseFails)/\(rows.count)",
                         "\(countHits)/\(rows.count)", "\(median)", "\(errors)"]
            print(pad(arm.id, 20) + pad("\(rows.count)", 6)
                  + cells.map { pad($0, 12) }.joined())
        }
        print("\n  fidelity / inSentence / listSyntax / parseFail are VIOLATION counts — 0 is the bar.")
        print("  engineErr runs are excluded from every column: a call that never answered")
        print("  has violated nothing, and folding it into fidelity would blur two findings.")
        print("  countHit is the number of runs whose break count equalled N.")

        print("\n\n════ BREAKS PER RUN, per arm per fixture (never pooled)\n")
        for arm in arms {
            let rows = all.filter { $0.arm == arm.id }
            guard !rows.isEmpty else { continue }
            print("── \(arm.id)")
            for fixture in orderedFixtures(rows) {
                let runs = rows.filter { $0.fixture == fixture }.sorted { $0.run < $1.run }
                let counts = runs.map { run -> String in
                    if run.engineError != nil { return "e" }
                    return run.parseFailure == nil ? String(run.breaks) : "x"
                }
                print("   " + pad(fixture, 20) + "N=\(runs[0].targetN)  "
                      + counts.joined(separator: ", "))
            }
        }
        print("\n   x = the arm returned something that is not a usable answer.")
        print("   e = Apple FM threw; the run is in no denominator above.")
    }

    /// Left-pad to a fixed column. `String(format: "%-20@")` does not honour a width
    /// for `%@` here, which silently produced an unreadable committed capture.
    static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text + " " : text + String(repeating: " ", count: width - text.count)
    }

    private static func orderedFixtures(_ rows: [ParagraphRun]) -> [String] {
        var seen: Set<String> = []
        return rows.map(\.fixture).filter { seen.insert($0).inserted }
    }
}
#endif
#endif
