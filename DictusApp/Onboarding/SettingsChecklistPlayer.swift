// DictusApp/Onboarding/SettingsChecklistPlayer.swift
// Plays an onboarding step's checklist in Picture in Picture over Settings (#682, #706).
import AVFoundation
import AVKit
import CoreMedia
import SwiftUI
import UIKit
import DictusCore

/// What one onboarding step's checklist brings to the player: its lines, the fact the
/// backgrounded app can observe, and what ends it. The keyboard step's is
/// `KeyboardSetupChecklistScript` (#682), the Apple Intelligence step's
/// `AppleIntelligenceChecklistScript` (#706).
@MainActor
protocol SettingsChecklistScript: AnyObject {
    /// The `component=` of every log line, so a device log tells the steps apart.
    var logComponent: String { get }
    /// The observed fact, for the log ("keyboardAdded=true").
    var factDetails: String { get }
    /// How often the backgrounded app reads the fact while the window is up.
    var backgroundPollInterval: TimeInterval { get }
    /// Whether the window goes by itself once the step is complete in the background, after
    /// the ticks have shown (`SettingsChecklistPlayer.completionHold`).
    var stopsWhenComplete: Bool { get }
    /// The text of each line, in order.
    var titles: [Text] { get }
    /// Reads the fact when the page appears, and answers whether the step is already done:
    /// the player then goes straight to `.complete`, with no controller and no audio borrow.
    func checkAlreadyComplete() -> Bool
    /// The tap on Open Settings: reads the fact afresh.
    func refreshFact()
    /// A read from the background while the window is up.
    func pollInBackground(sinceSettings: Int) -> SettingsChecklistPoll
    /// The page has seen the step done: the fact is now final.
    func markComplete()
    /// The page no longer sees the step done (the keyboard removed, #713): the fact is reset.
    func markIncomplete()
    /// The line states in `phase`.
    func states(for phase: SettingsChecklistPhase) -> [SettingsChecklistLineState]
}

/// What drives a checklist's lines, as the player sees it.
enum SettingsChecklistPhase: Equatable {
    /// Before the tap. `elapsed` is the time since the page appeared.
    case idle(elapsed: TimeInterval)
    /// After the tap on Open Settings: the lines follow the observed fact.
    case guide
    /// The step is done: every line ticked.
    case complete
}

/// What a background read found.
enum SettingsChecklistPoll: Equatable {
    case unchanged
    /// The fact moved without completing the step; logged as `action details`.
    case progressed(action: String, details: String)
    /// The step is done; logged as `action details`.
    case completed(action: String, details: String)
}

/// Drives the checklist an onboarding step shows: the clock, the line states, the frames,
/// and the Picture in Picture window that carries it over iOS Settings (#649 decision 10).
/// What the lines say and what ends them is the step's `SettingsChecklistScript`.
///
/// HOW IT PLAYS
/// - Before the tap, the clock runs the script's idle lines (the keyboard step loops in
///   time with its drawn Settings page); only the keyboard fallback's inline card shows it.
/// - Tapping Open Settings is the user action Apple requires to start Picture in Picture.
///   The player starts it, then opens Settings once the window is up. From then on the
///   lines follow what the app can observe (`.guide`): the backgrounded app reads the
///   script's fact (the keyboard list once a second, Apple Intelligence's availability).
/// - Coming back to the app stops the window. On the keyboard step, enabling Full Access
///   stops it too, because iOS terminates the app when that permission changes. On the
///   Apple Intelligence step, availability turning `available` ticks every line, and the
///   window goes a moment later (`stopsWhenComplete`).
/// - If the keyboard is removed after the page detected it, the loop starts again as on
///   first arrival (#713), but nothing is borrowed until the next tap (see
///   `markIncomplete`).
///
/// NOTHING SHOWS IN THE PAGE ON THE PICTURE IN PICTURE PATH (decided by Pierre after the
/// device test of 2026-10-10): competitors show the guide only once the user is in
/// Settings, and a card under the drawn Settings page repeated its numbered steps. The
/// sample-buffer layer still has to be in the window for Picture in Picture to start
/// from it, so it sits at the bottom of the page, covered (`ChecklistPictureSource`).
///
/// THE FALLBACK: when Picture in Picture is unsupported, cannot start, or fails to,
/// Settings opens anyway, and the page's existing return-from-Settings detection takes
/// over. `showsInlineCard` says when the page may show the checklist instead: from the
/// start where Picture in Picture is unavailable, and from the first failure where it was
/// expected to work. The keyboard step shows its inline card then
/// (`KeyboardSetupChecklistCard`); the Apple Intelligence step keeps its page as it is.
///
/// Everything it does is logged under the script's `component=` (`onboardingChecklist` on
/// the keyboard step), so a device run answers from `dictus_debug.log`.
@MainActor
final class SettingsChecklistPlayer: NSObject, ObservableObject {
    /// The line states, for the SwiftUI card and the VoiceOver label.
    @Published private(set) var lines: [SettingsChecklistLineState]
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

    private let script: SettingsChecklistScript
    private var mode: Mode = .demo
    private var demoStartedAt = Date()
    /// When the step was found complete in the background, for `completionHold`.
    private var completedInBackgroundAt: Date?
    private var doneAt: [Date?]

    private var pipController: AVPictureInPictureController?
    private var possibleObservation: NSKeyValueObservation?
    private let renderer = ChecklistFrameRenderer()
    private let audioSession = ChecklistAudioSession()

    private var timer: Timer?
    private var lastEnqueuedAt = Date.distantPast
    private var lastFactPollAt = Date.distantPast
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
    /// How long the tap waits for the window before opening Settings anyway.
    private static let startTimeout: TimeInterval = 1.5
    /// How long the ticks stay up before a complete step's window goes
    /// (`SettingsChecklistScript.stopsWhenComplete`): long enough to see them pop.
    static let completionHold: TimeInterval = 1.5

    init(script: SettingsChecklistScript) {
        self.script = script
        let initialLines = script.states(for: .idle(elapsed: 0))
        let lineCount = initialLines.count
        lines = initialLines
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

    /// Starts the loop. Called when the step appears.
    ///
    /// WHY THE STEP IS CHECKED FIRST (device log, 2026-10-10): the keyboard step is shown
    /// again when iOS relaunches the app after the Full Access kill, with the keyboard
    /// already there, and the Apple Intelligence step shows Continue when it is already
    /// available. The page then only offers Continue, so Picture in Picture will never
    /// start: the player goes straight to `.complete`, builds no controller and borrows no
    /// audio session. Borrowing there used to fail anyway (`OSStatus 560557684`, cannot
    /// interrupt others) right after the engine had configured its own session at launch.
    func start() {
        guard timer == nil else { return }
        demoStartedAt = Date()
        if script.checkAlreadyComplete() {
            mode = .complete
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
            script.refreshFact()
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

        let trip = SettingsChecklist.settingsTrip(
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
            log("pipStartRequested", "\(script.factDetails) waitsForPossible=\(waits)")
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
            "backgroundTicks=\(backgroundTicks) \(script.factDetails)"
        )
        self.settingsOpenedAt = nil
        if let pipController, pipController.isPictureInPictureActive {
            stopReason = "appActive"
            pipController.stopPictureInPicture()
        }
        // Completed in the background (the Apple Intelligence step): nothing will start
        // Picture in Picture again, and the session could not be given back from there
        // (`ChecklistAudioSession.giveBack` needs the foreground).
        if completedInBackgroundAt != nil {
            completedInBackgroundAt = nil
            giveBackAudioSession()
        }
    }

    /// The page no longer finds what it had detected (the keyboard removed, #713): back to
    /// the loop of first arrival, in time with the drawn page restarting above it.
    ///
    /// WHY NOTHING IS BORROWED HERE (decided by Pierre, 2026-10-12): Apple starts Picture in
    /// Picture only from a user action, and the audio session must not be taken without one.
    /// So the window waits for the next tap on Open Settings, which borrows the session
    /// (`preparesOnTap`). The controller is built now, since building it borrows nothing and
    /// lets the system get it ready before that tap. A session still held from an earlier
    /// tap stays held: it is not borrowed again.
    func markIncomplete() {
        guard mode == .complete else { return }
        mode = .demo
        script.markIncomplete()
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

    /// The page has seen the step done (the keyboard detected, Apple Intelligence ready):
    /// everything is ticked, as the drawing shows.
    func markComplete() {
        guard mode != .complete else { return }
        mode = .complete
        script.markComplete()
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
            pollFactInBackground(now: now)
            backgroundTicks += 1
            if now.timeIntervalSince(lastBackgroundHeartbeatAt) >= 5 {
                lastBackgroundHeartbeatAt = now
                log("backgroundTick", "ticks=\(backgroundTicks) \(script.factDetails)")
            }
            stopIfCompleteAndShown(now: now)
        }

        let newLines = script.states(for: currentPhase(now: now))
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

    private func currentPhase(now: Date) -> SettingsChecklistPhase {
        switch mode {
        case .demo: return .idle(elapsed: now.timeIntervalSince(demoStartedAt))
        case .guide: return .guide
        case .complete: return .complete
        }
    }

    /// The spike's measurement: can the backgrounded app see the step's fact change (the
    /// keyboard being added, Apple Intelligence turning available)?
    private func pollFactInBackground(now: Date) {
        guard mode == .guide,
              now.timeIntervalSince(lastFactPollAt) >= script.backgroundPollInterval else { return }
        let since = settingsOpenedAt.map { Int(now.timeIntervalSince($0)) } ?? -1
        switch script.pollInBackground(sinceSettings: since) {
        case .unchanged:
            break
        case .progressed(let action, let details):
            log(action, details)
        case .completed(let action, let details):
            log(action, details)
            mode = .complete
            completedInBackgroundAt = now
        }
        lastFactPollAt = now
    }

    /// A step completed in the background closes its window once the ticks have shown, when
    /// its script says so. The keyboard step's never does: iOS ends the app on Full Access.
    private func stopIfCompleteAndShown(now: Date) {
        guard script.stopsWhenComplete, let completedInBackgroundAt,
              now.timeIntervalSince(completedInBackgroundAt) >= Self.completionHold,
              stopReason == nil,
              let pipController, pipController.isPictureInPictureActive else { return }
        stopReason = "complete"
        pipController.stopPictureInPicture()
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
        let card = SettingsChecklistPictureCard(titles: script.titles, lines: lines, tickProgress: tickProgress)
        guard let sampleBuffer = renderer.sampleBuffer(drawing: card, at: time) else {
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

    // MARK: - Log

    private func log(_ action: String, _ details: String = "") {
        PersistentLog.log(.diagnosticProbe(
            component: script.logComponent,
            instanceID: usesPictureInPicture ? "pip" : "inline",
            action: action,
            details: "\(details) mode=\(mode.rawValue)"
        ))
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension SettingsChecklistPlayer: AVPictureInPictureControllerDelegate {
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

extension SettingsChecklistPlayer: AVPictureInPictureSampleBufferPlaybackDelegate {
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
