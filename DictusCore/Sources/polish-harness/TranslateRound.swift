// DictusCore/Sources/polish-harness/TranslateRound.swift
// `translate` — the Translate bench of #648, scored against bars declared before it ran.
//
// One invocation runs ONE arm of the 2026-10-05 comment over a fixture file, through the
// real `PolishPipeline` under a shipped `translate.*` mode, so the shipped contract judges
// every output whatever produced it. An arm is two choices:
//
//   --translator apple-fm | translation-framework   which engine translates
//   --strategy lowLatency | highFidelity            the Translation framework's model
//   --clean <prompt.txt> --clean-framing <file>     an Apple FM cleaning pass first
//
// and every run is scored on bars (a) to (e) of `docs/research/648-translate/bars.md`:
// what must disappear, what must survive, what must not appear, the output language,
// and the critical spans where the device inverted the meaning.
//
// WHY the ENGINE's output is scored rather than the inserted text, for the reason
// `summary` and `fidelity` give: a refused Smart Mode inserts nothing, and scoring the
// document would count every refusal as a translation that dropped nothing. The
// pipeline's verdict is printed beside each run and counted on its own.
//
// Research code. The cleaning pass is NOT a Smart Mode and nothing here ships: step 3 of
// #648 ships the winning arm after the device probe says where the translator can run.
#if os(macOS)
import Foundation
import DictusCore
import PolishFidelity
#if canImport(Translation)
import Translation
#endif

// MARK: - Bars

/// `TranslateBarSet.decode` over files, exiting on the first one that cannot be read.
/// The scorer itself is in `PolishFidelity` so `swift test` pins it, its redaction in
/// particular.
func loadTranslateBars(_ paths: [String]) -> TranslateBarSet {
    var files: [Data] = []
    for path in paths {
        guard let data = FileManager.default.contents(atPath: path) else {
            print("error: cannot read bars at \(path)")
            exit(1)
        }
        files.append(data)
    }
    do {
        return try TranslateBarSet.decode(files)
    } catch {
        print("error: bars: \(error)")
        exit(1)
    }
}

// MARK: - Per-pass log

/// What each pass did on the current call: the cleaned text, the time each pass took,
/// the source language the translator was given, and the error a pass threw.
///
/// A side channel rather than a return value because the engines sit behind
/// `PolishEngineProtocol`, whose `polish` returns one string — the pipeline must see the
/// arm exactly as it would see a shipping engine. The harness makes one call at a time,
/// so a lock is all the concurrency this needs.
final class TranslatePassLog: @unchecked Sendable {
    private let lock = NSLock()
    private var state = State()

    struct State {
        var cleaned: String?
        var cleanMs: Int?
        var translateMs: Int?
        var source: String?
        var error: String?
    }

    var snapshot: State { lock.withLock { state } }
    func reset() { lock.withLock { state = State() } }
    func update(_ change: (inout State) -> Void) { lock.withLock { change(&state) } }
}

// MARK: - Engines

enum TranslateEngineError: Error, CustomStringConvertible {
    case noSourceLanguage
    case noTarget

    var description: String {
        switch self {
        case .noSourceLanguage: return "no source language readable in the input"
        case .noTarget: return "the task names no fixed output language"
        }
    }
}

/// The language a translate task writes in. The pipeline hands the engine the PROMPT
/// language, which for a Smart Mode is the transcript's, so the target is read off the
/// contract — the same place the guardrail reads it from.
func translateTarget(of task: PolishTask) -> SupportedLanguage? {
    if case .fixed(let language) = task.contract.outputLanguage { return language }
    return nil
}

#if canImport(Translation)
/// Apple's Translation framework behind `PolishEngineProtocol` (#648, arms B, C, D).
///
/// Three adaptations, each forced by a measured behaviour of the framework rather than
/// chosen (bars.md §1):
///
/// - **The source language is passed, not inferred.** A session built for `fr` and
///   handed Italian returns the Italian untranslated, without an error. The source is the
///   dominant language `PolishLanguageMix` reads — the measurement the pipeline already
///   elects the polish target from.
/// - **Source == target returns the input.** The framework refuses `en → en` as an
///   unsupported pair; the shipped prompt's rule 8 asks for the input back unchanged.
/// - **Line breaks are carried by the marker, not by the framework.** A newline comes
///   back as a blank line, so the text is split on `<<NL>>`, each segment translated,
///   and the marker put back where it was.
@available(macOS 26.4, *)
struct TranslationFrameworkEngine: PolishEngineProtocol {
    let identifier: String
    let log: TranslatePassLog
    /// Stored as a flag because `TranslationSession.Strategy` is not `Sendable`, and the
    /// engine protocol is.
    private let isLowLatency: Bool
    private var strategy: TranslationSession.Strategy { isLowLatency ? .lowLatency : .highFidelity }

    init(strategy: TranslationSession.Strategy, log: TranslatePassLog) {
        self.isLowLatency = strategy == .lowLatency
        self.log = log
        self.identifier = "translation-framework." + (isLowLatency ? "lowLatency" : "highFidelity")
    }

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        guard let target = translateTarget(of: task) else { throw TranslateEngineError.noTarget }
        let plain = raw.replacingOccurrences(of: PolishPostpass.newlineMarker, with: "\n")
        guard let source = PolishLanguageMix.measure(plain).dominantCode else {
            log.update { $0.error = "translator: \(TranslateEngineError.noSourceLanguage)" }
            throw TranslateEngineError.noSourceLanguage
        }
        log.update { $0.source = source }
        let sourceLanguage = Locale.Language(identifier: source)
        let targetLocale = Locale.Language(identifier: target.rawValue)
        if sourceLanguage.languageCode == targetLocale.languageCode { return raw }
        let session = TranslationSession(installedSource: sourceLanguage, target: targetLocale,
                                         preferredStrategy: strategy)
        var segments: [String] = []
        do {
            for segment in raw.components(separatedBy: PolishPostpass.newlineMarker) {
                let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    segments.append(segment)
                    continue
                }
                let response = try await session.translate(trimmed)
                segments.append(response.targetText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch {
            log.update { $0.error = "translator: \(error)" }
            throw error
        }
        return segments.joined(separator: PolishPostpass.newlineMarker)
    }
}

@available(macOS 26.4, *)
func translationStrategy(named name: String) -> TranslationSession.Strategy? {
    switch name {
    case "lowLatency": return .lowLatency
    case "highFidelity": return .highFidelity
    default: return nil
    }
}

/// Whether `source → target` is installed for `strategy`, in the framework's own words.
@available(macOS 26.4, *)
func translationAvailability(strategy: TranslationSession.Strategy, source: String, target: String) async -> String {
    let status = await LanguageAvailability(preferredStrategy: strategy).status(
        from: Locale.Language(identifier: source), to: Locale.Language(identifier: target)
    )
    switch status {
    case .installed: return "installed"
    case .supported: return "supported, NOT installed"
    case .unsupported: return "unsupported"
    @unknown default: return "unknown status"
    }
}
#endif

/// An Apple FM cleaning pass in the source language, then a translator (#648, arms D, E).
///
/// The cleaning pass is `FramedAppleFMPolishEngine` with the research prompt passed by
/// path: same model, same one-session-per-call lifecycle as every other harness arm. Its
/// output is recorded in the log so the cleaned text can be read on its own — the 14:14
/// comment's point that two passes make each step measurable is only true if each step
/// is visible.
@available(macOS 26.0, *)
struct TwoPassTranslateEngine: PolishEngineProtocol {
    let identifier: String
    let cleaner: FramedAppleFMPolishEngine
    let translator: any PolishEngineProtocol
    let log: TranslatePassLog

    init(cleaner: FramedAppleFMPolishEngine, translator: any PolishEngineProtocol, log: TranslatePassLog) {
        self.cleaner = cleaner
        self.translator = translator
        self.log = log
        self.identifier = "clean+" + translator.identifier
    }

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        let cleanStart = Date()
        let cleaned: String
        do {
            cleaned = try await cleaner.polish(raw: raw, targetLanguage: targetLanguage, task: task)
        } catch {
            log.update { $0.error = "clean: \(error)" }
            throw error
        }
        let cleanMs = Int(Date().timeIntervalSince(cleanStart) * 1000)
        log.update {
            $0.cleaned = cleaned
            $0.cleanMs = cleanMs
        }
        let translateStart = Date()
        do {
            let translated = try await translator.polish(raw: cleaned, targetLanguage: targetLanguage, task: task)
            let translateMs = Int(Date().timeIntervalSince(translateStart) * 1000)
            log.update { $0.translateMs = translateMs }
            return translated
        } catch {
            log.update { state in
                if state.error == nil { state.error = "translator: \(error)" }
            }
            throw error
        }
    }

    /// The cleaning pass is the call with a prompt to price; the translator is asked too,
    /// on the raw as an upper bound, because the cleaned text does not exist yet.
    func contextFit(input: String, targetLanguage: SupportedLanguage, task: PolishTask) -> PolishContextFit {
        let first = cleaner.contextFit(input: input, targetLanguage: targetLanguage, task: task)
        if case .exceeds = first { return first }
        return translator.contextFit(input: input, targetLanguage: targetLanguage, task: task)
    }

    /// Pass 1 is Apple FM, so the input has to be readable by it (#490).
    func inputLanguageSupport(countedCodes: Set<String>) -> PolishInputLanguageSupport {
        cleaner.inputLanguageSupport(countedCodes: countedCodes)
    }

    func failureReason(for error: Error) -> PolishFailureReason {
        cleaner.failureReason(for: error)
    }
}

// MARK: - The round

struct TranslateRoundOptions {
    let label: String
    let translator: String
    let strategy: String?
    let cleanPrompt: String?
    let cleanFraming: String?
    let barPaths: [String]
    let runs: Int
    /// Fixture ids whose text never leaves the private capture.
    let redacted: Set<String>
    let jsonOut: String?
    let publicJSONOut: String?
    let publicLogOut: String?
}

struct TranslateRun: Codable {
    let arm: String
    let fixture: String
    let run: Int
    let outcome: String
    let rejectedCheck: String?
    let failure: String?
    let engineMs: Int
    let cleanMs: Int?
    let translateMs: Int?
    let source: String?
    let cleaned: String?
    let output: String?
    let score: TranslateScore

    var accepted: Bool { outcome == PolishMetrics.Outcome.success.rawValue }
    var hasOutput: Bool { output != nil }

    func redacted() -> TranslateRun {
        TranslateRun(arm: arm, fixture: fixture, run: run, outcome: outcome, rejectedCheck: rejectedCheck,
                     failure: failure, engineMs: engineMs, cleanMs: cleanMs, translateMs: translateMs,
                     source: source, cleaned: cleaned.map { _ in redactedText }, output: output.map { _ in redactedText },
                     score: score.redacted())
    }

    var flags: [String] {
        var flags: [String] = []
        if !score.drop.isEmpty { flags.append("(a)×\(score.drop.count)") }
        if !score.keep.isEmpty { flags.append("(b)×\(score.keep.count)") }
        if !score.add.isEmpty { flags.append("(c)×\(score.add.count)") }
        if hasOutput, score.outputLanguage != "en" { flags.append("(d)LANG=\(score.outputLanguage ?? "?")") }
        if !score.critical.isEmpty { flags.append("(e)×\(score.critical.count)") }
        if !score.expect.isEmpty { flags.append("#412×\(score.expect.count)") }
        return flags
    }
}

let redactedText = "<private fixture: text kept in .local-corpus/648-translate/>"

/// Two renderings of every line: the full one for the terminal and the private capture,
/// and the redacted one for the committed capture.
struct TranslateLog {
    private(set) var publicLines: [String] = []

    mutating func line(_ full: String, public redacted: String? = nil) {
        print(full)
        publicLines.append(redacted ?? full)
    }
}

@available(macOS 26.0, *)
func makeTranslateEngine(_ options: TranslateRoundOptions, log: TranslatePassLog) async -> any PolishEngineProtocol {
    let translator: any PolishEngineProtocol
    switch options.translator {
    case "apple-fm":
        guard options.strategy == nil else {
            print("error: --strategy belongs to --translator translation-framework")
            exit(2)
        }
        translator = AppleFoundationModelsPolishEngine()
    case "translation-framework":
        #if canImport(Translation)
        guard #available(macOS 26.4, *) else {
            print("error: TranslationSession(installedSource:target:preferredStrategy:) needs macOS 26.4")
            exit(1)
        }
        guard let name = options.strategy, let strategy = translationStrategy(named: name) else {
            print("error: --translator translation-framework needs --strategy lowLatency|highFidelity")
            exit(2)
        }
        translator = TranslationFrameworkEngine(strategy: strategy, log: log)
        #else
        print("error: the Translation framework is not importable on this toolchain")
        exit(1)
        #endif
    default:
        print("error: unknown --translator \(options.translator) (expected apple-fm or translation-framework)")
        exit(2)
    }
    guard let cleanPrompt = options.cleanPrompt else {
        guard options.cleanFraming == nil else {
            print("error: --clean-framing needs --clean")
            exit(2)
        }
        return translator
    }
    guard let framingPath = options.cleanFraming else {
        print("error: --clean needs --clean-framing (the cleaning pass's user turn is part of its prompt)")
        exit(2)
    }
    guard let instructions = try? String(contentsOfFile: cleanPrompt, encoding: .utf8),
          let framing = try? String(contentsOfFile: framingPath, encoding: .utf8) else {
        print("error: cannot read \(cleanPrompt) or \(framingPath)")
        exit(1)
    }
    let cleaner = FramedAppleFMPolishEngine(
        instructions: instructions,
        framing: framing.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    return TwoPassTranslateEngine(cleaner: cleaner, translator: translator, log: log)
}

@available(macOS 26.0, *)
func runTranslateRound(fixtures: [Fixture], mode: SmartMode?, options: TranslateRoundOptions) async {
    guard let mode, let target = translateTarget(of: .smart(mode)) else {
        print("error: translate needs --mode translate.<target>")
        exit(2)
    }
    let bars = loadTranslateBars(options.barPaths)
    let passLog = TranslatePassLog()
    let engine = await makeTranslateEngine(options, log: passLog)
    var log = TranslateLog()
    log.line("████ ARM \(options.label) — engine \(engine.identifier), mode \(mode.id), "
             + "\(options.runs) run(s) × \(fixtures.count) fixture(s)")
    if let clean = options.cleanPrompt { log.line("     clean prompt: \(clean)") }
    if !options.barPaths.isEmpty { log.line("     bars: \(options.barPaths.count) file(s), \(bars.byID.count) entries") }
    await logTranslatorAvailability(options, fixtures: fixtures, target: target, log: &log)

    var all: [TranslateRun] = []
    for fixture in fixtures {
        let isPrivate = options.redacted.contains(fixture.id)
        let fixtureBars = bars.bars(for: fixture.id)
        log.line("\n━━ [\(fixture.id)] \(fixture.raw.count) chars, lang=\(fixture.lang)")
        log.line("  raw: \(fixture.raw)", public: isPrivate ? "  raw: \(redactedText)" : nil)
        for index in 1...max(1, options.runs) {
            passLog.reset()
            let outcome = await runOnce(fixture, engine: engine, mode: mode)
            let pass = passLog.snapshot
            let output = outcome.engineOutput
            var score = output.map { TranslateScore.score(output: $0, bars: fixtureBars) } ?? TranslateScore()
            score.expect = expectationMisses(fixture, outcome: outcome)
            let run = TranslateRun(
                arm: options.label, fixture: fixture.id, run: index, outcome: outcome.outcome.rawValue,
                rejectedCheck: outcome.rejectedCheck?.rawValue,
                failure: pass.error ?? outcome.failureReason?.slug,
                engineMs: outcome.engineMs, cleanMs: pass.cleanMs,
                translateMs: pass.translateMs ?? (pass.cleanMs == nil ? outcome.engineMs : nil),
                source: pass.source, cleaned: pass.cleaned, output: output, score: score
            )
            all.append(run)
            logRun(run, isPrivate: isPrivate, log: &log)
        }
    }
    logTranslateSummary(all, label: options.label, log: &log)
    writeTranslateCapture(all, to: options.jsonOut)
    writeTranslateCapture(all.map { options.redacted.contains($0.fixture) ? $0.redacted() : $0 },
                          to: options.publicJSONOut)
    if let path = options.publicLogOut {
        do {
            try (log.publicLines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
            print("public log written: \(path)")
        } catch {
            print("error: cannot write \(path): \(error)")
        }
    }
}

/// The framework's own availability verdict for every source the fixtures read as, so a
/// capture says plainly whether the pair it measured was installed (bars.md §1).
@available(macOS 26.0, *)
func logTranslatorAvailability(_ options: TranslateRoundOptions, fixtures: [Fixture],
                               target: SupportedLanguage, log: inout TranslateLog) async {
    #if canImport(Translation)
    guard options.translator == "translation-framework", #available(macOS 26.4, *),
          let name = options.strategy, let strategy = translationStrategy(named: name) else { return }
    let sources = Set(fixtures.compactMap { PolishLanguageMix.measure($0.raw).dominantCode }).sorted()
    for source in sources where source != target.rawValue {
        let status = await translationAvailability(strategy: strategy, source: source, target: target.rawValue)
        log.line("     availability \(name) \(source) → \(target.rawValue): \(status)")
    }
    #endif
}

/// The fixture's own `expect` entries the run misses — #412's bars on `translate-en.json`.
@available(macOS 26.0, *)
func expectationMisses(_ fixture: Fixture, outcome: RunOutcome) -> [String] {
    let evidence = RunEvidence(
        polished: outcome.final, raw: fixture.raw, preprocessed: outcome.preprocessed,
        engineOutput: outcome.engineOutput, outcome: outcome.outcome.rawValue,
        failureReason: outcome.failureReason?.slug
    )
    let route = Expectation.routeName(perLanguage: fixture.language != nil)
    return (fixture.expect ?? []).filter { $0.applies(to: route) }.compactMap { $0.failure(evidence) }
}

func logRun(_ run: TranslateRun, isPrivate: Bool, log: inout TranslateLog) {
    let verdict = run.rejectedCheck.map { "\(run.outcome)/\($0)" } ?? run.outcome
    let timing = run.cleanMs.map { "clean \($0)ms + translate \(run.translateMs.map(String.init) ?? "-")ms" }
        ?? "\(run.engineMs)ms"
    let failure = run.failure.map { " failure=\($0)" } ?? ""
    let flags = run.flags.isEmpty ? "" : "  ⚑ " + run.flags.joined(separator: " ")
    log.line("  #\(run.run) \(verdict) \(timing) source=\(run.source ?? "-")\(failure)\(flags)")
    if let cleaned = run.cleaned {
        let shown = cleaned.replacingOccurrences(of: "\n", with: "⏎")
        log.line("     clean: \(shown)", public: isPrivate ? "     clean: \(redactedText)" : nil)
    }
    let output = (run.output ?? "<no engine output>").replacingOccurrences(of: "\n", with: "⏎")
    log.line("     out:   \(output)", public: isPrivate ? "     out:   \(redactedText)" : nil)
    // The public line of a private fixture prints what `TranslateScore.redacted` keeps.
    let shown = run.score.redacted()
    let bars: [(String, [String])] = [
        ("a", run.score.drop), ("b", run.score.keep), ("c", run.score.add),
        ("e", run.score.critical), ("412", run.score.expect)
    ]
    let redactedBars = [shown.drop, shown.keep, shown.add, shown.critical, shown.expect]
    for ((bar, failures), redactedFailures) in zip(bars, redactedBars) {
        for (failure, redactedFailure) in zip(failures, redactedFailures) {
            log.line("     (\(bar)) \(failure)", public: isPrivate ? "     (\(bar)) \(redactedFailure)" : nil)
        }
    }
}

/// One row per fixture and a total: how many runs raised each bar, and the latency.
func logTranslateSummary(_ all: [TranslateRun], label: String, log: inout TranslateLog) {
    log.line("\n══ arm \(label): runs with at least one flag, per bar (engine outputs)")
    log.line("fixture | runs | accepted | (a) drop | (b) keep | (c) add | (d) not en | (e) critical | #412 expect | median ms | max ms")
    let fixtureIDs = all.map(\.fixture).reduce(into: [String]()) { ids, id in
        if !ids.contains(id) { ids.append(id) }
    }
    for id in fixtureIDs + ["ALL"] {
        let rows = id == "ALL" ? all : all.filter { $0.fixture == id }
        let scored = rows.filter(\.hasOutput)
        let times = rows.map(\.engineMs).sorted()
        let cells = [
            id, "\(rows.count)", "\(rows.filter(\.accepted).count)",
            "\(scored.filter { !$0.score.drop.isEmpty }.count)",
            "\(scored.filter { !$0.score.keep.isEmpty }.count)",
            "\(scored.filter { !$0.score.add.isEmpty }.count)",
            "\(scored.filter { $0.score.outputLanguage != "en" }.count)",
            "\(scored.filter { !$0.score.critical.isEmpty }.count)",
            "\(rows.filter { !$0.score.expect.isEmpty }.count)",
            "\(times.isEmpty ? 0 : times[times.count / 2])", "\(times.last ?? 0)"
        ]
        log.line(cells.joined(separator: " | "))
    }
    let cleanTimes = all.compactMap(\.cleanMs).sorted()
    let translateTimes = all.compactMap(\.translateMs).sorted()
    if !cleanTimes.isEmpty {
        log.line("pass latency: clean median \(cleanTimes[cleanTimes.count / 2])ms max \(cleanTimes.last ?? 0)ms; "
                 + "translate median \(translateTimes.isEmpty ? 0 : translateTimes[translateTimes.count / 2])ms "
                 + "max \(translateTimes.last ?? 0)ms")
    }
    let refusals = Dictionary(grouping: all.filter { !$0.accepted }, by: { $0.rejectedCheck ?? $0.outcome })
    let line = refusals.sorted { $0.key < $1.key }.map { "\($0.key)×\($0.value.count)" }.joined(separator: ", ")
    log.line("not accepted: \(line.isEmpty ? "none" : line)")
}

func writeTranslateCapture(_ all: [TranslateRun], to path: String?) {
    guard let path else { return }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(all) else {
        print("error: cannot encode the capture")
        return
    }
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("capture written: \(path)")
    } catch {
        print("error: cannot write \(path): \(error)")
    }
}
#endif
