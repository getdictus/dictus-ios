// DictusCore/Sources/DictusCore/Polish/TranslateRoutingPolishEngine.swift
import Foundation
#if canImport(Translation)
import Translation
#endif

/// The polish engine: Apple FM, with the Translate Smart Mode run on Apple's
/// Translation framework (`.highFidelity`) and Apple FM as its fallback (#648).
///
/// ### Why Translate leaves the Apple FM prompt
///
/// Prompting the general chat model to translate inverted plain French on device
/// (`passer sur la phase de marketing` → `skip`, `vocaux` → `vowels`). The framework's
/// `.highFidelity` strategy fixed both, runs inside the keyboard extension (0.8 to
/// 4.2 s, 21 to 27 MB on an iPhone 15 Pro Max) and reads naturally. Measured on #648
/// with test build PR #669 and with this PR's first build. It is not perfect: it still
/// gives a meaning to speech-to-text garbage and keeps disfluencies, which the Apple FM
/// prompt did not fix either.
///
/// ### Every other task is untouched
///
/// Free polish and every other Smart Mode go straight to the wrapped engine. The
/// identifier is the wrapped engine's, so the availability gate (#315) keys on
/// `apple-fm` as it always has.
///
/// ### Chunked, on a budget that depends on the process
///
/// The text is translated in sentence-aligned chunks (`TranslationChunking`) under a
/// `TranslationTimeBudget`: 8 s in the keyboard, scaled to the input in DictusApp,
/// where voice notes run minutes long. Cancellation is checked between chunks, so a
/// superseded call stops spending.
///
/// ### Fall back, never pass the raw through
///
/// Each way the framework can decline falls back to the Apple FM prompt Translate
/// shipped with, and the `translateEngineCall` line says why: no known source, source
/// equal to target, an OS below 26.4, a pair not installed, an error, the keyboard's
/// deadline, or an answer identical to the input. The availability check is read
/// first, and an error is still caught after it, because the device test saw the
/// framework throw `notInstalled` on a pair it had just reported `installed`.
/// Returning the input untouched is never an outcome: the framework refuses a
/// same-language pair and silently returns untranslated text when handed the wrong
/// source, and a raw transcript inserted under "Translate" is the failure #79 names
/// worst.
///
/// Two exceptions, both about long text. In DictusApp a timeout fails the mode instead
/// of falling back (see `TranslationTimeBudget`). And a fallback whose text does not fit
/// Apple FM's context window throws `FallbackExceedsContext` rather than calling it:
/// `contextFit` answers `.fits` for a Translate task, because the framework has no
/// window, so the check Apple FM needs is made here, at the moment it is needed.
///
/// ### The source is the language Dictus already knows
///
/// `PolishJob.transcriptLanguageCode`, handed over by `PolishPipeline`: the
/// transcription language the user forced, else the one detected in the transcript.
public struct TranslateRoutingPolishEngine: PolishEngineProtocol {

    /// The `engine` value of a polish record whose text the framework wrote.
    public static let translationEngineLabel = "translation.highFidelity"

    private let inner: PolishEngineProtocol
    /// The caller's application state for the log line. The keyboard extension has
    /// none and passes a constant.
    private let appState: @Sendable () async -> String
    /// How long the framework may take in this process, and what a timeout means.
    private let budget: TranslationTimeBudget
    /// The framework calls, injectable so the routing and fallback rules are testable
    /// without Apple Intelligence. Production uses `TranslationFrameworkCall.live`.
    private let framework: TranslationFrameworkCall

    public init(wrapping inner: PolishEngineProtocol,
                budget: TranslationTimeBudget,
                appState: @escaping @Sendable () async -> String) {
        self.init(wrapping: inner, budget: budget, appState: appState, framework: .live)
    }

    init(wrapping inner: PolishEngineProtocol,
         budget: TranslationTimeBudget,
         appState: @escaping @Sendable () async -> String,
         framework: TranslationFrameworkCall) {
        self.inner = inner
        self.budget = budget
        self.appState = appState
        self.framework = framework
    }

    public var identifier: String { inner.identifier }
    public var announcesProcessingStage: Bool { inner.announcesProcessingStage }

    public func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        try await polishLabelled(raw: raw, targetLanguage: targetLanguage, task: task, sourceLanguageCode: nil).text
    }

    public func polishLabelled(raw: String,
                               targetLanguage: SupportedLanguage,
                               task: PolishTask,
                               sourceLanguageCode: String?) async throws -> PolishEngineOutput {
        guard let mode = task.smartMode, let target = TranslationLanguagePair.translateTarget(of: mode) else {
            return try await inner.polishLabelled(raw: raw, targetLanguage: targetLanguage, task: task,
                                                  sourceLanguageCode: sourceLanguageCode)
        }
        switch await attemptTranslation(raw, source: sourceLanguageCode, target: target) {
        case .translated(let text):
            return PolishEngineOutput(text: text, engine: Self.translationEngineLabel)
        case .failed(let error):
            throw error
        case .fallback:
            guard case .fits = inner.contextFit(input: raw, targetLanguage: targetLanguage, task: task) else {
                throw FallbackExceedsContext()
            }
            return try await inner.polishLabelled(raw: raw, targetLanguage: targetLanguage, task: task,
                                                  sourceLanguageCode: sourceLanguageCode)
        }
    }

    public func prewarm(task: PolishTask, targetLanguage: SupportedLanguage) async {
        await inner.prewarm(task: task, targetLanguage: targetLanguage)
    }

    /// `.fits` for a Translate task: the framework has no context window and translates
    /// in chunks. The Apple FM check is made in `polishLabelled`, if it falls back.
    public func contextFit(input: String, targetLanguage: SupportedLanguage, task: PolishTask) -> PolishContextFit {
        if let mode = task.smartMode, TranslationLanguagePair.translateTarget(of: mode) != nil { return .fits }
        return inner.contextFit(input: input, targetLanguage: targetLanguage, task: task)
    }

    public func inputLanguageSupport(countedCodes: Set<String>) -> PolishInputLanguageSupport {
        inner.inputLanguageSupport(countedCodes: countedCodes)
    }

    public func failureReason(for error: Error) -> PolishFailureReason {
        if error is FallbackExceedsContext { return .exceededContextWindowSize }
        if error is TranslationTimedOut { return .other(error) }
        return inner.failureReason(for: error)
    }

    // MARK: - Errors

    /// A Translate fallback whose text does not fit Apple FM's context window.
    public struct FallbackExceedsContext: Error {}

    /// The framework did not finish within DictusApp's budget. The mode fails rather
    /// than handing a long text to the slower Apple FM.
    public struct TranslationTimedOut: Error, Equatable {
        public let seconds: Int
    }

    // MARK: - The framework attempt

    /// What one framework attempt came to.
    enum Attempt {
        case translated(String)
        case fallback(Decline)
        /// The mode fails: cancelled, or a timeout in DictusApp.
        case failed(Error)
    }

    /// Why a Translate call did not use the framework. The `reason` field of the log.
    enum Decline: Equatable {
        case noSourceLanguage
        case sameLanguage
        case osBelow26_4
        case notInstalled(TranslationPairStatus)
        case deadline(Int)
        case error(String)
        /// The framework answered with the input itself. It does that, without an error,
        /// when told the wrong source: an English dictation transcribed under a forced
        /// French setting arrives labelled `fr`.
        case untranslated

        var slug: String {
            switch self {
            case .noSourceLanguage: return "noSourceLanguage"
            case .sameLanguage: return "sameLanguage"
            case .osBelow26_4: return "osBelow26.4"
            case .notInstalled: return "notInstalled"
            case .deadline(let seconds): return "deadline\(seconds)s"
            case .error(let slug): return slug
            case .untranslated: return "untranslated"
            }
        }
    }

    /// One framework attempt. Logs exactly one `translateEngineCall` line.
    private func attemptTranslation(_ raw: String, source: String?, target: SupportedLanguage) async -> Attempt {
        var line = TranslateCallLine(source: source ?? "-", target: target.rawValue)
        line.memBeforeMB = MemoryFootprint.residentMB()
        let start = Date()
        line.appState = await appState()
        let sampler = PeakMemorySampler()
        let sampling = Task.detached(priority: .utility) { await sampler.run() }
        let attempt = await translate(raw, source: source, target: target, line: &line)
        sampling.cancel()
        line.ms = Int(Date().timeIntervalSince(start) * 1000)
        line.memAfterMB = MemoryFootprint.residentMB()
        line.memPeakMB = max(await sampler.peakMB, line.memBeforeMB, line.memAfterMB)
        switch attempt {
        case .translated:
            line.outcome = "translated"
        case .fallback(let decline):
            line.reason = decline.slug
        case .failed(let error):
            line.outcome = "failed"
            line.reason = (error as? TranslationTimedOut).map { "deadline\($0.seconds)s" } ?? "cancelled"
        }
        line.log()
        return attempt
    }

    private func translate(_ raw: String, source: String?, target: SupportedLanguage,
                           line: inout TranslateCallLine) async -> Attempt {
        guard let source else { return .fallback(.noSourceLanguage) }
        guard let pair = TranslationLanguagePair(source: source, target: target) else {
            return .fallback(.sameLanguage)
        }
        let status = await framework.status(pair)
        line.status = status.rawValue
        switch status {
        case .installed: break
        case .unknown: return .fallback(.osBelow26_4)
        case .notInstalled, .unsupported: return .fallback(.notInstalled(status))
        }

        let pieces = TranslationChunking.pieces(raw, maxCharacters: budget.chunkCharacters)
        let overall = budget.overallSeconds(forCharacters: raw.count)
        let deadline = Date().addingTimeInterval(TimeInterval(overall))
        let session = framework.session(pair)
        var translated: [String] = []
        for piece in pieces {
            guard !piece.text.isEmpty else {
                translated.append("")
                continue
            }
            line.chunks += 1
            if Task.isCancelled {
                session.cancel()
                return .failed(CancellationError())
            }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else {
                session.cancel()
                return timedOut(overall)
            }
            let seconds = max(1, min(budget.perChunkSeconds, Int(remaining.rounded(.up))))
            let text = piece.text
            do {
                translated.append(try await withDetachedDeadline(seconds: seconds) {
                    try await session.translate(text).trimmingCharacters(in: .whitespacesAndNewlines)
                })
            } catch is DeadlineExpired {
                session.cancel()
                return timedOut(overall)
            } catch {
                if Task.isCancelled { return .failed(CancellationError()) }
                return .fallback(.error(Self.slug(of: error)))
            }
        }
        let output = TranslationChunking.join(pieces, translated: translated)
        guard Self.normalised(output) != Self.normalised(raw) else { return .fallback(.untranslated) }
        return .translated(output)
    }

    /// A timeout: Apple FM in the keyboard, a failed mode in DictusApp.
    private func timedOut(_ overall: Int) -> Attempt {
        budget.fallsBackOnTimeout ? .fallback(.deadline(overall)) : .failed(TranslationTimedOut(seconds: overall))
    }

    /// Case, surrounding whitespace and the line-break marker set aside, for the
    /// untranslated check.
    static func normalised(_ text: String) -> String {
        text.replacingOccurrences(of: PolishPostpass.newlineMarker, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    /// A log-safe name for an error: the framework's `Cause.<name>` when it has one,
    /// otherwise the type name. No message text.
    public static func slug(of error: Error) -> String {
        let described = String(describing: error)
        if let range = described.range(of: #"Cause\.[A-Za-z]+"#, options: .regularExpression) {
            return String(described[range]).replacingOccurrences(of: "Cause.", with: "error:")
        }
        return "error:\(String(describing: type(of: error)))"
    }
}

/// The framework calls the engine makes, as values so a test can replace them.
struct TranslationFrameworkCall: Sendable {
    let status: @Sendable (TranslationLanguagePair) async -> TranslationPairStatus
    /// One session per attempt, reused across its chunks.
    let session: @Sendable (TranslationLanguagePair) -> TranslationChunkSession

    /// Apple's Translation framework, `.highFidelity`.
    static let live = TranslationFrameworkCall(
        status: { await TranslationPairStatus.current(for: $0) },
        session: { pair in
            #if canImport(Translation)
            if #available(iOS 26.4, macOS 26.4, *) {
                let box = SessionBox(TranslationSession(
                    installedSource: Locale.Language(identifier: pair.source),
                    target: Locale.Language(identifier: pair.target.rawValue),
                    preferredStrategy: .highFidelity
                ))
                return TranslationChunkSession(
                    translate: { try await box.session.translate($0).targetText },
                    cancel: { box.session.cancel() }
                )
            }
            #endif
            return TranslationChunkSession(translate: { _ in throw TranslationUnavailable() }, cancel: {})
        }
    )

    struct TranslationUnavailable: Error {}
}

/// Translates one chunk at a time on one framework session.
struct TranslationChunkSession: Sendable {
    let translate: @Sendable (String) async throws -> String
    let cancel: @Sendable () -> Void
}

#if canImport(Translation)
/// `TranslationSession` is not `Sendable`. The engine uses one session per attempt, one
/// chunk after the other and never two at once, so handing it across the deadline's
/// detached task is safe; this box says so to the compiler.
@available(iOS 26.4, macOS 26.4, *)
private final class SessionBox: @unchecked Sendable {
    let session: TranslationSession
    init(_ session: TranslationSession) { self.session = session }
}
#endif

/// The fields of one `translateEngineCall` line, filled as the attempt goes.
struct TranslateCallLine {
    let source: String
    let target: String
    var status = "-"
    var outcome = "fallback"
    var reason = "-"
    var chunks = 0
    var ms = 0
    var appState = "-"
    var memBeforeMB = 0
    var memPeakMB = 0
    var memAfterMB = 0

    init(source: String, target: String) {
        self.source = source
        self.target = target
    }

    func log() {
        PersistentLog.log(.translateEngineCall(
            strategy: "highFidelity", status: status, source: source, target: target, outcome: outcome,
            reason: reason, chunks: chunks, ms: ms, process: PersistentLog.source, appState: appState,
            memBeforeMB: memBeforeMB, memPeakMB: memPeakMB, memAfterMB: memAfterMB
        ))
    }
}

/// Samples the resident footprint every 50 ms while the framework runs, because the
/// keyboard's ceiling (~70 MB, #361) is a peak, and before/after cannot see one.
private actor PeakMemorySampler {
    private(set) var peakMB = 0

    func run() async {
        while !Task.isCancelled {
            peakMB = max(peakMB, MemoryFootprint.residentMB())
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
