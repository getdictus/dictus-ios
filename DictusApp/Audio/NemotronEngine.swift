// DictusApp/Audio/NemotronEngine.swift
// FluidAudio-based Nemotron 3.5 ASR engine, driven offline, iOS 17+ (#558).
import Foundation
import DictusCore
import FluidAudio

/// Nemotron 3.5 ASR multilingual speech-to-text engine, through FluidAudio's streaming manager
/// used as a batch transcriber: one finished transcript per dictation, no partial results.
///
/// WHY THIS ENGINE EXISTS (#552, #558): Parakeet TDT v3 has no decoder prompt, so on hard
/// French audio it drifts into pseudo-English that nothing downstream can repair. Nemotron
/// takes the language as a prompt on its encoder and is forced to it. It is an added option the
/// user picks, never the recommended default.
///
/// WHY THE STREAMING MANAGER WITHOUT STREAMING: `StreamingNemotronMultilingualAsrManager` is the
/// only FluidAudio entry point for this model. `process(samples:)` takes a whole recording and
/// cuts it into chunks itself, and `finish()` returns the transcript, so it serves a batch
/// dictation exactly. Live text in the keyboard is a separate feature, out of #558's scope.
///
/// WHAT MAKES IT DIFFERENT FROM ParakeetEngine, AND DANGEROUS: the manager is a stateful actor.
/// `finish()` clears the accumulated tokens and nothing else. The encoder caches, the decoder's
/// LSTM state and the detected language all survive it, so a dictation that did not start with
/// `reset()` would begin inside the previous one's context. `transcribe` therefore resets
/// before every session, the warm inference included, and runs one session at a time.
///
/// Kept from `ParakeetEngine`, deliberately: the load is strictly local and never downloads
/// (#252), the one-second floor is refused as `noSpeechDetected` (#313), and the caller must
/// serialize engine loads: a Nemotron compile running alongside a WhisperKit or Parakeet compile
/// crashes the Neural Engine with "E5 bundle", and `DictationCoordinator` already runs one at
/// a time.
@available(iOS 17.0, *)
final class NemotronEngine: SpeechModelProtocol {
    var engineName: String { "Nemotron" }

    private var manager: StreamingNemotronMultilingualAsrManager?
    private var isInitialized = false

    /// One dictation session at a time on the shared manager. See `SessionGate`.
    private let sessionGate = SessionGate()

    var isReady: Bool {
        isInitialized
    }

    // MARK: - On-disk layout

    /// The compiled bundles the multilingual ship carries and the manager loads.
    ///
    /// Encoder, decoder and joint are FluidAudio's own names. `decoder_joint.mlmodelc` is the
    /// fused step decoder the manager prefers when present; FluidAudio loads it by that literal
    /// name and exposes no constant for it. All four are in the repository and all four are
    /// downloaded, so all four are required: a guard that accepted any valid decode path would
    /// have to restate the manager's own fallback order to stay true.
    static let requiredModelBundles: Set<String> = [
        ModelNames.NemotronMultilingualStreaming.encoderFile,
        ModelNames.NemotronMultilingualStreaming.decoderFile,
        ModelNames.NemotronMultilingualStreaming.jointFile,
        "decoder_joint.mlmodelc"
    ]

    /// `metadata.json` carries the prompt dictionary, `tokenizer.json` the vocabulary.
    /// `loadModels(from:)` refuses to run without either.
    static let rootFileNames = [
        ModelNames.NemotronMultilingualStreaming.metadata,
        ModelNames.NemotronMultilingualStreaming.tokenizer
    ]

    /// The repository's local root, where `ModelRepoDownloader` writes and where FluidAudio's
    /// own cache layout puts this repository:
    /// `Application Support/FluidAudio/Models/Nemotron-3.5-ASR-Streaming-Multilingual-0.6b-CoreML`.
    ///
    /// Process-relative Application Support, so DictusApp only, like Parakeet's cache.
    static var repositoryCacheDirectory: URL {
        MLModelConfigurationUtils.defaultModelsDirectory(for: .nemotronMultilingual)
    }

    /// The model directory the manager loads: the local copy of `multilingual/2240ms`.
    static var modelDirectory: URL {
        repositoryCacheDirectory.appendingPathComponent(NemotronModelRepository.variantDirectory, isDirectory: true)
    }

    /// The model directory when it holds a complete model, otherwise `nil` (#252).
    static func installedModelDirectory() -> URL? {
        NemotronModelRepository.installedModelDirectory(
            modelDirectory,
            requiredModelBundles: requiredModelBundles,
            rootFileNames: rootFileNames
        )
    }

    /// What a load would find missing, for the repair's log. Empty when complete.
    static func missingEntries() -> [String] {
        NemotronModelRepository.missingEntries(
            in: modelDirectory,
            requiredModelBundles: requiredModelBundles,
            rootFileNames: rootFileNames
        )
    }

    // MARK: - SpeechModelProtocol

    /// Load the compiled model from the local cache. Never downloads.
    ///
    /// The manager is built with no configuration on purpose: it pins `.cpuAndNeuralEngine`
    /// itself, and FluidAudio documents `.all` as routing the int8 encoder to the GPU at about
    /// ten times slower.
    ///
    /// `loadModels` also runs one zero-input prediction per model before returning, so the
    /// duration the coordinator logs around this call covers the Core ML compile and that
    /// first dispatch, which is the figure the #558 device test compares against Parakeet.
    func prepare(modelIdentifier: String) async throws {
        guard !isInitialized else { return }

        guard let directory = Self.installedModelDirectory() else {
            let error = SpeechModelError.modelNotInstalled(identifier: modelIdentifier)
            PersistentLog.log(.diagnosticProbe(
                component: "NemotronLoad",
                instanceID: modelIdentifier,
                action: "localModelMissing",
                details: "missing=\(Self.missingEntries().joined(separator: ",")) \(error.diagnosticDescription)"
            ))
            throw error
        }

        do {
            let manager = StreamingNemotronMultilingualAsrManager()
            try await manager.loadModels(from: directory)
            self.manager = manager
            self.isInitialized = true
            DictusLogger.app.info("NemotronEngine: multilingual 2240ms models loaded and ready")
        } catch {
            isInitialized = false
            manager = nil
            DictusLogger.app.error("NemotronEngine: initialization failed — \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// One discarded inference on generated silence, so the first real dictation does not pay
    /// the Neural Engine's per-shape specialization (#426).
    ///
    /// Goes through `transcribe`, which resets the manager first and holds the session gate, so
    /// nothing of this pass reaches the dictation that follows: the next `transcribe` resets
    /// again before it feeds a sample.
    func runWarmInference() async throws {
        do {
            _ = try await transcribe(audioSamples: WarmInferenceAudio.silence(), language: nil)
        } catch TranscriptionError.noSpeechDetected {
            // Silence produced no words: the expected outcome, and a success here. Same
            // reasoning as `ParakeetEngine.runWarmInference`.
        }
    }

    /// Shortest clip accepted, one second at 16 kHz. Parakeet's floor (#313), kept so the two
    /// FluidAudio engines refuse the same accidental tap the same way. The manager itself pads
    /// a short final chunk and would accept less; the rule is about what a user meant.
    private static let minimumSampleCount = 16_000

    /// Transcribe one dictation.
    ///
    /// - Parameters:
    ///   - audioSamples: Float32 audio samples at 16 kHz mono.
    ///   - language: `TranscriptionLanguagePolicy.sttLanguageCode`: the keyboard language in
    ///     `.followKeyboard`, the chosen one in `.explicit`, `nil` in `.autoDetect`. Mapped by
    ///     `NemotronLanguagePrompt`, so `nil` becomes the model's `"auto"` prompt.
    /// - Returns: the transcript, with the forced code, the prompt id FluidAudio resolved it to
    ///   and the language tag the decoder emitted, for the log. No confidence: FluidAudio
    ///   exposes none for this model, and #554's field is Parakeet's.
    func transcribe(audioSamples: [Float], language: String?) async throws -> SpeechTranscription {
        guard let manager else {
            throw TranscriptionError.notReady
        }
        guard !audioSamples.isEmpty else {
            throw TranscriptionError.emptyAudio
        }
        guard audioSamples.count >= Self.minimumSampleCount else {
            throw TranscriptionError.noSpeechDetected(
                context: "\(audioSamples.count) samples, below Nemotron's \(Self.minimumSampleCount) floor")
        }

        let code = NemotronLanguagePrompt.code(forSTTLanguageCode: language)

        await sessionGate.acquire()
        do {
            let result = try await runSession(on: manager, samples: audioSamples, languageCode: code)
            await sessionGate.release()
            return result
        } catch {
            await sessionGate.release()
            if let error = error as? TranscriptionError {
                throw error
            }
            throw TranscriptionError.transcriptionFailed("Nemotron: \(error.localizedDescription)")
        }
    }

    /// One complete session: reset, force the language, feed, finish.
    ///
    /// THE ORDER IS THE CONTRACT. `reset()` first, because nothing else clears the encoder
    /// caches and the decoder state a previous session left. `setLanguage` after it, because
    /// the prompt id is what the encoder receives for every chunk `process` feeds. `finish()`
    /// last, because it decodes the padded tail and returns the transcript.
    private func runSession(
        on manager: StreamingNemotronMultilingualAsrManager,
        samples: [Float],
        languageCode: String
    ) async throws -> SpeechTranscription {
        await manager.reset()
        await manager.setLanguage(languageCode)

        let promptId = await manager.promptId()
        let defaultPromptId = await manager.config.defaultPromptId
        if languageCode != NemotronLanguagePrompt.autoDetect, promptId == defaultPromptId {
            // FluidAudio resolves a code it does not know to the default prompt without an
            // error. Said out loud, because a French dictation silently run in auto mode is
            // exactly the drift this engine exists to prevent.
            PersistentLog.log(.diagnosticProbe(
                component: "NemotronPrompt",
                instanceID: languageCode,
                action: "languageFellBackToAuto",
                details: "code=\(languageCode) promptId=\(promptId) defaultPromptId=\(defaultPromptId)"
            ))
        }

        _ = try await manager.process(samples: samples)
        let rawText = try await manager.finish()
        let detected = await manager.detectedLanguage()

        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw TranscriptionError.noSpeechDetected(context: "empty Nemotron transcription result")
        }
        return SpeechTranscription(
            text: text,
            confidence: nil,
            language: languageCode,
            promptId: promptId,
            detectedLanguage: detected
        )
    }
}

/// A first-come, first-served lock for one async session at a time.
///
/// WHY NOT THE MANAGER'S OWN ACTOR ISOLATION: an actor serializes each call, not a sequence of
/// calls. `reset`, `setLanguage`, `process` and `finish` are four awaits, and a second session
/// arriving between two of them would reset the first one halfway through, or feed its samples
/// into it. The coordinator does not start two transcriptions on one engine (#144), and a warm
/// inference runs before the engine is published (#426), so this gate should never actually
/// queue anything. It exists so that "no state leaks between dictations" does not rest on two
/// facts held in another file.
private actor SessionGate {
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard isBusy else {
            isBusy = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if waiters.isEmpty {
            isBusy = false
        } else {
            // Ownership passes straight to the next waiter; `isBusy` stays true.
            waiters.removeFirst().resume()
        }
    }
}
