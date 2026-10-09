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
    /// Apple's background rate limit, and voice notes run their mode when the result
    /// is opened, with DictusApp in the foreground.
    private let voiceNoteService: PolishService

    /// The voice-note mode runs in flight, by note and mode (#648). A card that opens on
    /// a note whose mode is already running attaches to it rather than starting a
    /// second run, which would supersede the first on `voiceNoteService`'s slot.
    private let voiceNoteRuns = InFlightCalls<VoiceNoteRunKey, PolishOutcome>()

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

    /// Run a voice note's Smart Mode, on the voice-note slot (#648). Same pipeline and
    /// same contract as `polish`; a dictation starting meanwhile does not cancel it, and
    /// a second card on the same note and mode awaits this run instead of starting one.
    public func polishVoiceNote(noteID: UUID,
                                raw: String,
                                languagePolicy: TranscriptionLanguagePolicy,
                                smartMode: SmartMode,
                                recordingDuration: TimeInterval) async -> PolishOutcome {
        let key = VoiceNoteRunKey(noteID: noteID, modeIdentifier: smartMode.id)
        if voiceNoteRuns.isRunning(key) {
            PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "summary",
                                               action: "attached", details: "mode=\(smartMode.id)"))
        }
        let service = voiceNoteService
        return await voiceNoteRuns.run(key) {
            await service.polish(
                raw: raw,
                languagePolicy: languagePolicy,
                smartMode: smartMode,
                recordingDuration: recordingDuration
            )
        }
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
