// DictusKeyboard/InKeyboardDictation.swift
import AVFAudio
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

    // Round 4: capture from the tap (`InKeyboardEarlyCapture`).
    /// A capture started at the tap that the route decision has not kept or dropped yet.
    private var isProvisional = false
    /// When the mic was tapped; the zero of every latency logged below.
    private var tapAt: Date?
    /// When the capture was asked to start.
    private var captureRequestedAt: Date?
    private var firstSampleLogged = false
    /// The last time DictusApp answered `inKeyboardPing`.
    private var lastPong: Date?
    private var isObservingPongs = false

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
        tapAt = Date()
        let appAnswered = InKeyboardEarlyCapture.appAnsweredRecently(lastPong: lastPong, now: Date())
        guard InKeyboardEarlyCapture.shouldStartAtTap(mayTakeColdTap: mayTakeColdTap, appAnsweredRecently: appAnswered),
              !isActive, !isProvisional else {
            Self.log("earlyCapture", "started=false appAnsweredPing=\(appAnswered) mayTakeColdTap=\(mayTakeColdTap)")
            return
        }
        isProvisional = true
        beginCapture()
        Self.log("earlyCapture", "started=true lastPongAgeMs=\(lastPong.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1)")
        // The route decision lands at ~510–520 ms and keeps or drops this. If it never
        // comes — the app answered inside the window, so the keyboard's fallback closure
        // does not run — drop it here rather than leave the microphone open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self, self.isProvisional else { return }
            self.dropEarlyCapture(reason: "no-route-decision")
        }
    }

    /// Called when a keyboard controller appears: load the capture page now, off the
    /// tap's path, and ask DictusApp whether it is running. The microphone stays closed.
    func prewarm(in view: UIView) {
        guard InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults),
              Self.systemMajorVersion >= InKeyboardDictationRoute.minimumSystemMajorVersion,
              recognizer != nil else { return }
        observePongsIfNeeded()
        DarwinNotificationCenter.post(DarwinNotificationName.inKeyboardPing)
        if capture == nil { Self.log("prewarm", "webview=loading") }
        loadCaptureIfNeeded(into: view)
    }

    private func observePongsIfNeeded() {
        guard !isObservingPongs else { return }
        isObservingPongs = true
        DarwinNotificationCenter.addObserver(for: DarwinNotificationName.inKeyboardPong) {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { InKeyboardDictation.shared.lastPong = Date() }
            }
        }
    }

    /// The route decision's verdict on a capture started at the tap.
    func resolveEarlyCapture(_ resolution: InKeyboardEarlyCapture.Resolution) {
        guard isProvisional else { return }
        if resolution == .drop { dropEarlyCapture(reason: "route") }
    }

    private func dropEarlyCapture(reason: String) {
        guard isProvisional else { return }
        isProvisional = false
        capture?.stop()
        let dropped = recording.seconds
        recording = InKeyboardRecording()
        Self.log("earlyCapture", "dropped reason=\(reason) bufferedMs=\(Int(dropped * 1000))")
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
        guard !isActive, capture != nil else { return }
        self.state = state
        let keptEarly = isProvisional
        isProvisional = false
        isActive = true
        if !keptEarly { beginCapture() }
        Self.log("earlyCapture", "kept=\(keptEarly) bufferedMs=\(Int(recording.seconds * 1000))")
        startedAt = tapAt ?? Date()
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
        if let view = state.controller?.view { capture?.attach(to: view) }
        tick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.everySecond() }
        }
        waveformClock = Timer.scheduledTimer(withTimeInterval: WaveformFeed.publishInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.publishWaveform() }
        }
        Self.log("start", "engine=\(recognizer?.engineName ?? "none") lang=\(Self.languageCode()) \(MemoryTrace.reading())")
    }

    /// Start the page's capture into a fresh buffer. Used at the tap (provisional) and at
    /// the route decision when nothing was started at the tap.
    private func beginCapture() {
        guard let capture else { return }
        recording = InKeyboardRecording()
        waveform = WaveformFeed()
        chunkArrivals = ChunkArrivalTrace()
        firstSampleLogged = false
        legacyWaveform = Self.debugMarkerExists("in-keyboard-waveform-legacy")
        if let view = state?.controller?.view { capture.attach(to: view) }
        InKeyboardAudioSession.prepareForCapture()
        capture.onEvent = { [weak self] event in self?.handle(event) }
        captureRequestedAt = Date()
        capture.start(testAudioBase64: Self.debugTestAudioBase64())
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
        if isProvisional { dropEarlyCapture(reason: "cancel") }
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
        // Every capture stop ends here, whoever asked for it: the page has stopped its
        // tracks and closed its context, so the session can be handed back now.
        if case .stopped = event {
            InKeyboardAudioSession.releaseAfterCapture()
            return
        }
        guard isActive || isProvisional else { return }
        switch event {
        case .started(let rate, let device):
            let latency = (tapAt ?? startedAt).map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
            Self.log("captureStarted", "latencyMs=\(latency) provisional=\(isProvisional) contextRate=\(Int(rate)) device=\(device) \(MemoryTrace.reading())")
        case .timing(let getUserMediaMs, let contextMs, let firstSampleMs):
            var requestMs = -1
            if let tapAt, let captureRequestedAt { requestMs = Int(captureRequestedAt.timeIntervalSince(tapAt) * 1000) }
            Self.log(
                "captureTiming",
                "tapToRequestMs=\(requestMs) getUserMediaMs=\(Int(getUserMediaMs)) audioContextMs=\(Int(contextMs)) pageFirstSampleMs=\(Int(firstSampleMs))"
            )
        case .samples(let data, let rms):
            if !firstSampleLogged {
                firstSampleLogged = true
                let ms = tapAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1
                Self.log("firstSample", "tapToFirstSampleMs=\(ms) provisional=\(isProvisional)")
            }
            recording.pcm16.append(data)
            waveform.append(pcm16: data)
            chunkArrivals.note(samples: data.count / 2, rms: rms)
            if legacyWaveform { publishLegacyBar(rms: rms) }
            if isActive, recording.seconds >= Self.maximumSeconds { finishRecording(reason: "max-duration") }
        case .interrupted(let reason):
            Self.log("captureInterrupted", "reason=\(reason) provisional=\(isProvisional)")
            if isProvisional { dropEarlyCapture(reason: "interrupted") } else { finishRecording(reason: "interrupted") }
        case .failed(let reason):
            if isProvisional { dropEarlyCapture(reason: "failed: \(reason)") } else { fail("capture: \(reason)") }
        case .stopped:
            break
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
                var owner: DictationSessionClaim.Owner?
                if let sessionID = activeSessionID, let claims {
                    owner = DictationSessionClaim.claim(sessionID, as: .keyboard, in: claims)
                    InKeyboardDictation.log("sessionClaim", "session=\(sessionID) side=keyboard owner=\(owner?.rawValue ?? "unwritable")")
                }
                // Keep or drop what the capture buffered since the tap (round 4).
                dictation.resolveEarlyCapture(InKeyboardEarlyCapture.resolve(route: route, claimOwner: owner))
                // The app got there first and records: no second recording, no URL.
                if owner == .app { return true }
                dictation.start(for: self)
                return true
            }
            dictation.resolveEarlyCapture(.drop)
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

/// The keyboard extension's side of the audio session (round 4: music paused for good).
///
/// What WebKit does (WebKit main, 2026-11-21): any capture makes
/// `MediaSessionManagerCocoa` pick `PlayAndRecord`, whatever `navigator.audioSession.type`
/// says; `AudioSessionIOS.mm` sets it with `AllowBluetooth | AllowBluetoothA2DP |
/// AllowAirPlay | DefaultToSpeaker` and neither `MixWithOthers` nor `DuckOthers`, so it
/// interrupts the music; and `AudioSessionCocoa.mm` deactivates with `setActive:NO
/// withOptions:0`, so iOS never tells the music it may resume. A web page has no API to
/// ask for ducking.
///
/// What the extension can do, following anomalyco/hex's keyboard (MIT): set its own
/// session to a mixable, ducking category before the capture, and deactivate with
/// `notifyOthersOnDeactivation` once the page has stopped. Whether iOS applies the
/// extension's category to WebKit's capture is what the device has to show; the
/// simulator cannot (WebKit fakes PlayAndRecord as Playback there). The release is the
/// part that does not depend on it: it is what lets paused music resume.
enum InKeyboardAudioSession {
    static func prepareForCapture() {
        let session = AVAudioSession.sharedInstance()
        log("before", session)
        do {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.duckOthers, .allowBluetoothA2DP, .defaultToSpeaker])
            if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                // The iPhone microphone keeps AirPods on A2DP: music stays in the ears,
                // ducked, instead of switching the headset to call audio.
                try session.setPreferredInput(builtIn)
            }
        } catch {
            InKeyboardDictation.log("audioSession", "phase=prepare error=\(error.localizedDescription)")
        }
        log("prepared", session)
    }

    /// After the page has stopped. A short delay lets WebKit's own deactivation, which
    /// is asynchronous, land first; then the extension's notifies others.
    static func releaseAfterCapture() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                InKeyboardDictation.log("audioSession", "phase=release error=\(error.localizedDescription)")
            }
            log("released", session)
        }
    }

    private static func log(_ phase: String, _ session: AVAudioSession) {
        let options = session.categoryOptions
        let names = [
            (AVAudioSession.CategoryOptions.mixWithOthers, "mix"),
            (.duckOthers, "duck"),
            (.allowBluetoothA2DP, "a2dp"),
            (.defaultToSpeaker, "speaker"),
            (.allowAirPlay, "airplay")
        ].filter { options.contains($0.0) }.map(\.1)
        InKeyboardDictation.log(
            "audioSession",
            "phase=\(phase) category=\(session.category.rawValue) mode=\(session.mode.rawValue) options=\(names) otherAudioPlaying=\(session.isOtherAudioPlaying) silenceHint=\(session.secondaryAudioShouldBeSilencedHint)"
        )
    }
}
