// DictusCore/Sources/DictusCore/Polish/TranslateRoutingPolishEngine.swift
import Foundation
#if canImport(Translation)
import Translation
#endif

/// The Apple FM engine, with the Translate Smart Mode optionally routed to Apple's
/// Translation framework — the #648 device test.
///
/// ### Nothing changes unless the debug switch is set
///
/// Every call reads `TranslateEngineChoice.current`. On `.appleFM`, the default and
/// the only value a user who never opened the debug screen can have, every method
/// forwards to the wrapped engine and nothing else runs: no log line, no availability
/// read, no framework call. The identifier is the wrapped engine's, so the
/// availability gate (#315) and the polish export key on `apple-fm` exactly as before.
///
/// ### Fall back, never pass the raw through
///
/// With a Translation strategy selected and a Translate mode armed, the framework is
/// tried first. Every way it can decline — no known source language, source equal to
/// target, an OS older than 26.4, a pair not installed for the strategy, an error, a
/// deadline — falls back to the Apple FM path the mode ships with, and says why in one
/// `translateEngineCall` line. Returning the input untouched is never an outcome: the
/// framework refuses a same-language pair and silently returns untranslated text when
/// handed the wrong source (both measured on the Mac for #648), and a raw transcript
/// inserted under "Translate" is the failure #79 names worst.
///
/// ### The source is the language Dictus already knows
///
/// `PolishJob.transcriptLanguageCode`, handed over by `PolishPipeline`: the
/// transcription language the user forced, else the one detected in the transcript.
public struct TranslateRoutingPolishEngine: PolishEngineProtocol {

    /// How long the framework may run before Apple FM takes over. The keyboard's own
    /// ceiling is at least 15 s (`PolishTimeBudget`); 8 s leaves an Apple FM fallback
    /// on a short dictation room inside it.
    static let deadlineSeconds = 8

    private let inner: PolishEngineProtocol
    /// The caller's application state for the log line. The keyboard extension has
    /// none and passes a constant.
    private let appState: @Sendable () async -> String

    public init(wrapping inner: PolishEngineProtocol, appState: @escaping @Sendable () async -> String) {
        self.inner = inner
        self.appState = appState
    }

    public var identifier: String { inner.identifier }
    public var announcesProcessingStage: Bool { inner.announcesProcessingStage }

    public func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        try await polish(raw: raw, targetLanguage: targetLanguage, task: task, sourceLanguageCode: nil)
    }

    public func polish(raw: String,
                       targetLanguage: SupportedLanguage,
                       task: PolishTask,
                       sourceLanguageCode: String?) async throws -> String {
        let choice = TranslateEngineChoice.current
        guard choice != .appleFM, let target = Self.translateTarget(of: task) else {
            return try await inner.polish(raw: raw, targetLanguage: targetLanguage, task: task,
                                          sourceLanguageCode: sourceLanguageCode)
        }
        if let translated = await attemptTranslation(raw, source: sourceLanguageCode, target: target, choice: choice) {
            return translated
        }
        return try await inner.polish(raw: raw, targetLanguage: targetLanguage, task: task,
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

    /// The target of a Translate mode, or nil for any other task.
    static func translateTarget(of task: PolishTask) -> SupportedLanguage? {
        guard let mode = task.smartMode else { return nil }
        return SupportedLanguage.allCases.first { SmartModeCatalogue.translateIdentifier(target: $0) == mode.id }
    }

    // MARK: - The framework attempt

    /// One Translation-framework attempt: the translated text, or nil after logging why
    /// Apple FM has to run instead. Logs exactly one line either way.
    private func attemptTranslation(_ raw: String, source: String?, target: SupportedLanguage,
                                    choice: TranslateEngineChoice) async -> String? {
        var line = CallLine(strategy: choice.strategyName, source: source ?? "-", target: target.rawValue)
        line.memBeforeMB = MemoryFootprint.residentMB()
        line.memPeakMB = line.memBeforeMB
        let start = Date()
        defer {
            line.ms = Int(Date().timeIntervalSince(start) * 1000)
            line.memAfterMB = MemoryFootprint.residentMB()
            line.memPeakMB = max(line.memPeakMB, line.memAfterMB)
            line.log()
        }
        line.appState = await appState()
        guard let source else {
            line.reason = "noSourceLanguage"
            return nil
        }
        guard Locale.Language(identifier: source).languageCode?.identifier != target.rawValue else {
            line.reason = "sameLanguage"
            return nil
        }
        #if canImport(Translation)
        guard #available(iOS 26.4, macOS 26.4, *) else {
            line.reason = "osBelow26.4"
            return nil
        }
        let lowLatency = choice == .translationLowLatency
        let status = await Self.status(source: source, target: target.rawValue, lowLatency: lowLatency)
        line.status = status
        guard status == "installed" else {
            line.reason = "notInstalled"
            return nil
        }
        let sampler = PeakMemorySampler()
        let sampling = Task.detached(priority: .utility) { await sampler.run() }
        defer { sampling.cancel() }
        do {
            let output = try await withDetachedDeadline(seconds: Self.deadlineSeconds) {
                try await Self.translate(raw, source: source, target: target.rawValue, lowLatency: lowLatency)
            }
            line.memPeakMB = max(line.memPeakMB, await sampler.peakMB)
            line.outcome = "translated"
            line.reason = "-"
            return output
        } catch let expired as DeadlineExpired {
            line.memPeakMB = max(line.memPeakMB, await sampler.peakMB)
            line.reason = "deadline\(expired.seconds)s"
            return nil
        } catch {
            line.memPeakMB = max(line.memPeakMB, await sampler.peakMB)
            line.reason = Self.slug(of: error)
            return nil
        }
        #else
        line.reason = "frameworkUnavailable"
        return nil
        #endif
    }

    #if canImport(Translation)
    @available(iOS 26.4, macOS 26.4, *)
    private static func status(source: String, target: String, lowLatency: Bool) async -> String {
        let availability = LanguageAvailability(preferredStrategy: lowLatency ? .lowLatency : .highFidelity)
        let status = await availability.status(from: Locale.Language(identifier: source),
                                               to: Locale.Language(identifier: target))
        switch status {
        case .installed: return "installed"
        case .supported: return "supported"
        case .unsupported: return "unsupported"
        @unknown default: return "unknown"
        }
    }

    /// Translate segment by segment between `<<NL>>` markers: the framework turns a
    /// newline into a blank line, so the marker carries the break instead.
    @available(iOS 26.4, macOS 26.4, *)
    private static func translate(_ raw: String, source: String, target: String, lowLatency: Bool) async throws -> String {
        let session = TranslationSession(installedSource: Locale.Language(identifier: source),
                                         target: Locale.Language(identifier: target),
                                         preferredStrategy: lowLatency ? .lowLatency : .highFidelity)
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

/// The fields of one `translateEngineCall` line, filled as the attempt goes.
private struct CallLine {
    let strategy: String
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

    init(strategy: String, source: String, target: String) {
        self.strategy = strategy
        self.source = source
        self.target = target
    }

    func log() {
        PersistentLog.log(.translateEngineCall(
            strategy: strategy, status: status, source: source, target: target, outcome: outcome,
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
