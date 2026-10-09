// DictusApp/Onboarding/OnboardingView.swift
// Container for the onboarding flow with programmatic-only step advancement.
import SwiftUI
import AVFoundation
import DictusCore

/// Onboarding flow presented as a fullScreenCover on first launch.
/// Steps (#649, #675): intro, language, keyboard setup, the pick of three Smart Modes (#677,
/// only where Smart Modes can run), model preparation (only while the model is still
/// downloading or compiling), microphone (only while not yet granted), first dictation
/// through the globe key, completion. The order is `OnboardingStep.allCases`; which steps
/// are passed over is `OnboardingStep.next(skipping:deviceCanRunSmartModes:)`.
///
/// WHY switch/case instead of TabView:
/// TabView(.page) allows the user to swipe between pages, which means they could
/// skip required steps (mic permission, keyboard setup, model download).
/// Using a manual switch/case on the current step ensures the user can ONLY
/// advance via each page's completion button — no swiping. This guarantees every
/// prerequisite is properly set up before the user reaches the test recording step.
///
/// WHY @Binding isComplete:
/// The parent (DictusApp.swift) owns `hasCompletedOnboarding` via @AppStorage.
/// When the last page (the completion step) finishes, it sets isComplete = true,
/// which writes to App Group UserDefaults and dismisses the fullScreenCover.
///
/// WHY THE POLISH PAGE IS GONE (#649 decision 2): polish adds seconds to every dictation,
/// Parakeet's output is already clean, and a new user judges Dictus on speed. Polish stays
/// off by default and is found in Settings; a user who already turned it on keeps it.
struct OnboardingView: View {
    @Binding var isComplete: Bool

    /// The step on screen, persisted on every change.
    ///
    /// WHY persisted, and in the App Group: when the user enables "Allow Full Access" in
    /// iOS Settings, iOS's TCC daemon kills the main app because the
    /// kTCCServiceKeyboardNetwork permission changes. The step has to survive that
    /// termination so the user resumes at the right place. `OnboardingStep.current()` also
    /// places an install that was mid-onboarding on the pre-#649 page numbering.
    ///
    /// WHY @State + an explicit save instead of @AppStorage: the stored value is a step
    /// name with a one-time migration in front of it, which @AppStorage cannot express.
    @State private var step: OnboardingStep = OnboardingStep.current()

    /// One `ModelManager` for the whole flow, shared by the language page that starts the
    /// download and the preparation page that waits for it (#649).
    ///
    /// WHY HERE and not in the pages: the download now starts two pages before anybody
    /// watches it. A manager owned by the language page would be released with that page,
    /// and the preparation page would build a second one that only learns about the
    /// transfer through the peer broadcast. One owner for the length of the flow keeps a
    /// single source of truth for "is the model ready", which is also what decides whether
    /// the preparation step is shown at all.
    @StateObject private var modelManager = ModelManager()

    /// The model whose download the language screen just started, while the keep-open
    /// popup is up (`keepOpenWarning`). nil otherwise.
    @State private var keepOpenWarningModel: String?

    /// Whether this iPhone could ever run Smart Modes, which decides whether the Pro steps
    /// are part of the flow (#677, #593 decision 2). Read once: hardware, OS and SDK do
    /// not change during an onboarding, and the progress bar must not change length.
    @State private var deviceCanRunSmartModes = SmartModeAvailability.deviceIsCapable

    /// Reset when the first dictation is left, so Home does not open on its transcription.
    @EnvironmentObject private var coordinator: DictationCoordinator

    var body: some View {
        ZStack {
            Color.dictusBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // The shell's top row (#675): progress bar and Skip. Outside the sliding
                // page so it stays put while the pages change under it, and only its
                // segments animate.
                OnboardingTopBar(
                    step: step,
                    deviceCanRunSmartModes: deviceCanRunSmartModes,
                    onSkip: step.isSkippable ? skip : nil
                )
                    .padding(.top, 8)

                // Current page content — only one page visible at a time
                // WHY Group instead of ZStack: Group avoids stacking every page
                // on top of each other (unnecessary view hierarchy). Only the
                // matched case is instantiated.
                Group {
                    switch step {
                    case .welcome:
                        WelcomePage(onNext: advance)
                    case .language:
                        LanguageSetupPage(onConfirm: confirmLanguage)
                    case .keyboardSetup:
                        KeyboardSetupPage(onNext: advance)
                    case .smartModePick:
                        SmartModePickPage(
                            modelManager: modelManager,
                            modelIdentifier: onboardingModel,
                            onContinue: advance
                        )
                    case .modelPreparation:
                        ModelDownloadPage(
                            modelManager: modelManager,
                            modelIdentifier: onboardingModel,
                            onNext: advance
                        )
                    case .microphone:
                        MicPermissionPage(onNext: advance)
                    case .firstDictation:
                        GlobeKeyTutorialPage(onComplete: leaveFirstDictation)
                    case .completion:
                        OnboardingSuccessView(onComplete: finish)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Slide transition: new page slides in from trailing edge,
                // old page slides out to leading edge — standard forward navigation feel.
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
                .id(step) // Force SwiftUI to treat each page as a unique view for transitions
            }
        }
        .alert(Text("Keep Dictus open"), isPresented: keepOpenWarning) {
            Button("Got it") {}
        } message: {
            keepOpenWarningMessage
        }
        // Prevent interactive dismiss (swipe down) on the fullScreenCover
        .interactiveDismissDisabled()
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Skip

    /// The shell's Skip, on the steps that offer it (`OnboardingStep.isSkippable`).
    ///
    /// - The Smart Mode pick: moves on writing nothing, so the fan keeps the seed (#677).
    /// - The first dictation: closes the keyboard and goes to the completion screen, as a
    ///   finished dictation does.
    private func skip() {
        switch step {
        case .smartModePick:
            PersistentLog.log(.onboardingSmartModePickSkipped)
            advance()
        case .firstDictation:
            PersistentLog.log(.onboardingGlobeTutorialSkipped)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            leaveFirstDictation()
        case .welcome, .language, .keyboardSetup, .modelPreparation, .microphone, .completion:
            advance()
        }
    }

    // MARK: - Model

    /// The model the onboarding installs: the recommendation for the language the user
    /// confirmed and this device.
    ///
    /// Read from the settings the language page wrote, not held in memory, so it is still
    /// the same model after iOS kills the app during keyboard setup and the flow resumes.
    private var onboardingModel: String {
        ModelInfo.recommendedIdentifier()
    }

    /// Whether `identifier` has finished preparing, so the preparation step has nothing to
    /// show. Same test the preparation page applies (#433): files listed AND some model
    /// active, because a listed model whose compile was interrupted cannot transcribe yet.
    private func isReady(_ identifier: String) -> Bool {
        modelManager.downloadedModels.contains(identifier) && modelManager.isModelReady
    }

    // MARK: - Navigation

    private func advance() {
        guard let next = step.next(skipping: satisfiedSteps, deviceCanRunSmartModes: deviceCanRunSmartModes) else {
            return
        }
        go(to: next)
    }

    /// The steps with nothing left to ask, which `OnboardingStep.next(skipping:deviceCanRunSmartModes:)` passes
    /// over (#675). Which steps may be passed over is DictusCore's rule; this only reads
    /// the two facts it needs from the app.
    ///
    /// - The preparation: shown only while there is something to wait for (#649 decision
    ///   1.6). A download that finished while the user was in Settings goes straight on.
    /// - The microphone: already granted on a second run, or by an install that went
    ///   through the order before #675, where the microphone came first. A denied
    ///   microphone is still shown, because that page says where to turn it back on.
    private var satisfiedSteps: Set<OnboardingStep> {
        var satisfied: Set<OnboardingStep> = []
        if isReady(onboardingModel) {
            satisfied.insert(.modelPreparation)
        }
        if AVAudioApplication.shared.recordPermission == .granted {
            satisfied.insert(.microphone)
        }
        return satisfied
    }

    private func go(to newStep: OnboardingStep) {
        OnboardingStep.save(newStep)
        withAnimation {
            step = newStep
        }
    }

    /// Writes the language setup and starts the model download, then moves on (#649).
    ///
    /// WHY THE DOWNLOAD STARTS HERE: the microphone and keyboard steps take the user a
    /// minute or two, much of it in iOS Settings. Starting the transfer now spends that
    /// time downloading instead of making the user wait for it afterwards. It runs on the
    /// background `URLSession` (#449), on any network and without asking (decision 5),
    /// survives the trip to Settings and the kill that enabling Full Access causes, and
    /// its compile waits for the foreground (`ModelManager.waitForForegroundToCompile`).
    private func confirmLanguage(_ setup: LanguageSetup) {
        setup.apply()
        let model = setup.recommendedModel(on: DeviceCapabilities.current())
        if startDownloadIfNeeded(model) {
            // The download is already running; the popup only asks the user to stay. Its
            // button moves on (`keepOpenWarning`), so the flow continues as before.
            keepOpenWarningModel = model
        } else {
            advance()
        }
    }

    /// Starts the download of `identifier` unless it is already ready or already moving.
    ///
    /// WHY THE GUARD: this screen can be confirmed again after a relaunch, and by then the
    /// launch adoption (#449) may already be driving the transfer from this same manager.
    /// A second `downloadModel` would join the transfer but run its own compile after it.
    ///
    /// - Returns: whether bytes are now being transferred: false when nothing was started,
    ///   and false for a model whose files are already on disk (`.ready`), where only the
    ///   compile is left. That is the case the keep-open popup is about.
    @discardableResult
    private func startDownloadIfNeeded(_ identifier: String) -> Bool {
        guard !isReady(identifier) else { return false }
        let transfersBytes: Bool
        switch modelManager.modelStates[identifier] {
        case .downloading, .prewarming:
            return false
        case .ready:
            transfersBytes = false
        case .notDownloaded, .error, nil:
            transfersBytes = true
        }
        Task {
            // Failures are recorded on the model's state by `downloadModel` itself, and
            // the preparation page shows them with a retry. Nothing to do here.
            try? await modelManager.downloadModel(identifier)
        }
        return transfersBytes
    }

    // MARK: - Keep-open warning

    /// The popup raised when the language screen starts a download (decided 2026-10-09).
    ///
    /// WHY A POPUP AND WHY HERE: the background `URLSession` survives the user leaving
    /// (#449), but iOS throttles it hard. Measured on device: about 6.5 MB/s with Dictus in
    /// front, about 0.2 MB/s once it is in the background. Users start the download and go
    /// to another app; a line of text on a page is not read, a popup at the moment the
    /// download starts is. It does not block anything: the download is already running,
    /// and its one button continues the flow.
    ///
    /// WHY "EXCEPT TO TURN ON THE KEYBOARD": the very next step sends the user to Settings.
    /// The copy must not contradict it.
    private var keepOpenWarning: Binding<Bool> {
        Binding(
            get: { keepOpenWarningModel != nil },
            set: { isPresented in
                guard !isPresented, keepOpenWarningModel != nil else { return }
                keepOpenWarningModel = nil
                advance()
            }
        )
    }

    /// The popup's message, with the real size of the model being downloaded.
    private var keepOpenWarningMessage: Text {
        if let identifier = keepOpenWarningModel, let size = ModelInfo.forIdentifier(identifier)?.sizeLabel {
            return Text("The model (\(size)) is downloading now. It continues if you leave the app, but iOS slows it down a lot. To have it ready sooner, stay in Dictus, except to turn on the keyboard in Settings.")
        }
        return Text("The model is downloading now. It continues if you leave the app, but iOS slows it down a lot. To have it ready sooner, stay in Dictus, except to turn on the keyboard in Settings.")
    }

    /// Leaves the first dictation, whether it succeeded or was skipped, for the completion
    /// screen (#675: completion is a step of its own now, persisted like the others).
    ///
    /// WHY reset the coordinator here:
    /// If the user dictated during the first dictation, the DictationCoordinator holds the
    /// last transcription in `lastResult`. Without clearing it, HomeView displays a "last
    /// transcription card" as soon as the user lands on the main screen, which is not the
    /// expected fresh Home state.
    private func leaveFirstDictation() {
        coordinator.lastResult = nil
        coordinator.resetStatus()
        advance()
    }

    private func finish() {
        // Reset to the first step on completion so a future onboarding reset starts
        // cleanly from the welcome screen instead of resuming here.
        OnboardingStep.save(.welcome)
        isComplete = true
    }
}
