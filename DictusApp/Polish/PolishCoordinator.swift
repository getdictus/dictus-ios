// DictusApp/Polish/PolishCoordinator.swift
import Foundation
import UIKit
import DictusCore

/// DictusApp's polish entry point: one `PolishService` for dictations started
/// inside the app, plus the debug ring the settings screen and the JSON export
/// read.
///
/// ### What is left here, and why so little (#361)
///
/// The orchestration this type used to hold — the toggle, the language branch, the
/// duration and gibberish gates, the availability gate, the metrics — moved to
/// `PolishService` in DictusCore, because the keyboard extension now runs the same
/// pipeline for keyboard dictations. One pipeline, two call sites (decision 4).
///
/// What could not move is the app-only half: the ring's memory cache and retention,
/// the export, and the prewarm scheduled from the recording. A keyboard dictation
/// never reaches this object at all.
@MainActor
public final class PolishCoordinator {

    public static let shared = PolishCoordinator()

    private let metricsRing = PolishMetricsRing()
    private let service: PolishService

    /// A second service for voice notes, so they have their own in-flight slot (#648).
    ///
    /// `PolishService` serialises its calls on one slot: a new call cancels the one in
    /// flight (#361 decisions 10 and 15). That is right for dictations, where the new
    /// one replaces the old. It was wrong for voice notes sharing the slot:
    /// `DictationCoordinator.startDictation()` calls `cancelInflight()` for every
    /// recording, keyboard ones included, because DictusApp records them all. A device
    /// test on 2026-10-08 lost a 226 s voice note's translation that way: a keyboard
    /// dictation started while it was translating, and the log reads
    /// `polishCallSuperseded inflightMs=16812`, then `smartModeRefused outcome=cancelled`.
    /// A voice note is not replaced by a dictation, so it does not share its slot.
    ///
    /// The cost is a second #315 availability gate in this process. That gate tracks
    /// Apple's background rate limit; this service only runs with DictusApp in front,
    /// so it never sees a background refusal.
    private let voiceNoteService: PolishService

    /// A third service, for voice note modes started with DictusApp in the background
    /// (#627).
    ///
    /// Since #627 the queue runs a note's mode right after transcribing it, which on the
    /// warm path is in the background, where Apple's budget can refuse. Two refusals in
    /// a row latch a service's #315 gate for the rest of the process. Latched on
    /// `voiceNoteService`, that would turn the fallback — the card running the mode on
    /// open, in the foreground, where Apple serves it — into `engineUnavailable` until
    /// the process dies. So background attempts get their own gate: once it latches,
    /// further background attempts cost nothing, and the card still runs.
    ///
    /// Its own slot too: a card running one note's mode on open must not supersede the
    /// queue running another's in the background.
    private let voiceNoteBackgroundService: PolishService

    /// Voice note runs pending since they were requested, and whether the queue's
    /// background task expired under one (PR #689 review). Read by a background run
    /// before it calls the engine and when it labels its attempt line.
    private var backgroundExpiry = VoiceNoteBackgroundExpiry()

    /// The voice-note mode runs in flight, by note and mode (#648). A card that opens on
    /// a note whose mode is already running attaches to it rather than starting a
    /// second run, which would supersede the first on `voiceNoteService`'s slot.
    private let voiceNoteRuns = InFlightCalls<VoiceNoteRunKey, VoiceNoteModeRun>()

    private struct VoiceNoteRunKey: Hashable {
        let noteID: UUID
        let modeIdentifier: String
    }

    private init() {
        // No `onBecameUnavailable`: the #315 notice lives in the keyboard toolbar and
        // describes the keyboard's gate since #361. When an in-app dictation exhausts
        // the app's budget, the user is looking at DictusApp, and telling them through
        // a surface in another process would be both late and wrong.
        // `appState` feeds the `translateEngineCall` line (#648). The app translates for
        // voice notes and for dictations started inside it; the keyboard does the rest.
        // `translationBudget` (#648): voice notes run minutes long, so Translate's wait
        // scales with the input here rather than taking the keyboard's 8 s.
        self.service = PolishService(sink: metricsRing, translationBudget: .app,
                                     appState: Self.applicationStateName)
        self.voiceNoteService = PolishService(sink: metricsRing, translationBudget: .app,
                                              appState: Self.applicationStateName)
        self.voiceNoteBackgroundService = PolishService(sink: metricsRing, translationBudget: .app,
                                                        appState: Self.applicationStateName)
    }

    /// This app's state, read synchronously, for the voice note attempt line (#627).
    private static var currentApplicationStateName: String {
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    /// This app's state, for the `translateEngineCall` line.
    private static let applicationStateName: @Sendable () async -> String = {
        await MainActor.run {
            switch UIApplication.shared.applicationState {
            case .active: return "active"
            case .inactive: return "inactive"
            case .background: return "background"
            @unknown default: return "unknown"
            }
        }
    }

    // MARK: - Public API

    /// Cancel any in-flight polish. Called by `DictationCoordinator.startDictation()`
    /// so a new recording does not pile up behind the previous polish.
    public func cancelInflight() {
        service.cancelInflight()
    }

    /// Warm the Apple FM engine for the user's current target language (#141).
    ///
    /// Only ever called for a dictation started inside the app since #361: a keyboard
    /// dictation is polished in the extension, and warming a session in this process
    /// could not help it — the two hold separate `LanguageModelSession` caches.
    public func prewarm() {
        service.prewarm()
    }

    /// Polish raw STT output for an in-app dictation. See `PolishService.polish`.
    ///
    /// `smartMode` is the mode armed when this dictation started (#79). A dictation
    /// started inside the app honours it exactly as a keyboard one does: the mode is
    /// a parameter of the dictation, not of the process that runs it.
    public func polish(raw: String,
                       languagePolicy: TranscriptionLanguagePolicy,
                       smartMode: SmartMode?,
                       recordingDuration: TimeInterval,
                       engineRaw: String? = nil,
                       onEngineWillRun: (() -> Void)? = nil) async -> PolishOutcome {
        await service.polish(
            raw: raw,
            languagePolicy: languagePolicy,
            smartMode: smartMode,
            recordingDuration: recordingDuration,
            engineRaw: engineRaw,
            onEngineWillRun: onEngineWillRun
        )
    }

    /// What a voice note's mode runs on. Grouped because `noteID` and `smartMode` key
    /// the run and the rest is its input: one value, so a caller cannot pair them up
    /// wrong.
    public struct VoiceNoteModeRequest: Sendable {
        public let noteID: UUID
        public let raw: String
        public let languagePolicy: TranscriptionLanguagePolicy
        public let smartMode: SmartMode
        /// Smart tasks skip the duration gate; the value is the metrics' context.
        public let recordingDuration: TimeInterval
    }

    /// One voice note mode run, as every caller attached to it receives it (#627).
    public struct VoiceNoteModeRun: Sendable {
        public let outcome: PolishOutcome
        /// The attempt as logged: what the card's fallback decides on.
        public let attempt: VoiceNoteSmartModeAttempt
    }

    /// Run a voice note's Smart Mode, on a voice-note slot (#648). Same pipeline and
    /// same contract as `polish`; a dictation starting meanwhile does not cancel it, and
    /// a second caller on the same note and mode — the card opening while the queue
    /// runs it in the background — awaits this run instead of starting one.
    ///
    /// The service is chosen by the application state when the run starts, not by who
    /// asked: the rate limit is decided on the state (#315), and the cold path runs the
    /// queue with the app in front.
    ///
    /// Writes one `VoiceNote summary` line per run, attached callers included in none
    /// of them, so the #627 probe counts calls rather than cards.
    public func polishVoiceNote(_ request: VoiceNoteModeRequest,
                                trigger: VoiceNoteSmartModeTrigger) async -> VoiceNoteModeRun {
        let smartMode = request.smartMode
        let key = VoiceNoteRunKey(noteID: request.noteID, modeIdentifier: smartMode.id)
        if voiceNoteRuns.isRunning(key) {
            PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "summary",
                                               action: "attached", details: "mode=\(smartMode.id) trigger=\(trigger.rawValue)"))
        } else {
            // Counted here, before `run` starts its task, so an expiry in between is
            // recorded rather than missed.
            backgroundExpiry.runRequested()
        }
        // `self` is the process-wide singleton: capturing it strongly keeps nothing alive
        // that was not already.
        return await voiceNoteRuns.run(key) {
            let appState = Self.currentApplicationStateName
            // `.inactive` is the app coming to the front (an island tap, the switcher):
            // foreground for Apple's limit, so it takes the foreground service.
            let inBackground = UIApplication.shared.applicationState == .background
            let service = inBackground ? self.voiceNoteBackgroundService : self.voiceNoteService
            let outcome: PolishOutcome
            if inBackground, self.backgroundExpiry.expired {
                // The background task expired before this run reached the engine: no
                // call after `endBackgroundTask()`. A cancellation, so the card runs the
                // mode on open without an error.
                outcome = PolishOutcome(failure: SmartModeFailure(
                    modeIdentifier: smartMode.id, modeDisplayName: smartMode.displayName,
                    outcome: PolishMetrics.Outcome.cancelled.rawValue, reason: "-"
                ))
            } else {
                outcome = await service.polish(
                    raw: request.raw,
                    languagePolicy: request.languagePolicy,
                    smartMode: smartMode,
                    recordingDuration: request.recordingDuration
                )
            }
            let cancelReason = inBackground && self.backgroundExpiry.expired
                ? VoiceNoteSmartModeAttempt.backgroundTimeExpiredReason : nil
            self.backgroundExpiry.runEnded()
            let attempt = VoiceNoteSmartModeAttempt(
                outcome: outcome, modeIdentifier: smartMode.id, appState: appState,
                callIndex: AppleFMCallCounter.current, trigger: trigger, cancelReason: cancelReason
            )
            PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "summary",
                                               action: attempt.action.rawValue, details: attempt.logDetails))
            return VoiceNoteModeRun(outcome: outcome, attempt: attempt)
        }
    }

    /// The queue's background task is expiring (#627): stop the background voice note
    /// run in flight, so the process does not suspend in the middle of a generation
    /// that would then resume at some unknown later point. The note keeps no result and
    /// the card runs its mode on open. Synchronous, because the expiry handler must
    /// return before iOS suspends the app.
    ///
    /// A run requested but not yet at the engine is caught too: it checks the expiry
    /// before calling the engine (PR #689 review).
    public func cancelBackgroundVoiceNoteRun() {
        guard backgroundExpiry.expire() else { return }
        voiceNoteBackgroundService.cancelInflight()
    }

    /// Record that a voice note's mode declined its transcript for length (#650). See
    /// `PolishService.recordSkippedForLength`: the voice note card decides before
    /// calling `polish`, and this is how its decision still reaches the export.
    public func recordSkippedForLength(_ mode: SmartMode, raw: String) async {
        await voiceNoteService.recordSkippedForLength(mode, raw: raw)
    }

    // MARK: - Debug ring

    /// Recent polish events for the debug screen — both processes' events, read
    /// back off the shared file.
    public func metricsSnapshot() async -> [PolishDebugEntry] {
        await metricsRing.snapshot()
    }

    /// All polish events within the 7-day retention window — used by the JSON export.
    public func metricsAllEntries() async -> [PolishDebugEntry] {
        await metricsRing.allEntries()
    }

    /// Count of persisted events within the 7-day retention window.
    public func metricsStoredCount() async -> Int {
        await metricsRing.storedCount()
    }

    /// Empties the debug ring. Triggered from the debug screen's Clear button.
    public func clearMetricsRing() async {
        await metricsRing.clear()
    }
}
