// DictusApp/Views/MainTabView.swift
// Root navigation container with 3 tabs and full-screen recording overlay.
import SwiftUI
import DictusCore

/// Root view presenting the 3-tab navigation structure.
///
/// WHY TabView instead of NavigationStack:
/// The app has 3 distinct sections (Home, Models, Settings) that the user should be able
/// to switch between freely. A TabView provides standard iOS navigation for this pattern.
/// Each tab wraps its content in its own NavigationStack so push navigation works
/// independently per tab.
///
/// WHY ZStack overlay for RecordingView:
/// When dictation is active, the recording UI must cover the entire screen INCLUDING
/// the tab bar. A ZStack overlay with ignoresSafeArea achieves this, while a sheet or
/// fullScreenCover would leave the tab bar visible underneath on some iOS versions.
struct MainTabView: View {
    @EnvironmentObject var coordinator: DictationCoordinator
    @StateObject private var modelManager = ModelManager()

    @State private var selectedTab: Int = 0

    /// Tracks whether the app was opened from the keyboard for cold start dictation.
    /// WHY @State instead of reading App Group directly:
    /// SwiftUI needs a reactive property to trigger view updates. onOpenURL sets this
    /// to true when source=keyboard is detected, and scenePhase resets it on background.
    /// The App Group flag (SharedKeys.coldStartActive) persists the value for cross-process
    /// use; this @State drives the local UI.
    @State private var isColdStartMode = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if isColdStartMode {
                // Placeholder for SwipeBackOverlayView (Plan 02 will replace this).
                // Shows a simple gradient + text so we can verify the conditional rendering
                // path works before building the real overlay.
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.13, blue: 0.25),
                                 Color(red: 0.03, green: 0.06, blue: 0.13)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    Text("Swipe back to keyboard")
                        .foregroundColor(.white)
                }
            } else {
                // Main tab navigation (normal launch path)
                TabView(selection: $selectedTab) {
                    // Tab 0: Home dashboard
                    NavigationStack {
                        HomeView(modelManager: modelManager)
                    }
                    .tabItem {
                        Label("Accueil", systemImage: "house.fill")
                    }
                    .tag(0)

                    // Tab 1: Model management
                    NavigationStack {
                        ModelManagerView(modelManager: modelManager)
                    }
                    .tabItem {
                        Label("Modeles", systemImage: "cpu")
                    }
                    .tag(1)

                    // Tab 2: Settings
                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem {
                        Label("Reglages", systemImage: "gearshape.fill")
                    }
                    .tag(2)
                }
                .tint(.dictusAccent)
            }

            // Full-screen recording overlay covers everything including tab bar
            // WHY coordinator.status != .idle:
            // RecordingView handles all non-idle states (requested, recording,
            // transcribing, ready, failed). The ZStack overlay makes it cover the tab bar.
            //
            // WHY .tint on TabView:
            // Uses brand accent color for the selected tab icon/text instead of default blue.
            // On iOS 26, TabView automatically gets Liquid Glass styling -- no manual glass needed.
            if coordinator.status != .idle {
                RecordingView(mode: .standalone)
            }
        }
        // WHY onOpenURL here AND in DictusApp:
        // DictusApp.handleIncomingURL sets the App Group flag for cross-process persistence.
        // MainTabView.onOpenURL drives the local SwiftUI @State for reactive rendering.
        // Both fire on the same URL event — SwiftUI propagates onOpenURL through the view tree.
        .onOpenURL { url in
            if let host = url.host, host == "dictate",
               let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
               query.contains(where: { $0.name == "source" && $0.value == "keyboard" }) {
                isColdStartMode = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                isColdStartMode = false
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(DictationCoordinator.shared)
}
