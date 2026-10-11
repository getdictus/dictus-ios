// DictusApp/Onboarding/AppleIntelligencePage.swift
// Onboarding step: get Apple Intelligence ready by matching Siri's language, when it is
// not ready (#683).
import SwiftUI
import UIKit
import DictusCore

/// Tells the user how to get Apple Intelligence ready, which the Smart Modes run on.
///
/// Shown only on a capable iPhone where Apple Intelligence is not ready (#649 decision 7,
/// `AppleIntelligenceOnboarding.isStepNeeded`); `OnboardingView` passes over it otherwise.
///
/// WHY THE SIRI LANGUAGE IS THE INSTRUCTION (decided 2026-10-10, after the first device
/// test): Apple Intelligence stays off while Siri speaks another language than the iPhone,
/// and Apple reports that as `modelNotReady`. On iOS 27 there is no Apple Intelligence
/// switch at all: matching the languages is what turns it on. The first version of this
/// page sent the user looking for a switch that was already on, and kept the language as
/// a side warning.
///
/// WHY A DRAWN SETTINGS PAGE: there is no public deep link to Siri's settings, and private
/// `App-Prefs:` URLs get apps rejected. The only link an app may open is its own settings
/// page (`openSettingsURLString`), so the page draws the way from the Settings root, in the
/// keyboard step's style: numbered rows, lit in turn on a loop. The root row is the one
/// the running iOS shows (`AppleIntelligenceOnboarding.settingsRoute`).
///
/// WHY ONE PAGE FOR EVERY "NOT READY" REASON: the reason cannot be trusted to pick the
/// copy (a language mismatch and a switched-off Apple Intelligence both read as
/// `modelNotReady`), so the text covers the language, the switch where iOS 26 has one,
/// and that Apple then downloads its model.
///
/// WHY NO DURATION: Apple's model is up to several GB and takes from minutes to hours.
/// Any number would be wrong for someone, so the page says "sometimes a long time" and
/// re-checks when the user comes back.
///
/// WHY A DIFFERENT SCREEN ON RETURN (decided 2026-10-11, after the second device test):
/// coming back from Settings with Apple Intelligence still setting up used to show the
/// very same page, which read as "it did not work". A return now shows ready, or a calm
/// "getting ready" screen that lets the user go on and re-checks quietly. A fifteen-second
/// countdown was tried first and dropped after the next device test: it only added a wait.
/// The rules are `AppleIntelligenceStepState`. Nothing advances on its own.
///
/// WHY "LATER" IS AS LARGE AS THE MAIN BUTTON: dictation does not need Apple Intelligence.
/// The step must never feel like a gate, so leaving it is as easy as following it.
struct AppleIntelligencePage: View {
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding is downloading, for the progress pill.
    let modelIdentifier: String
    let onNext: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    /// What the page shows: the instructions, the check on return, ready, or setting up
    /// (`AppleIntelligenceStepState`, #683). Built from the first read in `onAppear`.
    @State private var state = AppleIntelligenceStepState(isAvailable: false)

    /// The reads after a return: one `returnRecheckDelay` later, then every
    /// `settingUpRecheckInterval` while the setting-up screen is up and the app active.
    @State private var checkTask: Task<Void, Never>?

    /// Which drawn Settings screen the loop shows, and which of its numbered rows is lit
    /// (0: none).
    @State private var screen: DrawnScreen = .root
    @State private var litStep = 0
    @State private var animationTimer: Timer?
    /// True while the loop goes back to the root: a crossfade, not a push from the trailing
    /// edge, which would read as a fourth screen.
    @State private var isRewinding = false

    /// Where Siri's language lives on this iOS. It cannot change while the page is up.
    private let route = AppleIntelligenceOnboarding.settingsRoute

    var body: some View {
        Group {
            switch state.phase {
            case .instructions, .ready:
                instructionsPage
            case .settingUp:
                settingUpPage
            }
        }
        .onAppear {
            let engineState = PolishAvailability.state
            logCheck(trigger: "appear", engineState: engineState)
            state = AppleIntelligenceStepState(isAvailable: engineState == .available)
            startAnimation()
        }
        .onDisappear {
            stopCheck()
            animationTimer?.invalidate()
            animationTimer = nil
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else {
                stopCheck()
                return
            }
            // Back on the step, from Settings or after a relaunch on it: ready, or the
            // getting-ready screen, so the user does not find the same page and conclude
            // it failed (device test of 2026-10-11).
            let engineState = PolishAvailability.state
            logCheck(trigger: "active", engineState: engineState)
            let transition = state.appBecameActive(isAvailable: engineState == .available, at: Date())
            log(transition, engineState: engineState)
            if state.rechecksQuietly { runRechecks() }
        }
        .animation(.easeInOut(duration: 0.3), value: state.phase)
    }

    // MARK: - Instructions (first visit) and ready

    private var instructionsPage: some View {
        OnboardingPage(
            title: Text("Set Siri's language"),
            subtitle: Text("Smart Modes run on Apple Intelligence, which turns on only when Siri speaks your iPhone's language. Dictation already works without it.")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                settingsIllustration

                if state.phase == .ready {
                    readyLabel
                } else {
                    guidance
                }
            }
        } bottom: {
            OnboardingDownloadPill(modelManager: modelManager, modelIdentifier: modelIdentifier)

            if state.phase == .ready {
                OnboardingPrimaryButton(Text("Continue"), action: onNext)
                    .accessibilityIdentifier("onboarding.primary")
                    .transition(.opacity)
            } else {
                OnboardingPrimaryButton(Text("Open Settings"), action: openSettings)
                    .accessibilityIdentifier("onboarding.openSettings")
                    .transition(.opacity)
                OnboardingSecondaryButton(Text("Later"), action: later)
                    .accessibilityIdentifier("onboarding.later")
                    .transition(.opacity)
            }
        }
    }

    private var readyLabel: some View {
        Label("Apple Intelligence is ready", systemImage: "checkmark.circle.fill")
            .font(.body.weight(.medium))
            .foregroundStyle(Color.dictusSuccess)
            .frame(maxWidth: .infinity)
            .transition(.opacity)
    }

    // MARK: - Setting up

    /// Back in the app and Apple Intelligence not available. Calm on purpose: nothing
    /// failed that the user can see, Apple finishes in the background, and the onboarding
    /// goes on. No duration is promised. It turns ready on its own if a quiet re-read finds
    /// Apple Intelligence available.
    ///
    /// WHY THE LANGUAGE HINT STAYS: the copy cannot depend on the reason, and a language
    /// that still does not match is one of the reasons. It is the one thing to check if
    /// Smart Modes never come.
    private var settingUpPage: some View {
        OnboardingCenteredPage(
            title: Text("Apple Intelligence is getting ready"),
            message: Text("It finishes setting up in the background. Smart Modes will work as soon as it is ready. You can go on.")
        ) {
            SettingUpHalo()
        } bottom: {
            Text("If Smart Modes stay unavailable, check that Siri speaks your iPhone's language.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            OnboardingDownloadPill(modelManager: modelManager, modelIdentifier: modelIdentifier)
            OnboardingPrimaryButton(Text("Continue"), action: continueWhileSettingUp)
                .accessibilityIdentifier("onboarding.primary")
            OnboardingSecondaryButton(Text("See the steps again"), action: showStepsAgain)
                .accessibilityIdentifier("onboarding.seeStepsAgain")
        }
    }

    // MARK: - Guidance

    /// The lines under the drawing: where the button lands, the search shortcut, the
    /// iOS 26 switch, and the wait. Same copy whatever the reason.
    private var guidance: some View {
        VStack(alignment: .leading, spacing: 8) {
            // WHY SAY WHERE THE BUTTON LANDS: it opens Dictus's own page (Settings > Apps >
            // Dictus), two levels below the root the drawing starts from. On the first
            // device test that page was read as the place to look.
            Text("Open Settings lands on Dictus's page: go back to the main Settings screen first. Shortcut: search “Apple Intelligence” in Settings.")
            if route.hasAppleIntelligenceSwitch {
                Text("If the page shows an Apple Intelligence switch, turn it on too.")
            }
            Text("Apple then downloads its model, sometimes for a long time. Dictus checks again when you come back.")
                .foregroundStyle(.tertiary)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Drawn Settings

    /// The three drawn screens, in the order the user walks them.
    private enum DrawnScreen {
        /// The Settings root, with the Siri row (1).
        case root
        /// The Siri page, with its Language row (2).
        case siri
        /// Siri's language list, with the iPhone's language (3).
        case languages
    }

    /// The top of an iPhone in a card, showing the current drawn screen.
    private var settingsIllustration: some View {
        OnboardingPhoneCard {
            ZStack(alignment: .topLeading) {
                switch screen {
                case .root: rootScreen.transition(screenTransition)
                case .siri: siriScreen.transition(screenTransition)
                case .languages: languagesScreen.transition(screenTransition)
                }
            }
            // One height for the three screens, so the card does not jump between them.
            // Sized to the tallest screen, so the guidance under the card stays in view
            // above the buttons on a 6.1" iPhone.
            .frame(height: 196, alignment: .topLeading)
            .clipped()
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 16)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    /// Settings' push: the next screen slides in from the trailing edge.
    private var screenTransition: AnyTransition {
        isRewinding ? .opacity : .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
    }

    private var rootScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                skeletonRow
                Divider().padding(.leading, 56)
                skeletonRow
                Divider().padding(.leading, 56)
                HStack(spacing: 12) {
                    OnboardingStepBadge(number: 1, isLit: litStep == 1)
                    DictusIconTileSymbol(systemName: Self.siriSymbol, fill: Self.siriTileGradient)
                    routeLabel
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    chevron
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dictusAccent.opacity(litStep == 1 ? 0.12 : 0))
            }
            .onboardingSettingsGroup()
        }
        .font(.body)
    }

    private var siriScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            backLabel(Text("Settings"))
            routeTitle
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                // iOS 27 puts Requests above Language; iOS 26 opens on Language. Either
                // way the row to touch is the language, the others stay blank.
                if route == .siri {
                    skeletonTextRow
                    Divider().padding(.leading, 14)
                }
                HStack(spacing: 12) {
                    OnboardingStepBadge(number: 2, isLit: litStep == 2)
                    Text("Language")
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    skeletonBar(width: 70)
                    chevron
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dictusAccent.opacity(litStep == 2 ? 0.12 : 0))
                Divider().padding(.leading, 14)
                skeletonTextRow
            }
            .onboardingSettingsGroup()
        }
        .font(.body)
    }

    private var languagesScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            backLabel(Text(verbatim: "Siri"))
            Text("Language")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                skeletonTextRow
                Divider().padding(.leading, 14)
                HStack(spacing: 12) {
                    OnboardingStepBadge(number: 3, isLit: litStep == 3)
                    Text(verbatim: Self.iPhoneLanguageName)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.dictusAccent)
                        .opacity(litStep == 3 ? 1 : 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dictusAccent.opacity(litStep == 3 ? 0.12 : 0))
                Divider().padding(.leading, 14)
                skeletonTextRow
            }
            .onboardingSettingsGroup()
        }
        .font(.body)
    }

    /// The root row's name on this iOS: *Siri* on iOS 27, *Apple Intelligence & Siri*
    /// before.
    private var routeLabel: Text {
        switch route {
        case .siri: return Text(verbatim: "Siri")
        case .appleIntelligenceAndSiri: return Text("Apple Intelligence & Siri")
        }
    }

    /// The Siri page's title: the root row's name, as large as the language list's.
    private var routeTitle: some View {
        routeLabel
            .font(.title2.weight(.bold))
    }

    private func backLabel(_ title: Text) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
            title
        }
        .font(.body)
        .foregroundStyle(Color.dictusAccent)
        .padding(.bottom, 10)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
    }

    /// A row of another setting, drawn blank: an icon tile and a bar. The rows around the
    /// one to touch differ by iOS version and language, so they are not written out.
    private var skeletonRow: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 26, height: 26)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.10))
                .frame(width: 30, height: 30)
            skeletonBar(width: 110)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// A blank row without an icon, as on the Siri page and the language list.
    private var skeletonTextRow: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: 26, height: 26)
            skeletonBar(width: 120)
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func skeletonBar(width: CGFloat) -> some View {
        Capsule()
            .fill(Color.primary.opacity(0.10))
            .frame(width: width, height: 10)
    }

    /// Settings' Siri glyph where the system has it (SF Symbols 6, iOS 18), sparkles
    /// before. A missing symbol would draw an empty tile.
    private static let siriSymbol =
        UIImage(systemName: "apple.intelligence") != nil ? "apple.intelligence" : "sparkles"

    /// The multicolour tile Settings draws for this row on iOS 26 and 27.
    private static let siriTileGradient = LinearGradient(
        colors: [Color(hex: 0xF5A623), Color(hex: 0xF0508C), Color(hex: 0xA65CF0), Color(hex: 0x3D9BFF)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The iPhone's language as Siri's list writes it ("Français (France)", "English
    /// (United States)"): the value the user has to pick.
    private static var iPhoneLanguageName: String {
        let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        let name = Locale.current.localizedString(forIdentifier: identifier) ?? identifier
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    private var accessibilitySummary: Text {
        switch route {
        case .siri:
            return Text("In Settings, open Siri, then Language, and choose your iPhone's language.")
        case .appleIntelligenceAndSiri:
            return Text("In Settings, open Apple Intelligence & Siri, then Language, and choose your iPhone's language.")
        }
    }

    // MARK: - Animation loop

    /// A repeating cycle (~7 s per loop) that walks the three screens, like the keyboard
    /// step's loop:
    ///
    /// 0.0 s → the root, nothing lit
    /// 0.6 s → 1 lit: the Siri row
    /// 1.8 s → the Siri page slides in
    /// 2.4 s → 2 lit: Language
    /// 3.6 s → the language list slides in
    /// 4.2 s → 3 lit: the iPhone's language, checked
    /// 7.0 s → restart
    private func startAnimation() {
        animationTimer?.invalidate()
        runAnimationCycle()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            runAnimationCycle()
        }
    }

    private func runAnimationCycle() {
        isRewinding = true
        withAnimation(.easeInOut(duration: 0.35)) {
            screen = .root
            litStep = 0
        }
        let steps: [(TimeInterval, () -> Void)] = [
            (0.4, { isRewinding = false }),
            (0.6, { litStep = 1 }),
            (1.8, { screen = .siri; litStep = 0 }),
            (2.4, { litStep = 2 }),
            (3.6, { screen = .languages; litStep = 0 }),
            (4.2, { litStep = 3 })
        ]
        for (delay, change) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // Stopped with the page: a step already scheduled must not run after it.
                guard animationTimer != nil else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    change()
                }
            }
        }
    }

    // MARK: - Re-checks

    /// After a return: a second read `returnRecheckDelay` later (a language just changed
    /// may not show yet), then a read every `settingUpRecheckInterval` for as long as the
    /// setting-up screen is up. Stopped when the app leaves the foreground or the page
    /// disappears, and restarted by the next return.
    private func runRechecks() {
        stopCheck()
        checkTask = Task { @MainActor in
            var delay = AppleIntelligenceStepState.returnRecheckDelay
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, state.rechecksQuietly else { return }
                let engineState = PolishAvailability.state
                logCheck(trigger: "recheck", engineState: engineState)
                log(state.availabilityRead(isAvailable: engineState == .available, at: Date()), engineState: engineState)
                delay = AppleIntelligenceStepState.settingUpRecheckInterval
            }
        }
    }

    private func stopCheck() {
        checkTask?.cancel()
        checkTask = nil
    }

    // MARK: - Logs

    private func logCheck(trigger: String, engineState: PolishAvailabilityState) {
        PersistentLog.log(.onboardingAppleIntelligenceChecked(trigger: trigger, state: String(describing: engineState)))
    }

    private func log(_ transition: AppleIntelligenceStepState.Transition?, engineState: PolishAvailabilityState) {
        guard let transition else { return }
        let engine = String(describing: engineState)
        switch transition {
        case .settingUpShown:
            PersistentLog.log(.onboardingAppleIntelligenceSettingUpShown(state: engine))
        case .becameAvailable(let afterSeconds):
            PersistentLog.log(.onboardingAppleIntelligenceBecameAvailable(afterSeconds: afterSeconds ?? -1))
        }
    }

    // MARK: - Actions

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func later() {
        stopCheck()
        PersistentLog.log(.onboardingAppleIntelligenceDeferred(state: String(describing: PolishAvailability.state)))
        onNext()
    }

    /// Continue on the setting-up screen: the user goes on while Apple finishes. Logged
    /// like Later, since Apple Intelligence is still not ready.
    private func continueWhileSettingUp() {
        later()
    }

    private func showStepsAgain() {
        stopCheck()
        state.showInstructionsAgain()
        startAnimation()
    }
}

// MARK: - Setting-up visuals

/// The setting-up screen's illustration: the Apple Intelligence glyph in the app's pale
/// rings, like the microphone step's halo.
private struct SettingUpHalo: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.dictusAccent.opacity(0.08))
                .frame(width: 200, height: 200)
            Circle()
                .fill(Color.dictusAccent.opacity(0.12))
                .frame(width: 140, height: 140)
            Image(systemName: UIImage(systemName: "apple.intelligence") != nil ? "apple.intelligence" : "sparkles")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Color.dictusAccent)
        }
        .accessibilityHidden(true)
    }
}
