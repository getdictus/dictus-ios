// DictusCore/Sources/polish-harness/LostWordReplay.swift
// Replaying recorded free-polish outputs through the shipped pipeline (#575).
import Foundation
import DictusCore

/// One recorded output to replay: the dictation, the route the device would take,
/// and what the model returned. Written by
/// `docs/research/575-normal-polish-damage/harness/replay.py`.
struct LostWordPair: Codable {
    let key: String
    /// `natural` (French, per-language route), `auto` or `repair`.
    let route: String
    let raw: String
    let output: String
}

/// What the pipeline does with one recorded output today.
struct LostWordVerdict: Codable {
    let key: String
    let route: String
    /// Characters of the pre-passed input, which is what the length gate reads.
    let chars: Int
    /// The language the lost-word check keys its lexicon on.
    let languageCode: String?
    /// `success` or `rejectedGuardrail`.
    let outcome: String
    /// The check that refused, when one did.
    let check: String?
    /// What the lost-word check reports with no length gate: what it WOULD refuse on
    /// long input it does not ship on. Empty on a route it never runs on.
    let unscopedLostWords: [String]
}

/// Replay every pair through `PolishPipeline.transform` with an engine that returns
/// the recorded output, so the verdict is the shipped chain's, in the shipped order —
/// not a mirror of it. Drives no model.
func runLostWordReplay() async {
    let paths = corpusPaths(in: args)
    guard paths.count == 1, let data = FileManager.default.contents(atPath: paths[0]) else {
        print("usage: swift run polish-harness lostword <pairs.jsonl>")
        exit(2)
    }
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let lines = (String(bytes: data, encoding: .utf8) ?? "").split(separator: "\n")
    for line in lines {
        guard let pair = try? decoder.decode(LostWordPair.self, from: Data(line.utf8)) else {
            print("error: cannot decode pair: \(line)")
            exit(1)
        }
        let verdict = await replay(pair)
        guard let json = try? encoder.encode(verdict) else { exit(1) }
        print(String(bytes: json, encoding: .utf8) ?? "")
    }
}

private func replay(_ pair: LostWordPair) async -> LostWordVerdict {
    let task: PolishTask
    let preprocessed: String
    let languageCode: String?
    switch pair.route {
    case "auto":
        task = .auto
        preprocessed = PolishPipeline.autoPreprocess(
            pair.raw, detectedCode: PolishPipeline.detectLanguageCode(in: pair.raw)
        )
        languageCode = PolishPipeline.detectLanguageCode(in: preprocessed)
    case "repair":
        task = .repair
        preprocessed = VerbalPunctuationPrepass.apply(pair.raw, language: .french)
        languageCode = nil
    default:
        task = .natural
        preprocessed = VerbalPunctuationPrepass.apply(pair.raw, language: .french)
        languageCode = "fr"
    }
    let job = PolishJob(task: task, promptLanguage: .french, languageAgnosticPath: pair.route == "auto")
    let result = await PolishPipeline.transform(
        preprocessed: preprocessed, engine: RecordedOutputEngine(output: pair.output), job: job
    )
    let unscoped = task.contract.refusesLostWords
        ? PolishLostWords.lostWords(polished: pair.output, raw: preprocessed,
                                    languageCode: languageCode, maximumCharacters: .max)
        : []
    return LostWordVerdict(
        key: pair.key, route: pair.route, chars: preprocessed.count, languageCode: languageCode,
        outcome: result.outcome.rawValue, check: result.rejectedCheck?.rawValue,
        unscopedLostWords: unscoped
    )
}

/// Returns the recorded output whatever it is handed.
private struct RecordedOutputEngine: PolishEngineProtocol {
    let identifier = "recorded-output"
    let output: String

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        output
    }
}
