// DictusKeyboard/KeyboardState.swift
import Foundation
import UIKit
import Combine
import DictusCore

/// Observes cross-process state changes from DictusApp via Darwin notifications.
/// Reads actual data from App Group UserDefaults after each notification.
///
/// Phase 3 additions:
/// - waveformEnergy/recordingElapsed for recording overlay visualization
/// - requestStop()/requestCancel() to send commands back to DictusApp
/// - Auto-insert transcription into active text field via textDocumentProxy
/// - Haptic feedback on recording lifecycle events
class KeyboardState: ObservableObject {
    @Published var dictationStatus: DictationStatus = .idle
    @Published var lastTranscription: String?
    @Published var statusMessage: String?
    @Published var waveformEnergy: [Float] = []
    @Published var recordingElapsed: Double = 0

    /// Reference to the keyboard controller for text insertion.
    /// WHY weak: KeyboardState is owned by KeyboardRootView (via @StateObject),
    /// and the controller owns the hosting view. A strong reference would create
    /// a retain cycle: controller -> view -> state -> controller.
    weak var controller: UIInputViewController?

    /// Closure to open a URL from the keyboard extension.
    /// WHY a closure: KeyboardState is not a SwiftUI View, so it cannot use
    /// @Environment(\.openURL). KeyboardRootView captures its own openURL
    /// environment action and injects it here via .onAppear — same pattern
    /// as the controller reference above.
    var openURL: ((URL) -> Void)?

    private let defaults = AppGroup.defaults

    init() {
        // Read initial state from App Group
        refreshFromDefaults()

        // Observe Darwin notifications for real-time updates
        DarwinNotificationCenter.addObserver(
            for: DarwinNotificationName.statusChanged
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.refreshFromDefaults()
            }
        }

        DarwinNotificationCenter.addObserver(
            for: DarwinNotificationName.transcriptionReady
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.handleTranscriptionReady()
            }
        }

        // Observe waveform updates from DictusApp during recording (~5Hz).
        // DictusApp writes JSON-encoded [Float] to SharedKeys.waveformEnergy
        // and elapsed seconds to SharedKeys.recordingElapsedSeconds, then posts
        // this notification. The keyboard reads the values for the overlay UI.
        DarwinNotificationCenter.addObserver(
            for: DarwinNotificationName.waveformUpdate
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.readWaveformData()
            }
        }
    }

    deinit {
        DarwinNotificationCenter.removeObserver(for: DarwinNotificationName.statusChanged)
        DarwinNotificationCenter.removeObserver(for: DarwinNotificationName.transcriptionReady)
        DarwinNotificationCenter.removeObserver(for: DarwinNotificationName.waveformUpdate)
    }

    // MARK: - Recording commands (keyboard -> app)

    /// Request DictusApp to stop recording and begin transcription.
    /// Uses the Darwin notification + Bool flag pattern: write the flag first,
    /// then post the notification so the app reads the flag when it handles the notification.
    func requestStop() {
        defaults.set(true, forKey: SharedKeys.stopRequested)
        defaults.synchronize()
        DarwinNotificationCenter.post(DarwinNotificationName.stopRecording)
        HapticFeedback.recordingStopped()
    }

    /// Request DictusApp to cancel recording and discard audio.
    /// Resets local keyboard state immediately for instant UI feedback,
    /// while the Darwin notification tells the app to clean up its side.
    func requestCancel() {
        defaults.set(true, forKey: SharedKeys.cancelRequested)
        defaults.synchronize()
        DarwinNotificationCenter.post(DarwinNotificationName.cancelRecording)

        // Reset local state immediately for responsive UI
        dictationStatus = .idle
        waveformEnergy = []
        recordingElapsed = 0
        statusMessage = nil
    }

    // MARK: - State observation

    /// Read current state from App Group UserDefaults.
    private func refreshFromDefaults() {
        if let rawStatus = defaults.string(forKey: SharedKeys.dictationStatus),
           let status = DictationStatus(rawValue: rawStatus) {
            dictationStatus = status
        }
    }

    /// Read waveform energy and elapsed time from App Group.
    /// Called when DictusApp posts waveformUpdate notification during recording.
    private func readWaveformData() {
        // Read elapsed seconds
        recordingElapsed = defaults.double(forKey: SharedKeys.recordingElapsedSeconds)

        // Read waveform energy: JSON-encoded [Float] array
        if let data = defaults.data(forKey: SharedKeys.waveformEnergy) {
            do {
                let energy = try JSONDecoder().decode([Float].self, from: data)
                waveformEnergy = energy
            } catch {
                // JSON decode failure — keep existing waveform data
                if #available(iOS 14.0, *) {
                    DictusLogger.keyboard.warning("Failed to decode waveform energy: \(error)")
                }
            }
        }
    }

    /// Handle transcription ready notification: auto-insert text into active field.
    ///
    /// Phase 3 behavior: instead of displaying transcription in a banner,
    /// insert it directly into the text field via textDocumentProxy.insertText().
    /// This matches the standard iOS dictation UX — user speaks, text appears at cursor.
    private func handleTranscriptionReady() {
        refreshFromDefaults()

        if let transcription = defaults.string(forKey: SharedKeys.lastTranscription),
           !transcription.isEmpty {
            // Auto-insert transcribed text into the active text field
            controller?.textDocumentProxy.insertText(transcription)
            HapticFeedback.textInserted()

            if #available(iOS 14.0, *) {
                DictusLogger.keyboard.info("Auto-inserted transcription: \(transcription)")
            }

            // Reset state to idle
            dictationStatus = .idle
            waveformEnergy = []
            recordingElapsed = 0
            statusMessage = nil
            lastTranscription = nil
        } else {
            // Retry after 100ms — mitigates UserDefaults race condition.
            // Darwin notifications are posted immediately after synchronize(),
            // but cross-App-Group propagation can lag on-device.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                if let transcription = self.defaults.string(forKey: SharedKeys.lastTranscription),
                   !transcription.isEmpty {
                    self.controller?.textDocumentProxy.insertText(transcription)
                    HapticFeedback.textInserted()

                    self.dictationStatus = .idle
                    self.waveformEnergy = []
                    self.recordingElapsed = 0
                    self.statusMessage = nil
                    self.lastTranscription = nil
                }
            }
        }
    }

    /// Start recording: set local state to .requested, then open DictusApp to begin recording.
    ///
    /// WHY the keyboard opens a URL instead of recording directly:
    /// WhisperKit requires loading ML models (~50-200MB) which exceeds the keyboard
    /// extension's ~50MB memory limit. The actual recording runs in DictusApp.
    /// The difference from Phase 2: the keyboard now controls the flow by setting
    /// local state FIRST (so the recording overlay appears immediately), then
    /// signaling the app. Previously a Link opened the app and the user stayed there.
    func startRecording() {
        markRequested()
        // Safe to force-unwrap: compile-time literal, always valid URL
        openURL?(URL(string: "dictus://dictate")!)
    }

    /// Write "requested" status to App Group before triggering URL.
    func markRequested() {
        defaults.set(DictationStatus.requested.rawValue, forKey: SharedKeys.dictationStatus)
        defaults.synchronize()
        dictationStatus = .requested
        HapticFeedback.recordingStarted()
    }
}
