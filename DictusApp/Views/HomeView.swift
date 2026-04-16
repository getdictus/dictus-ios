// DictusApp/Views/HomeView.swift
// Home dashboard showing model status, last transcription, and test dictation link.
import SwiftUI
import UIKit
import DictusCore

/// Home tab dashboard — the first screen users see after onboarding.
///
/// WHY a dedicated HomeView instead of reusing ContentView:
/// ContentView combined navigation, diagnostics, and model prompts in one view.
/// HomeView is focused: it's a dashboard showing current status and quick actions.
/// Diagnostics move to Settings (Plan 04-02), model management is its own tab.
struct HomeView: View {
    @EnvironmentObject var coordinator: DictationCoordinator
    @ObservedObject var modelManager: ModelManager
    @State private var showCopiedFeedback = false
    /// Bumped on scene-active to force `recoverableTranscription` to re-read
    /// the App Group fallback. SwiftUI caches computed-property output against
    /// observable dependencies; without a bumpable state this property would
    /// only re-evaluate when `coordinator.lastResult` changes.
    @State private var appGroupRefreshTrigger = 0

    /// Read active model name from App Group for display.
    private var activeModelName: String? {
        AppGroup.defaults.string(forKey: SharedKeys.activeModel)
    }

    /// Prefer in-memory coordinator.lastResult; fall back to App Group SharedKeys.lastTranscription
    /// when coordinator was discarded (cold scene) or its lastResult was cleared by a subsequent
    /// dictation start. Honors the same 300s staleness window as DictationCoordinator's init-time
    /// purge (DictationCoordinator.swift:97-102) so we never show content older than ~5 minutes.
    ///
    /// WHY: When the keyboard's loud-fail UX tells the user "Find your transcription in Dictus,"
    /// the card must be visible on the home screen even if the DictationCoordinator instance
    /// no longer holds lastResult in memory. The App Group read is the recovery surface.
    ///
    /// The `_ = appGroupRefreshTrigger` read below ensures SwiftUI re-evaluates this property
    /// whenever we bump the trigger on scene-active — otherwise the computed property is cached
    /// against coordinator.lastResult only.
    private var recoverableTranscription: String? {
        _ = appGroupRefreshTrigger  // dependency to force re-evaluation on scene-active
        if let inMemory = coordinator.lastResult, !inMemory.isEmpty {
            return inMemory
        }
        guard let text = AppGroup.defaults.string(forKey: SharedKeys.lastTranscription),
              !text.isEmpty,
              let ts = AppGroup.defaults.object(forKey: SharedKeys.lastTranscriptionTimestamp) as? Double,
              Date().timeIntervalSince1970 - ts < 300 else {
            return nil
        }
        return text
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo mark
            logoSection

            // Model status card
            modelStatusCard

            // Last transcription preview — reads recoverableTranscription so the card
            // stays visible as the recovery surface even when coordinator.lastResult
            // is nil (cold scene / coordinator discarded after keyboard loud-fail).
            if let result = recoverableTranscription {
                transcriptionCard(result: result)
            }

            // Test dictation button
            if modelManager.isModelReady {
                testDictationLink
            }

            Spacer()
        }
        .padding()
        .background(Color.dictusBackground.ignoresSafeArea())
        .onAppear {
            // Refresh model state every time HomeView appears.
            modelManager.loadState()
            // Force recoverableTranscription to re-read the App Group fallback.
            // onAppear fires when the view first mounts; bumping here covers the
            // initial render after cold launch (scene-active may fire before or
            // after onAppear depending on launch path).
            appGroupRefreshTrigger &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DictusOnboardingCompleted"))) { _ in
            // WHY onReceive in addition to onAppear:
            // HomeView mounts behind the onboarding fullScreenCover, so onAppear fires
            // before the model is downloaded. When onboarding completes and dismisses
            // the cover, onAppear does NOT re-fire. This notification-based refresh
            // ensures HomeView shows the correct model state immediately.
            modelManager.loadState()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // WHY: When the user returns to DictusApp from the keyboard host app after a
            // silent insertion failure, we need to re-read SharedKeys.lastTranscription
            // from App Group. onAppear does NOT re-fire if HomeView is already the active
            // tab — only scene activation does. Bumping the trigger forces
            // recoverableTranscription to re-evaluate so the recovery card appears
            // without requiring the user to tap anywhere.
            appGroupRefreshTrigger &+= 1
        }
    }

    // MARK: - Logo Section

    /// Static 3-bar brand logo at the top of the home screen.
    private var logoSection: some View {
        VStack(spacing: 8) {
            DictusLogo(height: 60)
                .padding(.top, 8)
            Text("Dictus")
                .font(.dictusHeading)
                .foregroundColor(.dictusAccent)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Model Status Card

    /// Shows active model name and ready status, or prompts to download.
    ///
    /// WHY a prominent card for "no model" state:
    /// First-time users need clear guidance. Without a model, the app can't transcribe.
    /// The card makes the first required action obvious (navigate to Models tab).
    private var modelStatusCard: some View {
        Group {
            if modelManager.isModelReady, let modelName = activeModelName {
                // Active model display using ModelInfo for human-readable name/size.
                // WHY ModelInfo.forIdentifier: The raw identifier (e.g. "openai_whisper-small")
                // is not user-friendly. ModelInfo maps it to "Small" + "~250 MB".
                HStack {
                    let info = ModelInfo.forIdentifier(modelName)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active model")
                            .font(.dictusCaption)
                            .foregroundColor(.secondary)
                        Text(info?.displayName ?? modelName)
                            .font(.dictusSubheading)
                        if let size = info?.sizeLabel {
                            Text(size)
                                .font(.dictusCaption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.dictusSuccess)
                }
                .padding()
                .dictusGlass()
            } else {
                // No model — prompt to download
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.dictusAccent)
                    Text("Download a model to get started")
                        .font(.dictusSubheading)
                        .multilineTextAlignment(.center)
                    Text("Go to the Models tab to download your first transcription model.")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .dictusGlass()
            }
        }
    }

    // MARK: - Last Transcription Card

    /// Shows the most recent transcription result in a tappable glass card.
    /// Tap to copy to clipboard (same behavior as RecordingView result).
    private func transcriptionCard(result: String) -> some View {
        Button {
            UIPasteboard.general.string = result
            HapticFeedback.recordingStopped()
            showCopiedFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showCopiedFeedback = false
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(showCopiedFeedback ? "Copied!" : "Last transcription")
                        .font(.dictusCaption)
                        .foregroundColor(showCopiedFeedback ? .dictusSuccess : .secondary)
                        .animation(.easeOut(duration: 0.2), value: showCopiedFeedback)
                    Spacer()
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                Text(result)
                    .font(.dictusBody)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .dictusGlass()
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.97))
    }

    // MARK: - Test Dictation Link

    /// Prominent button to test dictation. Only shown when a model is ready.
    ///
    /// WHY a Button instead of NavigationLink to TestDictationView:
    /// NavigationLink pushes TestDictationView inside the NavigationStack. Meanwhile,
    /// MainTabView shows a RecordingView overlay when coordinator.status != .idle.
    /// This creates TWO stacked RecordingViews. When the overlay dismisses (status → idle),
    /// the pushed TestDictationView is still there with its nav bar visible.
    /// A Button just starts dictation — the MainTabView overlay handles the full UI.
    private var testDictationLink: some View {
        Button {
            coordinator.startDictation()
        } label: {
            HStack {
                Image(systemName: "waveform")
                Text("New dictation")
                    .font(.dictusBody)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.dictusAccent)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(GlassPressStyle())
    }
}

#Preview {
    NavigationStack {
        HomeView(modelManager: ModelManager())
            .environmentObject(DictationCoordinator.shared)
    }
}
