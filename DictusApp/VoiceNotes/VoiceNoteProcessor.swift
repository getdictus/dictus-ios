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
        // Every note still to transcribe joins the ring, interrupted ones included.
        VoiceNoteIslandDriver.shared.arrived(store.queue.stackable.filter { !$0.state.isFinished }.map(\.id))
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
        VoiceNoteIslandDriver.shared.arrived(arrived.map(\.id))
        let state = UIApplication.shared.applicationState
        log("accepted", "count=\(arrived.count) appState=\(state.rawValue) activity=\(LiveActivityManager.shared.hasLiveActivity)")
        processQueue()
    }

    /// The cold path, and every return to the app.
    func appBecameActive() {
        VoiceNoteIslandDriver.shared.arrived(store.ingestInbox().map(\.id))
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
        }
        // A finished note's ring stays until it is read or its five minutes are up
        // (#620 decision 4): opening the app is not reading the note.
    }

    /// A card showed a note's outcome: the ring loses that segment (#620 decision 9).
    func noteRead(_ id: UUID) {
        VoiceNoteIslandDriver.shared.read(id)
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
        store.mutate {
            $0.complete(note.id, transcript: transcript, language: record.language, savedToHistory: saved)
        }
        log("finished", "id=\(note.id.uuidString.prefix(8)) chars=\(transcript.count) savedToHistory=\(saved) elapsedMs=\(Int(Date().timeIntervalSince(started) * 1000))")
        VoiceNoteIslandDriver.shared.finished(note.id, succeeded: true)
    }

    private func fail(_ note: VoiceNote, _ failure: VoiceNoteFailure, detail: String) {
        store.mutate { $0.fail(note.id, failure) }
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
