// DictusCore/Sources/DictusCore/LogEvent.swift
// Structured logging API with privacy-safe typed events.
// Callers log via enum cases with typed parameters -- no free-text strings.

import Foundation

// MARK: - LogLevel

/// Log severity levels for structured logging.
/// 4 levels: debug (internal details), info (normal operations),
/// warning (recoverable issues), error (failures).
public enum LogLevel: String, CaseIterable, Sendable {
    case debug, info, warning, error

    /// Level name padded to 7 characters for aligned log output.
    public var paddedName: String {
        rawValue.uppercased().padding(toLength: 7, withPad: " ", startingAt: 0)
    }
}

// MARK: - Subsystem

/// App subsystems that produce log events.
/// Each subsystem groups related events for filtering and analysis.
public enum Subsystem: String, CaseIterable, Sendable {
    case dictation, audio, transcription, model, keyboard, lifecycle
}

// MARK: - LogEvent

/// Typed log events with structured parameters.
///
/// WHY an enum instead of free-text logging:
/// Privacy by construction -- callers cannot pass arbitrary strings that might
/// contain transcription text or keystrokes. Each case defines exactly what
/// data can be logged. The `keyboardTextInserted` case intentionally has NO
/// content parameter.
///
/// Error string parameters accept framework error descriptions (WhisperKit, Parakeet,
/// AVAudioSession) which are safe to log per user decision.
public enum LogEvent: Sendable {
    // MARK: Dictation
    case dictationStarted(fromURL: Bool, appState: String, engineRunning: Bool)
    case dictationCompleted(durationMs: Int)
    case dictationFailed(error: String)
    case dictationDeferred(reason: String)

    // MARK: Audio
    case audioEngineStarted
    case audioEngineStopped
    case audioSessionConfigured(category: String)
    case audioSessionFailed(error: String)

    // MARK: Transcription
    case transcriptionStarted(modelName: String)
    case transcriptionCompleted(durationMs: Int, wordCount: Int)
    case transcriptionFailed(error: String)
    case recordingTooShort(durationMs: Int)

    // MARK: Model
    case modelDownloadStarted(name: String, sizeMB: Int)
    case modelDownloadCompleted(name: String)
    case modelDownloadFailed(name: String, error: String)
    case modelSelected(name: String)
    case modelCompilationStarted(name: String)
    case modelCompilationCompleted(name: String, durationMs: Int)
    case modelDeleted(name: String, engine: String)
    case modelDeleteFailed(name: String, error: String)
    case modelPrewarmStarted(name: String)
    case modelCleanupPerformed(name: String, reason: String)

    // MARK: Keyboard
    case keyboardDidAppear
    case keyboardDidDisappear
    case keyboardMicTapped
    case keyboardTextInserted  // No content parameter -- privacy by design

    /// Phase 34 STAB-01 — always-on probe for every insertText() attempt.
    /// Privacy: counts / booleans / identifiers / durations only. No raw text.
    case keyboardInsertProbe(
        path: String,               // "warmDarwin" | "coldStartBridge"
        sessionID: String,
        attempt: Int,               // 0 = first try, 1-3 = retries
        transcriptionCount: Int,    // utf16 count of transcription
        hasFullAccess: Bool,
        hasTextBefore: Bool,
        hasTextAfter: Bool,
        beforeCount: Int,           // documentContextBeforeInput.utf16.count or -1 if nil
        afterCount: Int,            // documentContextBeforeInput.utf16.count or -1 if nil
        keyboardVisible: Bool,
        darwinToInsertMs: Int       // ms between Darwin notification and insertText call
    )
    /// Phase 34 STAB-01 — retry notification after a probe detected a failure.
    case keyboardInsertRetry(
        path: String,
        sessionID: String,
        attempt: Int,
        reason: String              // InsertionFailureReason rawValue
    )
    /// Phase 34 STAB-01 — terminal failure after all retries exhausted.
    case keyboardInsertFailed(
        path: String,
        sessionID: String,
        totalAttempts: Int,
        finalReason: String
    )

    // MARK: Animation
    case overlayShown(status: String)
    case overlayHidden(status: String)
    case statusChanged(from: String, to: String, source: String)
    case watchdogReset(source: String, staleState: String)
    case rapidTapRejected

    // MARK: Engine Diagnostics (temporary — remove after debug)
    case engineWarmUpAttempt(context: String)
    case engineWarmUpSuccess(context: String)
    case engineWarmUpFailed(context: String, error: String)
    case engineStateSnapshot(engineRunning: Bool, isRecording: Bool, hasWhisperKit: Bool, sessionConfigured: Bool, context: String)
    case engineCollectResult(sampleCount: Int, engineRunning: Bool)
    case engineDarwinStartReceived(appState: String, engineRunning: Bool)

    // MARK: Waveform Diagnostics
    case waveformAppeared(refreshID: Int, isProcessing: Bool, energyCount: Int, killedState: Bool)
    case waveformDisappeared(refreshID: Int, renderTick: Int)
    case waveformHeartbeat(renderTick: Int, avgLevel: Float, energyCount: Int)
    case waveformStall(gapMs: Int, renderTick: Int, energyCount: Int)
    case waveformRefreshIDChanged(oldID: Int, newID: Int, status: String)
    case waveformEnergyTransition(fromCount: Int, toCount: Int, status: String)
    case waveformTimelineNotFiring(renderTick: Int, energyCount: Int)
    case diagnosticProbe(component: String, instanceID: String, action: String, details: String)

    // MARK: Overlay Diagnostics
    case overlayBodyEvaluated(status: String, showsOverlay: Bool, energyCount: Int)
    case overlayTimerStarted
    case overlayTimerStopped
    case overlayRecreated(reason: String, status: String)

    // MARK: Onboarding
    case onboardingScenePhaseChanged(phase: String)
    case onboardingKeyboardCheckStarted(modeCount: Int)
    case onboardingKeyboardDetected(identifier: String)
    case onboardingKeyboardNotFound(modeCount: Int)
    case onboardingKeyboardCheckSkipped(reason: String)
    case onboardingKeyboardRetry
    case onboardingDictusKeyboardActivated
    case onboardingGlobeTutorialTextDetected
    case onboardingGlobeTutorialSkipped

    // MARK: Live Activity
    case liveActivityStarted(id: String)
    case liveActivityTransition(from: String, to: String)
    case liveActivityFailed(context: String, error: String)
    case liveActivityEnded(reason: String)

    // MARK: Cold Start Diagnostics
    case coldStartURLReceived(isColdStart: Bool, isEngineDead: Bool, hasBeenActive: Bool)
    case coldStartFlagSet(active: Bool, context: String)
    case coldStartRetry(keyboardStatus: String)
    case coldStartDarwinFallback(elapsedMs: Int, status: String)

    // MARK: Log Management
    case logExportCompleted(durationMs: Int, sizeBytes: Int)

    // MARK: Lifecycle
    case appLaunched(version: String)
    case appDidBecomeActive
    case appWillResignActive
    case appDidEnterBackground
    case appWhisperKitLoaded(modelName: String)

    // MARK: - Computed Properties

    /// The subsystem this event belongs to, derived from the case.
    public var subsystem: Subsystem {
        switch self {
        case .dictationStarted, .dictationCompleted, .dictationFailed, .dictationDeferred:
            return .dictation
        case .audioEngineStarted, .audioEngineStopped, .audioSessionConfigured, .audioSessionFailed:
            return .audio
        case .transcriptionStarted, .transcriptionCompleted, .transcriptionFailed, .recordingTooShort:
            return .transcription
        case .modelDownloadStarted, .modelDownloadCompleted, .modelDownloadFailed,
             .modelSelected, .modelCompilationStarted, .modelCompilationCompleted,
             .modelDeleted, .modelDeleteFailed, .modelPrewarmStarted, .modelCleanupPerformed:
            return .model
        case .keyboardDidAppear, .keyboardDidDisappear, .keyboardMicTapped, .keyboardTextInserted,
             .keyboardInsertProbe, .keyboardInsertRetry, .keyboardInsertFailed,
             .overlayShown, .overlayHidden, .rapidTapRejected,
             .waveformAppeared, .waveformDisappeared, .waveformHeartbeat, .waveformStall,
             .waveformRefreshIDChanged, .waveformEnergyTransition, .waveformTimelineNotFiring,
             .overlayBodyEvaluated, .overlayTimerStarted, .overlayTimerStopped, .overlayRecreated,
             .diagnosticProbe:
            return .keyboard
        case .statusChanged, .watchdogReset:
            return .dictation
        case .engineWarmUpAttempt, .engineWarmUpSuccess, .engineWarmUpFailed,
             .engineStateSnapshot, .engineCollectResult, .engineDarwinStartReceived:
            return .audio
        case .onboardingScenePhaseChanged, .onboardingKeyboardCheckStarted,
             .onboardingKeyboardDetected, .onboardingKeyboardNotFound,
             .onboardingKeyboardCheckSkipped, .onboardingKeyboardRetry,
             .onboardingDictusKeyboardActivated, .onboardingGlobeTutorialTextDetected,
             .onboardingGlobeTutorialSkipped:
            return .lifecycle
        case .coldStartURLReceived, .coldStartFlagSet, .coldStartRetry, .coldStartDarwinFallback:
            return .lifecycle
        case .logExportCompleted:
            return .lifecycle
        case .liveActivityStarted, .liveActivityTransition, .liveActivityFailed, .liveActivityEnded:
            return .lifecycle
        case .appLaunched, .appDidBecomeActive, .appWillResignActive,
             .appDidEnterBackground, .appWhisperKitLoaded:
            return .lifecycle
        }
    }

    /// Log level derived from the event type.
    /// Failures = error, deferred/warnings = warning, starts/completes = info,
    /// stops/internal state = debug.
    public var level: LogLevel {
        switch self {
        // Errors
        case .dictationFailed, .audioSessionFailed, .transcriptionFailed,
             .modelDownloadFailed, .modelDeleteFailed,
             .liveActivityFailed, .keyboardInsertFailed:
            return .error

        // Warnings
        case .dictationDeferred, .watchdogReset, .engineWarmUpFailed, .recordingTooShort,
             .waveformStall, .waveformTimelineNotFiring,
             .coldStartDarwinFallback, .keyboardInsertRetry:
            return .warning

        // Info (normal operations: starts, completes, selections, configs)
        case .onboardingKeyboardDetected,
             .onboardingDictusKeyboardActivated, .onboardingGlobeTutorialTextDetected,
             .onboardingGlobeTutorialSkipped,
             .dictationStarted, .dictationCompleted,
             .audioEngineStarted, .audioSessionConfigured,
             .transcriptionStarted, .transcriptionCompleted,
             .modelDownloadStarted, .modelDownloadCompleted,
             .modelSelected, .modelCompilationStarted, .modelCompilationCompleted,
             .modelDeleted, .modelPrewarmStarted, .modelCleanupPerformed,
             .keyboardDidAppear, .keyboardMicTapped,
             .appLaunched, .appWhisperKitLoaded, .logExportCompleted,
             .liveActivityStarted, .liveActivityTransition, .liveActivityEnded,
             .coldStartURLReceived, .coldStartFlagSet, .coldStartRetry,
             .overlayShown, .overlayHidden, .statusChanged,
             .waveformAppeared, .waveformDisappeared, .waveformRefreshIDChanged,
             .waveformEnergyTransition, .overlayBodyEvaluated, .overlayRecreated:
            return .info

        // Debug (internal state transitions)
        case .onboardingScenePhaseChanged, .onboardingKeyboardCheckStarted,
             .onboardingKeyboardNotFound, .onboardingKeyboardCheckSkipped,
             .onboardingKeyboardRetry,
             .audioEngineStopped,
             .keyboardDidDisappear, .keyboardTextInserted, .keyboardInsertProbe,
             .appDidBecomeActive, .appWillResignActive, .appDidEnterBackground,
             .rapidTapRejected,
             .engineWarmUpAttempt, .engineWarmUpSuccess,
             .engineStateSnapshot, .engineCollectResult, .engineDarwinStartReceived,
             .waveformHeartbeat, .overlayTimerStarted, .overlayTimerStopped,
             .diagnosticProbe:
            return .debug
        }
    }

    /// Event name as it appears in the log line (matches the enum case name).
    public var name: String {
        switch self {
        case .dictationStarted: return "dictationStarted"
        case .dictationCompleted: return "dictationCompleted"
        case .dictationFailed: return "dictationFailed"
        case .dictationDeferred: return "dictationDeferred"
        case .audioEngineStarted: return "audioEngineStarted"
        case .audioEngineStopped: return "audioEngineStopped"
        case .audioSessionConfigured: return "audioSessionConfigured"
        case .audioSessionFailed: return "audioSessionFailed"
        case .transcriptionStarted: return "transcriptionStarted"
        case .transcriptionCompleted: return "transcriptionCompleted"
        case .transcriptionFailed: return "transcriptionFailed"
        case .recordingTooShort: return "recordingTooShort"
        case .modelDownloadStarted: return "modelDownloadStarted"
        case .modelDownloadCompleted: return "modelDownloadCompleted"
        case .modelDownloadFailed: return "modelDownloadFailed"
        case .modelSelected: return "modelSelected"
        case .modelCompilationStarted: return "modelCompilationStarted"
        case .modelCompilationCompleted: return "modelCompilationCompleted"
        case .modelDeleted: return "modelDeleted"
        case .modelDeleteFailed: return "modelDeleteFailed"
        case .modelPrewarmStarted: return "modelPrewarmStarted"
        case .modelCleanupPerformed: return "modelCleanupPerformed"
        case .keyboardDidAppear: return "keyboardDidAppear"
        case .keyboardDidDisappear: return "keyboardDidDisappear"
        case .keyboardMicTapped: return "keyboardMicTapped"
        case .keyboardTextInserted: return "keyboardTextInserted"
        case .keyboardInsertProbe: return "keyboardInsertProbe"
        case .keyboardInsertRetry: return "keyboardInsertRetry"
        case .keyboardInsertFailed: return "keyboardInsertFailed"
        case .engineWarmUpAttempt: return "engineWarmUpAttempt"
        case .engineWarmUpSuccess: return "engineWarmUpSuccess"
        case .engineWarmUpFailed: return "engineWarmUpFailed"
        case .engineStateSnapshot: return "engineStateSnapshot"
        case .engineCollectResult: return "engineCollectResult"
        case .engineDarwinStartReceived: return "engineDarwinStartReceived"
        case .onboardingScenePhaseChanged: return "onboardingScenePhaseChanged"
        case .onboardingKeyboardCheckStarted: return "onboardingKeyboardCheckStarted"
        case .onboardingKeyboardDetected: return "onboardingKeyboardDetected"
        case .onboardingKeyboardNotFound: return "onboardingKeyboardNotFound"
        case .onboardingKeyboardCheckSkipped: return "onboardingKeyboardCheckSkipped"
        case .onboardingKeyboardRetry: return "onboardingKeyboardRetry"
        case .onboardingDictusKeyboardActivated: return "onboardingDictusKeyboardActivated"
        case .onboardingGlobeTutorialTextDetected: return "onboardingGlobeTutorialTextDetected"
        case .onboardingGlobeTutorialSkipped: return "onboardingGlobeTutorialSkipped"
        case .liveActivityStarted: return "liveActivityStarted"
        case .liveActivityTransition: return "liveActivityTransition"
        case .liveActivityFailed: return "liveActivityFailed"
        case .liveActivityEnded: return "liveActivityEnded"
        case .appLaunched: return "appLaunched"
        case .appDidBecomeActive: return "appDidBecomeActive"
        case .appWillResignActive: return "appWillResignActive"
        case .appDidEnterBackground: return "appDidEnterBackground"
        case .appWhisperKitLoaded: return "appWhisperKitLoaded"
        case .overlayShown: return "overlayShown"
        case .overlayHidden: return "overlayHidden"
        case .statusChanged: return "statusChanged"
        case .watchdogReset: return "watchdogReset"
        case .rapidTapRejected: return "rapidTapRejected"
        case .waveformAppeared: return "waveformAppeared"
        case .waveformDisappeared: return "waveformDisappeared"
        case .waveformHeartbeat: return "waveformHeartbeat"
        case .waveformStall: return "waveformStall"
        case .waveformRefreshIDChanged: return "waveformRefreshIDChanged"
        case .waveformEnergyTransition: return "waveformEnergyTransition"
        case .waveformTimelineNotFiring: return "waveformTimelineNotFiring"
        case .diagnosticProbe: return "diagnosticProbe"
        case .overlayBodyEvaluated: return "overlayBodyEvaluated"
        case .overlayTimerStarted: return "overlayTimerStarted"
        case .overlayTimerStopped: return "overlayTimerStopped"
        case .overlayRecreated: return "overlayRecreated"
        case .coldStartURLReceived: return "coldStartURLReceived"
        case .coldStartFlagSet: return "coldStartFlagSet"
        case .coldStartRetry: return "coldStartRetry"
        case .coldStartDarwinFallback: return "coldStartDarwinFallback"
        case .logExportCompleted: return "logExportCompleted"
        }
    }

    /// Formatted key=value parameters from associated values.
    /// Returns empty string for events with no associated values.
    public var message: String {
        switch self {
        // Dictation
        case .dictationStarted(let fromURL, let appState, let engineRunning):
            return "fromURL=\(fromURL) appState=\(appState) engineRunning=\(engineRunning)"
        case .dictationCompleted(let durationMs):
            return "duration=\(durationMs)ms"
        case .dictationFailed(let error):
            return "error=\(error)"
        case .dictationDeferred(let reason):
            return "reason=\(reason)"

        // Audio
        case .audioEngineStarted, .audioEngineStopped:
            return ""
        case .audioSessionConfigured(let category):
            return "category=\(category)"
        case .audioSessionFailed(let error):
            return "error=\(error)"

        // Transcription
        case .transcriptionStarted(let modelName):
            return "model=\(modelName)"
        case .transcriptionCompleted(let durationMs, let wordCount):
            return "duration=\(durationMs)ms words=\(wordCount)"
        case .transcriptionFailed(let error):
            return "error=\(error)"
        case .recordingTooShort(let durationMs):
            return "duration=\(durationMs)ms"

        // Model
        case .modelDownloadStarted(let name, let sizeMB):
            return "name=\(name) size=\(sizeMB)MB"
        case .modelDownloadCompleted(let name):
            return "name=\(name)"
        case .modelDownloadFailed(let name, let error):
            return "name=\(name) error=\(error)"
        case .modelSelected(let name):
            return "name=\(name)"
        case .modelCompilationStarted(let name):
            return "name=\(name)"
        case .modelCompilationCompleted(let name, let durationMs):
            return "name=\(name) duration=\(durationMs)ms"
        case .modelDeleted(let name, let engine):
            return "name=\(name) engine=\(engine)"
        case .modelDeleteFailed(let name, let error):
            return "name=\(name) error=\(error)"
        case .modelPrewarmStarted(let name):
            return "name=\(name)"
        case .modelCleanupPerformed(let name, let reason):
            return "name=\(name) reason=\(reason)"

        // Keyboard (no content parameters -- privacy)
        case .keyboardDidAppear, .keyboardDidDisappear,
             .keyboardMicTapped, .keyboardTextInserted:
            return ""

        // Keyboard insertion probes (Phase 34 STAB-01) — counts/bools only, no raw text
        case .keyboardInsertProbe(let path, let sessionID, let attempt, let transcriptionCount,
                                  let hasFullAccess, let hasTextBefore, let hasTextAfter,
                                  let beforeCount, let afterCount, let keyboardVisible,
                                  let darwinToInsertMs):
            return "path=\(path) sessionID=\(sessionID) attempt=\(attempt) transcriptionCount=\(transcriptionCount) hasFullAccess=\(hasFullAccess) hasTextBefore=\(hasTextBefore) hasTextAfter=\(hasTextAfter) beforeCount=\(beforeCount) afterCount=\(afterCount) keyboardVisible=\(keyboardVisible) darwinToInsertMs=\(darwinToInsertMs)"
        case .keyboardInsertRetry(let path, let sessionID, let attempt, let reason):
            return "path=\(path) sessionID=\(sessionID) attempt=\(attempt) reason=\(reason)"
        case .keyboardInsertFailed(let path, let sessionID, let totalAttempts, let finalReason):
            return "path=\(path) sessionID=\(sessionID) totalAttempts=\(totalAttempts) finalReason=\(finalReason)"

        // Engine Diagnostics
        case .engineWarmUpAttempt(let context):
            return "context=\(context)"
        case .engineWarmUpSuccess(let context):
            return "context=\(context)"
        case .engineWarmUpFailed(let context, let error):
            return "context=\(context) error=\(error)"
        case .engineStateSnapshot(let engineRunning, let isRecording, let hasWhisperKit, let sessionConfigured, let context):
            return "engineRunning=\(engineRunning) isRecording=\(isRecording) hasWhisperKit=\(hasWhisperKit) sessionConfigured=\(sessionConfigured) context=\(context)"
        case .engineCollectResult(let sampleCount, let engineRunning):
            return "sampleCount=\(sampleCount) engineRunning=\(engineRunning)"
        case .engineDarwinStartReceived(let appState, let engineRunning):
            return "appState=\(appState) engineRunning=\(engineRunning)"

        // Onboarding
        case .onboardingScenePhaseChanged(let phase):
            return "phase=\(phase)"
        case .onboardingKeyboardCheckStarted(let modeCount):
            return "modeCount=\(modeCount)"
        case .onboardingKeyboardDetected(let identifier):
            return "identifier=\(identifier)"
        case .onboardingKeyboardNotFound(let modeCount):
            return "modeCount=\(modeCount)"
        case .onboardingKeyboardCheckSkipped(let reason):
            return "reason=\(reason)"
        case .onboardingKeyboardRetry:
            return ""
        case .onboardingDictusKeyboardActivated, .onboardingGlobeTutorialTextDetected,
             .onboardingGlobeTutorialSkipped:
            return ""

        // Live Activity
        case .liveActivityStarted(let id):
            return "id=\(id)"
        case .liveActivityTransition(let from, let to):
            return "from=\(from) to=\(to)"
        case .liveActivityFailed(let context, let error):
            return "context=\(context) error=\(error)"
        case .liveActivityEnded(let reason):
            return "reason=\(reason)"

        // Lifecycle
        case .appLaunched(let version):
            return "version=\(version)"
        case .appDidBecomeActive, .appWillResignActive, .appDidEnterBackground:
            return ""
        case .appWhisperKitLoaded(let modelName):
            return "model=\(modelName)"

        // Animation
        case .overlayShown(let status):
            return "status=\(status)"
        case .overlayHidden(let status):
            return "status=\(status)"
        case .statusChanged(let from, let to, let source):
            return "from=\(from) to=\(to) source=\(source)"
        case .watchdogReset(let source, let staleState):
            return "source=\(source) staleState=\(staleState)"
        case .rapidTapRejected:
            return ""

        // Waveform Diagnostics
        case .waveformAppeared(let refreshID, let isProcessing, let energyCount, let killedState):
            return "refreshID=\(refreshID) isProcessing=\(isProcessing) energyCount=\(energyCount) killed=\(killedState)"
        case .waveformDisappeared(let refreshID, let renderTick):
            return "refreshID=\(refreshID) renderTick=\(renderTick)"
        case .waveformHeartbeat(let renderTick, let avgLevel, let energyCount):
            return "renderTick=\(renderTick) avgLevel=\(String(format: "%.3f", avgLevel)) energyCount=\(energyCount)"
        case .waveformStall(let gapMs, let renderTick, let energyCount):
            return "gapMs=\(gapMs) renderTick=\(renderTick) energyCount=\(energyCount)"
        case .waveformRefreshIDChanged(let oldID, let newID, let status):
            return "oldID=\(oldID) newID=\(newID) status=\(status)"
        case .waveformEnergyTransition(let fromCount, let toCount, let status):
            return "fromCount=\(fromCount) toCount=\(toCount) status=\(status)"
        case .waveformTimelineNotFiring(let renderTick, let energyCount):
            return "renderTick=\(renderTick) energyCount=\(energyCount)"
        case .diagnosticProbe(let component, let instanceID, let action, let details):
            return "component=\(component) instanceID=\(instanceID) action=\(action) details=\(details)"

        // Overlay Diagnostics
        case .overlayBodyEvaluated(let status, let showsOverlay, let energyCount):
            return "status=\(status) showsOverlay=\(showsOverlay) energyCount=\(energyCount)"
        case .overlayTimerStarted, .overlayTimerStopped:
            return ""
        case .overlayRecreated(let reason, let status):
            return "reason=\(reason) status=\(status)"

        // Cold Start Diagnostics
        case .coldStartURLReceived(let isColdStart, let isEngineDead, let hasBeenActive):
            return "isColdStart=\(isColdStart) isEngineDead=\(isEngineDead) hasBeenActive=\(hasBeenActive)"
        case .coldStartFlagSet(let active, let context):
            return "active=\(active) context=\(context)"
        case .coldStartRetry(let keyboardStatus):
            return "keyboardStatus=\(keyboardStatus)"
        case .coldStartDarwinFallback(let elapsedMs, let status):
            return "elapsedMs=\(elapsedMs) status=\(status)"

        // Log Management
        case .logExportCompleted(let durationMs, let sizeBytes):
            return "duration=\(durationMs)ms size=\(sizeBytes)bytes"
        }
    }

    // MARK: - Formatting

    /// Static ISO8601 formatter -- reused across all calls to avoid allocation overhead.
    /// WHY static: ISO8601DateFormatter is expensive to create. Creating one per log call
    /// causes measurable performance overhead (research pitfall 3).
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Produces the full formatted log line.
    /// Format: `[ISO8601timestamp] LEVEL  [subsystem] eventName param=value ...`
    public func formatted() -> String {
        let timestamp = Self.isoFormatter.string(from: Date())
        let src = PersistentLog.source
        let params = message
        if params.isEmpty {
            return "[\(timestamp)] \(level.paddedName) [\(subsystem.rawValue)] <\(src)> \(name)"
        }
        return "[\(timestamp)] \(level.paddedName) [\(subsystem.rawValue)] <\(src)> \(name) \(params)"
    }
}
