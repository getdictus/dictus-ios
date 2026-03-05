// DictusApp/DictationCoordinator.swift
// Manages the dictation lifecycle: recording via AudioRecorder + transcription via TranscriptionService.
import Foundation
import Combine
import AVFoundation
import DictusCore
import WhisperKit

/// Manages the dictation lifecycle in the main app.
/// Phase 2.3: Integrated with SmartModelRouter for duration-based model selection
/// and FillerWordFilter (applied in TranscriptionService).
///
/// WHY this class is @MainActor and uses static let shared:
/// - @MainActor ensures all @Published property updates happen on the main thread (required by SwiftUI)
/// - Singleton pattern because there's only ever one dictation session active at a time,
///   and multiple views need to observe the same coordinator (ContentView, RecordingView)
@MainActor
class DictationCoordinator: ObservableObject {
    static let shared = DictationCoordinator()

    // MARK: - Published State

    @Published var status: DictationStatus = .idle
    @Published var lastResult: String?

    /// Forwarded from AudioRecorder for waveform visualization in RecordingView.
    @Published var bufferEnergy: [Float] = []

    /// Forwarded from AudioRecorder for elapsed time display in RecordingView.
    @Published var bufferSeconds: Double = 0

    // MARK: - Private

    private let defaults = AppGroup.defaults
    private let audioRecorder = AudioRecorder()
    private let transcriptionService = TranscriptionService()
    private var whisperKit: WhisperKit?
    private var dictationTask: Task<Void, Never>?

    /// Combine subscription forwarding AudioRecorder's published values to coordinator.
    ///
    /// WHY Combine sink instead of direct observation:
    /// AudioRecorder is a separate ObservableObject. We need to forward its @Published
    /// properties to DictationCoordinator's @Published properties so RecordingView can
    /// observe a single source of truth (the coordinator).
    private var energyCancellable: AnyCancellable?
    private var secondsCancellable: AnyCancellable?

    private init() {
        // Forward AudioRecorder's energy levels and seconds to coordinator
        energyCancellable = audioRecorder.$bufferEnergy
            .receive(on: DispatchQueue.main)
            .sink { [weak self] energy in
                self?.bufferEnergy = energy
            }
        secondsCancellable = audioRecorder.$bufferSeconds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] seconds in
                self?.bufferSeconds = seconds
            }
    }

    // MARK: - Public API

    /// Called when the app receives dictus://dictate URL.
    /// Starts the full recording pipeline.
    ///
    /// Phase 2.3: Now checks SharedKeys.modelReady before starting.
    /// If no model is downloaded, writes a descriptive error instead of crashing.
    func startDictation() {
        if #available(iOS 14.0, *) {
            DictusLogger.app.info("Dictation started via URL scheme")
        }

        // Check if a model is downloaded and ready
        let modelReady = defaults.bool(forKey: SharedKeys.modelReady)
        guard modelReady else {
            handleError("No model downloaded. Open Dictus to download a model.")
            return
        }

        // Cancel any in-flight dictation before starting a new one
        dictationTask?.cancel()

        dictationTask = Task {
            do {
                // Step 1: Check microphone permission
                let hasPermission = try await audioRecorder.ensureMicrophonePermission()
                guard hasPermission else {
                    handleError("Microphone permission denied")
                    return
                }

                // Step 2: Initialize WhisperKit if not already ready
                try await ensureWhisperKitReady()

                // Step 3: Start recording
                updateStatus(.recording)
                try audioRecorder.startRecording()

                if #available(iOS 14.0, *) {
                    DictusLogger.app.info("Recording started successfully")
                }
            } catch {
                if #available(iOS 14.0, *) {
                    DictusLogger.app.error("Failed to start dictation: \(error.localizedDescription)")
                }
                handleError(error.localizedDescription)
            }
        }
    }

    /// Called when user taps the stop button.
    /// Stops recording and starts transcription.
    ///
    /// Phase 2.3: Uses SmartModelRouter to select the best model based on
    /// recorded audio duration. Short clips (< 5s) use fast models, longer
    /// clips use accurate models.
    func stopDictation() {
        dictationTask?.cancel()

        dictationTask = Task {
            do {
                // Step 1: Stop recording and get audio samples
                let samples = audioRecorder.stopRecording()

                guard !samples.isEmpty else {
                    handleError("No audio recorded")
                    return
                }

                // Step 2: Calculate audio duration for smart routing
                let audioDuration = bufferSeconds

                if #available(iOS 14.0, *) {
                    DictusLogger.app.info("Recording stopped. Samples: \(samples.count), Duration: \(String(format: "%.1f", audioDuration))s")
                }

                // Step 3: Use SmartModelRouter to select the best model
                // Read downloaded models from App Group (loose coupling — no reference to ModelManager)
                let downloadedModels = readDownloadedModels()
                let selectedModel = SmartModelRouter.selectModel(
                    audioDuration: audioDuration,
                    downloadedModels: downloadedModels
                )

                if #available(iOS 14.0, *) {
                    DictusLogger.app.info("SmartModelRouter selected: \(selectedModel) for \(String(format: "%.1f", audioDuration))s audio")
                }

                // Step 4: Ensure WhisperKit is loaded with the selected model
                // If the router selected a different model than currently loaded,
                // this will reinitialize WhisperKit with the new model.
                if !selectedModel.isEmpty {
                    try await ensureWhisperKitReady(preferredModel: selectedModel)
                }

                // Step 5: Transcribe (FillerWordFilter.clean() is applied inside TranscriptionService)
                updateStatus(.transcribing)
                let text = try await transcriptionService.transcribe(audioSamples: samples)

                // Step 6: Write result to App Group
                // IMPORTANT: Write both lastTranscription AND status to UserDefaults
                // BEFORE posting any Darwin notifications. This prevents a race condition
                // where the keyboard reads UserDefaults between two separate notifications
                // and sees status=ready but lastTranscription is still nil.
                lastResult = text
                status = .ready
                defaults.set(text, forKey: SharedKeys.lastTranscription)
                defaults.set(Date().timeIntervalSince1970, forKey: SharedKeys.lastTranscriptionTimestamp)
                defaults.set(DictationStatus.ready.rawValue, forKey: SharedKeys.dictationStatus)
                defaults.synchronize()

                // Post notifications after ALL writes are complete
                DarwinNotificationCenter.post(DarwinNotificationName.statusChanged)
                DarwinNotificationCenter.post(DarwinNotificationName.transcriptionReady)

                if #available(iOS 14.0, *) {
                    DictusLogger.app.info("Transcription complete: \(text)")
                }

                // Step 7: Brief delay for checkmark flash before returning to idle
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if status == .ready {
                    updateStatus(.idle)
                }
            } catch {
                if #available(iOS 14.0, *) {
                    DictusLogger.app.error("Transcription failed: \(error.localizedDescription)")
                }
                handleError(error.localizedDescription)
            }
        }
    }

    /// Reset status to idle (e.g., after user returns to keyboard).
    func resetStatus() {
        updateStatus(.idle)
        lastResult = nil
    }

    // MARK: - Private Helpers

    /// Initialize WhisperKit with the preferred model if not already loaded.
    ///
    /// Phase 2.3: Now accepts an optional preferredModel parameter from SmartModelRouter.
    /// Falls back to the active model from App Group, then to "openai_whisper-tiny".
    ///
    /// WHY we support model switching:
    /// SmartModelRouter may select different models for different audio durations.
    /// A 3-second voice note should use tiny/base for speed, while a 30-second
    /// dictation benefits from small/medium for accuracy. This method handles
    /// lazy initialization AND model switching.
    private func ensureWhisperKitReady(preferredModel: String? = nil) async throws {
        let modelName = preferredModel
            ?? defaults.string(forKey: SharedKeys.activeModel)
            ?? "openai_whisper-tiny"

        // If WhisperKit is already loaded with a compatible model, reuse it
        // (We reinitialize only when the model changes)
        if whisperKit != nil, preferredModel == nil {
            return
        }

        if #available(iOS 14.0, *) {
            DictusLogger.app.info("Initializing WhisperKit with model: \(modelName)")
        }

        let config = WhisperKitConfig(
            model: modelName,
            verbose: false,
            prewarm: true,
            load: true,
            download: true
        )

        let kit = try await WhisperKit(config)
        self.whisperKit = kit

        // Share the instance with AudioRecorder and TranscriptionService
        audioRecorder.prepare(whisperKit: kit)
        transcriptionService.prepare(whisperKit: kit)

        if #available(iOS 14.0, *) {
            DictusLogger.app.info("WhisperKit ready with model: \(modelName)")
        }
    }

    /// Reads the list of downloaded model identifiers from App Group UserDefaults.
    ///
    /// WHY read from App Group instead of holding a ModelManager reference:
    /// Loose coupling — the coordinator doesn't need to know about ModelManager's
    /// UI state or lifecycle. It only needs the list of available models, which
    /// ModelManager persists to the shared App Group. This also means the keyboard
    /// extension could use the same pattern in the future.
    private func readDownloadedModels() -> [String] {
        guard let data = defaults.data(forKey: SharedKeys.downloadedModels),
              let models = try? JSONDecoder().decode([String].self, from: data) else {
            // Fallback: if no models stored yet, check for active model
            if let active = defaults.string(forKey: SharedKeys.activeModel) {
                return [active]
            }
            return []
        }
        return models
    }

    /// Write dictation status to App Group so the keyboard can observe it.
    private func updateStatus(_ newStatus: DictationStatus) {
        status = newStatus
        defaults.set(newStatus.rawValue, forKey: SharedKeys.dictationStatus)
        defaults.synchronize()

        // Signal keyboard that status changed
        DarwinNotificationCenter.post(DarwinNotificationName.statusChanged)
    }

    /// Handle errors by updating status and writing error to App Group.
    private func handleError(_ message: String) {
        defaults.set(message, forKey: SharedKeys.lastError)
        defaults.synchronize()
        updateStatus(.failed)
    }
}
