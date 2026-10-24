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

    /// The rows VoiceOver's actions on the mic offer, resolved with `smartModeMic` so a
    /// body evaluation never asks Apple Intelligence anything (#489).
    @State private var smartModeChoices: SmartModeHomePicker?

    /// The open dial: one long press, from the ring opening to the release (#489).
    @State private var ringSession: SmartModeRingSession?

    /// When the last dial closed. The release of a long press can still reach the mic's
    /// button and the dashboard's swipe as a tap and a drag; neither may act on it.
    @State private var ringClosedAt: Date?

    /// Whether the mic's long-press-then-slide gesture is in flight. Resets on its own
    /// when the touch ends or is cancelled, which is how a dial whose drag never began
    /// still closes.
    @GestureState private var ringGestureActive = false

    /// The mic's frame in the dashboard's coordinate space: the drag is measured from
    /// its centre.
    @State private var micFrame: CGRect = .zero

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Observed so a Smart Mode switch flipped in the Pro hub moves the badge and the
    /// mic's face on the way back here: the switch writes the App Group, which publishes nothing.
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
            .homeSmartModeRingDim(ringSession != nil)

            // The primary action, a round mic since #788. At the bottom of the content
            // rather than among the cards: it is within thumb reach, it stays put when
            // the last-transcription card comes and goes, and it sits where the
            // recording screen's own mic sits.
            if modelManager.isModelReady {
                micRow
                    // Above the hint below it, which the dial's line overlaps.
                    .zIndex(1)
            }

            // The affordance for the history (#70), last so it sits at the bottom
            // edge the swipe starts from. Absent entirely on `.hidden`: while the
            // paywall is unreachable the app must look like there is no subscription
            // at all (#236), and a lock leading nowhere is the one place that would
            // break it.
            Group {
                switch entryPoint {
                case .open:
                    SwipeUpHintView { showHistory = true }
                case .locked:
                    SwipeUpHintView(isLocked: true) { showPaywall = true }
                case .hidden:
                    EmptyView()
                }
            }
            // Gone rather than dimmed while the dial's line is drawn over it.
            .opacity(ringSession != nil && HomeSmartModeRingStyle.showsReleaseHint ? 0 : 1)
            .homeSmartModeRingDim(ringSession != nil)
        }
        .padding()
        .background(Color.dictusBackground.ignoresSafeArea())
        .coordinateSpace(.named(Self.dashboardSpace))
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
                    // A finger sliding up from the mic to the dial's Normal sector is
                    // a 60 pt swipe up; it chose a mode, it did not ask for the history.
                    guard !isRingBusy else { return }
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
            // Off as well while the Smart Mode dial is open (#489).
            including: entryPoint == .hidden || ringSession != nil ? .none : .all
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
        // A dial left open behind another tab would come back stale.
        .onDisappear { ringSession = nil }
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

    /// The mic, centred, with the Smart Mode dial's resting hint around it (#489).
    ///
    /// Everything Smart Mode draws here is an overlay or a background on the mic: the
    /// chevrons, the ring, the line under it. None of it owns layout, so the mic is
    /// exactly where #788 put it whatever the dial is doing, and the recording screen,
    /// which lines its own button up on this one, sees no difference.
    private var micRow: some View {
        newDictationButton
            // The ring and the resting hint behind the mic, so the mic draws over both.
            // Outside the button's accessibility modifiers on purpose: inside them, the
            // chevrons inherited the mic's identifier and read as three more mics.
            .background {
                if let ringSession {
                    HomeSmartModeRing(session: ringSession)
                        .transition(reduceMotion
                                    ? .opacity
                                    : .opacity.combined(with: .scale(scale: 0.85)))
                } else if smartModeMic.isOffered {
                    HomeSmartModeRestHint()
                }
            }
            .overlay(alignment: .top) {
                if let ringSession, HomeSmartModeRingStyle.showsReleaseHint {
                    HomeSmartModeRingHint(hint: ringSession.hint)
                        .fixedSize()
                        .offset(y: DictusHalo.size(isPill: false).height + 12)
                }
            }
            .frame(maxWidth: .infinity)
    }

    /// The round mic that starts a dictation. Only shown when a model is ready.
    ///
    /// WHY `AnimatedMicButton` (#788): the onboarding and the recording screen already
    /// draw their mic with it, so the home action is the same object the user taps on
    /// the next screen. Its status is pinned to `.idle`: as soon as a dictation starts,
    /// MainTabView covers this screen with the recording overlay, which carries the
    /// live states.
    ///
    /// The armed Smart Mode (#489) shows on it twice: the mode's glyph in the brand's
    /// deep blue as its face, and the keyboard pill's own corner badge. Both only when
    /// the next dictation will actually run it. Normal is a plain mic.
    ///
    /// WHY a button that starts dictation instead of a NavigationLink to TestDictationView:
    /// NavigationLink pushes TestDictationView inside the NavigationStack. Meanwhile,
    /// MainTabView shows a RecordingView overlay when coordinator.status != .idle.
    /// This creates TWO stacked RecordingViews. When the overlay dismisses (status → idle),
    /// the pushed TestDictationView is still there with its nav bar visible.
    /// A Button just starts dictation — the MainTabView overlay handles the full UI.
    private var newDictationButton: some View {
        AnimatedMicButton(
            status: .idle,
            badge: ringSession == nil ? smartModeMic.effectiveMode?.badge : nil,
            face: micFace
        ) {
            // The release of a long press still arrives here as a tap when the finger
            // lifts on the mic. The dial being open, or having just closed, is what says
            // so, and it must not also start a recording: lifting on the mic is the
            // dial's cancel.
            guard !isRingBusy else { return }
            startDictation()
        }
        // The dial's gesture: hold for the keyboard fan's 0.35 s, then slide. Simultaneous
        // rather than high-priority so a plain tap pays no delay, the fan's own reasoning
        // (`ToolbarView.micPill`). The drag is measured in the dashboard's space so the
        // finger keeps being tracked once it leaves the button.
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .sequenced(before: DragGesture(minimumDistance: 0,
                                               coordinateSpace: .named(Self.dashboardSpace)))
                .updating($ringGestureActive) { value, active, _ in
                    if case .second(true, _) = value { active = true }
                }
                .onChanged { value in
                    guard case .second(true, let drag) = value else { return }
                    if ringSession == nil { openRing() }
                    if let drag { moveRing(to: drag.location) }
                }
                .onEnded { value in
                    guard case .second(true, let drag) = value else { return }
                    if let drag { moveRing(to: drag.location) }
                    releaseRing()
                },
            including: smartModeMic.isOffered ? .all : .none
        )
        // A touch the system cancelled, or a long press lifted before the drag began,
        // never reaches `onEnded`: the gesture state resetting is the one signal left.
        .onChange(of: ringGestureActive) { _, active in
            if !active, ringSession != nil { closeRing(cancelled: true) }
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.dashboardSpace))
        } action: { frame in
            micFrame = frame
        }
        // The visible label went with the rectangle; VoiceOver keeps it, and hears the
        // mode the dictation will run as the value (#397's missing half, on this mic).
        .accessibilityLabel("New dictation")
        .accessibilityValue(smartModeMic.isOffered
                            ? Text(HomeSmartModeCopy.spokenName(of: smartModeMic.effectiveMode))
                            : Text(verbatim: ""))
        // The dial without the gesture, which VoiceOver takes for itself: one action per
        // row that may be chosen. Choosing arms the mode and stops there — the
        // double-tap that follows is the dictation, and VoiceOver reads the new value
        // first, so the user hears what they picked before anything records.
        .accessibilityActions {
            if let choices = smartModeChoices {
                ForEach(choices.entries.filter(choices.canChoose)) { entry in
                    Button(accessibilityActionName(for: entry)) { chooseFromAccessibility(entry) }
                }
            }
        }
        .accessibilityIdentifier("home.newDictation")
        // The recording screen draws its own button at this height, so tapping here
        // shows no jump (#788).
        .reportsPrimaryMicAnchor()
    }

    /// The mic's face: the targeted row's while the dial is open, the armed mode's at
    /// rest, nil for the plain mic.
    private var micFace: AnimatedMicButton.MicFace? {
        if let ringSession {
            return HomeSmartModeCopy.micFace(for: ringSession.micEntry)
        }
        return smartModeMic.effectiveMode.flatMap { HomeSmartModeCopy.micFace(for: .mode($0)) }
    }

    /// A tap on the mic, or a dial released on a mode after arming it.
    private func startDictation() {
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

    // MARK: - Smart Mode Dial

    /// Whether the dial is open or closed so recently that its release is still being
    /// delivered to the mic's tap and the dashboard's swipe.
    private var isRingBusy: Bool {
        if ringSession != nil { return true }
        guard let ringClosedAt else { return false }
        return Date().timeIntervalSince(ringClosedAt) < 0.4
    }

    /// Re-read what the home mic shows from the App Group.
    private func refreshSmartMode() {
        smartModeMic = SmartModeHomeMic.current
        smartModeChoices = smartModeMic.isOffered ? SmartModeHomePicker.current() : nil
    }

    /// Open the dial when the long press completes.
    ///
    /// Resolved at open, as the keyboard fan is: armability cannot change between the
    /// press and the release, and reading it once keeps `SystemLanguageModel` off the
    /// per-frame path of the drag.
    private func openRing() {
        guard let picker = SmartModeHomePicker.current() else { return }
        // The fan's own haptic on opening (`KeyboardSmartModeState.open`).
        HapticFeedback.keyTapped()
        withAnimation(.easeOut(duration: 0.18)) {
            ringSession = SmartModeRingSession(picker: picker)
        }
        PersistentLog.log(.diagnosticProbe(
            component: "HomeView", instanceID: "-", action: "smartModeRingOpened",
            details: "entries=\(picker.entries.count) armed=\(picker.armedIdentifier ?? "normal")"
        ))
    }

    /// Feed the finger's position, in the dashboard's space, to the dial.
    private func moveRing(to location: CGPoint) {
        guard var session = ringSession else { return }
        let point = CGPoint(x: location.x - micFrame.midX, y: location.y - micFrame.midY)
        let cue = session.move(to: point)
        ringSession = session
        if cue == .tick { HapticFeedback.keyTapped() }
    }

    /// Lift the finger: arm and record, open the paywall, refuse, or nothing.
    private func releaseRing() {
        guard let session = ringSession else { return }
        let outcome = session.commit()
        closeRing(cancelled: false)
        switch outcome {
        case .cancel:
            break
        case .refused:
            HapticFeedback.actionRefused()
        case .openPaywall:
            showPaywall = true
        case .record:
            refreshSmartMode()
            startDictation()
        }
        PersistentLog.log(.diagnosticProbe(
            component: "HomeView", instanceID: "-", action: "smartModeRingReleased",
            details: "outcome=\(Self.logName(outcome)) source=home"
        ))
    }

    private func closeRing(cancelled: Bool) {
        ringClosedAt = Date()
        withAnimation(.easeOut(duration: 0.15)) {
            ringSession = nil
        }
        if cancelled {
            PersistentLog.log(.diagnosticProbe(
                component: "HomeView", instanceID: "-", action: "smartModeRingReleased",
                details: "outcome=interrupted source=home"
            ))
        }
    }

    /// VoiceOver's action for `entry`: arm it (Normal disarms), or open the paywall.
    private func chooseFromAccessibility(_ entry: SmartModeFanEntry) {
        guard let picker = SmartModeHomePicker.current() else { return }
        switch picker.choose(entry) {
        case .openPaywall:
            showPaywall = true
        case .armed, .disarmed:
            refreshSmartMode()
        case .refused:
            HapticFeedback.actionRefused()
        }
        PersistentLog.log(.diagnosticProbe(
            component: "HomeView", instanceID: "-", action: "smartModeChosen",
            details: "row=\(entry.id) source=homeAccessibility"
        ))
    }

    private func accessibilityActionName(for entry: SmartModeFanEntry) -> String {
        if case .pro = entry { return String(localized: "Dictus Pro") }
        return String(localized: "Use \(HomeSmartModeCopy.spokenName(of: entry.smartMode))",
                      comment: "VoiceOver action on the Home mic that arms this Smart Mode. The placeholder is the mode's name, or Normal.")
    }

    private static func logName(_ outcome: SmartModeRingRelease) -> String {
        switch outcome {
        case .cancel: return "cancel"
        case .refused: return "refused"
        case .openPaywall: return "paywall"
        case .record(let entry): return "record:\(entry.id)"
        }
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
