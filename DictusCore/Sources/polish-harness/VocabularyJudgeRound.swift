// DictusCore/Sources/polish-harness/VocabularyJudgeRound.swift
// `vocabjudge` (#512 step 2): score a labelled pairs file, and run Apple FM as the judge when the labels ask for it.
// macOS only, like main.swift, whose `args` and `optionValue` this uses: the package
// also builds for the iOS Simulator destination of `swift test` (#301).
#if os(macOS)
import Foundation
import DictusCore
import PolishFidelity
#if canImport(FoundationModels)
import FoundationModels
#endif

// Step 2 brief, decision 6. The labels come first and decide whether the model is
// asked at all: with 17 or more of 20 pairs true, the generator ships alone and Apple
// FM is NOT called. Otherwise each pair is judged three times, each run in a fresh
// session so no run sees another's answer, and any disagreement is an error. The
// thresholds and the verdict are `VocabularyJudgeVerdict` (PolishFidelity), tested.
//
// What the judge is asked: whether, in this sentence, the span is the engine's attempt
// at the term. It is handed the pair; it never writes a spelling (homophone repair was
// measured 0 of 5, and a canonical comes from the user, decision 2). Its output is
// guided to two fields, the pair's id and `yes`/`no`, both closed sets, so nothing it
// returns can carry text.
//
// Default sampling, as the app's polish calls use: three runs of one pair measure the
// variance a device would see, which greedy decoding would hide.
//
// Mac model ≠ iPhone model (assumption, not measured): a go here is followed by one
// on-device check before any UI (decision 4).

enum VocabularyJudgeRound {

    /// Decision 6: three runs per pair.
    static let runsPerPair = 3

    static let instructions = """
    You check one possible speech-recognition mistake. A speech-to-text engine \
    transcribed a dictation, and the user keeps a personal vocabulary of terms the \
    engine often writes wrong. You are given one sentence of the transcript, a span of \
    that sentence, and one term of the vocabulary.

    Answer "yes" only if, in this sentence, the speaker most likely said the term and \
    the engine wrote the span in its place. Answer "no" if the span means what it says \
    in this sentence, or if the term does not fit there. Decide from the meaning of the \
    sentence, not only from how the words sound. The sentence may be in any language.
    """

    static func prompt(for entry: VocabularyPairsFile.Entry) -> String {
        """
        Pair: \(entry.id)
        Sentence: \(entry.sentence)
        Span: \(entry.observed)
        Term: \(entry.canonical)
        """
    }

    /// Loads and parses the file, and refuses one that is not fully labelled: blind
    /// labelling of every pair is the precondition of the whole measurement.
    static func labelledEntries(at path: String) -> [VocabularyPairsFile.Entry] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("error: cannot read \(path)")
            exit(1)
        }
        let entries: [VocabularyPairsFile.Entry]
        do {
            entries = try VocabularyPairsFile.parse(text)
        } catch {
            print("error: \(path): \(error)")
            exit(2)
        }
        guard !entries.isEmpty else {
            print("error: \(path) holds no pair line")
            exit(2)
        }
        let unlabelled = entries.filter { $0.isTrue == nil }.map(\.id)
        guard unlabelled.isEmpty else {
            print("error: not labelled yet: \(unlabelled.joined(separator: ", ")). Prefix each with v or f.")
            exit(2)
        }
        return entries
    }

    static func printVerdict(_ verdict: VocabularyJudgeVerdict) {
        print("pairs=\(verdict.total) true=\(verdict.trueCount) false=\(verdict.falseCount)")
        if let kept = verdict.trueKept, let rejected = verdict.falseRejected {
            print("judge: kept \(kept)/\(verdict.trueCount) true pairs, rejected \(rejected)/\(verdict.falseCount) false pairs (bar: 80 % each)")
        } else {
            print("judge: not called")
        }
        if !verdict.isBriefSample {
            print("WARNING: \(verdict.total) pairs, not \(VocabularyJudgeVerdict.sampleSize). The verdict applies the brief's shares and is NOT the brief's go/no-go.")
        }
        print("verdict: \(verdict.decision.summary)")
    }
}

#if canImport(FoundationModels)

@available(macOS 26.0, *)
extension VocabularyJudgeRound {

    /// Two closed fields: the id of the pair asked about, and yes or no.
    static func schema(for id: String) throws -> GenerationSchema {
        let root = DynamicGenerationSchema(name: "PairVerdict", properties: [
            DynamicGenerationSchema.Property(
                name: "pairID",
                description: "The id of the pair being judged.",
                schema: DynamicGenerationSchema(name: "PairID", anyOf: [id])
            ),
            DynamicGenerationSchema.Property(
                name: "verdict",
                description: "yes if the span is the engine's attempt at the term in this sentence, no otherwise.",
                schema: DynamicGenerationSchema(name: "Verdict", anyOf: ["yes", "no"])
            )
        ])
        return try GenerationSchema(root: root, dependencies: [])
    }

    /// One run: true for yes, false for no, nil when the call failed or answered about
    /// another pair. The failure's slug is printed, never its context, which can quote
    /// the prompt.
    static func judgeOnce(_ entry: VocabularyPairsFile.Entry, run: Int) async -> (answer: Bool?, ms: Int) {
        let started = Date()
        var answer: Bool?
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt(for: entry), schema: try schema(for: entry.id))
            let pairID = try response.content.value(String.self, forProperty: "pairID")
            let verdict = try response.content.value(String.self, forProperty: "verdict")
            if pairID == entry.id { answer = verdict == "yes" ? true : verdict == "no" ? false : nil }
            if answer == nil { print("  \(entry.id) run \(run): unusable output") }
        } catch {
            let slug = AppleFoundationModelsPolishEngine().failureReason(for: error).slug
            print("  \(entry.id) run \(run): failed (\(slug))")
        }
        return (answer, Int(Date().timeIntervalSince(started) * 1000))
    }
}

/// `polish-harness vocabjudge <labelled.txt>`
@available(macOS 26.0, *)
func runVocabularyJudge() async {
    let entries = VocabularyJudgeRound.labelledEntries(at: args[1])
    let labels = entries.compactMap(\.isTrue)

    if VocabularyJudgeVerdict.labelsSettle(trueCount: labels.filter { $0 }.count, total: labels.count) {
        guard let verdict = VocabularyJudgeVerdict(labels: labels, readings: nil) else { exit(1) }
        VocabularyJudgeRound.printVerdict(verdict)
        return
    }

    // Checked only now: a file the labels settle needs no Apple Intelligence.
    guard case .available = SystemLanguageModel.default.availability else {
        print("pairs=\(labels.count) true=\(labels.filter { $0 }.count): the labels do not settle it, the judge has to run.")
        print("error: Apple Foundation Models not available (\(SystemLanguageModel.default.availability)). Enable Apple Intelligence in System Settings.")
        exit(1)
    }

    var readings: [VocabularyJudgeReading] = []
    var milliseconds: [Int] = []
    for entry in entries {
        var runs: [Bool?] = []
        for run in 1...VocabularyJudgeRound.runsPerPair {
            let result = await VocabularyJudgeRound.judgeOnce(entry, run: run)
            runs.append(result.answer)
            milliseconds.append(result.ms)
        }
        let reading = VocabularyJudgeReading(runs: runs)
        readings.append(reading)
        let shown = runs.map { $0.map { $0 ? "yes" : "no" } ?? "fail" }.joined(separator: ",")
        // Ids and verdicts only: the text stays in the labelled file.
        print("\(entry.id) label=\(entry.isTrue == true ? "v" : "f") runs=\(shown) reading=\(reading)")
    }
    let mean = milliseconds.isEmpty ? 0 : milliseconds.reduce(0, +) / milliseconds.count
    print("calls=\(milliseconds.count) meanMs=\(mean)")

    guard let verdict = VocabularyJudgeVerdict(labels: labels, readings: readings) else { exit(1) }
    VocabularyJudgeRound.printVerdict(verdict)
}

#endif

#endif
