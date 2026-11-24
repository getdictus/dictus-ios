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
/// this: record through a hidden web view, transcribe with an `OnDeviceRecognizer`,
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

    private lazy var recognizer: OnDeviceRecognizer? = {
        // The keyboard's lines keep their name in the log (`OnDeviceSpeechLog`).
        OnDeviceSpeechLog.component = "InKeyboardDictation"
        OnDeviceSpeechLog.instanceID = "shared"
        return OnDeviceRecognizerFactory.make()
    }()
    private var capture: InKeyboardWebCapture?
    private var localeAnswer: (code: String, installed: Bool)?
    private var recording = OnDeviceRecording()
    private var startedAt: Date?
    private var tick: Timer?
    /// The overlay's 5 Hz clock, the cadence DictusApp publishes at (`WaveformFeed`).
    private var waveformClock: Timer?
    private var waveform = WaveformFeed()
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
    /// When this tap's ping was posted: only a pong after it counts.
    private var tapPingSentAt: Date?
    /// Full Access read at the tap, for a route decided after iOS tore the controller
    /// down (`InKeyboardDictationRoute.fullAccess`).
    private var fullAccessAtTap: Bool?
    /// The recording stage is on screen ahead of the route decision (first sample of an
    /// early capture): the overlay shows "Listening" as soon as audio arrives.
    private var showsRecordingAhead = false

    // Round 2 (2026-11-23): the start safety net (`DictationStartSafetyNet`).
    /// The session the net watches; nil once it fired or stood down.
    private var safetyNetSession: String?
    private var safetyNetTap: Date?
    /// The keyboard's capture for this tap ended before half a second of audio.
    private var captureEndedWithoutAudio = false
    /// The tap left the keyboard: a URL to DictusApp was opened.
    private var tapLeftKeyboard = false

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
        // No single dictation language (automatic detection): today's path, nothing to check.
        guard let code = Self.languageCode() else {
            Self.log("localeCheck", "skipped=true reason=autoDetect")
            return
        }
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
        let tap = Date()
        tapAt = tap
        fullAccessAtTap = state.controller?.hasFullAccess
        showsRecordingAhead = false
        // Ask the app now, not on a pong from when the keyboard appeared: a pong says
        // nothing about this tap (`InKeyboardEarlyCapture`, device 2026-11-23). The answer
        // is the app's stamp in the App Group (`PingAnswerStamp`).
        tapPingSentAt = tap
        DarwinNotificationCenter.post(DarwinNotificationName.inKeyboardPing)
        guard mayTakeColdTap, !isActive, !isProvisional else {
            Self.log("earlyCapture", "started=false mayTakeColdTap=\(mayTakeColdTap)")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + InKeyboardEarlyCapture.tapPingWindow) { [weak self] in
            self?.startEarlyCaptureIfTheAppIsSilent(tap: tap)
        }
    }

    /// The end of `tapPingWindow`: open the keyboard's microphone only when the app did
    /// not answer this tap's ping, has not claimed the session, and has not moved the
    /// status past `requested`. Nothing touches the audio session before this point.
    private func startEarlyCaptureIfTheAppIsSilent(tap: Date) {
        guard let state, tapAt == tap, !isActive, !isProvisional else { return }
        let appAnswer = appAnswer(since: tap)
        let answered = appAnswer == .willRecord
        let owner = sessionOwner(of: state)
        let stamp = DictationStartTable.PingAnswerStamp(storedValue: AppGroup.defaults.string(forKey: SharedKeys.inKeyboardPingAnswer))
        let pongMs = stamp.flatMap { $0.answeredAt >= tap ? Int($0.answeredAt.timeIntervalSince(tap) * 1000) : nil } ?? -1
        guard state.dictationStatus == .requested,
              InKeyboardEarlyCapture.shouldStartCapture(mayTakeColdTap: mayTakeColdTap, appAnsweredTapPing: answered,
                                                        sessionOwner: owner) else {
            Self.log("earlyCapture", "started=false appAnswer=\(appAnswer.rawValue) pongAtTapMs=\(pongMs) "
                     + "owner=\(owner?.rawValue ?? "none") status=\(state.dictationStatus.rawValue)")
            return
        }
        isProvisional = true
        beginCapture()
        Self.log("earlyCapture", "started=true appAnswer=\(appAnswer.rawValue) windowMs=\(Int(InKeyboardEarlyCapture.tapPingWindow * 1000))")
        // The route decision lands at ~510–520 ms and keeps or drops this. If it never
        // comes — the app answered inside the window, so the keyboard's fallback closure
        // does not run — drop it here rather than leave the microphone open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self, self.isProvisional else { return }
            self.dropEarlyCapture(reason: "no-route-decision")
        }
    }

    /// Who claimed the tap's session, read from the App Group.
    func sessionOwner(of state: KeyboardState) -> DictationSessionClaim.Owner? {
        guard let sessionID = state.activeSessionID, let claims = DictationSessionClaim.defaultDirectory else { return nil }
        return DictationSessionClaim.current(sessionID, in: claims)
    }

    /// Called when a keyboard controller appears: load the capture page now, off the
    /// tap's path, and ask DictusApp whether it is running. The microphone stays closed.
    func prewarm(in view: UIView) {
        guard InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults),
              Self.systemMajorVersion >= InKeyboardDictationRoute.minimumSystemMajorVersion,
              recognizer != nil else { return }
        observeAudioSessionIfNeeded()
        DarwinNotificationCenter.post(DarwinNotificationName.inKeyboardPing)
        if capture == nil { Self.log("prewarm", "webview=loading") }
        loadCaptureIfNeeded(into: view)
    }

    /// Read from the app's stamp in the App Group (`PingAnswerStamp`), never from when the
    /// Darwin pong reached this process, which a suspended keyboard receives late.
    private func appAnswer(since tap: Date?) -> DictationStartTable.AppAnswer {
        AppGroup.defaults.synchronize()
        return DictationStartTable.PingAnswerStamp.answer(
            to: tap, stored: AppGroup.defaults.string(forKey: SharedKeys.inKeyboardPingAnswer)
        )
    }

    /// Called by `KeyboardPolishCoordinator` after an in-keyboard dictation was typed: the
    /// first time, one line says why this text came from Apple's dictation.
    func didInsertInKeyboardTail() {
        guard InKeyboardFirstUse.shouldShow(in: AppGroup.defaults), let state else { return }
        InKeyboardFirstUse.markShown(in: AppGroup.defaults)
        Self.log("firstUse", "shown=true")
        state.presentStatusMessage(
            String(localized: "The Dictus app was closed, so your iPhone dictated with Apple's dictation."),
            reason: "inKeyboardFirstUse",
            timeoutReason: "inKeyboardFirstUse-timeout"
        )
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
        endTicking()
        let dropped = recording.seconds
        recording = OnDeviceRecording()
        if showsRecordingAhead {
            showsRecordingAhead = false
            state?.drawRecordingStageAhead(false)
        }
        Self.log("earlyCapture", "dropped reason=\(reason) bufferedMs=\(Int(dropped * 1000))")
    }

    /// Whether this process could dictate a cold tap by itself: setting on, iOS 26+,
    /// an engine, and no known "model missing" answer for the current language.
    var mayTakeColdTap: Bool {
        guard InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults),
              Self.systemMajorVersion >= InKeyboardDictationRoute.minimumSystemMajorVersion,
              recognizer != nil,
              state?.controller?.hasFullAccess ?? true,
              Self.microphonePermission == .granted,
              let code = Self.languageCode() else { return false }
        if let answer = localeAnswer, answer.code == code { return answer.installed }
        return true
    }

    /// The setting would apply but the microphone is refused for Dictus.
    var wouldRefuseForMicrophone: Bool {
        InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults)
            && Self.systemMajorVersion >= InKeyboardDictationRoute.minimumSystemMajorVersion
            && Self.microphonePermission == .denied
    }

    /// The route for a tap whose wait has just ended: `DictationStartTable`, with every
    /// input and the row it chose logged (`routeInputs`, `startRow`).
    func route(appAnswered: Bool) -> InKeyboardDictationRoute {
        // Automatic detection has no language to check: `nil` routes to today's path.
        let code = Self.languageCode()
        let installed = code.flatMap { code in localeAnswer.flatMap { $0.code == code ? $0.installed : nil } }
        let owner = state.flatMap { sessionOwner(of: $0) }
        let current = state?.controller?.hasFullAccess
        let answer = appAnswer(since: tapPingSentAt)
        let needsPreparation = state?.preparationDeferral()
        let decision = DictationStartTable.decide(.init(
            settingEnabled: InKeyboardDictationRoute.isSettingEnabled(in: AppGroup.defaults),
            systemMajorVersion: Self.systemMajorVersion,
            languageCode: code,
            localeInstalled: installed,
            hasFullAccess: InKeyboardDictationRoute.fullAccess(current: current, atTap: fullAccessAtTap),
            microphone: Self.microphonePermission,
            appAnswer: answer,
            sessionOwner: owner,
            appMovedPastRequested: appAnswered,
            dictusModelNeedsPreparation: needsPreparation != nil
        ))
        // Every input, so a route that surprises can be read from one line (device,
        // 2026-11-23 10:32:01: `openAppURL` with nothing to say why).
        Self.log("routeInputs", "lang=\(code ?? "auto") localeInstalled=\(installed.map(String.init) ?? "unknown") "
                 + "fullAccess=\(current.map(String.init) ?? "noController") fullAccessAtTap=\(fullAccessAtTap.map(String.init) ?? "unknown") "
                 + "microphone=\(Self.microphonePermission.rawValue) owner=\(owner?.rawValue ?? "none") appAnswered=\(appAnswered) "
                 + "appAnswer=\(answer.rawValue) dictusModel=\(needsPreparation ?? "ready")")
        Self.log("startRow", "outcome=\(decision.outcome.rawValue) why=\(decision.why) session=\(state?.activeSessionID ?? "none")")
        return decision.route
    }

    /// The app moved the status past `requested` within the wait: its row, for the log.
    func noteAppTookTapWithinWait(status: DictationStatus, elapsedMs: Int) {
        Self.log("startRow", "outcome=appRecords why=app-status-\(status.rawValue) elapsedMs=\(elapsedMs) "
                 + "appAnswer=\(appAnswer(since: tapPingSentAt).rawValue) session=\(state?.activeSessionID ?? "none")")
    }

    /// DictusApp's microphone permission, which WebKit's capture is attributed to.
    static var microphonePermission: InKeyboardDictationRoute.MicrophonePermission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        default: return .undetermined
        }
    }

    /// The one line the keyboard shows when the microphone is refused for Dictus: neither
    /// the keyboard nor the app can record, so nothing else happens.
    func refuseForMicrophone(reason: String) {
        Self.log("microphoneDenied", "reason=\(reason)")
        guard let state else { return }
        state.forceResetToIdle()
        state.presentStatusMessage(
            String(localized: "Microphone access is off for Dictus. Turn it on in Settings to dictate."),
            reason: "inKeyboardMicrophoneDenied",
            timeoutReason: "inKeyboardMicrophoneDenied-timeout"
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
        let wasShownAhead = showsRecordingAhead
        showsRecordingAhead = false
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
        if waveformClock == nil {
            waveformClock = Timer.scheduledTimer(withTimeInterval: WaveformFeed.publishInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.publishWaveform() }
            }
        }
        if !wasShownAhead {
            Self.log("recordingShown", "tapToListeningMs=\(tapAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? -1) ahead=false")
        }
        Self.log("start", "engine=\(recognizer?.engineName ?? "none") lang=\(Self.languageCode() ?? "auto") \(MemoryTrace.reading())")
    }

    /// Start the page's capture into a fresh buffer. Used at the tap (provisional) and at
    /// the route decision when nothing was started at the tap.
    private func beginCapture() {
        guard let capture else { return }
        recording = OnDeviceRecording()
        waveform = WaveformFeed()
        chunkArrivals = ChunkArrivalTrace()
        firstSampleLogged = false
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
        recording = OnDeviceRecording()
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
                if isProvisional { showRecordingAhead(tapMs: ms) }
            }
            recording.pcm16.append(data)
            waveform.append(pcm16: data)
            chunkArrivals.note(samples: data.count / 2, rms: rms)
            if isActive, recording.seconds >= Self.maximumSeconds { finishRecording(reason: "max-duration") }
        case .interrupted(let reason):
            Self.log("captureInterrupted", "reason=\(reason) provisional=\(isProvisional)")
            if isProvisional { dropEarlyCapture(reason: "interrupted") } else { applyInterruption(.captureEnded, reason: reason) }
        case .failed(let reason):
            if isProvisional {
                dropEarlyCapture(reason: "failed: \(reason)")
            } else if reason.contains("NotAllowedError") {
                // WebKit refused the microphone: the permission was revoked since the tap.
                capture?.stop()
                endTicking()
                isActive = false
                recording = OnDeviceRecording()
                refuseForMicrophone(reason: "capture-refused")
            } else if isActive, recording.seconds < InKeyboardInterruptionPolicy.minimumSeconds {
                // The capture died before the dictation began (the same half second as an
                // interruption, `InKeyboardInterruptionPolicy`): a "try again" line would
                // leave the user with nothing. The safety net opens the app (simulator,
                // 14:15:48: the web content process killed 0.34 s into a capture).
                Self.log("captureFailedBeforeAudio", "reason=\(reason) seconds=\(String(format: "%.2f", recording.seconds))")
                abandonKeyboardCapture()
                captureEndedWithoutAudio = true
                evaluateSafetyNet(trigger: "capture-failed")
            } else {
                fail("capture: \(reason)")
            }
        case .stopped:
            break
        }
    }

    /// The first sample of an early capture: the app was silent to this tap's ping, so
    /// show "Listening" now rather than at the route decision, ~0.1–0.2 s later (device,
    /// 2026-11-23: first sample at 374–490 ms, overlay switched at ~510 ms). Display only:
    /// `dictationStatus` stays `requested` until the route, which the 500 ms closure reads.
    private func showRecordingAhead(tapMs: Int) {
        guard let state, !showsRecordingAhead else { return }
        showsRecordingAhead = true
        state.drawRecordingStageAhead(true)
        if waveformClock == nil {
            waveformClock = Timer.scheduledTimer(withTimeInterval: WaveformFeed.publishInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.publishWaveform() }
            }
        }
        Self.log("recordingShown", "tapToListeningMs=\(tapMs) ahead=true")
    }

    /// Whether the overlay should name Apple's engine: the keyboard dictates, or its
    /// early capture is on screen.
    var drawsAsOnDevice: Bool { ownsKeyboardStatus || showsRecordingAhead }

    /// Publish on the app's clock, never on a chunk's arrival. `KeyboardWaveformDriver`
    /// eases toward each published array frame by frame, so the motion now depends on
    /// the audio and the 5 Hz clock, as it does for a recording in DictusApp.
    private func publishWaveform() {
        guard let state, isActive || showsRecordingAhead else { return }
        state.waveformEnergy = waveform.snapshot()
        state.recordingElapsed = Double(waveform.sampleCount) / OnDeviceRecording.sampleRate
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
        recording = OnDeviceRecording()
        Self.log("recordingStopped", "reason=\(reason) seconds=\(String(format: "%.1f", finished.seconds)) \(memory.dictationSummary())")
        guard let recognizer, finished.seconds > 0.2 else {
            fail("recording too short (\(String(format: "%.2f", finished.seconds)) s)")
            return
        }
        state.dictationStatus = .transcribing
        HapticFeedback.recordingStopped()
        guard let code = Self.languageCode() else {
            // The route never sends automatic detection here; a toolbar change during the
            // recording could, and then nothing is inserted rather than a wrong language.
            fail("no dictation language (automatic detection)")
            return
        }
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

    /// A call, Siri, or the page's capture ending: keep what was said (`InKeyboardInterruptionPolicy`).
    private func applyInterruption(_ event: InKeyboardInterruptionPolicy.Event, reason: String) {
        guard isActive, state?.dictationStatus == .recording else { return }
        let action = InKeyboardInterruptionPolicy.action(for: event, recordedSeconds: recording.seconds)
        Self.log("interruption", "event=\(event.rawValue) reason=\(reason) seconds=\(String(format: "%.1f", recording.seconds)) action=\(action.rawValue)")
        switch action {
        case .finishKeepingText:
            finishRecording(reason: "interruption-\(event.rawValue)")
        case .discard:
            capture?.stop()
            endTicking()
            isActive = false
            recording = OnDeviceRecording()
            state?.forceResetToIdle()
        case .openApp:
            abandonKeyboardCapture()
            captureEndedWithoutAudio = true
            evaluateSafetyNet(trigger: "capture-ended")
        case .continue:
            break
        }
    }

    /// The system's own audio events, observed once per process.
    private var isObservingAudioSession = false

    private func observeAudioSessionIfNeeded() {
        guard !isObservingAudioSession else { return }
        isObservingAudioSession = true
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw.flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began else { return }
            MainActor.assumeIsolated { InKeyboardDictation.shared.applyInterruption(.interruptionBegan, reason: "audio-session") }
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            guard raw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:)) == .oldDeviceUnavailable else { return }
            MainActor.assumeIsolated { InKeyboardDictation.shared.applyInterruption(.inputDeviceLost, reason: "route-change") }
        }
    }

    private func fail(_ reason: String) {
        capture?.stop()
        endTicking()
        isActive = false
        transcription = nil
        recording = OnDeviceRecording()
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

    // MARK: - Start safety net (round 2)

    /// Armed at every mic tap, whatever the row (`DictationStartSafetyNet`): checked at
    /// `deadline`, and at once when the keyboard's capture ends without audio.
    func armSafetyNet(for state: KeyboardState) {
        self.state = state
        safetyNetSession = state.activeSessionID
        safetyNetTap = tapAt.flatMap { Date().timeIntervalSince($0) < 0.5 ? $0 : nil } ?? Date()
        captureEndedWithoutAudio = false
        tapLeftKeyboard = false
        if !isProvisional { firstSampleLogged = false }
        let session = safetyNetSession
        DispatchQueue.main.asyncAfter(deadline: .now() + DictationStartSafetyNet.deadline) { [weak self] in
            guard let self, self.safetyNetSession == session else { return }
            self.evaluateSafetyNet(trigger: "deadline")
        }
    }

    /// A URL to DictusApp was opened for this tap: the tap is the app's now.
    func noteTapLeftKeyboard() {
        tapLeftKeyboard = true
    }

    private func evaluateSafetyNet(trigger: String) {
        // A capture that dies after the net stood down at its deadline (a few samples
        // in, then cut) still needs it: the overlay would otherwise stay on nothing.
        let lateCaptureEnd = safetyNetSession == nil && captureEndedWithoutAudio
        guard let state, let tap = safetyNetTap,
              let session = safetyNetSession ?? (lateCaptureEnd ? state.activeSessionID : nil) else { return }
        let elapsed = Date().timeIntervalSince(tap)
        let elapsedMs = Int(elapsed * 1000)
        let status = state.dictationStatus
        // The app's status as the app wrote it: the keyboard's own dictation draws
        // `recording` locally and leaves the App Group at `idle` (`start`).
        let appStatuses: Set<DictationStatus> = [.recording, .transcribing, .processing, .ready]
        AppGroup.defaults.synchronize()
        let stored = AppGroup.defaults.string(forKey: SharedKeys.dictationStatus).flatMap(DictationStatus.init(rawValue:))
        let reading = DictationStartSafetyNet.Reading(
            elapsed: elapsed,
            keyboardHasAudio: firstSampleLogged,
            appIsRecording: !ownsKeyboardStatus && stored.map(appStatuses.contains) == true,
            tapEnded: tapLeftKeyboard || state.activeSessionID != session || status == .idle || status == .failed,
            captureEndedWithoutAudio: captureEndedWithoutAudio
        )
        var verdict = DictationStartSafetyNet.evaluate(reading)
        // Never open the app for a tap the user can no longer see, or that a suspended
        // extension wakes up to long after it (iOS does not run timers in a suspended
        // extension): the watchdog owns those.
        if case .fire = verdict {
            if !state.isKeyboardVisible {
                verdict = .standDown("keyboard-hidden")
            } else if elapsed > DictationStartSafetyNet.deadline + 2, !captureEndedWithoutAudio {
                verdict = .standDown("late-\(elapsedMs)ms")
            }
        }
        if case .keepWaiting = verdict { return }
        safetyNetSession = nil
        Self.log("startSafetyNet", "\(verdict.logFields) elapsedMs=\(elapsedMs) trigger=\(trigger) "
                 + "status=\(status.rawValue) appAnswer=\(appAnswer(since: tapPingSentAt).rawValue) session=\(session)")
        guard case .fire = verdict else { return }
        abandonKeyboardCapture()
        // The keyboard's own bars and clock describe a capture that is gone.
        state.waveformEnergy = []
        state.recordingElapsed = 0
        state.openAppByTodaysPath(source: "startSafetyNet", elapsedMs: elapsedMs)
    }

    /// Stop whatever the keyboard captures for this tap, without touching the status.
    private func abandonKeyboardCapture() {
        if isProvisional { dropEarlyCapture(reason: "safety-net") }
        guard isActive else { return }
        capture?.stop()
        endTicking()
        isActive = false
        recording = OnDeviceRecording()
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

    /// The dictation language the user chose (`InKeyboardDictationRoute.dictationLanguageCode`);
    /// nil under automatic detection, where the keyboard keeps today's path.
    private static func languageCode() -> String? {
        InKeyboardDictationRoute.activeDictationLanguageCode()
    }

    /// The Pro vocabulary's enabled terms, the strings offered to the recognizer. Empty
    /// without the entitlement, as `CustomVocabulary.corrected` treats it.
    private static func vocabularyTerms() -> [String] {
        guard VocabularyAvailability.isEntitled else { return [] }
        return VocabularyStore.loadEntries().filter(\.isEnabled).map(\.term)
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
        // Also skipped when the microphone is refused: the keyboard's decision then says
        // so in one line, where opening the app for its model would hide the reason.
        let mayTakeOver = MainActor.assumeIsolated {
            InKeyboardDictation.shared.mayTakeColdTap || InKeyboardDictation.shared.wouldRefuseForMicrophone
        }
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
        // Every row, setting on or off (`DictationStartSafetyNet`).
        MainActor.assumeIsolated { InKeyboardDictation.shared.armSafetyNet(for: self) }
    }

    /// The 500 ms wait ended with the status past `requested`: the app took the tap.
    func noteAppTookTapWithinWait(elapsedMs: Int) {
        guard activeSessionID != nil else { return }
        let status = dictationStatus
        MainActor.assumeIsolated { InKeyboardDictation.shared.noteAppTookTapWithinWait(status: status, elapsedMs: elapsedMs) }
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
            if route == .microphoneDenied {
                dictation.refuseForMicrophone(reason: "route")
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

/// The keyboard extension's side of the audio session (music paused for good).
///
/// What WebKit does (WebKit main, `Source/WebCore/platform/audio/ios/AudioSessionIOS.mm`
/// and `cocoa/AudioSessionCocoa.mm`, read 2026-11-21 and again 2026-11-23): any capture
/// sets `PlayAndRecord` with `AllowBluetooth | AllowBluetoothA2DP | AllowAirPlay |
/// DefaultToSpeaker`, never `MixWithOthers` or `DuckOthers`, so it interrupts the music;
/// it activates with `setActive:YES withOptions:0` and deactivates with `setActive:NO
/// withOptions:0`, so iOS never tells the music it may resume. That session lives in
/// WebKit's process, not this one (the extension's own category never changes in the
/// log), and a page has no API to ask for ducking. **Ducking is not reachable.**
///
/// Device, 2026-11-23: the two dictations started over music logged
/// `otherAudioPlaying=true` before the capture and `false` after the release, and Pierre
/// heard the music stop for good. The extension's `notifyOthersOnDeactivation` did
/// nothing, because its session had never been active: it had not interrupted anyone.
///
/// The fallback: when music plays, the extension activates its own non-mixable session
/// before the capture, so it is the extension that interrupts the music, and it
/// deactivates with `notifyOthersOnDeactivation` once WebKit has stopped, which is the
/// signal a music app resumes on. The device has to confirm it (the simulator fakes
/// WebKit's capture as `Playback` and plays no music); without music nothing changes.
enum InKeyboardAudioSession {
    /// Set when the extension activated its session over music, so the release knows
    /// it has an interruption to end.
    private static var interruptedMusic = false

    static func prepareForCapture() {
        let session = AVAudioSession.sharedInstance()
        log("before", session)
        // Kept from round 4: ask for the iPhone microphone, so AirPods stay on A2DP. The
        // device log shows `device=Micro de l’iPhone` either way.
        if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? session.setPreferredInput(builtIn)
        }
        guard session.isOtherAudioPlaying else {
            interruptedMusic = false
            return
        }
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
            interruptedMusic = true
        } catch {
            interruptedMusic = false
            InKeyboardDictation.log("audioSession", "phase=prepare error=\(error.localizedDescription)")
        }
        log("prepared", session)
    }

    /// After the page has stopped. A short delay lets WebKit's own deactivation, which
    /// is asynchronous, land first; then the extension's notifies the music.
    static func releaseAfterCapture() {
        guard interruptedMusic else { return }
        interruptedMusic = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                InKeyboardDictation.log("audioSession", "phase=release error=\(error.localizedDescription)")
            }
            log("released", session)
            // Read again a second later: whether the music came back is the answer.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { log("afterRelease", session) }
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
