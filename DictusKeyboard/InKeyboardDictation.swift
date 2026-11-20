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

    /// Whether this process owns the dictation status: recording, transcribing, or its
    /// transcript being polished by `KeyboardPolishCoordinator` on this path. While true,
    /// `KeyboardState.refreshFromDefaults` must not adopt the App Group's `idle`, which
    /// describes an app that is not involved.
    var ownsKeyboardStatus: Bool {
        isActive || KeyboardPolishCoordinator.shared.isPolishingInKeyboardTail
    }

    /// Hard cap on one recording. 120 s of 16 kHz Int16 is 3.75 MB, held in this process.
    private static let maximumSeconds: Double = 120

    private lazy var recognizer: InKeyboardRecognizer? = InKeyboardRecognizerFactory.make()
    private var capture: InKeyboardWebCapture?
    private var localeAnswer: (code: String, installed: Bool)?
    private var recording = InKeyboardRecording()
    private var startedAt: Date?
    private var tick: Timer?
    /// The overlay's 5 Hz clock, the cadence DictusApp publishes at (`WaveformFeed`).
    private var waveformClock: Timer?
    private var waveform = WaveformFeed()
    /// Debug builds only: draw the waveform the way build ee238f03 did (one bar per
    /// WebView message), to film it beside the fix on the same input.
    private var legacyWaveform = false
    /// How the WebView's chunks arrived over the last second, logged by `everySecond`:
    /// the irregularity the 5 Hz clock absorbs.
    private var chunkArrivals = ChunkArrivalTrace()
    /// Samples memory while the tail (vocabulary, polish, Smart Mode) runs here.
    private var tailMemoryClock: Timer?
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

    /// Whether this process could dictate a cold tap by itself: setting on, iOS 26+,
    /// an engine, and no known "model missing" answer for the current language.
    var mayTakeColdTap: Bool {
        guard InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults),
              Self.systemMajorVersion >= InKeyboardDictationRoute.minimumSystemMajorVersion,
              recognizer != nil else { return false }
        let code = Self.languageCode()
        if let answer = localeAnswer, answer.code == code { return answer.installed }
        return true
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
        waveform = WaveformFeed()
        chunkArrivals = ChunkArrivalTrace()
        legacyWaveform = Self.debugMarkerExists("in-keyboard-waveform-legacy")

        if let view = state.controller?.view { capture.attach(to: view) }
        capture.onEvent = { [weak self] event in self?.handle(event) }
        capture.start(testAudioBase64: Self.debugTestAudioBase64())
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.everySecond() }
        }
        waveformClock = Timer.scheduledTimer(withTimeInterval: WaveformFeed.publishInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.publishWaveform() }
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
            waveform.append(pcm16: data)
            chunkArrivals.note(samples: data.count / 2, rms: rms)
            if legacyWaveform { publishLegacyBar(rms: rms) }
            if recording.seconds >= Self.maximumSeconds { finishRecording(reason: "max-duration") }
        case .interrupted(let reason):
            Self.log("captureInterrupted", "reason=\(reason)")
            finishRecording(reason: "interrupted")
        case .failed(let reason):
            fail("capture: \(reason)")
        }
    }

    /// Publish on the app's clock, never on a chunk's arrival. `KeyboardWaveformDriver`
    /// eases toward each published array frame by frame, so the motion now depends on
    /// the audio and the 5 Hz clock, as it does for a recording in DictusApp.
    private func publishWaveform() {
        guard let state, isActive, !legacyWaveform else { return }
        state.waveformEnergy = waveform.snapshot()
        state.recordingElapsed = Double(waveform.sampleCount) / InKeyboardRecording.sampleRate
    }

    /// The pre-fix behaviour, kept only behind the Debug marker for the comparison video.
    private func publishLegacyBar(rms: Float) {
        guard let state else { return }
        let level = min(1, max(0, (20 * log10(max(rms, 0.000_1)) + 50) / 40))
        var bars = state.waveformEnergy
        bars.append(level)
        if bars.count > WaveformFeed.barCount { bars.removeFirst(bars.count - WaveformFeed.barCount) }
        state.waveformEnergy = bars
        state.recordingElapsed = recording.seconds
    }

    private func everySecond() {
        memory.sample()
        Self.log("captureCadence", chunkArrivals.drain())
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
        // The per-dictation snapshot DictusApp takes at the same moment (#226, #79):
        // language policy and armed Smart Mode, read once so a change on the toolbar
        // during transcription cannot make the polish disagree with the transcript.
        let policy = TranscriptionLanguagePolicy.snapshot()
        let smartMode = SmartModeStore.resolveArmedMode()
        let begun = Date()
        transcription = Task { [weak self] in
            do {
                let text = try await recognizer.transcribe(finished, languageCode: code, contextualStrings: Self.vocabularyTerms())
                guard let self, !Task.isCancelled else { return }
                Self.log(
                    "transcribed",
                    "engine=\(recognizer.engineName) ms=\(Int(Date().timeIntervalSince(begun) * 1000)) chars=\(text.count) \(MemoryTrace.reading())"
                )
                self.transcription = nil
                self.runTail(engineText: text, policy: policy, smartMode: smartMode, seconds: finished.seconds)
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.fail("transcription: \(error.localizedDescription)")
            }
        }
    }

    /// What DictusApp does between a transcript and its hand-off, done here
    /// (`DictationCoordinator`, `handOffToKeyboard`), then the keyboard's own tail.
    ///
    /// 1. Custom vocabulary (#80) on the engine text: `DictationTranscript.corrected`.
    /// 2. The words-dictated tally (#726).
    /// 3. A History entry from the corrected raw, durable before any generation (#70,
    ///    #361), updated in place with the final text by the coordinator.
    /// 4. `KeyboardPolishCoordinator`: verbal punctuation, polish or the armed Smart Mode
    ///    with Apple Foundation Models, the guardrail, the trailing separator and the
    ///    insertion, exactly as for a transcript the app hands over.
    private func runTail(engineText: String, policy: TranscriptionLanguagePolicy,
                         smartMode: SmartModeResolution, seconds: Double) {
        let transcript = DictationTranscript.corrected(engineText)
        DictationTally.record(transcript.text, audioDuration: seconds)
        let historyID = TranscriptionHistoryStore.shared.append(TranscriptionRecord(
            text: transcript.text, policy: policy, duration: seconds
        ))?.id
        Self.log(
            "tail",
            "vocabularyChanged=\(transcript.engineRaw != nil) mode=\(smartMode.mode?.id ?? "normal") skipped=\(smartMode.skipped?.modeIdentifier ?? "none") history=\(historyID != nil) \(MemoryTrace.reading())"
        )
        isActive = false
        startTailMemoryClock()
        KeyboardPolishCoordinator.shared.handleInKeyboard(
            transcript: transcript,
            policy: policy,
            smartMode: smartMode,
            recordingDuration: seconds,
            historyID: historyID
        )
    }

    /// Memory while polish or a Smart Mode runs in this process, every 500 ms until the
    /// coordinator lets go.
    private func startTailMemoryClock() {
        tailMemoryClock?.invalidate()
        var peakKB = 0
        var minimumAvailableKB = Int.max
        var samples = 0
        tailMemoryClock = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                let footprint = MemoryFootprint.residentKB()
                let available = MemoryTrace.availableKB()
                peakKB = max(peakKB, footprint)
                minimumAvailableKB = min(minimumAvailableKB, available)
                samples += 1
                Self.log("memory", "phase=tail t=\(samples * 500)ms footprintKB=\(footprint) availableKB=\(available)")
                guard !KeyboardPolishCoordinator.shared.isPolishingInKeyboardTail else { return }
                Self.log("memory", "phase=tail-done peakFootprintKB=\(peakKB) minAvailableKB=\(minimumAvailableKB) samples=\(samples)")
                timer.invalidate()
                self?.tailMemoryClock = nil
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
        waveformClock?.invalidate()
        waveformClock = nil
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

    /// The Pro vocabulary's enabled terms, the strings offered to the recognizer. Empty
    /// without the entitlement, as `CustomVocabulary.corrected` treats it.
    private static func vocabularyTerms() -> [String] {
        guard VocabularyAvailability.isEntitled else { return [] }
        return VocabularyStore.loadEntries().filter(\.isEnabled).map(\.term)
    }

    /// Debug builds only: whether a marker file sits at the App Group root.
    private static func debugMarkerExists(_ name: String) -> Bool {
        #if DEBUG
        guard let url = AppGroup.containerURL?.appendingPathComponent(name) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
        #else
        return false
        #endif
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

    /// `liveKB` is what malloc still has allocated (#992): a leak raises it, freed pages the
    /// allocator keeps raise only `footprintKB`.
    static func reading() -> String {
        "footprintKB=\(MemoryFootprint.residentKB()) liveKB=\(MemoryFootprint.liveHeapKB()) availableKB=\(availableKB())"
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

    /// The model-preparation hand-off (#262, #542), skipped when the in-keyboard path
    /// could take this tap: it does not use the Dictus model, so a cold Core ML cache —
    /// the state every development install leaves behind — must not send a cold-start
    /// tap to the app before the keyboard has had its chance. The 500 ms fallback still
    /// runs the real `preparationDeferral()` when the keyboard does not take the tap.
    func preparationDeferralUnlessKeyboardTakesOver() -> String? {
        guard let deferral = preparationDeferral() else { return nil }
        let mayTakeOver = MainActor.assumeIsolated { InKeyboardDictation.shared.mayTakeColdTap }
        guard mayTakeOver else { return deferral }
        InKeyboardDictation.log("preparationDeferralSkipped", "deferral=\(deferral)")
        return nil
    }

    /// The Darwin start post, preceded by the spike's preparation so the asset check and
    /// the web view load run during the app's 500 ms.
    func postStartRecordingPreparingInKeyboardDictation() {
        MainActor.assumeIsolated { InKeyboardDictation.shared.prepare(for: self) }
        // The session the app must claim before it records (`DictationSessionClaim`).
        // Written before the post, so the app's handler always finds it.
        AppGroup.defaults.set(activeSessionID, forKey: SharedKeys.dictationSessionRequest)
        AppGroup.defaults.synchronize()
        DarwinNotificationCenter.post(DarwinNotificationName.startRecording)
    }

    /// Called when the 500 ms wait ends with the app silent. Returns true when the
    /// keyboard took the dictation itself, false to carry on with today's URL fallback.
    func dictateInKeyboardInsteadOfOpeningApp(elapsedMs: Int) -> Bool {
        MainActor.assumeIsolated {
            let dictation = InKeyboardDictation.shared
            let route = dictation.route(appAnswered: dictationStatus != .requested)
            InKeyboardDictation.log("route", "route=\(route.rawValue) elapsedMs=\(elapsedMs)")
            // One owner per session: an app that answers just after the window has
            // claimed it, or will find it claimed (`DictationSessionClaim`).
            let claims = DictationSessionClaim.defaultDirectory
            if route == .inKeyboard {
                if let sessionID = activeSessionID, let claims {
                    let owner = DictationSessionClaim.claim(sessionID, as: .keyboard, in: claims)
                    InKeyboardDictation.log("sessionClaim", "session=\(sessionID) side=keyboard owner=\(owner?.rawValue ?? "unwritable")")
                    // The app got there first and records: no second recording, no URL.
                    if owner == .app { return true }
                }
                dictation.start(for: self)
                return true
            }
            // Today's URL fallback, except when the app answered late and already owns
            // the session: opening it again would only bring it forward mid-recording.
            if let sessionID = activeSessionID, let claims,
               DictationSessionClaim.current(sessionID, in: claims) == .app {
                InKeyboardDictation.log("sessionClaim", "session=\(sessionID) side=keyboard owner=app skipped=urlFallback")
                return true
            }
            return false
        }
    }
}

/// How the WebView delivered its chunks during the last second: count, samples, and the
/// longest silence between two of them. Bursts show up as a high `maxGapMs` with the
/// same sample total.
private struct ChunkArrivalTrace {
    private var chunks = 0
    private var samples = 0
    private var last: Date?
    private var maxGap: TimeInterval = 0

    mutating func note(samples count: Int, rms: Float) {
        let now = Date()
        if let last { maxGap = max(maxGap, now.timeIntervalSince(last)) }
        last = now
        chunks += 1
        samples += count
    }

    mutating func drain() -> String {
        defer { chunks = 0; samples = 0; maxGap = 0 }
        return "chunks=\(chunks) samples=\(samples) maxGapMs=\(Int(maxGap * 1000))"
    }
}
