// DictusApp/DictusApp.swift
import SwiftUI
import StoreKit
import Combine
import DictusCore

// MARK: - AppDelegate (sourceApplication diagnostic)
// Temporary diagnostic: UIApplicationDelegateAdaptor captures sourceApplication
// from the legacy application(_:open:options:) callback, which SwiftUI's onOpenURL
// does not expose. This lets us empirically confirm that sourceApplication returns nil
// for cross-team apps (e.g., WhatsApp opening DictusApp via dictus:// URL).
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        let source = options[.sourceApplication] as? String
        PersistentLog.log(.diagnosticProbe(
            component: "sourceApp", instanceID: "0",
            action: "delegateSourceApp",
            details: "source=\(source ?? "nil") url=\(url.absoluteString)"
        ))
        // Return false so SwiftUI onOpenURL still handles the URL
        return false
    }

    /// Reconnects the app to model transfers that outlived the previous process
    /// (issue #449).
    ///
    /// WHY HERE AND NOWHERE ELSE: recreating the background `URLSession` with its stable
    /// identifier is what makes the system hand back the tasks it kept running, and it
    /// has to happen before anything can ask for a download — otherwise a second copy of
    /// a live transfer is exactly what starts. This is also the earliest callback that
    /// exists on every launch, including the ones iOS makes in the background purely to
    /// deliver those transfers' events.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundModelDownloadService.shared.restore()
        return true
    }

    /// iOS relaunched (or resumed) the app to deliver background transfer events.
    ///
    /// The handler must be called once the session says it has no more events, and on the
    /// main thread — that is what lets the system snapshot the UI and suspend the process
    /// again. `BackgroundModelDownloadService` holds it until
    /// `urlSessionDidFinishEvents(forBackgroundURLSession:)` fires.
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == BackgroundModelDownloadService.sessionIdentifier else {
            completionHandler()
            return
        }
        let box = BackgroundEventsHandlerBox(completionHandler)
        BackgroundModelDownloadService.shared.setBackgroundCompletionHandler { box.call() }
    }

    /// Installs `DictusSceneDelegate` so the launch URL can be read at scene connection.
    ///
    /// WHY here rather than in Info.plist: the app has no `UISceneConfigurations` entry,
    /// and UIKit asks the app delegate first. Returning a configuration with our delegate
    /// class is the least invasive way to get `UIScene.ConnectionOptions` — the only API
    /// that exposes the launch URL before SwiftUI evaluates its first body (issue #264).
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = DictusSceneDelegate.self
        return configuration
    }
}

/// Carries UIKit's background-session completion handler across one queue hop.
///
/// WHY a box: `application(_:handleEventsForBackgroundURLSession:completionHandler:)`
/// hands over a plain, non-`Sendable` closure, and it has to reach the download
/// service's serial queue and come back to the main thread to be called.
/// `@unchecked` is honest here because exactly one place ever calls it —
/// `BackgroundModelDownloadService.drainBackgroundEventsIfNeeded`, on the main queue,
/// once, after the session reports it has no more events to deliver.
private final class BackgroundEventsHandlerBox: @unchecked Sendable {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    func call() {
        handler()
    }
}

@main
struct DictusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = DictationCoordinator.shared
    @StateObject private var proStatus: ProStatusManager
    @StateObject private var subscriptionManager: SubscriptionManager

    /// The saved dictations (#70). A `StateObject` on the singleton, like the
    /// coordinator above: the object outlives every view, and this is what publishes
    /// it to the screens that read it.
    @StateObject private var history = TranscriptionHistoryStore.shared

    /// Onboarding completion flag stored in App Group for cross-process access.
    ///
    /// WHY AppStorage with suiteName instead of plain @State:
    /// AppStorage with the App Group suite persists the value across app launches AND
    /// makes it accessible to the keyboard extension if needed. The `store:` parameter
    /// points to the shared UserDefaults container.
    ///
    /// Default is `false` — first-time users see the onboarding flow.
    /// Set to `true` when user completes the 5-step onboarding.
    @AppStorage(SharedKeys.hasCompletedOnboarding, store: UserDefaults(suiteName: AppGroup.identifier))
    private var hasCompletedOnboarding = false

    init() {
        PersistentLog.source = "APP"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        PersistentLog.log(.appLaunched(version: version))

        // A process that has just started cannot have a model load in flight (#428).
        //
        // `modelLoadState` lives in the App Group and nothing ever cleared it, so a
        // compile interrupted by a force-quit or a jetsam left "loading" behind for
        // good. The keyboard reads that value and answers a mic tap by opening Dictus
        // with `intent=prepare`, which makes `MainTabView` replace the tab bar with the
        // preparation screen — no Settings, no model list, no way to pick something
        // else. One dead compile locked the app out of itself on every later launch.
        //
        // WHY here, above everything: this must run before any reader.
        //
        // The reader that could plausibly beat it is `DictationCoordinator.shared`, and
        // it cannot. `@StateObject`'s initializer takes its value as an
        // `@autoclosure @escaping` closure, so `DictationCoordinator.shared` is not
        // built when this struct is initialized at all — SwiftUI calls that closure the
        // first time it needs the object, which is during the first `body` evaluation,
        // after `init()` has returned. (An earlier version of this comment said it was
        // built as a stored-property default before the body ran. The conclusion was
        // right and the reason was wrong, which is worse than saying nothing: the next
        // person checks the reason.)
        //
        // The coordinator's own preload then writes "loading" from a main-actor `Task`,
        // later still, and that write is the honest one — that load really is in flight.
        if ModelLoadState.clearStaleLoadingState(in: AppGroup.defaults) {
            // Two lines on purpose, and neither is redundant.
            //
            // The transition line keeps the `modelLoadStateChanged` grep complete: a
            // reader following the state across a session must not find a gap where a
            // correction happened. The probe carries the model identifier, which the
            // transition event has no field for and which is the first thing anyone
            // debugging this will want.
            //
            // WHY it matters that this logs at all: a stuck load is otherwise INVISIBLE
            // across relaunches. `setModelLoadState` returns without logging when the
            // persisted value already matches what it is being asked to write, so a
            // process that starts on a stale "loading" and writes "loading" again says
            // nothing. Measured on the maintainer's device: six consecutive launches
            // with an `appLaunched` line and not one `modelLoadStateChanged` after it.
            // From this build on, the correction is on the record, and the `.loading`
            // that follows it is a real transition that logs like any other.
            let stuckModel = AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? "unknown"
            PersistentLog.log(.modelLoadStateChanged(
                from: ModelLoadState.loading.rawValue,
                to: ModelLoadState.idle.rawValue,
                reason: "stale-loading-cleared-at-launch"
            ))
            PersistentLog.log(.diagnosticProbe(
                component: "ModelPreload",
                instanceID: stuckModel,
                action: "staleLoadingCleared",
                details: "from=loading to=idle trigger=appLaunch"
            ))
        }

        // Clean up any Live Activities left over from a previous app session.
        // WHY in init: If the app crashed or was force-quit, the Dynamic Island
        // keeps showing stale data for up to 8 hours. Cleaning up here ensures
        // a fresh start.
        LiveActivityManager.shared.cleanupStaleActivities()

        // Retire App Group keys nothing reads any more (#361 removed the #357 probe's
        // arming flag). A device where the debug toggle was left on carries a `true`
        // for a key that no longer exists in code, and this is the only process that
        // owns hygiene over shared state.
        SharedKeys.clearRetiredKeys()

        let result = AppGroupDiagnostic.run()
        DictusLogger.app.info(
            "AppGroup diagnostic: healthy=\(result.isHealthy, privacy: .public)"
        )

        // Read n-gram diagnostic written by keyboard extension
        if let ngramDiag = UserDefaults(suiteName: AppGroup.identifier)?.string(forKey: "ngramDiagnostic") {
            DictusLogger.app.info("ngramDiagnostic: \(ngramDiag, privacy: .public)")
        }

        // Persist language default so TranscriptionService always reads "fr"
        // even before user visits Settings. @AppStorage defaults are in-memory only
        // and never written to UserDefaults until the Picker is interacted with.
        // WHY `if nil` check: Only write if the key doesn't exist yet. If user already
        // set a language preference (e.g., "en"), don't overwrite it.
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        if defaults?.string(forKey: SharedKeys.language) == nil {
            defaults?.set("fr", forKey: SharedKeys.language)
        }
        // Freeze the layout an updating install is already typing on, before anything can
        // change the active language (#272). The migration is idempotent and also runs from
        // the first layout read in either process — the keyboard extension can run before
        // this app is ever launched again — so this call is only about doing it as early as
        // possible on the app side.
        KeyboardLayoutPreference.migrateToPerLanguageLayoutsIfNeeded()

        // Register liveActivityEnabled default as true for existing users.
        // WHY: UserDefaults.bool(forKey:) returns false for missing keys.
        // Without this, existing users upgrading would see Live Activity disabled.
        if defaults?.object(forKey: SharedKeys.liveActivityEnabled) == nil {
            defaults?.set(true, forKey: SharedKeys.liveActivityEnabled)
        }

        // Initialize Pro subscription management.
        // WHY explicit _proStatus / _subscriptionManager initialization:
        // SubscriptionManager depends on ProStatusManager (it writes Pro status
        // to App Group). We need to create proStatus first, pass it to
        // SubscriptionManager, then wrap both in StateObject.
        let proStatus = ProStatusManager()
        _proStatus = StateObject(wrappedValue: proStatus)
        _subscriptionManager = StateObject(wrappedValue: SubscriptionManager(proStatus: proStatus))

        // Warm up the polish engine for the current target language (#141).
        // No-op when the toggle is off or when the engine has nothing to warm.
        PolishCoordinator.shared.prewarm()
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(coordinator)
                .environmentObject(proStatus)
                .environmentObject(subscriptionManager)
                .environmentObject(history)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { phase in
                    // #281 probe: publish the phase before anything else in this
                    // closure, so the keyboard extension reads a value that is at
                    // worst microseconds behind the transition it describes. It is
                    // written from the same callback that logs the lifecycle line
                    // below, which is what lets the two be compared at all.
                    AppScenePhaseProbe.record(phase.sceneMarker)

                    switch phase {
                    case .active:
                        PersistentLog.log(.appDidBecomeActive)
                    case .inactive:
                        PersistentLog.log(.appWillResignActive)
                    case .background:
                        PersistentLog.log(.appDidEnterBackground)

                        // A cold start parked waiting for `.active` gets its last
                        // chance here (#311), because `.active` is not coming — the
                        // user swiped back before the app settled. Called from this
                        // handler rather than from a `didEnterBackground` observer of
                        // its own so the recovery and the `appDidEnterBackground` line
                        // the regression grep pivots on come from one event and cannot
                        // drift apart.
                        let resumedColdStart = coordinator.resolvePendingColdStartOnBackground()

                        // Exhaustive by construction (#267): a status added later
                        // cannot be left out of this list and silently clear the
                        // cold-start flag mid-dictation.
                        //
                        // A cold start resumed one line above counts as recording even
                        // though `status` has not moved yet — it starts inside a Task.
                        // Without the first clause, the two decisions below would clear
                        // `coldStartActive` out from under it (killing the keyboard's
                        // 15 s watchdog grace) and race a standby activity against the
                        // recording one, both of which the comments below already warn
                        // against for the healthy cold start.
                        let isRecordingActive = resumedColdStart
                            || DictationSessionLivenessPolicy.isActive(coordinator.status)

                        // Only clear cold start state if NOT recording.
                        // During cold start, the app transitions to background while recording
                        // continues. Clearing the flag here kills the keyboard's watchdog grace period
                        // and freezes the keyboard UI. The flag is cleared later in
                        // DictationCoordinator.cleanupRecordingKeys() when the recording finishes.
                        if !isRecordingActive {
                            AppGroup.defaults.set(false, forKey: SharedKeys.coldStartActive)
                            AppGroup.defaults.synchronize()
                            PersistentLog.log(.coldStartFlagSet(active: false, context: "background-cleanup"))
                        }

                        // Only start standby activity if NOT recording.
                        // During cold start recording, transitionToRecording() already manages
                        // the Live Activity. Calling startStandbyActivity() here creates a race:
                        // it detects the recording activity as "stale" and replaces it with a new
                        // standby activity, losing all waveform updates to the Dynamic Island.
                        if !isRecordingActive {
                            LiveActivityManager.shared.startStandbyActivity()
                        }
                    @unknown default:
                        break
                    }
                }
                .onChange(of: hasCompletedOnboarding) { completed in
                    // WHY this notification:
                    // MainTabView's HomeView mounts BEHIND the fullScreenCover before
                    // onboarding completes. Its onAppear fires early with stale state.
                    // When onboarding finishes and the cover dismisses, onAppear does NOT
                    // re-fire. This notification tells HomeView to refresh model state.
                    if completed {
                        NotificationCenter.default.post(
                            name: Notification.Name("DictusOnboardingCompleted"),
                            object: nil
                        )
                    }
                }
                .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                    OnboardingView(isComplete: $hasCompletedOnboarding)
                        .environmentObject(coordinator)
                        .environmentObject(proStatus)
                        .environmentObject(subscriptionManager)
                }
        }
    }

    /// In-memory flag: true after the app has handled its first URL or become active.
    /// Resets naturally when iOS terminates the process (true cold start).
    /// WHY static: @State/@StateObject reset on view recreation, but a static var persists
    /// for the entire process lifetime — exactly matching "app was killed vs still in memory".
    private static var hasBeenActive = false

    /// Reopens the app the keyboard was serving, if it can be named and has a way back.
    ///
    /// Runs inside the ~300 ms window in which a freshly foregrounded app is still
    /// allowed to call `open()`. Past it, iOS refuses with "Application is neither
    /// visible nor entitled" — which is why the 200 ms wait is a wait and not a retry
    /// loop: there is no second chance to schedule.
    ///
    /// WHY 200 ms at all: the recording needs to have actually started before the
    /// foreground changes hands. It is the same figure VivaDicta settled on, and it sits
    /// comfortably inside the window.
    ///
    /// WHY it waits for the recording rather than a fixed delay. `startDictation` returns
    /// before its recording task has run, so the previous fixed 200 ms was a bet that the
    /// task wins the race. A device capture settled it: `recState=idle`, 7 times out of 7
    /// — the bet was lost every time, and the user lost the head of the dictation while
    /// the engine started underneath a backgrounding app.
    ///
    /// So this now waits for `.recording` and opens anyway at `recordingWaitCeilingMs`.
    /// **The property that matters is that it can only gain, never lose**: if the engine
    /// is ready early the user arrives already recording, and if it is not, the open
    /// happens exactly as it did before. Waiting *without* a ceiling would have been the
    /// obvious reading of the review and is the one thing that must not be done — it
    /// trades a partial loss for a total one.
    ///
    /// `recState=` stays on the line, with `waitedMs=`, because they are what will say
    /// whether the ceiling is calibrated and whether a later change to the audio pipeline
    /// has pushed the start out again.
    ///
    /// Every branch that does not open something logs why, at `notice`. The app is
    /// usually terminated moments after this runs, so an `info` line would not survive
    /// to explain itself, and `no-scheme` is this project's only report channel for a
    /// host nobody has mapped — there is no analytics, the debug log is it (#255).
    /// How long the return may wait for recording to have actually started.
    ///
    /// **A ceiling, not a wait.** It is bounded by the window in which a freshly
    /// foregrounded app may still call `open()` — about 300 ms, past which iOS refuses
    /// with "Application is neither visible nor entitled" and the user gets *no* return
    /// at all. 250 ms keeps margin under that.
    ///
    /// Do not raise it to "make the wait more reliable": every millisecond added is
    /// borrowed from the only thing that makes the feature work, and a return that never
    /// happens is a worse failure than a dictation missing its first syllable. If a
    /// capture keeps showing `recState=idle waitedMs=250`, the answer is not a longer
    /// ceiling — it is that the engine cannot start inside the window at all, and the fix
    /// moves to starting it sooner rather than waiting for it longer.
    ///
    /// Note the ceiling is not the elapsed time: `asyncAfter` is a floor, not a deadline,
    /// and a simulator under load turned 250 into a measured `waitedMs=305`. The return
    /// still succeeded at 305 ms, which is mild evidence the foreground window is more
    /// forgiving than the ~300 ms figure — but not evidence to spend, and `waitedMs=` is
    /// on the line precisely so the real distribution can be read instead of assumed.
    private static let recordingWaitCeilingMs = 250

    private func returnToHostApp(hostId: String?, coordinator: DictationCoordinator) {
        guard let hostId else {
            PersistentLog.log(.hostReturn(hostId: "unknown", outcome: "table-miss"))
            return
        }
        guard let target = KnownAppSchemes.returnURL(forHostId: hostId) else {
            // `isWorthReporting` keeps the system pseudo-hosts — the in-app browser, the
            // share-sheet composer, Spotlight — out of the log. They are dead ends, not
            // gaps in the catalogue, and reporting them at every triage pass costs
            // attention forever.
            let outcome = KnownAppSchemes.isWorthReporting(hostId) ? "no-scheme" : "no-scheme-known"
            PersistentLog.log(.hostReturn(hostId: hostId, outcome: outcome))
            return
        }

        let startedAt = Date()
        var readyCancellable: AnyCancellable?
        var hasOpened = false

        // Both paths funnel here, and the first one to arrive wins. Whichever it is, the
        // subscription is torn down — which is also what breaks the reference cycle that
        // keeps it alive in the meantime, since nothing else holds it.
        func openNow() {
            guard !hasOpened else { return }
            hasOpened = true
            readyCancellable?.cancel()
            readyCancellable = nil

            let waitedMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            let stateAtOpen = coordinator.status.rawValue
            UIApplication.shared.open(target, options: [:]) { opened in
                PersistentLog.log(.hostReturn(
                    hostId: hostId,
                    outcome: (opened ? "returned" : "open-failed")
                        + " recState=\(stateAtOpen) waitedMs=\(waitedMs)"
                ))
            }
        }

        // The coordinator already publishes its status, so the wait rides that rather
        // than a timer. Deliberate: a run-loop `Timer` with `target: self` outlives what
        // scheduled it and goes on firing, which is how #390 deleted text after the
        // finger had left the key and what #416 still does. `@Published` replays its
        // current value on subscribe, so a recording that is already running opens
        // immediately instead of waiting for a transition that has been and gone.
        readyCancellable = coordinator.$status
            .first { $0 == .recording }
            .receive(on: DispatchQueue.main)
            .sink { _ in openNow() }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Self.recordingWaitCeilingMs)) {
            openNow()
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "dictus" else { return }

        // Temporary diagnostic: log all URL components for cold start investigation.
        // This captures what information IS available from the URL itself (host, query params).
        // Combined with AppDelegate.sourceApplication logging, this lets us confirm empirically
        // that iOS provides no way to identify the keyboard's host app from a URL open.
        let diagComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        PersistentLog.log(.diagnosticProbe(
            component: "sourceApp", instanceID: "0",
            action: "urlComponents",
            details: "host=\(url.host ?? "nil") query=\(diagComponents?.queryItems?.map { "\($0.name)=\($0.value ?? "nil")" }.joined(separator: ",") ?? "none")"
        ))

        switch url.host {
        case "dictate":
            // Single source of truth for what the keyboard is asking (issue #264).
            let keyboardIntent = KeyboardDictationURL.intent(from: url)
            let isFromKeyboard = keyboardIntent != nil

            if keyboardIntent == .prepare {
                DictusLogger.app.info("Keyboard requested model preparation without recording")
                PersistentLog.log(.dictationDeferred(reason: "keyboard prepare-only URL"))
                NotificationCenter.default.post(
                    name: .dictusKeyboardPreparationRequested,
                    object: nil
                )
                return
            }

            // Show cold start overlay when:
            // 1. TRUE cold start: app was terminated by iOS and keyboard just launched it
            // 2. Engine-dead restart: app is in memory but audio engine was stopped
            //    (e.g., Power button in Dynamic Island). Functionally a cold start because
            //    the app must come to foreground to restart the engine.
            let isColdStart = isFromKeyboard && !Self.hasBeenActive
            let isEngineDeadRestart = isFromKeyboard && Self.hasBeenActive
                && !DictationCoordinator.shared.isEngineRunning

            PersistentLog.log(.coldStartURLReceived(
                isColdStart: isColdStart,
                isEngineDead: isEngineDeadRestart,
                hasBeenActive: Self.hasBeenActive
            ))

            if isColdStart || isEngineDeadRestart {
                let reason = isColdStart ? "first launch" : "engine dead"
                DictusLogger.app.info("Cold/engine-dead start from keyboard (\(reason, privacy: .public)) — showing swipe-back overlay")
                AppGroup.defaults.set(true, forKey: SharedKeys.coldStartActive)
                AppGroup.defaults.synchronize()
                PersistentLog.log(.coldStartFlagSet(active: true, context: reason))
            } else if isFromKeyboard {
                DictusLogger.app.info("Warm start dictation from keyboard — skipping overlay")
            }

            Self.hasBeenActive = true
            // `dictate` is not only the keyboard's URL. `KeyboardDictationURL.intent`
            // returns nil for the widget's `dictus://dictate`, which carries no
            // `source=keyboard`, and that dictation completes in the app like any
            // other. Handing it off would write a hand-off record no keyboard is there
            // to claim, and the result would wait out the watchdog unpolished.
            coordinator.startDictation(
                fromURL: true,
                origin: isFromKeyboard ? .keyboard : .app
            )

            // #23: send the user back to the app they were typing in.
            //
            // Only on a cold start. A warm start never took the foreground away, so
            // there is nothing to give back, and opening the host app then would yank a
            // user who is deliberately looking at Dictus.
            //
            // Ordered after `startDictation` on purpose: recording has to be running
            // before the foreground goes away, because the user arrives back in the host
            // app expecting to already be recording, and `open()` only reports failure
            // once it has already tried. Waiting for its answer would cost the head of
            // the recording for no information.
            //
            // Every failure below falls through to `SwipeBackOverlayView`, which is
            // already on screen at this point and stays the floor: unresolved host, host
            // with no known scheme, and `open()` returning false all land there.
            if isColdStart, isFromKeyboard {
                returnToHostApp(hostId: KeyboardDictationURL.hostId(from: url), coordinator: coordinator)
            }
        case "stop":
            // Stop recording from Dynamic Island expanded view button.
            coordinator.stopDictation()
        default:
            break
        }
    }
}

extension ScenePhase {
    /// This phase as the App Group marker the keyboard extension reads (#281).
    ///
    /// `ScenePhase` is a SwiftUI type and the keyboard has no business linking SwiftUI
    /// for a log field, so the crossing happens here, on the app side, and only the
    /// `String` raw value travels between the processes.
    var sceneMarker: AppScenePhaseMarker {
        switch self {
        case .active: return .active
        case .inactive: return .inactive
        case .background: return .background
        // A phase SwiftUI adds after this was written is reported honestly rather
        // than guessed at: the probe's value comes from being trustworthy.
        @unknown default: return .unknown
        }
    }
}

extension Notification.Name {
    /// Posted by `DictationCoordinator.setModelLoadState` whenever the persisted
    /// `SharedKeys.modelLoadState` changes. UI overlays observe this to dismiss
    /// themselves once the model is `.ready` (issue #144).
    static let dictusModelLoadStateChanged = Notification.Name("DictusModelLoadStateChanged")

    /// Posted when the keyboard opens Dictus only to prepare a model before a
    /// later, explicit microphone tap (issue #262).
    static let dictusKeyboardPreparationRequested = Notification.Name(
        "DictusKeyboardPreparationRequested"
    )

    /// Posted by a `ModelManager` whenever a model's preparation state or download
    /// progress changes, so the other instance in this process draws the same thing
    /// (issue #449). Process-local: `MainTabView` builds one `ModelManager` and
    /// onboarding's `ModelDownloadPage` builds another, and after a relaunch the
    /// download is resumed by whichever of them was created first.
    static let dictusModelPreparationChanged = Notification.Name(
        "DictusModelPreparationChanged"
    )
}
