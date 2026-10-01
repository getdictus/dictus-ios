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
        // Anything shared before this launch, and anything a dead process left
        // mid-transcription, is picked up now.
        store.ingestInbox()
        log("launch", "pending=\(store.queue.hasPendingWork)")
    }

    /// The warm path: a note arrived while this process was alive to hear it.
    private func noteQueuedWhileAlive() {
        let arrived = store.ingestInbox()
        guard !arrived.isEmpty else { return }
        // Written before the post, so the extension reads it when the post lands.
        AppGroup.defaults.set(LiveActivityManager.shared.hasLiveActivity, forKey: SharedKeys.voiceNoteAcceptedWithActivity)
        AppGroup.defaults.synchronize()
        DarwinNotificationCenter.post(DarwinNotificationName.voiceNoteAccepted)
        let state = UIApplication.shared.applicationState
        log("accepted", "count=\(arrived.count) appState=\(state.rawValue) activity=\(LiveActivityManager.shared.hasLiveActivity)")
        processQueue()
    }

    /// The cold path, and every return to the app.
    func appBecameActive() {
        store.ingestInbox()
        if store.queue.hasPendingWork {
            // The user opened Dictus because the extension told them to: show them
            // the note itself, turning from progress into its result. A Live Activity
            // link that already chose a screen keeps it. Not without the entitlement:
            // the queue would not run, and a screen raised on every launch to say so
            // would be a nag (#593).
            if presentation == nil && VoiceNoteAvailability.isEntitled {
                presentation = VoiceNoteStackRequest(focus: nil)
            }
            processQueue()
        } else {
            // The user is in the app; a finished note on the pill has done its job.
            LiveActivityManager.shared.updateVoiceNote(nil)
        }
    }

    /// `dictus://voice-note[?id=…]`, from the Live Activity: the voice note screen,
    /// on the unread stack (see `VoiceNoteStackView`).
    func open(_ target: UUID?) {
        presentation = VoiceNoteStackRequest(focus: target)
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
                LiveActivityManager.shared.updateVoiceNote(nil)
                return
            }
            await transcribe(note)
        }
        publishActivity(finished: nil)
    }

    private func transcribe(_ note: VoiceNote) async {
        let started = Date()
        store.mutate { $0.update(note.id) { $0.state = .transcribing(progress: 0) } }
        publishActivity(progress: 0, preview: nil)
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
            publishActivity(progress: progress, preview: parts.joined(separator: " "))
        }

        let transcript = parts.joined(separator: " ")
        guard !transcript.isEmpty else { return fail(note, .noSpeech, detail: "empty transcript") }

        let record = TranscriptionRecord(id: note.id, text: transcript, policy: policy, duration: duration,
                                         createdAt: note.receivedAt, source: .sharedFile)
        let saved = TranscriptionHistoryStore.shared.append(record) != nil
        store.mutate {
            $0.complete(note.id, transcript: transcript, language: record.language, savedToHistory: saved)
        }
        log("finished", "id=\(note.id.uuidString.prefix(8)) chars=\(transcript.count) savedToHistory=\(saved) elapsedMs=\(Int(Date().timeIntervalSince(started) * 1000))")
        publishActivity(finished: .success(id: note.id, transcript: transcript))
    }

    private func fail(_ note: VoiceNote, _ failure: VoiceNoteFailure, detail: String) {
        store.mutate { $0.fail(note.id, failure) }
        log("failed", "id=\(note.id.uuidString.prefix(8)) failure=\(failure.rawValue) detail=\(detail)")
        publishActivity(finished: .failure(note.id))
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
        case .unrecognisedFormat: return .unsupportedFormat
        case .unreadable: return .unreadable
        case .tooLong: return .tooLong
        case .empty: return .noSpeech
        }
    }

    // MARK: - Live Activity

    private enum Finished {
        case success(id: UUID, transcript: String)
        case failure(UUID)
    }

    /// While a note runs: progress, the queue line, and the first lines once known.
    private func publishActivity(progress: Double, preview: String?) {
        let counts = store.queue.activityCounts
        LiveActivityManager.shared.updateVoiceNote(VoiceNoteActivityContent(
            headline: String(localized: "Transcribing a voice note…",
                             comment: "Live Activity headline while a shared voice note is transcribed (#620)."),
            detail: counts.waiting > 0 ? VoiceNoteCopy.queueLine(inProgress: counts.inProgress, waiting: counts.waiting) : nil,
            progress: progress,
            preview: (preview?.isEmpty ?? true) ? nil : preview
        ))
    }

    /// Once the queue has nothing left running, the outcome of the last note — and
    /// nothing at all if the loop ended with no note finished.
    private func publishActivity(finished: Finished?) {
        if store.queue.hasPendingWork, let progressNote = store.queue.inProgress,
           case .transcribing(let progress) = progressNote.state {
            publishActivity(progress: progress, preview: nil)
            return
        }
        switch finished {
        case .success(let id, let transcript):
            LiveActivityManager.shared.updateVoiceNote(VoiceNoteActivityContent(
                headline: String(localized: "Voice note transcribed",
                                 comment: "Live Activity headline once a shared voice note is transcribed. A tap opens it (#620)."),
                preview: transcript, noteID: id, isDone: true
            ))
        case .failure(let failedID):
            LiveActivityManager.shared.updateVoiceNote(VoiceNoteActivityContent(
                headline: String(localized: "Voice note not transcribed",
                                 comment: "Live Activity headline when a shared voice note failed. A tap opens the voice note screen, which says why (#620)."),
                noteID: failedID, isDone: true
            ))
        case nil:
            break
        }
    }

    // MARK: - Background time

    /// Belt and braces under the warm engine: a background task covers the seconds
    /// iOS grants after the engine is released or the activity is stopped, so a note
    /// a few seconds from done is not lost to a suspension. If it expires, the note
    /// stays `.transcribing` on disk and is recovered on the next run.
    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "dictus.voiceNote") { [weak self] in
            Task { @MainActor in
                self?.log("backgroundTimeExpired", "remaining=\(self?.store.queue.waitingCount ?? 0)")
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
