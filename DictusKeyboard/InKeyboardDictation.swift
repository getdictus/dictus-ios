// DictusKeyboard/InKeyboardDictation.swift
import DictusCore
import Foundation
import os
import UIKit

/// Dictation that runs entirely inside the keyboard when DictusApp is cold (spike).
///
/// `KeyboardState.startRecording` still posts its Darwin notification first and still
/// waits 500 ms; a warm app answers and nothing here runs. Only when that wait ends
/// unanswered does `InKeyboardDictationRoute` decide between today's URL fallback and
/// this: record through a hidden web view, transcribe with an `InKeyboardRecognizer`,
/// insert through `KeyboardState.insertDictation`, the same funnel as an app result.
///
/// The App Group is told nothing beyond `idle`: the app is not involved, and a
/// `requested` left there would be read by the next app launch as a dictation it owes.
/// While a dictation is in flight here, `KeyboardState.refreshFromDefaults` stops
/// adopting the App Group's status, which would otherwise take the overlay down.
@MainActor
final class InKeyboardDictation {
    static let shared = InKeyboardDictation()

    /// Recording or transcribing here, in this process.
    private(set) var isActive = false

    /// Hard cap on one recording. 120 s of 16 kHz Int16 is 3.75 MB, held in this process.
    private static let maximumSeconds: Double = 120
    /// Bars the overlay draws, matching what DictusApp writes.
    private static let waveformBarCount = 30

    private lazy var recognizer: InKeyboardRecognizer? = InKeyboardRecognizerFactory.make()
    private var capture: InKeyboardWebCapture?
    private var localeAnswer: (code: String, installed: Bool)?
    private var recording = InKeyboardRecording()
    private var startedAt: Date?
    private var tick: Timer?
    private var transcription: Task<Void, Never>?
    private var memory = MemoryTrace()
    private weak var state: KeyboardState?

    // MARK: - Before the 500 ms wait ends

    /// Called at the mic tap, before the Darwin post, when the experiment could apply.
    /// Starts the asset check and loads the web view, so both have answered by the time
    /// the wait ends. Costs nothing when the setting is off.
    func prepare(for state: KeyboardState) {
        guard InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults),
              Self.systemMajorVersion >= InKeyboardDictationRoute.minimumSystemMajorVersion,
              let recognizer
        else { return }
        self.state = state
        let code = Self.languageCode()
        if localeAnswer?.code != code {
            localeAnswer = nil
            Task { [weak self] in
                let installed = await recognizer.isReadyOnDevice(languageCode: code)
                self?.localeAnswer = (code, installed)
                Self.log("localeCheck", "engine=\(recognizer.engineName) lang=\(code) installed=\(installed)")
            }
        }
        if capture != nil, !isActive {
            // The web view is already loaded from an earlier dictation: the idle cost of
            // keeping it, read before this tap records anything.
            Self.log("memory", "phase=idle-with-webview \(MemoryTrace.reading())")
        }
        loadCaptureIfNeeded(into: state.controller?.view)
    }

    /// The route for a tap whose wait has just ended.
    func route(appAnswered: Bool) -> InKeyboardDictationRoute {
        let code = Self.languageCode()
        let installed = localeAnswer.flatMap { $0.code == code ? $0.installed : nil }
        return InKeyboardDictationRoute.decide(
            settingEnabled: InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults),
            appAnswered: appAnswered,
            systemMajorVersion: Self.systemMajorVersion,
            localeInstalled: installed
        )
    }

    // MARK: - Recording

    func start(for state: KeyboardState) {
        guard !isActive, let capture else { return }
        self.state = state
        isActive = true
        recording = InKeyboardRecording()
        startedAt = Date()
        memory.beginDictation()

        // The app is not coming: stop waiting for its heartbeat, and leave the App Group
        // describing no dictation at all.
        state.stopWatchdog()
        let defaults = AppGroup.defaults
        defaults.set(DictationStatus.idle.rawValue, forKey: SharedKeys.dictationStatus)
        defaults.set(false, forKey: SharedKeys.coldStartActive)
        defaults.synchronize()
        state.dictationStatus = .recording
        state.waveformEnergy = []
        state.recordingElapsed = 0

        if let view = state.controller?.view { capture.attach(to: view) }
        capture.onEvent = { [weak self] event in self?.handle(event) }
        capture.start(testAudioBase64: Self.debugTestAudioBase64())
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.everySecond() }
        }
        Self.log("start", "engine=\(recognizer?.engineName ?? "none") lang=\(Self.languageCode()) \(MemoryTrace.reading())")
    }

    /// The overlay's stop button. Returns false when this process is not dictating, so
    /// `requestStop` carries on with the app path.
    func stop() -> Bool {
        guard isActive else { return false }
        guard state?.dictationStatus == .recording else { return true }
        finishRecording(reason: "stop-tap")
        return true
    }

    /// The overlay's cancel button. `requestCancel` then resets the overlay as it always
    /// does; this only drops the capture and the audio.
    func cancel() {
        guard isActive else { return }
        transcription?.cancel()
        transcription = nil
        capture?.stop()
        endTicking()
        isActive = false
        recording = InKeyboardRecording()
        Self.log("cancel", MemoryTrace.reading())
    }

    private func handle(_ event: InKeyboardWebCapture.Event) {
        guard isActive else { return }
        switch event {
        case .started(let rate, let device):
            let latency = startedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            Self.log("captureStarted", "latencyMs=\(latency) contextRate=\(Int(rate)) device=\(device) \(MemoryTrace.reading())")
        case .samples(let data, let rms):
            recording.pcm16.append(data)
            pushWaveform(rms: rms)
            if recording.seconds >= Self.maximumSeconds { finishRecording(reason: "max-duration") }
        case .interrupted(let reason):
            Self.log("captureInterrupted", "reason=\(reason)")
            finishRecording(reason: "interrupted")
        case .failed(let reason):
            fail("capture: \(reason)")
        }
    }

    private func pushWaveform(rms: Float) {
        guard let state else { return }
        // Same 0...1 range the app's bars use; speech RMS sits around 0.02–0.2.
        let level = min(1, max(0, (20 * log10(max(rms, 0.000_1)) + 50) / 40))
        var bars = state.waveformEnergy
        bars.append(level)
        if bars.count > Self.waveformBarCount { bars.removeFirst(bars.count - Self.waveformBarCount) }
        state.waveformEnergy = bars
        state.recordingElapsed = recording.seconds
    }

    private func everySecond() {
        memory.sample()
        // iOS rebuilds keyboard controllers mid-dictation (#281). Keep the web view in
        // whichever view is on screen, or WebKit throttles the capture.
        if let view = state?.controller?.view { capture?.attach(to: view) }
    }

    // MARK: - Transcription

    private func finishRecording(reason: String) {
        guard isActive, let state else { return }
        capture?.stop()
        endTicking()
        let finished = recording
        recording = InKeyboardRecording()
        Self.log("recordingStopped", "reason=\(reason) seconds=\(String(format: "%.1f", finished.seconds)) \(memory.dictationSummary())")
        guard let recognizer, finished.seconds > 0.2 else {
            fail("recording too short (\(String(format: "%.2f", finished.seconds)) s)")
            return
        }
        state.dictationStatus = .transcribing
        HapticFeedback.recordingStopped()
        let code = Self.languageCode()
        let begun = Date()
        transcription = Task { [weak self] in
            do {
                let text = try await recognizer.transcribe(finished, languageCode: code)
                guard let self, !Task.isCancelled else { return }
                Self.log(
                    "transcribed",
                    "engine=\(recognizer.engineName) ms=\(Int(Date().timeIntervalSince(begun) * 1000)) chars=\(text.count) \(MemoryTrace.reading())"
                )
                self.isActive = false
                self.transcription = nil
                // The one insertion funnel: undo, haptics and the idle reset come with it.
                self.state?.insertDictation(text)
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.fail("transcription: \(error.localizedDescription)")
            }
        }
    }

    private func fail(_ reason: String) {
        capture?.stop()
        endTicking()
        isActive = false
        transcription = nil
        recording = InKeyboardRecording()
        Self.log("failed", "reason=\(reason) \(MemoryTrace.reading())")
        guard let state else { return }
        state.forceResetToIdle()
        state.presentStatusMessage(
            String(localized: "Dictation in the keyboard failed. Try again."),
            reason: "inKeyboardFailed",
            timeoutReason: "inKeyboardFailed-timeout"
        )
    }

    private func endTicking() {
        tick?.invalidate()
        tick = nil
    }

    // MARK: - Web view

    private func loadCaptureIfNeeded(into view: UIView?) {
        guard capture == nil, let view else { return }
        Self.log("memory", "phase=idle-without-webview \(MemoryTrace.reading())")
        let capture = InKeyboardWebCapture()
        capture.onLoaded = {
            Self.log("memory", "phase=webview-loaded \(MemoryTrace.reading())")
        }
        capture.attach(to: view)
        self.capture = capture
    }

    // MARK: - Inputs

    private static var systemMajorVersion: Int {
        InKeyboardDictationRoute.majorVersion(of: UIDevice.current.systemVersion)
    }

    /// The dictation language: the explicit transcription language when there is one,
    /// otherwise the keyboard's. Auto-detect has no single locale to check, so it falls
    /// back to the keyboard language too.
    private static func languageCode() -> String {
        let keyboard = SupportedLanguage.active.rawValue
        return TranscriptionLanguageMode.active.resolvedLanguageCode(keyboardLanguageCode: keyboard) ?? keyboard
    }

    /// Debug builds only: a WAV at the App Group root replaces the microphone, for a
    /// simulator whose microphone cannot be fed. Release builds never look.
    private static func debugTestAudioBase64() -> String? {
        #if DEBUG
        guard let url = AppGroup.containerURL?.appendingPathComponent("in-keyboard-test-audio.wav"),
              let data = try? Data(contentsOf: url) else { return nil }
        log("debugTestAudio", "bytes=\(data.count)")
        return data.base64EncodedString()
        #else
        return nil
        #endif
    }

    nonisolated static func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(
            component: "InKeyboardDictation",
            instanceID: "shared",
            action: action,
            details: details
        ))
    }
}

/// The extension's own memory, as iOS budgets it (#555).
///
/// `phys_footprint` is what jetsam counts; `os_proc_available_memory` is how far this
/// process is from its limit. WebKit's GPU and WebContent processes are separate
/// processes with their own budgets and do not appear in either number.
private struct MemoryTrace {
    private var peakKB = 0
    private var minimumAvailableKB = Int.max
    private var samples = 0

    static func reading() -> String {
        "footprintKB=\(MemoryFootprint.residentKB()) availableKB=\(availableKB())"
    }

    static func availableKB() -> Int {
        Int(os_proc_available_memory() / 1024)
    }

    mutating func beginDictation() {
        peakKB = MemoryFootprint.residentKB()
        minimumAvailableKB = Self.availableKB()
        samples = 0
    }

    mutating func sample() {
        let footprint = MemoryFootprint.residentKB()
        let available = Self.availableKB()
        peakKB = max(peakKB, footprint)
        minimumAvailableKB = min(minimumAvailableKB, available)
        samples += 1
        InKeyboardDictation.log("memory", "phase=dictation t=\(samples)s footprintKB=\(footprint) availableKB=\(available)")
    }

    func dictationSummary() -> String {
        "peakFootprintKB=\(peakKB) minAvailableKB=\(minimumAvailableKB == Int.max ? -1 : minimumAvailableKB) samples=\(samples)"
    }
}

// MARK: - The fallback hook

extension KeyboardState {

    /// The Darwin start post, preceded by the spike's preparation so the asset check and
    /// the web view load run during the app's 500 ms.
    func postStartRecordingPreparingInKeyboardDictation() {
        MainActor.assumeIsolated { InKeyboardDictation.shared.prepare(for: self) }
        DarwinNotificationCenter.post(DarwinNotificationName.startRecording)
    }

    /// Called when the 500 ms wait ends with the app silent. Returns true when the
    /// keyboard took the dictation itself, false to carry on with today's URL fallback.
    func dictateInKeyboardInsteadOfOpeningApp(elapsedMs: Int) -> Bool {
        MainActor.assumeIsolated {
            let dictation = InKeyboardDictation.shared
            let route = dictation.route(appAnswered: dictationStatus != .requested)
            InKeyboardDictation.log("route", "route=\(route.rawValue) elapsedMs=\(elapsedMs)")
            guard route == .inKeyboard else { return false }
            dictation.start(for: self)
            return true
        }
    }
}
