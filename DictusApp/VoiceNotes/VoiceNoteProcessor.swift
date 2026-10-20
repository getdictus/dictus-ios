// DictusApp/VoiceNotes/VoiceNoteProcessor.swift
// Runs the shared voice note queue: decode, transcribe chunk by chunk, save (#620).
import Foundation
import UIKit
import DictusCore

/// The voice note queue's engine room.
///
/// ### The two paths of #620
///
/// - **Warm.** DictusApp is alive in the background — the warm audio engine of #106
///   keeps it so, with the standby Live Activity on screen. The share extension
///   posts `voiceNoteQueued`; this object takes the note out of the inbox at once
///   (which is how the extension learns the app is alive), transcribes it where it
///   is, in the background, and drives the standby pill with progress, then the
///   first lines. The user never leaves the conversation they shared from.
/// - **Cold.** The app is suspended or not running: nothing receives the post, the
///   extension says "Open Dictus, your voice note is waiting", and the queue starts
///   here the next time the app becomes active, with the list on screen.
///
/// ### The Smart Mode, right after the transcript (#627)
///
/// Once a note is transcribed, the queue runs its Smart Mode (Résumé by default) at
/// once, inside the same background task, so the card opens on a result instead of a
/// spinner. Apple's background budget can refuse that call (#315); a refusal, or the
/// background task expiring under it, stores nothing, and the card runs the mode on
/// open as it did before #627, without an error for the refusal itself.
///
/// ### What it never does
///
/// Touch the dictation. No status write, no session, no App Group key the keyboard
/// reads. The only thing a voice note shares with a dictation is the speech engine,
/// and that goes through `EngineAccessGate`, which serves the dictation first; and
/// before each chunk the queue also waits out any dictation in flight, so it never
/// starts work a user at the keyboard would then wait behind.
@MainActor
final class VoiceNoteProcessor: ObservableObject {

    static let shared = VoiceNoteProcessor()

    let store = VoiceNoteQueueStore.shared

    /// The voice note screen the app should present, set by a Live Activity tap or by
    /// the cold path. `MainTabView` binds to it.
    @Published var presentation: VoiceNoteStackRequest?

    private var runTask: Task<Void, Never>?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var didStart = false

    private init() {}

    // MARK: - Entry points

    /// Listen for the share extension. Called once, at launch.
    func start() {
        guard !didStart else { return }
        didStart = true
        // Darwin callbacks arrive on an arbitrary thread; everything here is main-actor.
        DarwinNotificationCenter.addObserver(for: DarwinNotificationName.voiceNoteQueued) {
            Task { @MainActor in VoiceNoteProcessor.shared.noteQueuedWhileAlive() }
        }
        // The keyboard just showed or inserted a note (#639): mark it read now, so the
        // island and the cards follow while this process is alive in the background.
        DarwinNotificationCenter.addObserver(for: DarwinNotificationName.voiceNoteKeyboardReceipt) {
            Task { @MainActor in VoiceNoteProcessor.shared.reconcileKeyboardDeliveries(reason: "keyboardSignal") }
        }
        // Anything shared before this launch, and anything a dead process left
        // mid-transcription, is picked up now.
        store.ingestInbox()
        // A voice note History drops at its cap leaves the keyboard with it (#639,
        // decision C): set before anything here can append.
        TranscriptionHistoryStore.shared.onEvicted = { ids in
            VoiceNoteProcessor.shared.withdrawKeyboardDeliveries(ids, reason: "evictedFromHistory")
        }
        // And whatever the keyboard did with a transcript while this process was
        // not running (#637).
        reconcileKeyboardDeliveries(reason: "launch")
        // Every note still to transcribe joins the ring, interrupted ones included.
        VoiceNoteIslandDriver.shared.arrived(store.queue.stackable.filter { !$0.state.isFinished }.map(\.id))
        log("launch", "pending=\(store.queue.hasPendingWork)")
    }

    /// The warm path: a note arrived while this process was alive to hear it.
    private func noteQueuedWhileAlive() {
        // Written before the ingest: the extension reads it as soon as its sidecar is
        // gone, which the ingest does, possibly before the post below lands.
        AppGroup.defaults.set(LiveActivityManager.shared.hasLiveActivity, forKey: SharedKeys.voiceNoteAcceptedWithActivity)
        AppGroup.defaults.synchronize()
        let arrived = store.ingestInbox()
        guard !arrived.isEmpty else { return }
        DarwinNotificationCenter.post(DarwinNotificationName.voiceNoteAccepted)
        VoiceNoteIslandDriver.shared.arrived(arrived.map(\.id))
        let state = UIApplication.shared.applicationState
        log("accepted", "count=\(arrived.count) appState=\(state.rawValue) activity=\(LiveActivityManager.shared.hasLiveActivity)")
        processQueue()
    }

    /// The cold path, and every return to the app.
    func appBecameActive() {
        // Before anything can raise the stack: a note the user inserted from the
        // keyboard is read, and must not come back up as unread (#637).
        reconcileKeyboardDeliveries(reason: "active")
        VoiceNoteIslandDriver.shared.arrived(store.ingestInbox().map(\.id))
        if store.queue.hasPendingWork { processQueue() }
        // Any door into the app — icon, island, link, switcher, launch — raises the
        // stack when a note is ready and unread (smoke test of 7fdf2e1c). A finished
        // note's ring stays until it is read or its five minutes are up (#620
        // decision 4): opening the app is not reading the note.
        evaluatePresentation()
    }

    // MARK: - Raising the stack on its own

    private var presentationRecheck: Task<Void, Never>?

    /// Set by `MainTabView` while a screen that replaces the tab bar is up — the model
    /// preparation screen or the cold-start swipe-back overlay. Neither is a sheet, so
    /// UIKit's presented controller does not see them.
    var mainScreenBlocked = false {
        didSet { if oldValue && !mainScreenBlocked { evaluatePresentation() } }
    }

    /// Results waiting to be read: unread in History, or held by the queue when History
    /// is off. Notes still running do not count (`VoiceNoteStackPresentationPolicy`).
    private var readyUnreadCount: Int {
        TranscriptionHistoryStore.shared.unreadVoiceNotes.count
            + store.queue.notes.filter { $0.state == .done && $0.openedAt == nil }.count
    }

    /// Raise the stack if a note is ready and unread and nothing is in the way; if
    /// something is, ask again every two seconds while the app stays active.
    func evaluatePresentation() {
        guard UIApplication.shared.applicationState == .active else { return }
        let decision = VoiceNoteStackPresentationPolicy.decide(
            readyUnreadCount: readyUnreadCount,
            onboardingCompleted: AppGroup.defaults.bool(forKey: SharedKeys.hasCompletedOnboarding),
            dictationActive: DictationCoordinator.shared.status != .idle,
            somethingPresented: Self.somethingIsPresented || mainScreenBlocked,
            stackShowing: presentation != nil
        )
        switch decision {
        case .present:
            presentationRecheck?.cancel()
            presentationRecheck = nil
            presentation = VoiceNoteStackRequest(focus: nil, source: "auto")
        case .wait:
            guard presentationRecheck == nil else { return }
            presentationRecheck = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self, !Task.isCancelled else { return }
                self.presentationRecheck = nil
                self.evaluatePresentation()
            }
        case .none:
            presentationRecheck?.cancel()
            presentationRecheck = nil
        }
    }

    /// Whether a sheet or full-screen cover is up — the paywall, the trial screens,
    /// History, a settings sheet. Asked of UIKit rather than of each view's own flag,
    /// so a sheet added later is covered without anyone remembering to wire it here.
    private static var somethingIsPresented: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains { $0.isKeyWindow && $0.rootViewController?.presentedViewController != nil }
    }

    /// A card showed a note's outcome: the ring loses that segment (#620 decision 9).
    func noteRead(_ id: UUID) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "stack", action: "markRead",
                                           details: "id=\(id.uuidString.prefix(8))"))
        VoiceNoteIslandDriver.shared.read(id)
        // The keyboard keeps offering it: since #639 a note leaves the keyboard by time
        // (or a delete), not because it was read here.
    }

    /// `dictus://voice-note[?id=…]`, from the Live Activity: the voice note screen,
    /// on the unread stack (see `VoiceNoteStackView`).
    func open(_ target: UUID?) {
        // The island's link names no note; the share extension's cold-path link does.
        // A screen the activation already raised shows the same cards: keep it rather
        // than close and reopen it (never two presentations in a row).
        if target == nil, presentation != nil { return }
        presentation = VoiceNoteStackRequest(focus: target, source: target == nil ? "island" : "link")
    }

    /// The app left the foreground: the voice note screen closes with it, so the next
    /// activation opens a fresh one from what is unread then (`VoiceNoteStackSession`).
    func appWentToBackground() {
        // The keyboard is about to be the surface in front of the user: whatever it
        // inserted is read here, and whatever outlived its window leaves it (#637, #639).
        reconcileKeyboardDeliveries(reason: "background")
        guard presentation != nil else { return }
        presentation = nil
    }

    /// Put a failed note back in the queue.
    func retry(_ id: UUID) {
        store.mutate { $0.retry(id) }
        processQueue()
    }

    // MARK: - The queue

    /// Start the loop if it is not running. Idempotent.
    func processQueue() {
        guard runTask == nil else { return }
        guard store.queue.next != nil else { return }
        runTask = Task { [weak self] in
            await self?.runLoop()
            self?.runTask = nil
        }
    }

    private func runLoop() async {
        beginBackgroundTask()
        defer { endBackgroundTask() }
        while let note = store.queue.next {
            // Per note, not per queue: the trial can end while a queue runs (#593).
            guard VoiceNoteAvailability.mayTranscribe(isEntitled: VoiceNoteAvailability.isEntitled) else {
                log("paused", "reason=notEntitled waiting=\(store.queue.waitingCount)")
                VoiceNoteIslandDriver.shared.paused()
                return
            }
            await transcribe(note)
        }
    }

    private func transcribe(_ note: VoiceNote) async {
        let started = Date()
        store.mutate { $0.update(note.id) { $0.state = .transcribing(progress: 0) } }
        DictationCoordinator.shared.extendWarmWindowForVoiceNote()

        guard AppGroup.defaults.bool(forKey: SharedKeys.modelReady) else {
            return fail(note, .transcriptionFailed, detail: "no model downloaded")
        }
        guard let url = store.audioURL(for: note) else {
            return fail(note, .unreadable, detail: "audio missing")
        }

        let samples: [Float]
        do {
            samples = try await Task.detached(priority: .userInitiated) {
                try await SharedAudioDecoder.decode(url: url)
            }.value
        } catch let error as VoiceNoteDecodeError {
            return fail(note, Self.failure(for: error), detail: error.diagnosticDescription)
        } catch {
            return fail(note, .unreadable, detail: error.localizedDescription)
        }

        let duration = Double(samples.count) / SharedAudioDecoder.sampleRate
        store.mutate { $0.update(note.id) { $0.durationSeconds = Int(duration.rounded()) } }
        // Captured once per note, for #226's reason: the settings can change mid-queue.
        let policy = VoiceNoteSettings.load().languagePolicy(
            activeModel: AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? "openai_whisper-small",
            keyboardLanguage: SupportedLanguage.active
        )
        let ranges = VoiceNoteChunker.ranges(for: samples)
        log("started", "id=\(note.id.uuidString.prefix(8)) seconds=\(Int(duration)) chunks=\(ranges.count) mode=\(policy.mode.telemetryDescription) engine=\(policy.engine.rawValue)")

        var parts: [String] = []
        for (index, range) in ranges.enumerated() {
            await waitForDictationToEnd()
            DictationCoordinator.shared.extendWarmWindowForVoiceNote()
            let chunk = Array(samples[range])
            do {
                let text = try await EngineAccessGate.shared.withAccess(.voiceNote) {
                    try await DictationCoordinator.shared.transcribeVoiceNoteChunk(chunk, languagePolicy: policy)
                }
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { parts.append(trimmed) }
            } catch let error as TranscriptionError {
                // A chunk of silence inside a note is not a failure of the note.
                switch error {
                case .noSpeechDetected, .emptyAudio:
                    break
                case .notReady, .transcriptionFailed:
                    return fail(note, .transcriptionFailed, detail: error.diagnosticDescription)
                }
            } catch {
                return fail(note, .transcriptionFailed, detail: DictationFailureMessage.diagnostic(for: error))
            }
            let progress = Double(index + 1) / Double(ranges.count)
            store.mutate { $0.update(note.id) { $0.state = .transcribing(progress: progress) } }
        }

        let transcript = parts.joined(separator: " ")
        guard !transcript.isEmpty else { return fail(note, .noSpeech, detail: "empty transcript") }

        let record = TranscriptionRecord(id: note.id, text: transcript, policy: policy, duration: duration,
                                         createdAt: note.receivedAt, source: .sharedFile)
        let saved = TranscriptionHistoryStore.shared.append(record) != nil
        var evicted: [UUID] = []
        store.mutate {
            evicted = $0.complete(note.id, transcript: transcript, language: record.language, savedToHistory: saved)
        }
        // History off: the queue's cap may have pushed an older transcript out, and the
        // keyboard must not keep offering it (#639, decision C).
        withdrawKeyboardDeliveries(evicted, reason: "evictedFromQueue")
        log("finished", "id=\(note.id.uuidString.prefix(8)) chars=\(transcript.count) savedToHistory=\(saved) elapsedMs=\(Int(Date().timeIntervalSince(started) * 1000))")
        publishToKeyboard(note: note, transcript: transcript, language: record.language,
                          durationSeconds: Int(duration.rounded()))
        VoiceNoteIslandDriver.shared.finished(note.id, succeeded: true)
        // A result that lands while the app is in front is ready and unread too.
        evaluatePresentation()
        // Still inside the queue's background task: the mode's result is then ready
        // before the user opens the card (#627). The island already shows the note as
        // ready; a card opened meanwhile attaches to this run rather than starting one.
        await runSmartModeInBackground(noteID: note.id, source: SmartModeSource(
            transcript: transcript, language: record.language,
            engine: policy.engine, durationSeconds: Int(duration.rounded())
        ))
    }

    // MARK: - The Smart Mode (#627)

    /// What a note's mode runs on: its transcript and what the card shows beside it.
    struct SmartModeSource {
        let transcript: String
        /// `TranscriptionRecord.language`: a language code, or the auto-detected marker.
        let language: String
        let engine: SpeechEngine?
        let durationSeconds: Int?
    }

    /// Run the note's Smart Mode right after its transcription, when the card would.
    private func runSmartModeInBackground(noteID: UUID, source: SmartModeSource) async {
        let mode = VoiceNoteSettings.load().mode.smartMode
        guard VoiceNoteSmartModeAttempt.runsInBackground(
            mode: mode,
            transcriptLength: source.transcript.count,
            unavailableReason: VoiceNoteAvailability.summaryUnavailableReason(engineState: PolishAvailability.state),
            isEntitled: VoiceNoteAvailability.isEntitled,
            hasStoredResult: storedSummary(for: noteID) != nil
        ) else { return }
        _ = await runSmartMode(noteID: noteID, source: source, trigger: .background)
    }

    /// Run the voice note mode on a transcript and store a result, from the queue or
    /// from the card (#627). One code path, so the card and the background build the
    /// same request and store the same way: History when the note is there, the queue
    /// when History is off.
    ///
    /// Returns nil when no mode is chosen.
    func runSmartMode(noteID: UUID, source: SmartModeSource,
                      trigger: VoiceNoteSmartModeTrigger) async -> PolishCoordinator.VoiceNoteModeRun? {
        guard let mode = VoiceNoteSettings.load().mode.smartMode else { return nil }
        let policy = TranscriptionLanguagePolicy(
            mode: source.language == TranscriptionRecord.autoDetectedCode
                ? .autoDetect
                : SupportedLanguage(rawValue: source.language).map(TranscriptionLanguageMode.explicit) ?? .autoDetect,
            keyboardLanguage: SupportedLanguage.active,
            engine: source.engine ?? .parakeet,
            modelIdentifier: AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? ""
        )
        // Its own slot (#648): a dictation started while this runs must not cancel it.
        // Keyed by note: a caller arriving while this note's mode is still running (the
        // card opened mid-run, the stack dismissed and the note reopened from History)
        // attaches to that run instead of starting a second one that would supersede it.
        let run = await PolishCoordinator.shared.polishVoiceNote(
            PolishCoordinator.VoiceNoteModeRequest(
                noteID: noteID, raw: source.transcript, languagePolicy: policy, smartMode: mode,
                recordingDuration: TimeInterval(source.durationSeconds ?? 0)
            ),
            trigger: trigger
        )
        // A degraded outcome hands back the transcript itself: never stored as a result.
        if run.attempt.action == .success,
           let summary = run.outcome.text?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            storeSummary(summary, modeIdentifier: mode.id, for: noteID)
        }
        return run
    }

    /// The stored mode result for a note, from whichever store holds it.
    private func storedSummary(for noteID: UUID) -> String? {
        if let record = TranscriptionHistoryStore.shared.record(id: noteID) { return record.summary }
        return store.queue.note(id: noteID)?.summary
    }

    /// Store a mode result where the note lives. A note deleted meanwhile is in neither
    /// store, and both writes are then no-ops.
    private func storeSummary(_ summary: String, modeIdentifier: String, for noteID: UUID) {
        let history = TranscriptionHistoryStore.shared
        if history.record(id: noteID) != nil {
            history.updateSummary(id: noteID, to: summary, modeIdentifier: modeIdentifier)
        } else {
            store.mutate {
                $0.update(noteID) {
                    $0.summary = summary
                    $0.summaryModeIdentifier = modeIdentifier
                }
            }
        }
    }

    // MARK: - The keyboard (#637)

    /// Offer a finished transcript to the keyboard, then tell a keyboard on screen.
    ///
    /// After the transcript is durable in History or the queue, so the keyboard can
    /// never hold the only copy; and the post comes after the file, so a keyboard that
    /// hears it always finds it. The post is best-effort — a suspended keyboard misses
    /// it and rereads the directory on its next appearance instead.
    ///
    /// Whatever the Pro status (#637 decision 9): `VoiceNoteAvailability` locks
    /// nothing already produced away.
    private func publishToKeyboard(note: VoiceNote, transcript: String, language: String, durationSeconds: Int) {
        guard let deliveries = VoiceNoteKeyboardDeliveryStore.appGroup else { return }
        let delivery = VoiceNoteKeyboardDelivery(
            id: note.id, transcript: transcript, sharedAt: note.receivedAt, transcribedAt: Date(),
            language: language, durationSeconds: durationSeconds
        )
        do {
            try deliveries.publish(delivery)
        } catch {
            // The note is still in History or the queue, and readable in the app.
            keyboardLog("publishFailed", "id=\(note.id.uuidString.prefix(8)) error=\(error.localizedDescription)")
            return
        }
        DarwinNotificationCenter.post(DarwinNotificationName.voiceNoteResultReady)
        keyboardLog("published", "id=\(note.id.uuidString.prefix(8)) chars=\(transcript.count)")
    }

    /// Take notes out of the keyboard. Since #639 for a delete in DictusApp — a History
    /// row, or the whole History — and for a note evicted by History's or the queue's
    /// cap (decision C): a note neither store holds any more must not live on in the
    /// keyboard. Reading or dismissing it here does not.
    func withdrawKeyboardDeliveries(_ ids: [UUID], reason: String) {
        guard let deliveries = VoiceNoteKeyboardDeliveryStore.appGroup else { return }
        let published = Set(deliveries.allDeliveries().map(\.id))
        let withdrawn = ids.filter(published.contains)
        guard !withdrawn.isEmpty else { return }
        withdrawn.forEach(deliveries.withdraw)
        keyboardLog("withdrawn", "ids=\(withdrawn.map { String($0.uuidString.prefix(8)) }.joined(separator: ",")) reason=\(reason)")
    }

    /// Turn the keyboard's receipts into "read" (`VoiceNoteKeyboardReceipts`, plus the
    /// island's segment), and prune what outlived its window.
    ///
    /// Called from every way in (#639): launch, every activation and every background,
    /// every `dictus://` URL before it is handled, the keyboard's Darwin recording
    /// start, and the keyboard's own receipt signal while this process is alive. The
    /// device test of 5f27a393 is why: two notes read in the keyboard stayed unread in
    /// the island because the app, alive in the background since a mic-tap dictation,
    /// went through none of the three transitions that used to be the only callers.
    ///
    /// What this no longer does (#639): withdraw the delivery with the receipt, or
    /// withdraw a note because it was read here, or because it is in neither store.
    /// The keyboard keeps a note 15 minutes after its last use so a long one can be
    /// quoted in several passes, and a History-off note leaves the queue the moment it
    /// is read — "in neither store" is that note too, so it cannot be the test. A
    /// delete in DictusApp, and an eviction by either cap (decision C), withdraw at
    /// the moment they happen instead (`withdrawKeyboardDeliveries`).
    func reconcileKeyboardDeliveries(reason: String) {
        guard let deliveries = VoiceNoteKeyboardDeliveryStore.appGroup else { return }
        let history = TranscriptionHistoryStore.shared

        let applied = VoiceNoteKeyboardReceipts.apply(from: deliveries, history: history, queue: store)
        var acknowledged: [String] = []
        for receipt in applied {
            VoiceNoteIslandDriver.shared.read(receipt.id)
            acknowledged.append("\(receipt.id.uuidString.prefix(8)):\(receipt.action.rawValue)")
        }

        // Deleted from the keyboard's reader (#639): the keyboard already hides them;
        // the files are this process's to remove. The note itself stays in History
        // or the queue, by their own rules.
        let deletedInKeyboard = Array(deliveries.deletedIDs())
        deletedInKeyboard.forEach(deliveries.withdraw)

        let expired = deliveries.pruneExpired()
        guard !acknowledged.isEmpty || !deletedInKeyboard.isEmpty || !expired.isEmpty else { return }
        keyboardLog("reconciled", "reason=\(reason) acknowledged=\(acknowledged.joined(separator: ",")) deletedInKeyboard=\(deletedInKeyboard.count) expired=\(expired.count) remaining=\(deliveries.allDeliveries().count)")
    }

    /// Ids, counts and actions only. Never the transcript (#637).
    private func keyboardLog(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "keyboard", action: action, details: details))
    }

    private func fail(_ note: VoiceNote, _ failure: VoiceNoteFailure, detail: String) {
        var evicted: [UUID] = []
        store.mutate { evicted = $0.fail(note.id, failure) }
        withdrawKeyboardDeliveries(evicted, reason: "evictedFromQueue")
        log("failed", "id=\(note.id.uuidString.prefix(8)) failure=\(failure.rawValue) detail=\(detail)")
        VoiceNoteIslandDriver.shared.finished(note.id, succeeded: false)
    }

    /// The queue never starts a chunk under a dictation. The gate would already serve
    /// the dictation first; this keeps the voice note from even competing for the
    /// Neural Engine while the user is speaking.
    private func waitForDictationToEnd() async {
        while DictationSessionLivenessPolicy.isActive(DictationCoordinator.shared.status) {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    static func failure(for error: VoiceNoteDecodeError) -> VoiceNoteFailure {
        switch error {
        case .unrecognisedFormat, .unsupportedCodec: return .unsupportedFormat
        case .unreadable: return .unreadable
        case .tooLong: return .tooLong
        case .empty: return .noSpeech
        }
    }

    // MARK: - Background time

    /// Belt and braces under the warm engine: a background task covers the seconds
    /// iOS grants after the engine is released or the activity is stopped, so a note
    /// a few seconds from done is not lost to a suspension. If it expires, the note
    /// stays `.transcribing` on disk and is recovered on the next run.
    ///
    /// A Smart Mode running when it expires is cancelled (#627): the note keeps its
    /// transcript, stores no result, and the card runs the mode on open.
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        // The handler runs synchronously on the main thread and must end the task before
        // it returns, or iOS kills the process; hence no hop (same pattern as #470).
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "dictus.voiceNote") { [weak self] in
            MainActor.assumeIsolated {
                self?.log("backgroundTimeExpired", "remaining=\(self?.store.queue.waitingCount ?? 0)")
                PolishCoordinator.shared.cancelBackgroundVoiceNoteRun()
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    private func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "queue", action: action, details: details))
    }
}
