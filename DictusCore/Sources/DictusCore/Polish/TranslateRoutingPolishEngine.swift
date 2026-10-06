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
/// `.highFidelity` strategy fixed both, runs inside the keyboard extension (4.2 s,
/// 21 → 22 MB on an iPhone 15 Pro Max) and reads naturally. Measured on #648 with test
/// build PR #669. It is not perfect: it still gives a meaning to speech-to-text garbage
/// and keeps disfluencies, which the Apple FM prompt did not fix either.
///
/// ### Every other task is untouched
///
/// Free polish and every other Smart Mode go straight to the wrapped engine. The
/// identifier is the wrapped engine's, so the availability gate (#315) keys on
/// `apple-fm` as it always has.
///
/// ### Fall back, never pass the raw through
///
/// Each way the framework can decline falls back to the Apple FM prompt Translate
/// shipped with, and the `translateEngineCall` line says why: no known source, source
/// equal to target, an OS below 26.4, a pair not installed, an error, the deadline, or
/// an answer identical to the input.
/// The availability check is read first, and an error is still caught after it,
/// because the device test saw the framework throw `notInstalled` on a pair it had just
/// reported `installed`. Returning the input untouched is never an outcome: the
/// framework refuses a same-language pair and silently returns untranslated text when
/// handed the wrong source, and a raw transcript inserted under "Translate" is the
/// failure #79 names worst.
///
/// ### The source is the language Dictus already knows
///
/// `PolishJob.transcriptLanguageCode`, handed over by `PolishPipeline`: the
/// transcription language the user forced, else the one detected in the transcript.
public struct TranslateRoutingPolishEngine: PolishEngineProtocol {

    /// The `engine` value of a polish record whose text the framework wrote.
    public static let translationEngineLabel = "translation.highFidelity"

    /// How long the framework may run before Apple FM takes over. The keyboard's own
    /// ceiling is at least 15 s (`PolishTimeBudget`); 8 s leaves an Apple FM fallback
    /// on a short dictation room inside it. The device measured 1.3 to 6.8 s.
    static let deadlineSeconds = 8

    private let inner: PolishEngineProtocol
    /// The caller's application state for the log line. The keyboard extension has
    /// none and passes a constant.
    private let appState: @Sendable () async -> String
    /// The framework call, injectable so the routing and fallback rules are testable
    /// without Apple Intelligence. Production uses `TranslationFrameworkCall.live`.
    private let framework: TranslationFrameworkCall

    public init(wrapping inner: PolishEngineProtocol,
                appState: @escaping @Sendable () async -> String) {
        self.init(wrapping: inner, appState: appState, framework: .live)
    }

    init(wrapping inner: PolishEngineProtocol,
         appState: @escaping @Sendable () async -> String,
         framework: TranslationFrameworkCall) {
        self.inner = inner
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
        if let mode = task.smartMode, let target = TranslationLanguagePair.translateTarget(of: mode),
           let translated = await attemptTranslation(raw, source: sourceLanguageCode, target: target) {
            return PolishEngineOutput(text: translated, engine: Self.translationEngineLabel)
        }
        return try await inner.polishLabelled(raw: raw, targetLanguage: targetLanguage, task: task,
                                              sourceLanguageCode: sourceLanguageCode)
    }

    public func prewarm(task: PolishTask, targetLanguage: SupportedLanguage) async {
        await inner.prewarm(task: task, targetLanguage: targetLanguage)
    }

    public func contextFit(input: String, targetLanguage: SupportedLanguage, task: PolishTask) -> PolishContextFit {
        inner.contextFit(input: input, targetLanguage: targetLanguage, task: task)
    }

    public func inputLanguageSupport(countedCodes: Set<String>) -> PolishInputLanguageSupport {
        inner.inputLanguageSupport(countedCodes: countedCodes)
    }

    public func failureReason(for error: Error) -> PolishFailureReason {
        inner.failureReason(for: error)
    }

    // MARK: - The framework attempt

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

    /// One framework attempt: the translated text, or nil after logging why Apple FM
    /// has to run instead. Logs exactly one `translateEngineCall` line either way.
    private func attemptTranslation(_ raw: String, source: String?, target: SupportedLanguage) async -> String? {
        var line = TranslateCallLine(source: source ?? "-", target: target.rawValue)
        line.memBeforeMB = MemoryFootprint.residentMB()
        let start = Date()
        defer {
            line.ms = Int(Date().timeIntervalSince(start) * 1000)
            line.memAfterMB = MemoryFootprint.residentMB()
            line.memPeakMB = max(line.memPeakMB, line.memBeforeMB, line.memAfterMB)
            line.log()
        }
        line.appState = await appState()
        let result = await translate(raw, source: source, target: target, line: &line)
        switch result {
        case .success(let text):
            line.outcome = "translated"
            return text
        case .failure(let declined):
            line.reason = declined.decline.slug
            return nil
        }
    }

    private func translate(_ raw: String, source: String?, target: SupportedLanguage,
                           line: inout TranslateCallLine) async -> Result<String, DeclineError> {
        guard let source else { return .failure(DeclineError(.noSourceLanguage)) }
        guard let pair = TranslationLanguagePair(source: source, target: target) else {
            return .failure(DeclineError(.sameLanguage))
        }
        let status = await framework.status(pair)
        line.status = status.rawValue
        switch status {
        case .installed: break
        case .unknown: return .failure(DeclineError(.osBelow26_4))
        case .notInstalled, .unsupported: return .failure(DeclineError(.notInstalled(status)))
        }
        let sampler = PeakMemorySampler()
        let sampling = Task.detached(priority: .utility) { await sampler.run() }
        defer { sampling.cancel() }
        let framework = self.framework
        do {
            let output = try await withDetachedDeadline(seconds: Self.deadlineSeconds) {
                try await framework.translate(raw, pair)
            }
            line.memPeakMB = await sampler.peakMB
            guard Self.normalised(output) != Self.normalised(raw) else {
                return .failure(DeclineError(.untranslated))
            }
            return .success(output)
        } catch let expired as DeadlineExpired {
            line.memPeakMB = await sampler.peakMB
            return .failure(DeclineError(.deadline(expired.seconds)))
        } catch {
            line.memPeakMB = await sampler.peakMB
            return .failure(DeclineError(.error(Self.slug(of: error))))
        }
    }

    /// `Decline` as an `Error`, so it fits `Result`.
    struct DeclineError: Error {
        let decline: Decline
        init(_ decline: Decline) { self.decline = decline }
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

/// The two framework calls the engine makes, as values so a test can replace them.
struct TranslationFrameworkCall: Sendable {
    let status: @Sendable (TranslationLanguagePair) async -> TranslationPairStatus
    let translate: @Sendable (String, TranslationLanguagePair) async throws -> String

    /// Apple's Translation framework, `.highFidelity`.
    static let live = TranslationFrameworkCall(
        status: { await TranslationPairStatus.current(for: $0) },
        translate: { raw, pair in
            #if canImport(Translation)
            guard #available(iOS 26.4, macOS 26.4, *) else { throw TranslationUnavailable() }
            return try await translateSegments(raw, pair: pair)
            #else
            throw TranslationUnavailable()
            #endif
        }
    )

    struct TranslationUnavailable: Error {}

    #if canImport(Translation)
    /// Translate segment by segment between `<<NL>>` markers: the framework turns a
    /// newline into a blank line, so the marker carries the break instead.
    @available(iOS 26.4, macOS 26.4, *)
    private static func translateSegments(_ raw: String, pair: TranslationLanguagePair) async throws -> String {
        let session = TranslationSession(installedSource: Locale.Language(identifier: pair.source),
                                         target: Locale.Language(identifier: pair.target.rawValue),
                                         preferredStrategy: .highFidelity)
        var segments: [String] = []
        for segment in raw.components(separatedBy: PolishPostpass.newlineMarker) {
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                segments.append(segment)
                continue
            }
            segments.append(try await session.translate(trimmed).targetText
                .trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return segments.joined(separator: PolishPostpass.newlineMarker)
    }
    #endif
}

/// The fields of one `translateEngineCall` line, filled as the attempt goes.
struct TranslateCallLine {
    let source: String
    let target: String
    var status = "-"
    var outcome = "fallback"
    var reason = "-"
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
            reason: reason, ms: ms, process: PersistentLog.source, appState: appState,
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
