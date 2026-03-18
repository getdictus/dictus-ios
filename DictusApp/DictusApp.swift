// DictusApp/DictusApp.swift
import SwiftUI
import DictusCore

@main
struct DictusApp: App {
    @StateObject private var coordinator = DictationCoordinator.shared

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

        // Clean up any Live Activities left over from a previous app session.
        // WHY in init: If the app crashed or was force-quit, the Dynamic Island
        // keeps showing stale data for up to 8 hours. Cleaning up here ensures
        // a fresh start.
        LiveActivityManager.shared.cleanupStaleActivities()

        let result = AppGroupDiagnostic.run()
        DictusLogger.app.info(
            "AppGroup diagnostic: healthy=\(result.isHealthy, privacy: .public)"
        )

        // Persist language default so TranscriptionService always reads "fr"
        // even before user visits Settings. @AppStorage defaults are in-memory only
        // and never written to UserDefaults until the Picker is interacted with.
        // WHY `if nil` check: Only write if the key doesn't exist yet. If user already
        // set a language preference (e.g., "en"), don't overwrite it.
        let defaults = UserDefaults(suiteName: AppGroup.identifier)
        if defaults?.string(forKey: SharedKeys.language) == nil {
            defaults?.set("fr", forKey: SharedKeys.language)
        }
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(coordinator)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        PersistentLog.log(.appDidBecomeActive)
                    case .inactive:
                        PersistentLog.log(.appWillResignActive)
                    case .background:
                        PersistentLog.log(.appDidEnterBackground)

                        let isRecordingActive = coordinator.status == .recording
                            || coordinator.status == .requested
                            || coordinator.status == .transcribing

                        // Only clear cold start state if NOT recording.
                        // During cold start, the app transitions to background while recording
                        // continues. Clearing the flag here kills the keyboard's watchdog grace period
                        // and freezes the keyboard UI. The flag is cleared later in
                        // DictationCoordinator.cleanupRecordingKeys() when the recording finishes.
                        if !isRecordingActive {
                            AppGroup.defaults.set(false, forKey: SharedKeys.coldStartActive)
                            AppGroup.defaults.removeObject(forKey: SharedKeys.sourceAppScheme)
                            AppGroup.defaults.synchronize()
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
                }
        }
    }

    /// In-memory flag: true after the app has handled its first URL or become active.
    /// Resets naturally when iOS terminates the process (true cold start).
    /// WHY static: @State/@StateObject reset on view recreation, but a static var persists
    /// for the entire process lifetime — exactly matching "app was killed vs still in memory".
    private static var hasBeenActive = false

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "dictus" else { return }

        switch url.host {
        case "dictate":
            let isFromKeyboard = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "source" })?
                .value == "keyboard"

            // Show cold start overlay when:
            // 1. TRUE cold start: app was terminated by iOS and keyboard just launched it
            // 2. Engine-dead restart: app is in memory but audio engine was stopped
            //    (e.g., Power button in Dynamic Island). Functionally a cold start because
            //    the app must come to foreground to restart the engine.
            let isColdStart = isFromKeyboard && !Self.hasBeenActive
            let isEngineDeadRestart = isFromKeyboard && Self.hasBeenActive
                && !DictationCoordinator.shared.isEngineRunning

            if isColdStart || isEngineDeadRestart {
                let reason = isColdStart ? "first launch" : "engine dead"
                DictusLogger.app.info("Cold/engine-dead start from keyboard (\(reason, privacy: .public)) — showing swipe-back overlay")
                AppGroup.defaults.set(true, forKey: SharedKeys.coldStartActive)
                AppGroup.defaults.synchronize()
            } else if isFromKeyboard {
                DictusLogger.app.info("Warm start dictation from keyboard — skipping overlay")
            }

            Self.hasBeenActive = true
            coordinator.startDictation(fromURL: true)

            // On cold start, the swipe-back overlay (Plan 02) guides the user back.
            // Auto-return was removed because there's no public API to detect which app
            // the keyboard is serving — iterating KnownAppSchemes always opened the first
            // installed app (e.g., WhatsApp) regardless of where the user actually was.
        case "stop":
            // Stop recording from Dynamic Island expanded view button.
            coordinator.stopDictation()
        default:
            break
        }
    }
}
