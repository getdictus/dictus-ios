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
    @EnvironmentObject var trialCoordinator: ProTrialCoordinator
    @EnvironmentObject var proStatus: ProStatusManager
    @StateObject private var modelManager = ModelManager()

    @State private var selectedTab: Int = 0

    /// In-memory flag: true after the first URL has been handled in this process.
    /// Resets naturally when iOS terminates the process (true cold start).
    /// WHY static on MainTabView (not DictusApp): onOpenURL fires inner-to-outer in SwiftUI,
    /// so MainTabView's handler fires BEFORE DictusApp's. We need the detection here.
    private static var hasHandledURL = false

    /// Tracks whether the app was opened from the keyboard for cold start dictation.
    @State private var isColdStartMode: Bool

    /// Active model preparation shown without starting a recording. The overlay dismisses
    /// itself after its contextual ready state.
    ///
    /// Three of its four writers are URL-driven — the keyboard asking for `intent=prepare` —
    /// and the two of those that can fire while the process is already alive are gated on
    /// #458's rule below. `init`'s launch-intent seed is not: a process being launched has no
    /// dictation to interrupt. The fourth is `presentModelPreparation`, an in-app record tap
    /// that landed during a load (#484), which carries its own context and its own gate.
    ///
    /// WHY the model and the context travel together in one value: the overlay's copy is
    /// chosen from the context and names the model, so a context left behind by a previous
    /// presentation would put "Return to your app and tap the microphone again." in front of
    /// a user who never left Dictus. Storing them apart makes that a two-line mistake.
    @State private var preparation: PreparationPresentation?

    /// A preparation screen to show: which model, and why it is up.
    private struct PreparationPresentation: Equatable {
        let modelIdentifier: String
        let context: ModelPreparationContext
    }

    /// The paywall, opened from the keyboard (#404).
    ///
    /// WHY here and not in `SettingsView`, which owns the other two entry points: a
    /// `dictus://open?intent=pro` URL is answered by whichever view is in the tree, and
    /// `SettingsView` only is when the Settings tab is selected. `paywallCover` is
    /// documented as *"one way to open the paywall, shared by every entry point"*, and
    /// a cover presented here covers the tab bar as well, so which tab the user lands
    /// on stops mattering.
    @State private var showsPaywall = false

    /// The steps What's new is playing in place of the tabs (#685), nil when it is not on
    /// screen. Set once per install, by `presentWhatsNewIfDue`.
    @State private var whatsNewSteps: [OnboardingStep]?

    /// Whether a URL opened this activation, which defers What's new to the next one
    /// (`WhatsNew.mayAppear`, #685). Seeded from the launch, set by `.onOpenURL`, cleared
    /// when the app goes to the background.
    @State private var activationOpenedByURL: Bool

    /// The shared voice notes (#620): what the Live Activity link or the cold path
    /// asked to show.
    @ObservedObject private var voiceNotes = VoiceNoteProcessor.shared

    @Environment(\.scenePhase) private var scenePhase

    /// Seeds the presentation state from the URL this process was launched with (issue #264).
    ///
    /// WHY in init rather than in `.onOpenURL`:
    /// SwiftUI evaluates `body` before any URL handler runs, so a cold start decided in
    /// `.onOpenURL` always rendered one frame of the home screen first. `ColdStartLaunch`
    /// reads the launch URL at scene connection, which happens before this view is built,
    /// so the very first frame is already the right one. Every other launch leaves the
    /// intent nil and lands on the tab navigation with nothing added to the path.
    init() {
        let launchIntent = ColdStartLaunch.intent
        // #827: a launch from the keyboard before onboarding is done raises neither
        // screen; onboarding is what the user must see.
        let onboarded = KeyboardOnboardingGate.isOnboardingCompleted()
        _isColdStartMode = State(initialValue: onboarded && launchIntent == .record)
        _preparation = State(
            initialValue: onboarded && launchIntent == .prepare
                ? PreparationPresentation(
                    modelIdentifier: Self.persistedActiveModelIdentifier,
                    context: .keyboardColdStart
                )
                : nil
        )
        // What's new is decided here too, for the same first frame: an existing user's
        // first launch of 2.0.0 from the icon opens on it, not on one frame of Home. Two
        // launches leave it to the activation instead (`presentWhatsNewIfDue`), which runs
        // after the URL handlers:
        // - a launch through any URL (a dictation from the keyboard, the voice note link,
        //   the Pro entry), whose URL is handled after this frame;
        // - a launch in the background (iOS prewarming the process, measured on the
        //   simulator): its URL, if any, is not in the scene's connection options but comes
        //   later through `.onOpenURL`, so this frame cannot know it. Nothing is on screen
        //   in the background, so waiting costs no frame of Home.
        let openedByURL = ColdStartLaunch.carriedURL
        let launchedInForeground = UIApplication.shared.applicationState != .background
        _activationOpenedByURL = State(initialValue: openedByURL)
        _whatsNewSteps = State(
            initialValue: launchedInForeground
                && WhatsNew.mayAppear(displayIsFree: true, activationOpenedByURL: openedByURL)
                ? Self.dueWhatsNewSteps()
                : nil
        )
    }

    /// What's new's steps on this device if it is due and has something to show, nil
    /// otherwise (#685). A device with nothing to show (one that can never run Smart Modes)
    /// was already recorded at launch (`WhatsNew.recordLaunch`); the empty check only makes
    /// sure no path can ever put an empty What's new on screen.
    private static func dueWhatsNewSteps() -> [OnboardingStep]? {
        guard WhatsNew.isDue() else { return nil }
        let steps = WhatsNew.steps(deviceCanRunSmartModes: SmartModeAvailability.deviceIsCapable)
        return steps.isEmpty ? nil : steps
    }

    /// The active model as persisted in the App Group, with the shipped default.
    /// Static so `init` can read it before `modelManager` exists — `ModelManager.init`
    /// loads `activeModel` from the same key, so both paths agree.
    private static var persistedActiveModelIdentifier: String {
        AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? "openai_whisper-small"
    }

    private var activeModelIdentifier: String {
        modelManager.activeModel ?? Self.persistedActiveModelIdentifier
    }

    /// Whether the app may raise one of the reverse trial's own screens (#593).
    ///
    /// Only over the ordinary tab navigation, and only when nothing else owns the
    /// display: a cold-start dictation, a model preparation screen, a recording or a
    /// paywall the user opened. The trial is announced openly, but never by
    /// interrupting a dictation.
    ///
    /// Not while What's new is up either (#685): the existing-user announcement comes
    /// after it, when the tabs come back.
    private var mayRaiseTrialScreens: Bool {
        mayRaiseWhatsNew && whatsNewSteps == nil
    }

    /// Whether nothing owns the display, so What's new may replace the tabs (#685): the
    /// trial screens' own conditions. `presentWhatsNewIfDue` adds what sits on top of the
    /// tabs and would be torn down with them.
    private var mayRaiseWhatsNew: Bool {
        !isColdStartMode && preparation == nil && coordinator.status == .idle && !showsPaywall
    }

    /// Shows What's new if it is due and nothing owns the display (#685). Returns whether
    /// it is on screen, in which case the trial screens wait for it.
    ///
    /// WHY ALSO ON ACTIVATION: an existing user's first launch of 2.0.0 is often a dictation
    /// started from the keyboard, which What's new must not interrupt. It then waits for the
    /// next time the app comes to the front on its own.
    @discardableResult
    private func presentWhatsNewIfDue() -> Bool {
        if whatsNewSteps != nil { return true }
        let displayIsFree = mayRaiseWhatsNew
            && trialCoordinator.announcement == nil
            && !trialCoordinator.showsEndOfTrialPaywall
            && voiceNotes.presentation == nil
        guard WhatsNew.mayAppear(displayIsFree: displayIsFree, activationOpenedByURL: activationOpenedByURL),
              let steps = Self.dueWhatsNewSteps() else { return false }
        whatsNewSteps = steps
        return true
    }

    /// What's new is done: the tabs come back, and their `onAppear` raises the trial
    /// announcement in its existing-user form (#593, #685).
    private func finishWhatsNew() {
        withAnimation(.easeInOut(duration: 0.3)) {
            whatsNewSteps = nil
        }
    }

    /// The voice note sheet's presentation, read from and written back to the
    /// processor, which is what the Live Activity link and the cold path set.
    private var voiceNotePresentation: Binding<VoiceNoteStackRequest?> {
        Binding(
            get: { voiceNotes.presentation },
            set: { voiceNotes.presentation = $0 }
        )
    }

    var body: some View {
        ZStack {
            if let preparation {
                ModelLoadingOverlay(
                    modelManager: modelManager,
                    modelIdentifier: preparation.modelIdentifier,
                    context: preparation.context,
                    isPresented: Binding(
                        get: { self.preparation != nil },
                        set: { if !$0 { self.preparation = nil } }
                    )
                )
            } else if isColdStartMode {
                // Full-screen branded overlay with animated swipe gesture and bilingual text.
                // WHY SwipeBackOverlayView instead of inline code:
                // The overlay has its own animation state and bilingual logic -- keeping it
                // in a separate file follows "one file = one responsibility".
                SwipeBackOverlayView(isPreparingMicrophone: coordinator.isRecoveringAudioSession)
            } else if let whatsNewSteps {
                // What's new for existing users (#685), in place of the tabs. Below the
                // two branches above: a dictation from the keyboard still takes the screen.
                WhatsNewView(
                    steps: whatsNewSteps,
                    modelManager: modelManager,
                    modelIdentifier: activeModelIdentifier,
                    onFinish: finishWhatsNew
                )
                .transition(.opacity)
            } else {
                // Main tab navigation (normal launch path)
                TabView(selection: $selectedTab) {
                    // Tab 0: Home dashboard
                    NavigationStack {
                        HomeView(modelManager: modelManager)
                    }
                    // On the Home stack rather than the TabView, which already carries
                    // the trial's sheet: one sheet per view is what SwiftUI honours.
                    // Shown only from the ordinary navigation — never over the cold
                    // start overlay or the preparation screen, which replace it.
                    .sheet(item: voiceNotePresentation) { request in
                        VoiceNoteStackView(request: request)
                            // A new request is a new screen, never the previous one kept.
                            .id(request.id)
                    }
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                    // Tab 1: Model management
                    NavigationStack {
                        ModelManagerView(modelManager: modelManager)
                    }
                    .tabItem {
                        Label("Models", systemImage: "cpu")
                    }
                    .tag(1)

                    // Tab 2: Settings
                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                    .tag(2)
                }
                .tint(.dictusAccent)
                // The voice note sheet hangs off the Home tab; a sheet on a tab that is
                // not on screen does not present, so a Live Activity tap brings Home
                // forward first.
                .onChange(of: voiceNotes.presentation) { _, presentation in
                    if presentation != nil { selectedTab = 0 }
                }
                // Dismissing a sheet is the app becoming idle again: a voice note that
                // waited behind it may come up now (`VoiceNoteStackPresentationPolicy`).
                .onChange(of: showsPaywall) { _, shown in
                    if !shown { voiceNotes.evaluatePresentation() }
                }
                // The reverse trial's two self-raised screens (#593). On the TabView and
                // not on the ZStack below, which already carries the user's paywall
                // cover: two full-screen covers on one view is a presentation SwiftUI
                // does not promise to honour. Here they also only exist while the
                // ordinary navigation is on screen, which is the only time they may.
                .sheet(
                    item: $trialCoordinator.announcement,
                    onDismiss: { trialCoordinator.announcementDismissed() },
                    content: { announcement in ProTrialAnnouncementView(announcement: announcement) }
                )
                .paywallCover(
                    isPresented: $trialCoordinator.showsEndOfTrialPaywall,
                    trialEnd: trialCoordinator.endOfTrialPaywall
                )
                .onAppear {
                    trialCoordinator.evaluate(canPresent: mayRaiseTrialScreens)
                }
                // The trial screens wait for StoreKit's first scan; this is the
                // evaluation that runs when it lands.
                .onChange(of: proStatus.hasResolvedEntitlements) { _, resolved in
                    if resolved { trialCoordinator.evaluate(canPresent: mayRaiseTrialScreens) }
                }
            }

            // Full-screen recording overlay covers everything including tab bar.
            // WHY not shown in cold start mode: During cold start, the recording runs
            // in the background while the user sees the SwipeBackOverlayView. Showing
            // RecordingView would cover the swipe-back instructions.
            if coordinator.status != .idle && !isColdStartMode {
                RecordingView(mode: .standalone)
            }
        }
        // Detect cold start directly from URL params. MainTabView's onOpenURL fires
        // BEFORE DictusApp's (SwiftUI propagates inner-to-outer), so we can't rely
        // on DictusApp having set the AppGroup flag yet.
        //
        // A URL-launched cold start has already been answered in init, but this handler
        // still runs for it: it is what marks the URL handled, and re-asserting the same
        // state is a no-op. It remains the only path for every URL that arrives while the
        // process is already alive.
        .paywallCover(isPresented: $showsPaywall)
        // The preparation screen and the cold-start overlay replace the tab bar without
        // being sheets; the voice note stack waits for them to go.
        // What's new replaces it too (#685).
        .onAppear { voiceNotes.mainScreenBlocked = preparation != nil || isColdStartMode || whatsNewSteps != nil }
        .onChange(of: preparation != nil || isColdStartMode || whatsNewSteps != nil) { _, blocked in
            voiceNotes.mainScreenBlocked = blocked
        }
        .onOpenURL { url in
            // Whatever this URL asks for, What's new does not take its place (#685). If it
            // was drawn before the URL was known, it has not been recorded yet (it is, once
            // the app is active), so it steps aside and stays due for the next activation.
            // If it was already on screen and recorded, it steps aside all the same: the
            // voice note sheet hangs off the tab bar, which What's new replaces.
            activationOpenedByURL = true
            if whatsNewSteps != nil {
                whatsNewSteps = nil
            }

            // The keyboard's Pro entries (#241's panel pill, #404's fan row). Until
            // 2026-08-29 nothing routed on `dictus://open` at all, so both of them
            // brought the app forward on whatever screen it happened to be showing and
            // left the user to find the paywall — which empties a Pro row of its
            // purpose.
            //
            // Gated on `paywallVisible` on this side too (#236). The keyboard already
            // refuses to draw either entry while the flag is down, but the scheme is
            // public and the app must not be the half of the pair that trusts it.
            if KeyboardOpenURL.intent(from: url) == .pro {
                guard PremiumFlags.paywallVisible else { return }
                // #827: never a paywall over onboarding, whatever keyboard sent this.
                guard KeyboardOnboardingGate.isOnboardingCompleted() else { return }
                // Logged because the two halves of this live in different processes:
                // the keyboard records that it opened the URL, and this is the line
                // that says the app received it and answered.
                PersistentLog.log(.diagnosticProbe(
                    component: "paywall", instanceID: "0", action: "keyboardProIntent",
                    details: "source=keyboard"
                ))
                showsPaywall = true
                return
            }

            // The keyboard's "Dictation interrupted" banner (#860). The text comes from the
            // App Group, not from `lastResult`: that one lives in memory, and an app
            // relaunched since the dictation would land on an empty home screen.
            if KeyboardOpenURL.intent(from: url) == .transcription {
                let recovered = RecoveredTranscriptionChannel.take()
                if let recovered { coordinator.lastResult = recovered }
                PersistentLog.log(.diagnosticProbe(
                    component: "recoveredTranscription", instanceID: "0", action: "opened",
                    details: "source=keyboard chars=\(recovered?.count ?? 0)"
                ))
                selectedTab = 0
                return
            }

            guard let intent = KeyboardDictationURL.intent(from: url) else { return }

            // #827: before onboarding is done a dictation URL raises nothing here — no
            // cold-start overlay, no preparation screen. Onboarding stays on screen.
            guard KeyboardOnboardingGate.isOnboardingCompleted() else {
                Self.hasHandledURL = true
                return
            }

            if intent == .prepare {
                // #458's rule applies here too. This overlay sits BELOW `RecordingView`
                // in the ZStack above, so it could never be what replaced the recording
                // screen — but raising it during a dictation would still leave the app
                // showing a preparation screen the moment the dictation ended.
                //
                // A prepare URL arrives because the keyboard refused a mic tap while a
                // load was in flight, so the app's own status is normally `.idle` here;
                // this guard is about the case where it is not.
                guard !ModelPreparationGate.dictationOwnsTheDisplay(coordinator.status) else {
                    return
                }
                preparation = PreparationPresentation(
                    modelIdentifier: activeModelIdentifier,
                    context: .keyboardColdStart
                )
                return
            }

            if !Self.hasHandledURL {
                // True cold start: process was just launched by keyboard URL.
                isColdStartMode = true
            } else if !coordinator.isEngineRunning {
                // Engine-dead restart: app is in memory but audio engine was stopped
                // (e.g., Power button in Dynamic Island). User needs the swipe-back
                // overlay to know how to return to their keyboard.
                isColdStartMode = true
            }
            Self.hasHandledURL = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .dictusKeyboardPreparationRequested)) { _ in
            // Gated for the same reason as the `.prepare` branch above, and gated with
            // it rather than instead of it: `DictusApp.handleIncomingURL` posts this
            // notification for the very same `dictate?…prepare` URL that handler sees,
            // so the two are one event and must not disagree about whether to answer it.
            guard !ModelPreparationGate.dictationOwnsTheDisplay(coordinator.status) else {
                return
            }
            preparation = PreparationPresentation(
                modelIdentifier: activeModelIdentifier,
                context: .keyboardColdStart
            )
        }
        // The fourth writer (#484): a record button inside the app, tapped while a model load
        // was in flight. The decision to present rather than to call `startDictation` was
        // already made at the button — `RecordTapRouting` in DictusCore, where it is tested —
        // so this handler only presents. It is installed on the ZStack rather than on the
        // TabView so `RecordingView`, a sibling and the second of the two buttons, sees it too.
        .environment(\.presentModelPreparation, PresentModelPreparationAction {
            // A preparation screen with nothing preparing behind it is a dead end (#542).
            // #484's case always had a load in flight — that is what it was refusing for —
            // but the cold-cache refusal can land with `modelLoadState` at `.idle`, which in
            // a live process means the last load failed or was abandoned. The screen would
            // then show its ready state, dismiss, and send the user back to a tap that
            // refuses again. Kicking the load is what makes the refusal productive.
            //
            // ONLY in that exact state. `.loading` is #484 untouched, and `.ready` never
            // reaches here cold: the load that writes `.ready` is the same one that records
            // the warmth. `preloadActiveModel` also clears the memory of an abandoned load,
            // which is correct here and only here — the user is asking for this load.
            if coordinator.modelLoadState == .idle {
                coordinator.preloadActiveModel()
            }
            preparation = PreparationPresentation(
                modelIdentifier: activeModelIdentifier,
                context: .appRecordTap
            )
        })
        .onChange(of: scenePhase) { _, newPhase in
            // Every return to the foreground can be "the next launch" #593 speaks of:
            // the trial may have ended while the app sat suspended.
            if newPhase == .active {
                // What's new first (#685): the existing-user announcement follows it.
                if !presentWhatsNewIfDue() {
                    trialCoordinator.evaluate(canPresent: mayRaiseTrialScreens)
                }
            }
            if newPhase == .background {
                isColdStartMode = false
                activationOpenedByURL = false
                // The launch intent describes the frame this process launched into.
                // Forgetting it here keeps a view rebuilt later in the same process
                // from replaying the cold-start overlay (issue #264).
                ColdStartLaunch.clear()
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(DictationCoordinator.shared)
        .environmentObject(TranscriptionHistoryStore.shared)
        .environmentObject(ProStatusManager())
        .environmentObject(ProTrialCoordinator(proStatus: ProStatusManager()))
}
