// DictusApp/Views/HomeView.swift
// Home dashboard showing model status, last transcription, and the new-dictation mic.
import SwiftUI
import DictusCore

/// Home tab dashboard — the first screen users see after onboarding.
///
/// WHY a dedicated HomeView instead of reusing ContentView:
/// ContentView combined navigation, diagnostics, and model prompts in one view.
/// HomeView is focused: it's a dashboard showing current status and quick actions.
/// Diagnostics move to Settings (Plan 04-02), model management is its own tab.
struct HomeView: View {
    @EnvironmentObject var coordinator: DictationCoordinator
    @EnvironmentObject var proStatus: ProStatusManager
    @EnvironmentObject var history: TranscriptionHistoryStore
    @ObservedObject var modelManager: ModelManager

    /// Raises the model preparation screen when a tap arrives during a load (#484).
    @Environment(\.presentModelPreparation) private var presentModelPreparation

    @State private var showCopiedFeedback = false

    /// Drives the history sheet (#70).
    @State private var showHistory = false

    /// Drives the Dictus Pro hub: from the Pro banner, or when a non-subscriber
    /// reaches for the history. One cover on a view that never leaves the screen (#216).
    @State private var showPaywall = false

    /// What the home mic says about Smart Modes: whether the surface is offered, and
    /// which mode the next dictation runs (#489). A copy of the App Group, refreshed by
    /// `refreshSmartMode()` rather than read per body evaluation, because the keyboard
    /// writes it from another process and nothing publishes that write.
    @State private var smartModeMic = SmartModeHomeMic(isOffered: false, effectiveMode: nil)

    /// The open picker, or nil when it is closed (#489).
    @State private var smartModePicker: SmartModeHomePicker?

    /// The mic's frame in the dashboard's coordinate space, which is where the picker
    /// anchors its rows.
    @State private var micFrame: CGRect = .zero

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Observed so a Smart Mode switch flipped in the Pro hub moves the badge and the
    /// chip on the way back here: the switch writes the App Group, which publishes nothing.
    @ObservedObject private var switches = ProFeatureSwitches.shared

    private static let dashboardSpace = "home.dashboard"

    /// What the history offers this user (#70, corrected 2026-08-28): the feature is
    /// Pro, so the hint and the gesture are open, locked, or absent.
    ///
    /// Recomputed on every body evaluation rather than stored, and read through
    /// `proStatus.isProActive` first so SwiftUI actually re-renders: `FeatureGate`
    /// goes straight to the App Group, which publishes nothing. Without touching the
    /// observed object here, a subscription that arrived or lapsed while this screen
    /// was on show would not move the hint until something else redrew it.
    private var entryPoint: HistoryEntryPoint {
        _ = proStatus.isProActive
        return HistoryAvailability.entryPoint
    }

    /// How far up the finger has to travel before the history opens.
    ///
    /// WHY 60pt and not the 20pt that would already register as a drag: this gesture
    /// sits over the whole dashboard, including two buttons and a card. A short flick
    /// while reaching for one of them must not open another screen.
    private let swipeUpThreshold: CGFloat = 60

    /// Read active model name from App Group for display.
    private var activeModelName: String? {
        AppGroup.defaults.string(forKey: SharedKeys.activeModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            // The cards scroll only when they do not fit: a short screen (iPhone SE, or
            // the iPhone layout an iPad runs in), a last transcription, a large Dynamic
            // Type. Since #788 the mic below is 92 pt tall with its halo, and without
            // this the cards pushed it and the history hint under the tab bar.
            //
            // WHY `ViewThatFits` and not a permanent ScrollView: a scroll view takes
            // every vertical drag that starts on it, which would take the swipe up to
            // the history (#70) away from most of the screen. Here it exists only on
            // the screens that need it, and there the mic and the hint below it,
            // which stay outside, are still where the swipe starts.
            ViewThatFits(in: .vertical) {
                // Centred in the space above the mic. A frame and not a `Spacer` on
                // each side: two collapsed spacers in a 24 pt stack still cost 64 pt,
                // which is what tipped an iPhone SE height into scrolling.
                dashboardCards
                    .frame(maxHeight: .infinity)
                ScrollView {
                    dashboardCards
                }
            }

            // The primary action, a round mic since #788. At the bottom of the content
            // rather than among the cards: it is within thumb reach, it stays put when
            // the last-transcription card comes and goes, and it sits where the
            // recording screen's own mic sits.
            if modelManager.isModelReady {
                micRow
            }

            // The affordance for the history (#70), last so it sits at the bottom
            // edge the swipe starts from. Absent entirely on `.hidden`: while the
            // paywall is unreachable the app must look like there is no subscription
            // at all (#236), and a lock leading nowhere is the one place that would
            // break it.
            switch entryPoint {
            case .open:
                SwipeUpHintView { showHistory = true }
            case .locked:
                SwipeUpHintView(isLocked: true) { showPaywall = true }
            case .hidden:
                EmptyView()
            }
        }
        .padding()
        .background(Color.dictusBackground.ignoresSafeArea())
        .coordinateSpace(.named(Self.dashboardSpace))
        // The Smart Mode picker (#489), over the dashboard and under nothing: it is the
        // one thing on screen while it is open, and a tap anywhere else closes it.
        .overlay {
            if let picker = smartModePicker {
                smartModePickerOverlay(picker)
            }
        }
        // The swipe itself. Attached to the whole dashboard rather than to the hint,
        // because the issue asks for a swipe up "from the home screen" — the hint
        // says where, it is not the only place the gesture is allowed to start.
        //
        // `.gesture` and not `.simultaneousGesture`: a simultaneous drag would fire
        // alongside the buttons underneath instead of losing to their taps, which is
        // exactly backwards. With `minimumDistance` set, a tap never reaches here.
        //
        // Installed only when the gesture leads somewhere. On `.hidden` there is no
        // gesture at all, so nothing on this screen behaves differently for someone
        // who has never heard of the feature; on `.locked` the same swipe opens the
        // paywall, because a user who performed the gesture has asked for the thing.
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    // The predicted end is what makes a fast flick work: the finger
                    // may lift after 30pt while still travelling. Either the actual
                    // or the predicted travel clearing the threshold opens the sheet.
                    let travelled = min(value.translation.height, value.predictedEndTranslation.height)
                    guard travelled < -swipeUpThreshold else { return }
                    if entryPoint == .open {
                        showHistory = true
                    } else {
                        showPaywall = true
                    }
                },
            // `.none` rather than an optional gesture: `gesture(_:)` takes a
            // concrete `Gesture`, and the mask is the API's own way to say "declared
            // but not receiving". On `.hidden` no touch on this screen reaches the
            // drag at all.
            //
            // Off as well while the Smart Mode picker is open (#489): a swipe on its dim
            // is a dismissal at most, never a second screen opening under the menu.
            including: entryPoint == .hidden || smartModePicker != nil ? .none : .all
        )
        .sheet(isPresented: $showHistory) {
            // A sheet is the vertical transition the issue asks for, and it brings
            // the swipe-down back to the home screen with it. See HistoryView.
            //
            // The store is handed over explicitly rather than left to the ambient
            // environment: a sheet is presented from a different part of the view
            // tree, and an `@EnvironmentObject` that resolves today because the root
            // happens to publish it is a crash waiting for someone to move it.
            HistoryView()
                .environmentObject(history)
                .environmentObject(proStatus)
        }
        .paywallCover(isPresented: $showPaywall)
        .onAppear {
            // Refresh model state every time HomeView appears.
            modelManager.loadState()
            refreshSmartMode()
        }
        // The keyboard arms modes from another app, so the change lands while this
        // screen is in the background. Coming back to the foreground is when the badge
        // has to catch up — the keyboard does the same on every appearance
        // (`KeyboardState.refreshFromDefaults`), which is what makes the two agree.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSmartMode() }
        }
        .onChange(of: proStatus.isProActive) { _, _ in refreshSmartMode() }
        .onChange(of: switches.values) { _, _ in refreshSmartMode() }
        // A picker left open behind another tab would come back stale.
        .onDisappear { smartModePicker = nil }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DictusOnboardingCompleted"))) { _ in
            // WHY onReceive in addition to onAppear:
            // HomeView mounts behind the onboarding fullScreenCover, so onAppear fires
            // before the model is downloaded. When onboarding completes and dismisses
            // the cover, onAppear does NOT re-fire. This notification-based refresh
            // ensures HomeView shows the correct model state immediately.
            modelManager.loadState()
        }
    }

    // MARK: - Dashboard Cards

    /// Logo, model, last transcription and Pro card.
    private var dashboardCards: some View {
        VStack(spacing: 24) {
            // Logo mark
            logoSection

            // Model status card
            modelStatusCard

            // Last transcription preview
            if let result = coordinator.lastResult {
                transcriptionCard(result: result)
            }

            // The Home Pro card: the offer, the trial reminder, or since #216 decision
            // 16 a subscriber's way into the hub. Gated behind
            // PremiumFlags.paywallVisible until the first Pro
            // feature ships and ASC setup is done (#236, #79, #215).
            if PremiumFlags.paywallVisible {
                ProBannerView { showPaywall = true }
            }
        }
    }

    // MARK: - Logo Section

    /// Static 3-bar brand logo at the top of the home screen.
    /// Subscribers see the Dictus Pro gradient wordmark from the paywall hero,
    /// a quiet permanent reminder of what they unlocked.
    private var logoSection: some View {
        VStack(spacing: 8) {
            DictusLogo(height: 60)
                .padding(.top, 8)
            if proStatus.isProActive {
                Text("Dictus Pro")
                    .font(.dictusHeading)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.dictusGradientStart, .dictusGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                // During the reverse trial, the one indicator it gets on this screen
                // (#593): discreet, never a nag, and honest about the wordmark above
                // it, which would otherwise read as a subscription.
                if let daysLeft = proStatus.trialBadgeDaysLeft {
                    ProTrialBadge(daysLeft: daysLeft)
                }
            } else {
                Text("Dictus")
                    .font(.dictusHeading)
                    .foregroundColor(.dictusAccent)
            }
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
                        Text(info?.localizedDisplayName ?? modelName)
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

    // MARK: - New Dictation Button

    /// The mic, centred, with the Smart Mode chip beside it (#489).
    ///
    /// The chip sits in the same row rather than under the mic so the row costs no
    /// height: #788 had to win back 64 pt to keep the history hint above the tab bar on
    /// an iPhone SE height, and a line under the mic would give it back. The two sides
    /// take equal widths, so the mic stays on the screen's centre line whatever the chip
    /// says.
    private var micRow: some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(height: 1)
                .frame(maxWidth: .infinity)
            newDictationButton
            Group {
                if smartModeMic.isOffered {
                    HomeSmartModeChip(mode: smartModeMic.effectiveMode) { openSmartModePicker() }
                } else {
                    Color.clear.frame(height: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The round mic that starts a dictation. Only shown when a model is ready.
    ///
    /// WHY `AnimatedMicButton` (#788): the onboarding and the recording screen already
    /// draw their mic with it, so the home action is the same object the user taps on
    /// the next screen. Its status is pinned to `.idle`: as soon as a dictation starts,
    /// MainTabView covers this screen with the recording overlay, which carries the
    /// live states.
    ///
    /// The armed Smart Mode (#489) rides on it as the keyboard pill's own badge — the
    /// mode's glyph, or a translation's target code — and only when the next dictation
    /// will actually run it. Normal is a plain mic.
    ///
    /// WHY a button that starts dictation instead of a NavigationLink to TestDictationView:
    /// NavigationLink pushes TestDictationView inside the NavigationStack. Meanwhile,
    /// MainTabView shows a RecordingView overlay when coordinator.status != .idle.
    /// This creates TWO stacked RecordingViews. When the overlay dismisses (status → idle),
    /// the pushed TestDictationView is still there with its nav bar visible.
    /// A Button just starts dictation — the MainTabView overlay handles the full UI.
    private var newDictationButton: some View {
        AnimatedMicButton(status: .idle, badge: smartModeMic.effectiveMode?.badge) {
            // The release of a long press that opened the picker still arrives here as a
            // tap. The picker being open is what says so, and it must not also start a
            // recording: the user asked for the menu, not for the mic.
            guard smartModePicker == nil else { return }
            // A tap that lands during a model load gets the preparation screen instead of
            // being swallowed by `startDictation`'s guard (#484). The button stays live and
            // keeps its shape: `isModelReady` above says a model is on disk and elected, which
            // is a different question from whether one is loading right now.
            switch coordinator.recordTapDecision {
            case .presentPreparation:
                presentModelPreparation()
            case .startDictation:
                coordinator.startDictation(origin: .app)
            }
        }
        // The long press is the keyboard fan's gesture, at the fan's 0.35 s. Simultaneous
        // rather than high-priority so a plain tap pays no delay, the fan's own reasoning
        // (`ToolbarView.micPill`). It does not compete with the dashboard's swipe to the
        // history: that drag needs 20 pt of travel, and a long press is a finger at rest.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in openSmartModePicker() },
            including: smartModeMic.isOffered ? .all : .none
        )
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.dashboardSpace))
        } action: { frame in
            micFrame = frame
        }
        // The visible label went with the rectangle; VoiceOver keeps it, and hears the
        // mode the dictation will run as the value (#397's missing half, on this mic).
        .accessibilityLabel("New dictation")
        .accessibilityValue(smartModeMic.isOffered
                            ? Text(HomeSmartModePicker.spokenName(of: smartModeMic.effectiveMode))
                            : Text(verbatim: ""))
        // The picker without the long press, which VoiceOver takes for itself.
        .accessibilityActions {
            if smartModeMic.isOffered {
                Button("Choose a Smart Mode") { openSmartModePicker() }
            }
        }
        .accessibilityIdentifier("home.newDictation")
        // The recording screen draws its own button at this height, so tapping here
        // shows no jump (#788).
        .reportsPrimaryMicAnchor()
    }

    // MARK: - Smart Mode Picker

    /// The dimmed dashboard and the picker's rows, anchored just above the mic.
    private func smartModePickerOverlay(_ picker: SmartModeHomePicker) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // A dim in the background colour, so the rows stand on the screen's own
                // surface in both appearances rather than on a black veil.
                Color.dictusBackground.opacity(0.9)
                    .ignoresSafeArea()
                    .onTapGesture { closeSmartModePicker() }
                    .accessibilityHidden(true)

                HomeSmartModePicker(
                    picker: picker,
                    onChoose: chooseSmartMode,
                    onDismiss: closeSmartModePicker
                )
                .frame(maxWidth: 320)
                .padding(.horizontal)
                // Its bottom edge 8 pt above the top of the mic's halo, so the column
                // rises out of the button the way the fan drops out of the pill.
                .padding(.bottom, max(0, proxy.size.height - micFrame.minY) + 8)
                .transition(reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.92, anchor: .bottom)))
            }
        }
    }

    /// Re-read what the home mic shows from the App Group.
    private func refreshSmartMode() {
        smartModeMic = SmartModeHomeMic.current
    }

    /// Open the picker, from the long press, the chip or VoiceOver's action.
    ///
    /// Resolved at open, as the fan is: armability cannot change between opening the
    /// menu and touching a row, and reading it once keeps `SystemLanguageModel` off the
    /// main thread's per-frame path.
    private func openSmartModePicker() {
        guard smartModePicker == nil, let picker = SmartModeHomePicker.current() else { return }
        // The fan's own haptic on opening (`KeyboardSmartModeState.open`).
        HapticFeedback.keyTapped()
        withAnimation(.easeOut(duration: 0.18)) {
            smartModePicker = picker
        }
        PersistentLog.log(.diagnosticProbe(
            component: "HomeView", instanceID: "-", action: "smartModePickerOpened",
            details: "entries=\(picker.entries.count) armed=\(picker.armedIdentifier ?? "normal")"
        ))
    }

    private func closeSmartModePicker() {
        withAnimation(.easeOut(duration: 0.18)) {
            smartModePicker = nil
        }
    }

    /// Apply a row. Arming changes the setting and nothing else: no recording starts,
    /// unlike the fan's release. Here the mic is one tap away and in sight, and a menu
    /// row that suddenly records would be a surprise; in the keyboard the release *is*
    /// the commitment because the finger is already on the mic.
    private func chooseSmartMode(_ entry: SmartModeFanEntry) {
        guard let picker = smartModePicker else { return }
        let choice = picker.choose(entry)
        switch choice {
        case .refused:
            // The reason is already written above the rows; the haptic says this row
            // is one of the ones it is about. The picker stays open on it.
            HapticFeedback.actionRefused()
            return
        case .openPaywall:
            closeSmartModePicker()
            showPaywall = true
        case .armed, .disarmed:
            HapticFeedback.keyTapped()
            refreshSmartMode()
            closeSmartModePicker()
        }
        PersistentLog.log(.diagnosticProbe(
            component: "HomeView", instanceID: "-", action: "smartModeChosen",
            details: "row=\(entry.id) source=home"
        ))
    }
}

#Preview {
    NavigationStack {
        HomeView(modelManager: ModelManager())
            .environmentObject(DictationCoordinator.shared)
            .environmentObject(ProStatusManager())
            .environmentObject(TranscriptionHistoryStore.shared)
    }
}
