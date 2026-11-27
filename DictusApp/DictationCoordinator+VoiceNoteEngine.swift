// DictusApp/DictationCoordinator+VoiceNoteEngine.swift
// The engine a voice note runs on when it is not the dictation's (#1084, PR 2).
//
// WHY a file of its own: DictationCoordinator.swift sits at the length budget of #146,
// the reason `DictationCoordinator+WarmEngineTimeout.swift` exists.
import DictusCore
import Foundation
import WhisperKit

extension DictationCoordinator {

    /// Load the engine `VoiceNoteEngineChoice` picked for a voice note, before a chunk.
    ///
    /// `.downloadedModel` loads `activeModel` even though Apple's model dictates. It is a load
    /// like any other (`ensureEngineReady(preferredModel:)`): the init lock, the Neural Engine
    /// gate, the warm inference. Nothing switches under a dictation: the queue calls this
    /// inside `EngineAccessGate`, after `waitForDictationToEnd`.
    ///
    /// A downloaded model that fails to load hands the note to the dictation's engine, Apple's,
    /// which reads it as before this choice existed (in the dictation language, said on the
    /// card) rather than failing a note Apple can read.
    func prepareVoiceNoteEngine(_ engine: VoiceNoteEngineChoice) async throws {
        guard engine == .downloadedModel else { return try await ensureEngineReady() }
        let model = AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? "openai_whisper-small"
        guard currentModelName != model else { return }
        let before = currentModelName ?? "none"
        let started = Date()
        do {
            try await ensureEngineReady(preferredModel: model)
        } catch {
            Self.logVoiceNoteEngine("downloadedModelFailed",
                                    "model=\(model) error=\(DictationFailureMessage.diagnostic(for: error)) fallback=dictationEngine")
            return try await ensureEngineReady()
        }
        Self.logVoiceNoteEngine("downloadedModelLoaded",
                                "from=\(before) model=\(model) loadMs=\(Self.milliseconds(since: started))")
    }

    /// Put the dictation's engine back once the voice-note queue drained, so the downloaded
    /// model a note loaded does not stay in memory beside Apple's. The next dictation would do
    /// it anyway in its own `ensureEngineReady`, and Apple's engine loads nothing in this
    /// process, so neither waits. The caller holds `EngineAccessGate`, as for a chunk.
    func restoreDictationEngineAfterVoiceNotes() async {
        let before = currentModelName ?? "none"
        let started = Date()
        do {
            try await ensureEngineReady()
            Self.logVoiceNoteEngine("dictationEngineRestored",
                                    "from=\(before) to=\(currentModelName ?? "none") elapsedMs=\(Self.milliseconds(since: started))")
        } catch {
            Self.logVoiceNoteEngine("restoreFailed", "from=\(before) error=\(DictationFailureMessage.diagnostic(for: error))")
        }
    }

    /// Compile `model`'s Core ML cache and run its warm inference, which records it warm
    /// (`ModelWarmth.markWarm`), then drop the engine (#1084, PR 2, cold-cache variant).
    ///
    /// WHY ASIDE and not through `ensureEngineReady`: that publishes the engine into
    /// `TranscriptionService`, so a keyboard dictation running on Apple's engine meanwhile
    /// could find the downloaded model under it, and a load holds `EngineAccessGate` for the
    /// length of a compile. This touches neither: Apple's engine stays installed, and a
    /// dictation on it takes no Neural Engine lock. It does take that lock, so it never
    /// compiles beside another load. `VoiceNoteModelCompile` decides when it runs.
    func compileDownloadedModelAside(_ model: String) async throws {
        let holder = "VoiceNoteCompile:\(model)"
        try await acquireNeuralEngine(for: holder)
        defer { releaseNeuralEngine(from: holder) }
        switch ModelInfo.forIdentifier(model)?.engine ?? .whisperKit {
        case .parakeet:
            guard ParakeetEngine.installedModelCacheDirectory() != nil else {
                throw SpeechModelError.modelNotInstalled(identifier: model)
            }
            _ = try await warmedParakeetEngine(modelName: model)
        case .nemotron:
            guard NemotronEngine.installedModelDirectory() != nil else {
                throw SpeechModelError.modelNotInstalled(identifier: model)
            }
            _ = try await warmedNemotronEngine(modelName: model)
        case .whisperKit, .apple:
            guard let folder = WhisperModelRepository.installedModelFolderURL(for: model) else {
                throw SpeechModelError.modelNotInstalled(identifier: model)
            }
            // The configuration `ensureWhisperKitEngineReady` loads with, so the cache it
            // compiles is the one a later load reads.
            let kit = try await WhisperKit(WhisperKitConfig(model: model, modelFolder: folder.path,
                                                            computeOptions: WhisperComputeOptions.current(),
                                                            verbose: false, prewarm: true, load: true, download: false))
            _ = await warmedWhisperKitEngine(for: kit, modelName: model)
        }
    }

    private static func milliseconds(since date: Date) -> Int {
        Int(Date().timeIntervalSince(date) * 1000)
    }

    private static func logVoiceNoteEngine(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "engine", action: action, details: details))
    }
}
