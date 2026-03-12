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
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        PersistentLog.log(.appLaunched(version: version))

        let result = AppGroupDiagnostic.run()
        DictusLogger.app.info(
            "AppGroup diagnostic: healthy=\(result.isHealthy)"
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
                        // Clear cold start state to prevent stale overlay on next normal launch.
                        // WHY here: When the user leaves the app (swipes away, switches app),
                        // the cold start flow is over. Next time the app opens normally,
                        // MainTabView should show regular tabs, not the swipe-back placeholder.
                        AppGroup.defaults.set(false, forKey: SharedKeys.coldStartActive)
                        AppGroup.defaults.removeObject(forKey: SharedKeys.sourceAppScheme)
                        AppGroup.defaults.synchronize()
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

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "dictus" else { return }

        switch url.host {
        case "dictate":
            // Detect cold start mode: the keyboard appends ?source=keyboard to signal
            // it opened the app for dictation. This flag drives MainTabView's conditional
            // rendering (swipe-back placeholder vs normal tabs).
            let isFromKeyboard = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "source" })?
                .value == "keyboard"

            if isFromKeyboard {
                DictusLogger.app.info("Cold start dictation requested from keyboard")
                AppGroup.defaults.set(true, forKey: SharedKeys.coldStartActive)
                AppGroup.defaults.synchronize()
            }

            coordinator.startDictation(fromURL: true)
        default:
            break
        }
    }
}
