// DictusApp/Views/ModelLoadingOverlay.swift
// Full-screen blocking screen shown while a model is downloading, compiling
// for the Neural Engine, or being loaded into RAM. Issues #144, #708.
import SwiftUI
import DictusCore

/// Full-screen cover that surfaces long-running model preparation work to the user.
///
/// Why this exists:
/// Whisper turbo (~645 MB) takes about three and a half minutes of one-off Core ML
/// compilation on a 15 Pro Max, and a couple of seconds to load into RAM every time
/// after that. The "~2 min" figure this comment used to quote was never measured on
/// this variant at all — it described the ~954 MB one issue #408 replaced. Four cold
/// readings of the current variant now live in `ModelInfo.firstPreparationSeconds`,
/// which is where the number belongs. Without a blocking UI the user could mistake
/// the wait for a frozen app, tap the keyboard mic mid-load, and trigger a
/// `Swift.CancellationError` cascade (issue #144). The overlay refuses any further
/// model interaction until `modelLoadState == .ready`.
///
/// Refusing to let the user act made it this screen's job to SAY how long the wait is
/// (issue #432), and then how far along it is: a coarse countdown under the compile,
/// "About 3 minutes left", then "Less than a minute left", held (issue #533). The rules
/// live in `ModelPreparationCountdown`, where they are tested.
///
/// WHAT IT LOOKS LIKE, AND WHY (#708, mock-up validated 2026-10-12): every new user waits
/// on this screen, and the onboarding shows it under its new shell (#649, #675), next to
/// which the old one looked like a different app and moved three times between phases.
/// From top to bottom: a ring around the Dictus logo, a title, a subtitle, a card with the
/// two steps of the wait, and a two-line caption. Every block has a fixed height
/// (`ModelPreparationMetrics`), so a phase change only swaps content, and the ring sits at
/// the same y in every phase and every context. No waveform, no button.
///
/// WHAT IS GONE FROM IT: the rotating phrases (`CyclingLoadingText`, deleted) and the
/// #432 duration sentence. The phrases were the screen's way of looking alive; the ring
/// and the step card do that now and say something true while doing it. The duration
/// sentence is replaced by the #533 countdown in the caption, which says how long without
/// a second line saying it again.
///
/// The overlay observes two signals to decide which phase to show:
/// 1. `ModelManager.modelStates[id]` — `.downloading`, `.prewarming`, `.ready`
/// 2. `ModelManager.modelLoadState` (mirrored from the App Group via Combine) —
///    `.loading` once `DictationCoordinator.preloadActiveModel` is in flight.
struct ModelLoadingOverlay: View {
    @ObservedObject var modelManager: ModelManager

    /// Identifier of the model the user just acted on (download or select).
    /// Drives the phase logic and which copy is shown.
    let modelIdentifier: String

    /// Two-way binding controlled by the parent. The overlay flips it to false
    /// once the model becomes ready so the cover dismisses itself.
    @Binding var isPresented: Bool

    /// The user-facing flow that caused preparation to be shown.
    let context: ModelPreparationContext

    @State private var showCompletion = false
    @State private var activeContext: ModelPreparationContext

    /// Set when the load ended because the app STOPPED WAITING for it, rather than
    /// because it finished (third review, finding D).
    ///
    /// Both outcomes leave `modelLoadState == .idle`, and `rawPhase` maps a downloaded
    /// model plus `.idle` to `.ready` — so a deadline expiring with this screen up, the
    /// keyboard-cold-start case issue #428 exists for, showed the user the "Model ready"
    /// checkmark while the compile was still running and no engine was loaded. The
    /// reason travels on the notification that already drives this screen.
    @State private var loadGaveUp = false

    /// Tracks whether we have ever observed an active prep phase (downloading,
    /// compiling, or loading). Without this, the overlay would auto-dismiss
    /// when presented synchronously by the parent before `downloadModel`
    /// has had a chance to flip `modelStates[id]` from `.notDownloaded` to
    /// `.downloading` — the onboarding race that surfaced after f5ba7ab.
    @State private var hasSeenWorkPhase = false

    /// Whether every file the model needs was on disk when the screen opened (#708).
    ///
    /// Decides the phase drawn before any work has been seen: the optimization frame for a
    /// model already downloaded, the download frame otherwise. Read once, in `init`, so the
    /// very first frame is already the right one; an `onAppear` would come one frame late,
    /// and one frame of a download that does not happen is the defect this fixes.
    @State private var filesOnDiskAtOpen: Bool

    /// The last work phase drawn, held while the model state already reads `.ready` but
    /// the completion has not been decided yet (`checkForCompletion` runs in `onChange`,
    /// after the frame that saw the change). Without it that frame would draw the ready
    /// copy without the ready ring, or flash back to the opening phase.
    @State private var lastWorkPhase: ModelPreparationPhase

    /// When this screen first saw a COLD preparation of a model measured in minutes —
    /// the clock the countdown runs on (issue #533). Nil means no countdown at all.
    ///
    /// WHY NEVER RESET: a download-then-prepare goes `.compiling` → `.loading`, and to the
    /// user that is one wait. Restarting the clock at the hand-over would add minutes back.
    ///
    /// WHY THE WALL CLOCK: time spent in the background keeps counting. A compile throttled
    /// there (#472) only reaches the floor earlier and holds it longer, which is the
    /// designed behaviour. When the screen appears mid-preparation (keyboard cold start into
    /// a compile already running) the anchor is late and the countdown overstates what is
    /// left — the safe direction under #432's rule, so no persisted start time is added.
    @State private var preparationStartedAt: Date?

    private typealias Phase = ModelPreparationPhase
    private typealias Metrics = ModelPreparationMetrics

    init(
        modelManager: ModelManager,
        modelIdentifier: String,
        context: ModelPreparationContext = .modelSelection,
        isPresented: Binding<Bool>
    ) {
        self.modelManager = modelManager
        self.modelIdentifier = modelIdentifier
        self.context = context
        self._isPresented = isPresented
        self._activeContext = State(initialValue: context)
        let filesOnDisk = ModelManager.hasCompleteFilesOnDisk(modelIdentifier)
        self._filesOnDiskAtOpen = State(initialValue: filesOnDisk)
        self._lastWorkPhase = State(initialValue: Phase.displayed(
            raw: .ready,
            hasSeenWorkPhase: false,
            filesOnDisk: filesOnDisk
        ))
    }

    var body: some View {
        ZStack {
            // Adaptive brand background — auto switches between light/dark
            // (#F2F2F7 in light, #0A1628 in dark).
            Color.dictusBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // WHY THIS INSET (#708): in the onboarding the shell's progress bar row sits
                // above this screen, outside it. The in-app contexts have no bar, so their
                // content is pushed down by the bar row's height and the ring lands at the
                // same y in both. The context the screen was raised with decides it, not
                // `activeContext`: a keyboard request arriving mid-way turns one in-app
                // context into another and must not move anything.
                if context != .onboarding {
                    Color.clear.frame(height: OnboardingMetrics.topRowHeight)
                }

                // Centred in the height left, with fixed blocks between the two spacers, so
                // the spacers never change size between phases.
                Spacer(minLength: 0)
                content
                Spacer(minLength: 0)
            }
        }
        .interactiveDismissDisabled(true)
        .onReceive(NotificationCenter.default.publisher(for: .dictusModelLoadStateChanged)) { note in
            if let reason = note.userInfo?["reason"] as? String,
               ModelPreparationOutcome.reasonMeansGaveUp(reason) {
                loadGaveUp = true
            }
            checkForCompletion()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dictusKeyboardPreparationRequested)) { _ in
            activeContext = .keyboardColdStart
        }
        .onChange(of: currentModelState) { _, _ in
            checkForCompletion()
        }
        .onAppear {
            checkForCompletion()
        }
        // `initial: true` also runs this for the phase the screen opens on, which is the
        // keyboard cold start's case: it can arrive with the load already in flight.
        .onChange(of: currentPhase, initial: true) { _, newPhase in
            if newPhase != .ready {
                lastWorkPhase = newPhase
            }
            anchorCountdownIfCold()
        }
    }

    // MARK: - Layout

    private var content: some View {
        let phase = displayedPhase
        return VStack(spacing: 0) {
            ModelPreparationRingView(ring: ModelPreparationRing(
                phase: phase,
                downloadFraction: downloadFraction
            ))

            title(for: phase)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .frame(height: Metrics.titleHeight)
                .padding(.top, Metrics.ringToTitle)

            subtitle(for: phase)
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .frame(height: Metrics.subtitleHeight)
                .padding(.top, Metrics.titleToSubtitle)

            stepsCard(for: phase)
                .padding(.top, Metrics.subtitleToCard)

            caption(for: phase)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .frame(height: Metrics.captionHeight)
                .padding(.top, Metrics.cardToCaption)
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        // Every text block above is a fixed slot: a phase change swaps what is in it, so
        // the fade is the only movement, and nothing slides.
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    // MARK: - Title and subtitle

    private func title(for phase: Phase) -> Text {
        phase == .ready
            ? Text("Your model is ready", comment: "Model preparation screen title, once the model is ready (#708).")
            : Text("Preparing your model", comment: "Model preparation screen title, while downloading, optimizing or loading (#708).")
    }

    /// The subtitle names the model, and in the onboarding the language it was picked for
    /// (#649 decision 4: the screen says the model is the best one for the user's language
    /// and iPhone).
    private func subtitle(for phase: Phase) -> Text {
        if phase == .ready {
            return Text(
                "\(modelName) runs on your iPhone. Dictation works even without a network.",
                comment: "Model preparation screen subtitle, once ready. The placeholder is the model's name (Parakeet v3) (#708)."
            )
        }
        guard context == .onboarding else {
            return Text(
                "\(modelName). Once ready, everything runs offline.",
                comment: "Model preparation screen subtitle in the app (model switch, keyboard cold start). The placeholder is the model's name (#708)."
            )
        }
        if let language = spokenLanguagePhrase {
            return Text(
                "\(modelName), picked for \(language) and this iPhone. After that, everything runs offline.",
                comment: "Onboarding model preparation subtitle (#708). First placeholder: the model's name (Parakeet v3). Second: the spoken language with its article in French (le français, l'anglais)."
            )
        }
        return Text(
            "\(modelName), picked for your language and this iPhone. After that, everything runs offline.",
            comment: "Onboarding model preparation subtitle when the language cannot be named in the sentence (#708). The placeholder is the model's name."
        )
    }

    private var modelName: String {
        ModelInfo.forIdentifier(modelIdentifier)?.localizedDisplayName ?? String(localized: "Voice model")
    }

    /// The language the onboarding picked this model for, ready to slot into the sentence,
    /// or nil for the sentence that does not name it. The rules are
    /// `ModelPreparationLanguagePhrase`'s.
    ///
    /// WHY `SpokenLanguage.forRecommendation()`: it is the input
    /// `ModelInfo.recommendedIdentifier()` chose this model from, so the sentence names the
    /// language that actually decided it. Named in the interface's language, which is the
    /// app's localization and not the device locale: a German iPhone reads the app in
    /// English, and "picked for Französisch" would be wrong twice.
    private var spokenLanguagePhrase: String? {
        let interfaceLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        let name = Locale(identifier: interfaceLanguage)
            .localizedString(forLanguageCode: SpokenLanguage.forRecommendation())
        return ModelPreparationLanguagePhrase.phrase(languageName: name, interfaceLanguage: interfaceLanguage)
    }

    // MARK: - Steps card

    private func stepsCard(for phase: Phase) -> some View {
        let steps = ModelPreparationSteps(phase: phase)
        return VStack(spacing: Metrics.rowSpacing) {
            ModelPreparationStepRow(
                state: steps.download,
                label: downloadLabel(steps.download),
                value: steps.download == .running ? downloadPercentage : nil
            )
            ModelPreparationStepRow(
                state: steps.second,
                label: secondLabel(steps.secondLabel)
            )
        }
        .padding(.vertical, Metrics.cardVerticalPadding)
        .padding(.horizontal, Metrics.cardHorizontalPadding)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cardCornerRadius, style: .continuous)
                .fill(Color.dictusSurface)
        )
    }

    private func downloadLabel(_ state: ModelPreparationStepState) -> Text {
        guard state == .done else {
            return Text("Downloading")
        }
        // The catalogue's size, the same figure the model card and the language screen
        // show. The byte counter's total is gone by then: it is cleared with the bar.
        // Without the card's "~": the mock-up writes a finished download as a size, not an
        // estimate of one ("Downloaded · 483 MB").
        guard let label = ModelInfo.forIdentifier(modelIdentifier)?.sizeLabel else {
            return Text("Download complete", comment: "Model preparation step, download done, when the model's size is unknown (#708).")
        }
        let size = label.hasPrefix("~") ? String(label.dropFirst()) : label
        return Text("Downloaded · \(size)", comment: "Model preparation step, download done. The placeholder is the model's size (483 MB) (#708).")
    }

    private func secondLabel(_ step: ModelPreparationSecondStep) -> Text {
        switch step {
        case .optimizing:
            return Text("Optimizing for this iPhone", comment: "Model preparation step: the Core ML compile, pending or running (#708).")
        case .loading:
            return Text("Loading the model", comment: "Model preparation step: the model loading into memory (#708).")
        case .optimized:
            return Text("Optimized for this iPhone", comment: "Model preparation step, done (#708).")
        }
    }

    /// "34 %", formatted for the locale (a narrow space before the sign in French).
    private var downloadPercentage: Text {
        Text(downloadFraction ?? 0, format: .percent.precision(.fractionLength(0)))
    }

    private var downloadFraction: Double? {
        modelManager.downloadProgress[modelIdentifier].map(Double.init)
    }

    // MARK: - Caption

    /// Line 1: the MB counter while downloading, the #533 countdown while optimizing or
    /// loading. Line 2: the line about leaving the screen, or, once ready, what to do next.
    ///
    /// WHY LINE 2 MAY WRAP ONLY WHEN LINE 1 IS EMPTY: the slot is two lines tall, and the
    /// completion instructions of the prepare-only contexts are a full sentence each.
    private func caption(for phase: Phase) -> some View {
        let hasFirstLine = phase != .ready
        return VStack(spacing: 4) {
            if hasFirstLine {
                captionFirstLine(for: phase)
                    .font(.system(size: 14).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            captionSecondLine(for: phase)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.dictusAccent)
                .multilineTextAlignment(.center)
                .lineLimit(hasFirstLine ? 1 : 2)
                .minimumScaleFactor(0.75)
        }
    }

    @ViewBuilder
    private func captionFirstLine(for phase: Phase) -> some View {
        switch phase {
        case .downloading:
            // Moving byte counter — reads as alive even while the percentage crawls
            // through the 445 MB Encoder file (#207). An empty line before the first tick:
            // the slot keeps its height either way.
            if let bytes = modelManager.downloadByteInfo[modelIdentifier] {
                Text("\(bytes.downloadedMB) MB of \(bytes.totalMB) MB")
            } else {
                Text(verbatim: " ")
            }
        case .compiling, .loading:
            if let preparationStartedAt, !loadGaveUp {
                // Ticks every second so a minute boundary shows within a second of being
                // crossed; the text itself only changes at those boundaries. Empty when
                // there is no countdown: an unmeasured or brief model, or a warm cache.
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    if let countdown = ModelPreparationCountdown.at(
                        elapsedSeconds: Int(timeline.date.timeIntervalSince(preparationStartedAt)),
                        measuredSeconds: ModelInfo.forIdentifier(modelIdentifier)?.firstPreparationSeconds
                    ) {
                        Text(countdownText(countdown))
                    } else {
                        Text(verbatim: " ")
                    }
                }
            } else {
                Text(verbatim: " ")
            }
        case .ready:
            EmptyView()
        }
    }

    private func countdownText(_ countdown: ModelPreparationCountdown) -> LocalizedStringKey {
        switch countdown {
        case .minutesLeft(let minutes):
            return "About \(minutes) minutes left"
        case .underAMinute:
            return "Less than a minute left"
        }
    }

    @ViewBuilder
    private func captionSecondLine(for phase: Phase) -> some View {
        if phase == .ready {
            if let completionInstruction {
                Text(completionInstruction)
            }
        } else {
            leaveNotice(isDownloading: phase == .downloading)
        }
    }

    /// What the user does next, once the model is ready.
    ///
    /// Only the two prepare-only contexts have anything to say here: they are the ones reached
    /// from a tap that deliberately does NOT become a recording, so the screen owes the user
    /// the action that does. Which sentence is a question about where they came from, not
    /// about the prepare-only rule — hence `startedFromAnotherApp` and not `isPrepareOnly`
    /// (#484). Onboarding and model selection dismiss into the screen the user was already on.
    ///
    /// WHY IT SURVIVED #708: the brief leaves the caption empty once ready, drawn for the
    /// onboarding, which has no instruction to give. For a user who tapped the keyboard's mic
    /// and was sent here, the instruction is the only thing on the ready screen that says the
    /// tap did not start a dictation, so it keeps the caption's second line there.
    private var completionInstruction: LocalizedStringKey? {
        switch activeContext {
        case .onboarding, .modelSelection:
            return nil
        case .keyboardColdStart:
            return "Return to your app and tap the microphone again."
        case .appRecordTap:
            return "Tap again to start your dictation."
        }
    }

    /// The line about leaving this screen. Which one is `ModelPreparationContext.leaveNotice`.
    ///
    /// WHICH OF THE FIRST TWO, and why it is not `isPrepareOnly` (#484): "stay on this
    /// page" is only sayable to someone who is on it. The keyboard cold start brings a user
    /// whose next move is to leave, so it asks for patience instead. The in-app tap does
    /// not — and staying in the foreground is what keeps the compile off the system's
    /// background throttle (#472), so it is the stronger of the two sentences and the right
    /// one there.
    ///
    /// THE THIRD is the onboarding variant (#675, #649 decision 6): while the onboarding's
    /// download runs, it survives leaving the app, so the screen says that instead.
    ///
    /// WHY ALL THREE IN THE ACCENT COLOUR NOW (#708): the mock-up draws the caption's second
    /// line as one style, whatever it says. It used to be the onboarding line alone, drawn
    /// apart because it is the one that gives the user something rather than asks for
    /// something; on the new screen the line is the caption's call to the user, so it reads
    /// as one.
    ///
    /// WHY THE ONBOARDING LINE IS SHORTER THAN IT WAS: it said "…but much more slowly" (the
    /// cost of a backgrounded transfer, decided 2026-10-09). The validated #708 brief and
    /// mock-up give the line as "The download continues if you leave the app." and hold the
    /// caption to two single lines, which the longer sentence did not fit.
    private func leaveNotice(isDownloading: Bool) -> Text {
        switch activeContext.leaveNotice(isDownloading: isDownloading) {
        case .downloadContinuesInBackground:
            return Text("The download continues if you leave the app.", comment: "Onboarding model preparation, while downloading (#675, #708).")
        case .waitForPreparation:
            return Text("Please wait for preparation to finish.")
        case .stayOnPage:
            return Text("Please stay on this page and do not leave the app.")
        }
    }

    // MARK: - Phase logic

    /// The phase the screen draws: the completion once it has been decided, otherwise the
    /// current work phase, holding the last one through the frame where the model state
    /// already reads ready but `checkForCompletion` has not run yet.
    private var displayedPhase: Phase {
        if showCompletion { return .ready }
        let phase = currentPhase
        return phase == .ready ? lastWorkPhase : phase
    }

    /// Starts the countdown's clock, once, if this preparation deserves one (issue #533).
    ///
    /// WHY WARMTH IS PART OF IT: an ordinary launch with a warm Core ML cache also goes
    /// through `.loading`, for about three seconds. Without this check every warm load
    /// would flash "About 4 minutes left". `ModelWarmth` is false exactly when the cache is
    /// cold, and it answers `true` when the install identity cannot be read — here that
    /// means "no countdown", the safe direction.
    ///
    /// WHY ONLY `.minutes`: `.brief` (Medium's 32 s) would only ever show "Less than a
    /// minute left"; `.unmeasured` has nothing to count down from.
    ///
    /// WHY `rawPhase` AND NOT THE PHASE ON SCREEN (#708): a model already on disk is drawn
    /// as optimizing from the first frame, before any work has started — and when that
    /// model turns out to be loaded already, no work ever starts. The clock waits for the
    /// model's state to say a compile or a load is really running.
    ///
    /// Warmth is read here, when the anchor is decided, and never on a tick: by the time
    /// the warm inference records the model as warm, the screen is on its way out.
    private func anchorCountdownIfCold() {
        guard preparationStartedAt == nil,
              rawPhase == .compiling || rawPhase == .loading,
              !loadGaveUp,
              !showCompletion,
              case .minutes = ModelPreparationWait.forModel(modelIdentifier) else {
            return
        }
        let identity = ModelWarmth.installIdentity(
            bundlePathComponents: Bundle.main.bundleURL.pathComponents,
            systemVersion: UIDevice.current.systemVersion
        )
        guard !ModelWarmth.isWarm(modelIdentifier, identity: identity) else { return }
        preparationStartedAt = Date()
    }

    private var currentModelState: ModelState {
        modelManager.modelStates[modelIdentifier] ?? .notDownloaded
    }

    /// The phase, with the opening frame decided by `ModelPreparationPhase.displayed`:
    /// before any work has been seen, a resting state is drawn as the work about to start
    /// (the download, or the optimization for a model already on disk) rather than as done.
    /// This is the seam that fixes the onboarding presentation race (commit f5ba7ab
    /// follow-up) and the download that did not happen (#708).
    private var currentPhase: Phase {
        Phase.displayed(raw: rawPhase, hasSeenWorkPhase: hasSeenWorkPhase, filesOnDisk: filesOnDiskAtOpen)
    }

    private var rawPhase: Phase {
        switch currentModelState {
        case .downloading:
            return .downloading
        case .prewarming:
            return .compiling
        case .ready:
            switch modelManager.modelLoadState {
            case .loading:
                return .loading
            case .ready:
                return .ready
            case .idle:
                // Defensive: model is ready on disk but no load is in flight.
                // Treat as ready so the overlay can dismiss.
                return .ready
            }
        case .notDownloaded, .error:
            return .ready
        }
    }

    private func checkForCompletion() {
        // A failed download must dismiss the cover immediately — without this,
        // `.error` falls into rawPhase's `.ready` mapping below and flashes the
        // "Model ready" celebration on a failure (issue #207). The parent view
        // surfaces the error message once the cover is gone.
        if case .error = currentModelState {
            isPresented = false
            return
        }
        // Latch the work-phase flag the first time we observe real activity.
        // We read `rawPhase` here (not the user-facing `currentPhase`) because
        // the latter masquerades the initial `.ready` state as a work phase
        // until this flag flips, which would cause an infinite loop.
        if rawPhase != .ready {
            hasSeenWorkPhase = true
            return
        }
        // The model is ready, but if we have never seen any actual work happen
        // yet, the parent likely just opened the overlay and the state will
        // imminently flip to `.downloading`. Keep the cover up.
        //
        // The one exception — a preparation asked for a model that genuinely is loaded
        // already — is `ModelPreparationOutcome`'s to decide, in DictusCore where it is
        // tested. What it needs and this line used to omit is whether anything alive in
        // this launch wrote the load state at all (#579): read at `onAppear` on a launch
        // from dead, it is the previous process's, and every part of it is false.
        let preparationWasAlreadyReady = ModelPreparationOutcome.preparationWasAlreadyReady(
            context: activeContext,
            isModelOnDisk: currentModelState == .ready,
            loadState: modelManager.modelLoadState,
            loadStateIsFromThisLaunch: modelManager.loadStateIsFromThisLaunch
        )
        guard hasSeenWorkPhase || preparationWasAlreadyReady else {
            return
        }
        guard !showCompletion else { return }

        // Nothing to celebrate: the app gave up on this load, the compile is still
        // running, and no engine arrived. Leave without the checkmark (finding D).
        guard !loadGaveUp else {
            isPresented = false
            return
        }

        // No `withAnimation` here: the content animates its own phase change in place
        // (`content`), and the ring times its own close and colour (#708). A transaction
        // around this flag used to drive a scale transition between two layouts.
        showCompletion = true

        // The ready state holds for a moment, then the screen dismisses itself and the
        // onboarding moves on by itself (#708: no Continue button).
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeOut(duration: 0.4)) {
                isPresented = false
            }
        }
    }
}

#Preview("Downloading — light") {
    ModelLoadingOverlay(
        modelManager: {
            let m = ModelManager()
            m.modelStates["parakeet-tdt-0.6b-v3"] = .downloading
            m.downloadProgress["parakeet-tdt-0.6b-v3"] = 0.34
            return m
        }(),
        modelIdentifier: "parakeet-tdt-0.6b-v3",
        context: .onboarding,
        isPresented: .constant(true)
    )
    .preferredColorScheme(.light)
}

#Preview("Compiling — dark") {
    ModelLoadingOverlay(
        modelManager: {
            let m = ModelManager()
            m.modelStates["openai_whisper-large-v3-v20240930_turbo_632MB"] = .prewarming
            return m
        }(),
        modelIdentifier: "openai_whisper-large-v3-v20240930_turbo_632MB",
        isPresented: .constant(true)
    )
    .preferredColorScheme(.dark)
}
