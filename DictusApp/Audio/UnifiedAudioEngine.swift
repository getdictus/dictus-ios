// DictusApp/Audio/UnifiedAudioEngine.swift
// Single audio engine for all recording paths — replaces both AudioRecorder and RawAudioCapture.
// Uses native AVAudioEngine (no WhisperKit dependency). Captured samples are passed to
// transcribe(audioArray:) which accepts any [Float] 16kHz mono array.
import Foundation
@preconcurrency import AVFoundation
import DictusCore

/// Errors that can occur during audio engine operations.
enum AudioEngineError: Error, LocalizedError {
    case permissionDenied
    case permissionUndetermined

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied"
        case .permissionUndetermined:
            return "Microphone permission not yet requested"
        }
    }
}

/// Unified audio engine for recording dictation audio.
///
/// WHY this replaces AudioRecorder + RawAudioCapture:
/// Both classes did the same job (capture 16kHz mono Float32 audio). AudioRecorder wrapped
/// WhisperKit's AudioProcessor (tight coupling, manual isEngineRunning bool = bug #38).
/// RawAudioCapture used native AVAudioEngine (zero WhisperKit dependency, computed
/// isEngineRunning = always correct). Since transcribe(audioArray:) accepts any [Float],
/// we don't need WhisperKit's AudioProcessor for capture. One engine, one code path.
///
/// KEY DESIGN: Sample gating via isRecording flag.
/// The engine runs continuously (keeps app alive via UIBackgroundModes:audio) but only
/// accumulates audio samples when isRecording is true. When idle, the engine still processes
/// buffers for heartbeat/energy (background survival) but discards the actual audio data.
/// This eliminates the 64M idle sample accumulation bug (#38).
@MainActor
class UnifiedAudioEngine: ObservableObject {
    // MARK: - Published State

    /// Whether the user is actively recording (samples being accumulated).
    @Published var isRecording = false

    /// Energy levels (0.0-1.0) for waveform visualization.
    @Published var bufferEnergy: [Float] = []

    /// Elapsed recording time in seconds.
    @Published var bufferSeconds: Double = 0

    // MARK: - Engine State

    /// Whether the underlying AVAudioEngine is currently running.
    /// COMPUTED from engine.isRunning — always accurate, fixes #38.
    var isEngineRunning: Bool { engine.isRunning }

    // MARK: - Private

    private let engine = AVAudioEngine()

    /// Accumulated audio samples in 16kHz mono Float32 (WhisperKit/Parakeet expected format).
    private var audioSamples: [Float] = []

    /// Converter from hardware sample rate (typically 48kHz) to 16kHz mono.
    /// WHY nonisolated(unsafe): Written once from main thread in startEngine(),
    /// read from audio callback thread in processBuffer(). Write completes before
    /// the audio tap is installed, so no race condition.
    private nonisolated(unsafe) var converter: AVAudioConverter?

    /// Target format: 16kHz mono Float32 — what WhisperKit and Parakeet expect.
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    /// Whether the audio session has been configured at least once.
    /// WHY: iOS forbids changing AVAudioSession category from background.
    /// We configure once and keep the category set forever.
    private var sessionConfigured = false

    /// Sample gating flag read from the audio thread.
    /// WHY nonisolated(unsafe): Read from audio callback thread (single reader pattern).
    /// Written from main thread via startRecording()/collectSamples()/stopEngine().
    /// The flag is a simple Bool — partial reads are impossible on ARM64.
    private nonisolated(unsafe) var isRecordingFlag = false

    /// Timestamp of last heartbeat write to App Group.
    /// Throttled to ~1Hz to avoid excessive UserDefaults writes from the audio thread.
    /// WHY nonisolated(unsafe): Written only from the audio callback thread (single writer).
    private nonisolated(unsafe) var lastHeartbeatWrite: TimeInterval = 0

    /// Timestamp of last waveform write to App Group from the audio thread.
    /// Throttled to ~5Hz (every 200ms) — same rate as keyboard waveform display.
    /// WHY from audio thread: In background, iOS throttles DispatchQueue.main.async delivery.
    /// Writing directly from the audio thread bypasses this throttling.
    private nonisolated(unsafe) var lastWaveformWrite: TimeInterval = 0

    /// Timestamp of the last waveform-shape diagnostic emitted from the audio thread.
    private nonisolated(unsafe) var lastWaveformDiagnosticsWrite: TimeInterval = 0

    /// Rolling energy buffer maintained on the audio thread for direct App Group writes.
    /// Separate from @Published bufferEnergy (which is main-thread-only for SwiftUI).
    /// WHY nonisolated(unsafe): Single writer (audio callback thread).
    private nonisolated(unsafe) var audioThreadEnergy: [Float] = []

    /// Rolling per-bucket waveform shape used by the keyboard/App Group snapshot.
    /// Unlike audioThreadEnergy (one RMS value per callback), this keeps a short envelope
    /// history with enough local variation to render an actual waveform silhouette.
    private nonisolated(unsafe) var audioThreadWaveformBins: [Float] = []

    /// Accumulated sample count on the audio thread for elapsed time calculation.
    /// WHY nonisolated(unsafe): Single writer (audio callback thread).
    private nonisolated(unsafe) var audioThreadSampleCount: Int = 0

    private let waveformBarCount = 30

    // MARK: - Session & Permissions (ported from AudioRecorder)

    /// Configure the audio session. Must be called from foreground.
    ///
    /// WHY these specific options:
    /// .playAndRecord + [.defaultToSpeaker, .allowBluetooth] matches what WhisperKit uses
    /// internally in startRecordingLive(). Using the same options ensures WhisperKit's
    /// transcribe() doesn't conflict with our session config.
    ///
    /// WHY setActive every time (no sessionConfigured guard for setActive):
    /// iOS interrupts the audio session when the app goes to background. Even if the
    /// category was set, setActive(true) must be called again on foreground return.
    func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        if !sessionConfigured {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        }
        try session.setActive(true)
        try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        sessionConfigured = true

        PersistentLog.log(.audioSessionConfigured(category: "playAndRecord"))
    }

    /// Check and request microphone permission if needed.
    /// Returns true if permission is granted, false otherwise.
    func ensureMicrophonePermission() async throws -> Bool {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return true
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            return granted
        case .denied:
            throw AudioEngineError.permissionDenied
        @unknown default:
            return false
        }
    }

    // MARK: - Engine Lifecycle

    /// Start the engine in idle mode (running but not recording).
    /// Keeps the app alive in background via UIBackgroundModes:audio.
    func warmUp() throws {
        guard !engine.isRunning else {
            PersistentLog.log(.engineWarmUpSuccess(context: "already running"))
            return
        }
        try startEngine()
        PersistentLog.log(.engineWarmUpSuccess(context: "unifiedEngine-warmUp"))
    }

    /// Begin recording: purge idle audio and start accumulating samples.
    /// If the engine isn't running yet, starts it first (<100ms).
    func startRecording() throws {
        if !engine.isRunning {
            try startEngine()
        }
        purgeState()
        isRecording = true
        isRecordingFlag = true
        PersistentLog.log(.audioEngineStarted)
    }

    /// Collect recorded samples WITHOUT stopping the engine.
    /// Keeps the engine alive for subsequent recordings (no cold start needed).
    ///
    /// WHY keep engine running: iOS requires an active audio engine to keep
    /// the app alive in background (UIBackgroundModes:audio). Stopping the engine
    /// causes iOS to suspend the app, breaking Darwin notification reception.
    ///
    /// - Returns: Audio samples ready for transcription. Engine keeps running.
    func collectSamples() -> [Float] {
        isRecording = false
        isRecordingFlag = false

        let samples = audioSamples
        audioSamples = []

        PersistentLog.log(.engineCollectResult(sampleCount: samples.count, engineRunning: engine.isRunning))

        if #available(iOS 14.0, *) {
            DictusLogger.app.info("UnifiedAudioEngine collectSamples. Samples: \(samples.count, privacy: .public), Duration: \(String(format: "%.1f", Double(samples.count) / 16000.0), privacy: .public)s, engine still running")
        }

        // Reset published state but keep engine running
        bufferEnergy = []
        bufferSeconds = 0

        return samples
    }

    /// Stop the engine completely and return all accumulated samples.
    /// After this, the next recording requires warmUp() or startRecording().
    ///
    /// - Returns: Audio samples ready for transcription.
    func stopEngine() -> [Float] {
        isRecording = false
        isRecordingFlag = false

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        let samples = audioSamples
        audioSamples = []

        if #available(iOS 14.0, *) {
            DictusLogger.app.info("UnifiedAudioEngine stopped. Samples: \(samples.count, privacy: .public), Duration: \(String(format: "%.1f", Double(samples.count) / 16000.0), privacy: .public)s")
        }

        bufferEnergy = []
        bufferSeconds = 0

        return samples
    }

    /// Fully deactivate audio: stop engine + deactivate AVAudioSession.
    /// Call when user explicitly stops all audio (e.g., Power button in Dynamic Island).
    func deactivateSession() {
        isRecording = false
        isRecordingFlag = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioSamples = []
        PersistentLog.log(.audioEngineStopped)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        sessionConfigured = false

        bufferEnergy = []
        bufferSeconds = 0
    }

    /// Deactivate audio session after recording completes.
    /// Stops engine, deactivates session with .notifyOthersOnDeactivation so other
    /// apps (Spotify, YouTube) resume playback and AirPods controls return to them.
    ///
    /// WHY not keep engine running: Keeping .playAndRecord active makes iOS treat
    /// Dictus as the "now playing" app, hijacking AirPods remote controls (#72).
    /// The trade-off is ~100-200ms re-activation cost on next recording.
    ///
    /// WHY separate from deactivateSession(): deactivateSession is for explicit user
    /// stop (Power button). deactivateAndIdle is for normal post-recording cleanup.
    func deactivateAndIdle() {
        isRecording = false
        isRecordingFlag = false
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioSamples = []

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        sessionConfigured = false

        bufferEnergy = []
        bufferSeconds = 0

        PersistentLog.log(.audioEngineStopped)
    }

    // MARK: - Private Helpers

    /// Start the AVAudioEngine with a tap on the input node.
    private func startEngine() throws {
        audioSamples = []
        audioThreadEnergy = []
        audioThreadWaveformBins = []
        audioThreadSampleCount = 0
        lastHeartbeatWrite = 0
        lastWaveformWrite = 0
        lastWaveformDiagnosticsWrite = 0

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        // Create converter from hardware format to 16kHz mono
        guard let conv = AVAudioConverter(from: hwFormat, to: targetFormat) else {
            throw NSError(domain: "UnifiedAudioEngine", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot create audio converter from \(hwFormat) to 16kHz mono"])
        }
        converter = conv

        // Remove any stale tap before installing a new one.
        // WHY: If a previous startEngine() installed a tap but engine.start() threw
        // (e.g., app in background → AUIOClient_StartIO error), the tap remains
        // but the engine isn't running. The next call crashes on installTap.
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw error
        }

        if #available(iOS 14.0, *) {
            DictusLogger.app.info("UnifiedAudioEngine started (hw: \(hwFormat.sampleRate, privacy: .public)Hz -> 16kHz)")
        }
    }

    /// Reset recording state without stopping the engine.
    private func purgeState() {
        audioSamples = []
        bufferEnergy = []
        bufferSeconds = 0
        audioThreadEnergy = []
        audioThreadWaveformBins = []
        audioThreadSampleCount = 0
        lastWaveformWrite = 0
        lastWaveformDiagnosticsWrite = 0
    }

    /// Process incoming audio buffer: convert to 16kHz and compute energy for waveform.
    ///
    /// WHY nonisolated: This callback fires on the audio thread. We do the CPU-intensive
    /// conversion here, then dispatch UI updates and sample accumulation to main thread.
    ///
    /// SAMPLE GATING: Samples only accumulate when isRecordingFlag is true. When idle,
    /// the engine still processes buffers for heartbeat + waveform (keeps background alive)
    /// but discards audio data. This prevents the 64M idle sample accumulation bug (#38).
    private nonisolated func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

        // Calculate output frame count: input frames * (target rate / source rate) + 1
        let ratio = 16000.0 / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCount
        ) else { return }

        // Convert from hardware format to 16kHz mono
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if let error {
            if #available(iOS 14.0, *) {
                DictusLogger.app.warning("Audio conversion error: \(error.localizedDescription, privacy: .public)")
            }
            return
        }

        // Extract Float32 samples from the converted buffer
        guard let channelData = outputBuffer.floatChannelData else { return }
        let frameLength = Int(outputBuffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        // Compute RMS energy for this buffer (0.0-1.0 range)
        let rms = sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(max(samples.count, 1)))
        // Scale RMS to waveform range. 15x scaling maps: quiet speech (0.01) → 0.15,
        // normal (0.05) → 0.75, loud (0.07+) → 1.0 capped.
        let energy = min(rms * 15.0, 1.0)

        // === Audio thread writes (bypass main thread throttling in background) ===

        // Update audio-thread energy buffer (rolling window of last 30 values)
        audioThreadEnergy.append(energy)
        if audioThreadEnergy.count > 30 {
            audioThreadEnergy.removeFirst(audioThreadEnergy.count - 30)
        }

        // Build a short-lived waveform silhouette from local buckets inside the current buffer.
        // WHY: A single RMS value per callback tends to produce a flat line that only moves
        // vertically. Splitting the converted buffer into several peak+RMS buckets preserves
        // intra-utterance shape, which makes the keyboard waveform feel alive even after app
        // switches or when speech loudness is relatively stable.
        let waveformBuckets = makeWaveformBuckets(from: samples)
        audioThreadWaveformBins.append(contentsOf: waveformBuckets)
        if audioThreadWaveformBins.count > waveformBarCount {
            audioThreadWaveformBins.removeFirst(audioThreadWaveformBins.count - waveformBarCount)
        }

        let now = Date().timeIntervalSince1970

        // Write heartbeat (~1Hz) — always, even when idle (keeps background alive)
        if now - lastHeartbeatWrite >= 1.0 {
            lastHeartbeatWrite = now
            AppGroup.defaults.set(now, forKey: SharedKeys.recordingHeartbeat)
        }

        // Write waveform data + elapsed time to App Group (~5Hz) — only when recording
        if isRecordingFlag, now - lastWaveformWrite >= 0.2 {
            lastWaveformWrite = now
            audioThreadSampleCount += 0 // count is updated in main thread dispatch below
            let snapshot = makeWaveformSnapshot()
            if let data = try? JSONEncoder().encode(snapshot) {
                AppGroup.defaults.set(data, forKey: SharedKeys.waveformEnergy)
            }
            AppGroup.defaults.set(Double(audioThreadSampleCount) / 16000.0, forKey: SharedKeys.recordingElapsedSeconds)
            AppGroup.defaults.synchronize()
            DarwinNotificationCenter.post(DarwinNotificationName.waveformUpdate)

            if now - lastWaveformDiagnosticsWrite >= 1.0 {
                lastWaveformDiagnosticsWrite = now
                PersistentLog.log(.diagnosticProbe(
                    component: "UnifiedAudioEngine",
                    instanceID: "shared",
                    action: "waveformSnapshot",
                    details: waveformStatsDetails(snapshot)
                ))
            }
        }

        // Track sample count on audio thread (needed for elapsed time in App Group writes)
        if isRecordingFlag {
            audioThreadSampleCount += samples.count
        }

        // === Main thread dispatch (for in-app UI: RecordingView, SwiftUI) ===

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // SAMPLE GATE: only accumulate when recording
            guard self.isRecording else { return }
            self.audioSamples.append(contentsOf: samples)
            self.bufferSeconds = Double(self.audioSamples.count) / 16000.0

            // Maintain a rolling window of energy values (last 30 = matches barCount in BrandWaveform)
            self.bufferEnergy = self.makeWaveformSnapshot()
        }
    }

    private nonisolated func makeWaveformBuckets(from samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return [] }

        let bucketCount = max(3, min(6, samples.count / 160))
        let bucketSize = max(samples.count / bucketCount, 1)
        var buckets: [Float] = []
        buckets.reserveCapacity(bucketCount)

        var start = 0
        while start < samples.count {
            let end = min(start + bucketSize, samples.count)
            let slice = samples[start..<end]

            var sumSquares: Float = 0
            var peak: Float = 0
            for sample in slice {
                let magnitude = abs(sample)
                sumSquares += magnitude * magnitude
                peak = max(peak, magnitude)
            }

            let rms = sqrt(sumSquares / Float(max(slice.count, 1)))
            let shaped = min(max((peak * 0.65) + (rms * 6.5), 0), 1)
            buckets.append(shaped)
            start = end
        }

        return buckets
    }

    private nonisolated func makeWaveformSnapshot() -> [Float] {
        let source = audioThreadWaveformBins.isEmpty ? audioThreadEnergy : audioThreadWaveformBins
        let resampled = resampleWaveform(source, targetCount: waveformBarCount)
        return enhanceWaveformContrast(resampled)
    }

    private nonisolated func resampleWaveform(_ source: [Float], targetCount: Int) -> [Float] {
        guard targetCount > 0 else { return [] }
        guard !source.isEmpty else { return Array(repeating: 0, count: targetCount) }
        guard source.count != targetCount else { return source }

        var result: [Float] = []
        result.reserveCapacity(targetCount)

        for index in 0..<targetCount {
            let position = Float(index) / Float(max(targetCount - 1, 1))
            let arrayIndex = position * Float(source.count - 1)
            let lower = Int(arrayIndex)
            let upper = min(lower + 1, source.count - 1)
            let fraction = arrayIndex - Float(lower)
            let value = source[lower] * (1 - fraction) + source[upper] * fraction
            result.append(min(max(value, 0), 1))
        }

        return result
    }

    private nonisolated func enhanceWaveformContrast(_ values: [Float]) -> [Float] {
        guard !values.isEmpty else { return [] }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let spread = maxValue - minValue

        guard maxValue > 0.06 else { return values }

        if spread < 0.12 {
            let centerBias = stride(from: 0, to: values.count, by: 1).map { index -> Float in
                let normalized = Float(index) / Float(max(values.count - 1, 1))
                let distance = abs(normalized - 0.5)
                return 1.0 - (distance * 0.18)
            }

            return values.enumerated().map { index, value in
                let normalized: Float
                if spread > 0.0001 {
                    normalized = (value - minValue) / spread
                } else {
                    normalized = 0.5
                }

                let floor = min(maxValue * 0.28, 0.16)
                let stretched = floor + normalized * (1 - floor)
                return min(max(stretched * centerBias[index], 0), 1)
            }
        }

        return values
    }

    private nonisolated func waveformStatsDetails(_ values: [Float]) -> String {
        guard !values.isEmpty else { return "count=0" }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let spread = maxValue - minValue
        let first = values.first ?? 0
        let middle = values[values.count / 2]
        let last = values.last ?? 0
        return String(
            format: "count=%d min=%.3f max=%.3f spread=%.3f first=%.3f mid=%.3f last=%.3f",
            values.count,
            minValue,
            maxValue,
            spread,
            first,
            middle,
            last
        )
    }
}
