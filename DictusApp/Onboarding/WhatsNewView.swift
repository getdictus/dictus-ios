// DictusApp/Onboarding/WhatsNewView.swift
// What's new for existing users: the onboarding's four feature scenes (#685).
import SwiftUI
import DictusCore

/// What's new (#685, #649 decisions 11 and 12): shown once, at the first launch of 2.0.0, to
/// an install that completed onboarding on an earlier version. It replays the onboarding's
/// own pages, without the setup steps: the Smart Modes, voice notes, vocabulary and history
/// scenes. How to stop Dictus is not part of it (Pierre, 2026-10-14): it is not new. Which
/// pages, and who sees them, is `WhatsNew` in DictusCore.
///
/// WHY THE ONBOARDING'S PAGES AND NOT COPIES: decision 12, one feature-scene component for
/// the onboarding, What's new and the hub. The pages already carry the shell's Next and
/// Skip, and the scenes follow the system appearance and language.
///
/// WHY MAINTABVIEW SHOWS IT IN PLACE OF THE TABS, NOT AS A COVER: the trial announcement
/// comes right after it (decision 11), as a sheet on the tabs. With the tabs gone while
/// What's new is up, the announcement cannot be raised over it, and the tabs' `onAppear`
/// raises it once What's new is done. A cover would also have to wait for its own
/// dismissal before the sheet could go up.
struct WhatsNewView: View {
    /// `WhatsNew.steps(deviceCanRunSmartModes:)`, never empty.
    let steps: [OnboardingStep]
    /// The app's model manager, read by the scene pages' download pill.
    @ObservedObject var modelManager: ModelManager
    /// The active model, the one the pill would show downloading.
    let modelIdentifier: String
    /// What's new was left: Next on the last scene, or Skip on any.
    let onFinish: () -> Void

    @State private var step: OnboardingStep

    /// Whether this presentation has recorded What's new as seen.
    @State private var isRecorded = false

    @Environment(\.scenePhase) private var scenePhase

    init(steps: [OnboardingStep],
         modelManager: ModelManager,
         modelIdentifier: String,
         onFinish: @escaping () -> Void) {
        self.steps = steps
        self.modelManager = modelManager
        self.modelIdentifier = modelIdentifier
        self.onFinish = onFinish
        _step = State(initialValue: steps.first ?? .smartModesScene)
    }

    var body: some View {
        ZStack {
            Color.dictusBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.top, OnboardingMetrics.topBarTopPadding)

                Group {
                    page
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // WHY `geometryGroup` (Pierre's device test of PR #741): without it, the page
                // coming in had its title and drawn phone, which a scene page lays out through
                // `ViewThatFits` and a `GeometryReader`, drawn straight at their final place,
                // while only its button slid in. The two pages overlapped for the length of
                // the slide. Captured frame by frame on the simulator; the same pages slide
                // whole in the onboarding's cover, so the onboarding is left as it is. The
                // group resolves the page's geometry as one block, which the slide then moves.
                .geometryGroup()
                // A scene's Skip jumps the scenes, as in the onboarding (#649 decision 8),
                // which here is the whole of What's new.
                .environment(\.onboardingSkip, step.isInSceneSequence ? OnboardingSkipAction(perform: skip) : nil)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .id(step)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .onAppear { recordSeenIfOnScreen() }
        .onChange(of: scenePhase) { _, _ in recordSeenIfOnScreen() }
    }

    /// Records What's new as seen once it is really in front of the user: on screen and the
    /// app active. Then it is shown once even if the app is closed halfway through.
    ///
    /// WHY NOT ON APPEAR ALONE (CodeRabbit on PR #741): a view appears in a launch the user
    /// does not see yet, and a URL opening the app is handled before it becomes active.
    /// Waiting for `.active` lets that URL withdraw What's new unrecorded
    /// (`MainTabView.onOpenURL`), so it is still due at the next activation.
    private func recordSeenIfOnScreen() {
        guard scenePhase == .active, !isRecorded else { return }
        isRecorded = true
        WhatsNew.recordSeen()
        PersistentLog.log(.diagnosticProbe(
            component: "whatsNew", instanceID: "0", action: "shown",
            details: "steps=\(steps.map(\.rawValue).joined(separator: ","))"
        ))
    }

    /// The onboarding's top row, without a back control: the progress bar over What's new's
    /// own pages, between two empty slots so it sits where the onboarding's does.
    private var topBar: some View {
        HStack(spacing: 16) {
            Color.clear
                .frame(width: OnboardingMetrics.topBarHeight)
            if steps.count > 1 {
                OnboardingProgressBar(segmentCount: steps.count, current: steps.firstIndex(of: step) ?? 0)
            } else {
                Spacer()
            }
            Color.clear
                .frame(width: OnboardingMetrics.topBarHeight)
        }
        .frame(height: OnboardingMetrics.topBarHeight)
        .padding(.horizontal, OnboardingMetrics.horizontalPadding)
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .smartModesScene:
            SmartModesScenePage(
                eyebrow: Text("New in Dictus",
                              comment: "What's new for existing users: small label above the title of its first page, the Smart Modes scene (#685)."),
                modelManager: modelManager,
                modelIdentifier: modelIdentifier,
                onNext: advance
            )
        case .voiceNotesScene:
            VoiceNotesScenePage(modelManager: modelManager, modelIdentifier: modelIdentifier, onNext: advance)
        case .vocabularyScene:
            VocabularyScenePage(modelManager: modelManager, modelIdentifier: modelIdentifier, onNext: advance)
        case .historyScene:
            HistoryScenePage(modelManager: modelManager, modelIdentifier: modelIdentifier, onNext: advance)
        case .welcome, .language, .keyboardSetup, .appleIntelligence, .smartModePick, .modelPreparation,
             .microphone, .firstDictation, .stopStandby, .completion:
            // Never in `WhatsNew.steps`: the setup steps, and how to stop Dictus.
            EmptyView()
        }
    }

    private func advance() {
        guard let next = WhatsNew.next(after: step, in: steps) else {
            finish(action: "finished")
            return
        }
        // In an explicit animation, as `OnboardingView.show` does.
        withAnimation {
            step = next
        }
    }

    /// Every page is a scene, so Skip leaves What's new, as it leaves the scene sequence in
    /// the onboarding.
    private func skip() {
        finish(action: "skipped")
    }

    private func finish(action: String) {
        PersistentLog.log(.diagnosticProbe(
            component: "whatsNew", instanceID: "0", action: action, details: "last=\(step.rawValue)"
        ))
        onFinish()
    }
}
