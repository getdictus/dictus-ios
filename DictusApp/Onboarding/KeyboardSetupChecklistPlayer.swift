// DictusApp/Onboarding/KeyboardSetupChecklistPlayer.swift
// Plays the keyboard step's checklist inline, and in Picture in Picture over Settings (#682).
import AVFoundation
import AVKit
import CoreMedia
import SwiftUI
import UIKit
import DictusCore

/// Drives the checklist the keyboard step shows: the clock, the line states, the frames,
/// and the Picture in Picture window that carries it over iOS Settings (#649 decision 10).
///
/// HOW IT PLAYS
/// - Before the tap, the clock loops in time with the drawn Settings page
///   (`KeyboardSetupChecklist.Phase.demo`); only the fallback's inline card shows it.
/// - Tapping Open Settings is the user action Apple requires to start Picture in Picture.
///   The player starts it, then opens Settings once the window is up. From then on the
///   lines follow what the app can observe (`.guide`): the backgrounded app polls the
///   keyboard list once a second, and adding Dictus ticks the first two lines.
/// - Coming back to the app stops the window. Enabling Full Access stops it too, because
///   iOS terminates the app when that permission changes; nothing else in the app can see
///   Full Access.
/// - If the keyboard is removed after the page detected it, the loop starts again as on
///   first arrival (#713), but nothing is borrowed until the next tap (see
///   `keyboardRemoved`).
///
/// NOTHING SHOWS IN THE PAGE ON THE PICTURE IN PICTURE PATH (decided by Pierre after the
/// device test of 2026-10-10): competitors show the guide only once the user is in
/// Settings, and a card under the drawn Settings page repeated its numbered steps. The
/// sample-buffer layer still has to be in the window for Picture in Picture to start
/// from it, so it sits behind the drawn phone, covered (`ChecklistPictureSource`).
///
/// THE FALLBACK: when Picture in Picture is unsupported, cannot start, or fails to, the
/// checklist plays inline in the page (SwiftUI, `KeyboardSetupChecklistCard`), Settings
/// opens anyway, and the page's existing return-from-Settings detection takes over.
/// `showsInlineCard` says when the page shows it: from the start where Picture in Picture
/// is unavailable, and from the first failure where it was expected to work.
///
/// Everything it does is logged under `component=onboardingChecklist`, so a device run
/// answers the spike's questions from `dictus_debug.log`.
@MainActor
final class KeyboardSetupChecklistPlayer: NSObject, ObservableObject {
    /// The line states, for the SwiftUI card and the VoiceOver label.
    @Published private(set) var lines: [KeyboardSetupChecklistLineState]
    /// How far each line's tick has popped in, 0 to 1.
    @Published private(set) var tickProgress: [Double]
    /// Whether the Picture in Picture window is up.
    @Published private(set) var isPictureInPictureActive = false
    /// Whether the page shows the inline card: the fallback is in use.
    @Published private(set) var showsInlineCard: Bool

    /// Whether the frames are rendered for Picture in Picture (true), or the fallback is
    /// used from the start (false).
    let usesPictureInPicture: Bool

    /// The layer the frames go to: the content source of the Picture in Picture window,
    /// hosted out of sight in the page.
    let displayLayer = AVSampleBufferDisplayLayer()

    /// A launch argument that forces the fallback (`-DictusChecklistPiPOff YES`), so the
    /// inline path can be tested on a device that supports Picture in Picture. Launch
    /// arguments only reach the app from Xcode or `devicectl`, never from a user.
    static var isForcedOff: Bool {
        UserDefaults.standard.bool(forKey: "DictusChecklistPiPOff")
    }

    // MARK: - Private state

    private enum Mode: String {
        case demo, guide, complete
    }

    private var mode: Mode = .demo
    private var keyboardAdded = false
    private var demoStartedAt = Date()
    private var doneAt: [Date?]

    private var pipController: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private let renderer = ChecklistFrameRenderer()
    private let audioSession = ChecklistAudioSession()

    private var timer: Timer?
    private var lastEnqueuedAt = Date.distantPast
    private var lastKeyboardPollAt = Date.distantPast
    private var lastBackgroundHeartbeatAt = Date.distantPast
    private var backgroundTicks = 0
    private var settingsOpenedAt: Date?

    /// Opens Settings once the Picture in Picture window is up (or failed to come up).
    private var pendingSettingsOpen: (() -> Void)?
    /// The step went back to "not detected" without the audio session (#713): the next tap
    /// borrows it before starting Picture in Picture.
    private var preparesOnTap = false
    /// The tap is waiting for `isPictureInPicturePossible` before starting the window
    /// (`.pictureInPictureOnceReady`), within the tap's deadline.
    private var startsWhenPossible = false
    private var settingsOpenDeadline: DispatchWorkItem?
    /// Why the window was asked to stop, for the log. nil when the system or the user
    /// closed it.
    private var stopReason: String?

    /// Frame clock: 10 per second, enough for the tick's pop.
    private static let tickInterval: TimeInterval = 0.1
    /// How long a tick takes to pop in.
    private static let tickPopDuration: TimeInterval = 0.4
    /// A frame at least this often even when nothing changed, so the layer never sits on a
    /// stale timestamp.
    private static let refreshInterval: TimeInterval = 1
    /// How often the backgrounded app looks for the keyboard.
    private static let keyboardPollInterval: TimeInterval = 1
    /// How long the tap waits for the window before opening Settings anyway.
    private static let startTimeout: TimeInterval = 1.5

    override init() {
        let lineCount = KeyboardSetupChecklistLine.allCases.count
        lines = KeyboardSetupChecklist.states(for: .demo(elapsed: 0))
        tickProgress = Array(repeating: 1, count: lineCount)
        doneAt = Array(repeating: nil, count: lineCount)
        usesPictureInPicture = AVPictureInPictureController.isPictureInPictureSupported() && !Self.isForcedOff
        showsInlineCard = !usesPictureInPicture
        super.init()
        if usesPictureInPicture {
            configureLayer()
        }
        log("created", "pipSupported=\(AVPictureInPictureController.isPictureInPictureSupported()) forcedOff=\(Self.isForcedOff)")
    }

    // MARK: - Page lifecycle

    /// Starts the loop. Called when the keyboard step appears.
    ///
    /// WHY THE KEYBOARD IS CHECKED FIRST (device log, 2026-10-10): the step is shown again
    /// when iOS relaunches the app after the Full Access kill, with the keyboard already
    /// there. The page then only offers Continue, so Picture in Picture will never start:
    /// the player goes straight to `.complete`, builds no controller and borrows no audio
    /// session. Borrowing there used to fail anyway (`OSStatus 560557684`, cannot interrupt
    /// others) right after the engine had configured its own session at launch.
    func start() {
        guard timer == nil else { return }
        demoStartedAt = Date()
        if Self.isDictusKeyboardActive() {
            mode = .complete
            keyboardAdded = true
            log("startedComplete")
        } else if usesPictureInPicture {
            preparePictureInPicture()
        }
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // `.common` so the clock keeps running while the page scrolls.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    /// Stops everything and gives the audio session back. Called when the step is left.
    func stop() {
        timer?.invalidate()
        timer = nil
        settingsOpenDeadline?.cancel()
        settingsOpenDeadline = nil
        pendingSettingsOpen = nil
        startsWhenPossible = false
        if let pipController, pipController.isPictureInPictureActive {
            stopReason = "pageLeft"
            pipController.stopPictureInPicture()
        }
        giveBackAudioSession()
        displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true, completionHandler: nil)
    }

    /// The tap on Open Settings. Starts Picture in Picture when it can, and opens Settings
    /// through `open` in every case.
    func openSettings(using open: @escaping () -> Void) {
        if mode != .complete {
            mode = .guide
            keyboardAdded = Self.isDictusKeyboardActive()
        }
        settingsOpenedAt = Date()
        backgroundTicks = 0
        // The frame the window opens on is the guide's, not a demo frame.
        tick(forceFrame: true)

        // Back in the not-detected state (#713), this tap is the user action that may
        // borrow the audio session again.
        let preparedByTheTap = preparesOnTap
        if preparesOnTap {
            preparesOnTap = false
            preparePictureInPicture()
        }

        let trip = KeyboardSetupChecklist.settingsTrip(
            isSupported: AVPictureInPictureController.isPictureInPictureSupported(),
            isPossible: pipController?.isPictureInPicturePossible ?? false,
            isForcedOff: Self.isForcedOff,
            preparedByTheTap: preparedByTheTap
        )
        switch trip {
        case .pictureInPictureThenSettings, .pictureInPictureOnceReady:
            guard let pipController else {
                fallBackInline(reason: "noController")
                open()
                return
            }
            let waits = trip == .pictureInPictureOnceReady
            log("pipStartRequested", "keyboardAdded=\(keyboardAdded) waitsForPossible=\(waits)")
            pendingSettingsOpen = open
            // Never leave the user on the page: if the window has not answered in time,
            // Settings opens anyway and the inline checklist plus the return detection take
            // over.
            let deadline = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.pendingSettingsOpen != nil else { return }
                    // A window that never became possible must not start after Settings.
                    self.startsWhenPossible = false
                    self.fallBackInline(reason: "startTimeout")
                    self.openPendingSettings()
                }
            }
            settingsOpenDeadline = deadline
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.startTimeout, execute: deadline)
            if waits {
                // Started from the `isPictureInPicturePossible` observation.
                startsWhenPossible = true
            } else {
                pipController.startPictureInPicture()
            }
        case .settingsOnly(let reason):
            fallBackInline(reason: reason)
            open()
        }
    }

    /// The app is in front again: the trip to Settings is over, so the window goes.
    func appBecameActive() {
        guard let settingsOpenedAt else { return }
        log(
            "returnedFromSettings",
            "after=\(Int(Date().timeIntervalSince(settingsOpenedAt)))s pipActive=\(isPictureInPictureActive) " +
            "backgroundTicks=\(backgroundTicks) keyboardAdded=\(keyboardAdded)"
        )
        self.settingsOpenedAt = nil
        if let pipController, pipController.isPictureInPictureActive {
            stopReason = "appActive"
            pipController.stopPictureInPicture()
        }
    }

    /// The page no longer finds the keyboard it had detected (#713): back to the loop of
    /// first arrival, in time with the drawn page restarting above it.
    ///
    /// WHY NOTHING IS BORROWED HERE (decided by Pierre, 2026-10-12): Apple starts Picture in
    /// Picture only from a user action, and the audio session must not be taken without one.
    /// So the window waits for the next tap on Open Settings, which borrows the session
    /// (`preparesOnTap`). The controller is built now, since building it borrows nothing and
    /// lets the system get it ready before that tap. A session still held from an earlier
    /// tap stays held: it is not borrowed again.
    func keyboardRemoved() {
        guard mode == .complete else { return }
        mode = .demo
        keyboardAdded = false
        demoStartedAt = Date()
        // As on first arrival: inline only where Picture in Picture is not used. A failure
        // earlier in this visit shows the card again at the next tap's fallback.
        showsInlineCard = !usesPictureInPicture
        if usesPictureInPicture {
            // Same guard as `preparePictureInPicture`: no controller where it is unsupported.
            if pipController == nil, AVPictureInPictureController.isPictureInPictureSupported() {
                makePictureInPictureController()
            }
            preparesOnTap = !audioSession.isBorrowed
        }
        log("reverted", "controller=\(pipController != nil) audioBorrowed=\(audioSession.isBorrowed)")
        tick(forceFrame: true)
    }

    /// The page has detected the keyboard: everything is ticked, as the drawing shows.
    func keyboardDetected() {
        guard mode != .complete else { return }
        mode = .complete
        keyboardAdded = true
        preparesOnTap = false
        log("complete")
        tick(forceFrame: true)
        // Nothing will start Picture in Picture from here (the page offers Continue), so
        // the session goes back to the engine now rather than when the step is left.
        if !isPictureInPictureActive {
            giveBackAudioSession()
        }
    }

    // MARK: - Clock

    private func tick(forceFrame: Bool = false) {
        let now = Date()
        let inBackground = UIApplication.shared.applicationState != .active

        if inBackground {
            // Nothing is visible in the background without the window: no work at all.
            guard isPictureInPictureActive else { return }
            pollKeyboardInBackground(now: now)
            backgroundTicks += 1
            if now.timeIntervalSince(lastBackgroundHeartbeatAt) >= 5 {
                lastBackgroundHeartbeatAt = now
                log("backgroundTick", "ticks=\(backgroundTicks) keyboardAdded=\(keyboardAdded)")
            }
        }

        let newLines = KeyboardSetupChecklist.states(for: currentPhase(now: now))
        var newProgress = tickProgress
        for index in newLines.indices {
            if newLines[index] == .done {
                if lines[index] != .done || doneAt[index] == nil {
                    doneAt[index] = now
                }
            } else {
                doneAt[index] = nil
            }
            newProgress[index] = doneAt[index].map {
                min(1, now.timeIntervalSince($0) / Self.tickPopDuration)
            } ?? 1
        }

        let changed = newLines != lines || newProgress != tickProgress
        if changed {
            lines = newLines
            tickProgress = newProgress
        }
        if usesPictureInPicture,
           changed || forceFrame || now.timeIntervalSince(lastEnqueuedAt) >= Self.refreshInterval {
            enqueueFrame(now: now)
        }
    }

    private func currentPhase(now: Date) -> KeyboardSetupChecklist.Phase {
        switch mode {
        case .demo: return .demo(elapsed: now.timeIntervalSince(demoStartedAt))
        case .guide: return .guide(keyboardAdded: keyboardAdded)
        case .complete: return .complete
        }
    }

    /// The spike's measurement: can the backgrounded app see the keyboard being added?
    private func pollKeyboardInBackground(now: Date) {
        guard mode == .guide, !keyboardAdded,
              now.timeIntervalSince(lastKeyboardPollAt) >= Self.keyboardPollInterval else { return }
        lastKeyboardPollAt = now
        if Self.isDictusKeyboardActive() {
            keyboardAdded = true
            let since = settingsOpenedAt.map { Int(now.timeIntervalSince($0)) } ?? -1
            log("keyboardAddedSeen", "background=true sinceSettings=\(since)s")
        }
    }

    // MARK: - Frames

    private func configureLayer() {
        displayLayer.videoGravity = .resizeAspect
        // A timebase running on the host clock: frames are stamped "now" on it and shown
        // immediately, like a live stream.
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(
            allocator: kCFAllocatorDefault,
            sourceClock: CMClockGetHostTimeClock(),
            timebaseOut: &timebase
        )
        if let timebase {
            CMTimebaseSetTime(timebase, time: CMClockGetTime(CMClockGetHostTimeClock()))
            CMTimebaseSetRate(timebase, rate: 1)
            displayLayer.controlTimebase = timebase
        }
    }

    private func enqueueFrame(now: Date) {
        let time = displayLayer.controlTimebase.map { CMTimebaseGetTime($0) }
            ?? CMClockGetTime(CMClockGetHostTimeClock())
        guard let sampleBuffer = renderer.sampleBuffer(lines: lines, tickProgress: tickProgress, at: time) else {
            log("frameFailed")
            return
        }
        let sampleRenderer = displayLayer.sampleBufferRenderer
        // A renderer that failed (media services reset, a backgrounding without the
        // window) accepts nothing until it is flushed.
        if sampleRenderer.status == .failed {
            log("rendererFailed", "error=\(sampleRenderer.error?.localizedDescription ?? "nil")")
            sampleRenderer.flush()
        }
        sampleRenderer.enqueue(sampleBuffer)
        lastEnqueuedAt = now
    }

    // MARK: - Picture in Picture

    /// Builds the controller and borrows the audio session, once, for a step where Picture
    /// in Picture may start.
    private func preparePictureInPicture() {
        // Checked again on its own, not through `usesPictureInPicture`: on a device without
        // Picture in Picture the controller's initializer returns a nil object that Swift
        // sees as non-optional, and observing it aborts the app (measured on a simulator,
        // which reports Picture in Picture as unsupported).
        if pipController == nil, AVPictureInPictureController.isPictureInPictureSupported() {
            makePictureInPictureController()
        }
        let outcome = audioSession.borrow(engineIsRunning: DictationCoordinator.shared.isAudioEngineRunning)
        log("audioSession", outcome)
    }

    private func giveBackAudioSession() {
        if let outcome = audioSession.giveBack(restoreEngineSession: {
            try DictationCoordinator.shared.configureAudioSessionForWarmUp()
        }) {
            log("audioSession", outcome)
        }
    }

    private func makePictureInPictureController() {
        let source = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: source)
        controller.delegate = self
        // No seeking, no skip buttons: the checklist is live, not a timeline.
        controller.requiresLinearPlayback = true
        // Only the tap on Open Settings starts it; leaving the app another way must not.
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            let possible = controller.isPictureInPicturePossible
            Task { @MainActor in
                self?.log("pipPossible", "value=\(possible)")
                if possible { self?.startIfWaiting() }
            }
        }
        pipController = controller
    }

    /// Starts the window a tap is waiting for (`.pictureInPictureOnceReady`, #713).
    private func startIfWaiting() {
        guard startsWhenPossible, let pipController else { return }
        startsWhenPossible = false
        log("pipStartRequestedWhenPossible")
        pipController.startPictureInPicture()
    }

    /// Picture in Picture will not carry the checklist this time: the page shows it.
    private func fallBackInline(reason: String) {
        log("fallback", "reason=\(reason)")
        showsInlineCard = true
    }

    private func openPendingSettings() {
        settingsOpenDeadline?.cancel()
        settingsOpenDeadline = nil
        guard let open = pendingSettingsOpen else { return }
        pendingSettingsOpen = nil
        open()
    }

    // MARK: - Keyboard

    /// Whether the Dictus keyboard is in the user's keyboard list. Same test as the page's
    /// detection (`KeyboardSetupPage.checkKeyboardInstalled`), without its logging, which
    /// would write a line a second here.
    static func isDictusKeyboardActive() -> Bool {
        // value(forKey:) is KVO; anything but a String is ignored.
        DictusKeyboardPresence(inputModeIdentifiers: UITextInputMode.activeInputModes.compactMap {
            $0.value(forKey: "identifier") as? String
        }).isListed
    }

    // MARK: - Log

    private func log(_ action: String, _ details: String = "") {
        PersistentLog.log(.diagnosticProbe(
            component: "onboardingChecklist",
            instanceID: usesPictureInPicture ? "pip" : "inline",
            action: action,
            details: "\(details) mode=\(mode.rawValue)"
        ))
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension KeyboardSetupChecklistPlayer: AVPictureInPictureControllerDelegate {
    // AVKit calls these on the main thread; the class is @MainActor.

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            isPictureInPictureActive = true
            log("pipStarted")
            openPendingSettings()
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        MainActor.assumeIsolated {
            isPictureInPictureActive = false
            fallBackInline(reason: "failedToStart error=\(error.localizedDescription)")
            openPendingSettings()
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        MainActor.assumeIsolated {
            isPictureInPictureActive = false
            log("pipStopped", "reason=\(stopReason ?? "systemOrUser")")
            stopReason = nil
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        // The window's "back to the app" button: the page is still there, nothing to
        // rebuild.
        completionHandler(true)
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension KeyboardSetupChecklistPlayer: AVPictureInPictureSampleBufferPlaybackDelegate {
    // The checklist is live content that never pauses: the window shows no scrubber and
    // its play button does nothing.

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {}

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        false
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
