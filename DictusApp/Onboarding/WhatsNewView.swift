// DictusApp/Onboarding/WhatsNewView.swift
// What's new for existing users: the onboarding's feature scenes and how to stop Dictus (#685).
import SwiftUI
import DictusCore

/// What's new (#685, #649 decisions 11, 12 and 19): shown once, at the first launch of 2.0.0,
/// to an install that completed onboarding on an earlier version. It replays the
/// onboarding's own pages, without the setup steps: the Smart Modes, voice notes,
/// vocabulary and history scenes, then how to stop Dictus, the question existing users ask
/// most. Which pages, and who sees them, is `WhatsNew` in DictusCore.
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
    /// `WhatsNew.steps(deviceCanRunSmartModes:device:)`, never empty.
    let steps: [OnboardingStep]
    /// The app's model manager, read by the scene pages' download pill.
    @ObservedObject var modelManager: ModelManager
    /// The active model, the one the pill would show downloading.
    let modelIdentifier: String
    /// The last page was left, by its button or by a Skip with nothing after it.
    let onFinish: () -> Void

    @State private var step: OnboardingStep

    init(steps: [OnboardingStep],
         modelManager: ModelManager,
         modelIdentifier: String,
         onFinish: @escaping () -> Void) {
        self.steps = steps
        self.modelManager = modelManager
        self.modelIdentifier = modelIdentifier
        self.onFinish = onFinish
        _step = State(initialValue: steps.first ?? .stopStandby)
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
                // A scene's Skip jumps the scenes, as in the onboarding (#649 decision 8).
                .environment(\.onboardingSkip, step.isInSceneSequence ? OnboardingSkipAction(perform: skip) : nil)
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                .id(step)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .onAppear {
            // Recorded once it is on screen, so it is shown once even if the app is closed
            // halfway through, and never recorded by a launch that could not show it.
            WhatsNew.recordSeen()
            PersistentLog.log(.diagnosticProbe(
                component: "whatsNew", instanceID: "0", action: "shown",
                details: "steps=\(steps.map(\.rawValue).joined(separator: ","))"
            ))
        }
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
        case .stopStandby:
            StopStandbyPage(onNext: advance)
        case .welcome, .language, .keyboardSetup, .appleIntelligence, .smartModePick, .modelPreparation,
             .microphone, .firstDictation, .completion:
            // Setup steps: never in `WhatsNew.steps`.
            EmptyView()
        }
    }

    private func advance() {
        guard let next = WhatsNew.next(after: step, in: steps) else {
            finish(action: "finished")
            return
        }
        step = next
    }

    private func skip() {
        guard let next = WhatsNew.stepAfterScenes(from: step, in: steps) else {
            finish(action: "skipped")
            return
        }
        PersistentLog.log(.diagnosticProbe(
            component: "whatsNew", instanceID: "0", action: "scenesSkipped",
            details: "from=\(step.rawValue) to=\(next.rawValue)"
        ))
        step = next
    }

    private func finish(action: String) {
        PersistentLog.log(.diagnosticProbe(
            component: "whatsNew", instanceID: "0", action: action, details: "last=\(step.rawValue)"
        ))
        onFinish()
    }
}
