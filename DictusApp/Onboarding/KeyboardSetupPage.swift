// DictusApp/Onboarding/KeyboardSetupPage.swift
// Onboarding step: guide the user to add the Dictus keyboard, with auto-detection.
import SwiftUI
import UIKit
import DictusCore

/// Guides the user through adding the Dictus keyboard in iOS Settings.
///
/// WHY a drawn Settings page:
/// Users need to enable two toggles in iOS Settings (add keyboard + Full Access).
/// A visual simulation showing exactly what to toggle reduces friction and support
/// requests. Since the shell (#675) it is drawn as the mock-up draws it: the top of an
/// iPhone, cropped, showing Settings > Apps > Dictus with the three things to touch
/// numbered 1, 2, 3, and the current one lit in turn on a loop. Only iOS system UI is
/// drawn this way (#649 decision 13). The Picture in Picture checklist over the real
/// Settings is #682's.
struct KeyboardSetupPage: View {
    let onNext: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var keyboardDetected = false

    /// Guard to prevent concurrent keyboard checks (race condition on Settings return).
    /// WHY this guard: When returning from iOS Settings after enabling the keyboard,
    /// scenePhase can change rapidly (.inactive -> .active). Without this guard,
    /// multiple concurrent calls to checkKeyboardInstalled() race and can crash
    /// when accessing UITextInputMode.activeInputModes.
    @State private var isCheckingKeyboard = false

    /// Cancellable task for the delayed keyboard check.
    /// WHY @State Task?:
    /// The previous code spawned a `Task { ... }` without storing it, so the
    /// task kept running even after the view disappeared. Storing the task lets
    /// us cancel it on .onDisappear to avoid UI updates against a dead view.
    @State private var keyboardCheckTask: Task<Void, Never>?

    /// Which of the three numbered Settings controls the loop is pointing at: 1 the
    /// Keyboards row, 2 the Dictus switch, 3 the Full Access switch, 0 none (the loop's
    /// reset, and the final state once the keyboard is detected).
    @State private var litSettingsStep = 0
    @State private var dictusToggleOn = false
    @State private var fullAccessToggleOn = false
    @State private var animationTimer: Timer?

    /// The device's capabilities, read once: only the hardware identifier is used, and
    /// it cannot change while the page is on screen.
    private let device = DeviceCapabilities.current()

    var body: some View {
        OnboardingPage(
            title: Text("Turn on the keyboard"),
            subtitle: Text("In Settings, open Keyboards, then turn on Dictus and Full Access.")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                settingsIllustration

                detectionStatus

                if !device.supportsKeyboardDictation {
                    keyboardDictationNotice
                }
            }
        } bottom: {
            Text("Nothing you type leaves your iPhone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // One button, two jobs: it opens Settings until the keyboard is detected, then
            // moves on. The mock-up draws the first; the second replaces the old page's
            // separate Continue, which sat hidden until the detection.
            if keyboardDetected {
                OnboardingPrimaryButton(Text("Continue"), action: onNext)
                    .accessibilityIdentifier("onboarding.primary")
                    .transition(.opacity)
            } else {
                OnboardingPrimaryButton(Text("Open Settings"), action: openSettings)
                    .accessibilityIdentifier("onboarding.openSettings")
                    .transition(.opacity)
            }
        }
        .onAppear {
            checkKeyboardInstalled()
            startToggleAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
            // Cancel any pending keyboard check task to prevent UI updates
            // after the view has disappeared (potential crash source).
            keyboardCheckTask?.cancel()
            keyboardCheckTask = nil
        }
        .onChange(of: scenePhase) { newPhase in
            // WHY debounced check with 800ms delay:
            // When returning from iOS Settings, scenePhase fires .active before
            // UITextInputMode.activeInputModes has updated. The 800ms delay gives
            // iOS more time to register the newly-enabled keyboard. A second retry
            // at 2s catches slow Settings sync.
            PersistentLog.log(.onboardingScenePhaseChanged(phase: "\(newPhase)"))

            // WHY cancel on inactive: Scene transitions during Settings return
            // can fire rapidly (active → inactive → active). Cancel any in-flight
            // check when we go inactive to avoid stale tasks mutating state
            // after the view has been torn down or re-entered.
            if newPhase != .active {
                keyboardCheckTask?.cancel()
                keyboardCheckTask = nil
                isCheckingKeyboard = false
                return
            }

            guard !isCheckingKeyboard else {
                PersistentLog.log(.onboardingKeyboardCheckSkipped(reason: "alreadyChecking"))
                return
            }
            isCheckingKeyboard = true

            // Cancel any previous task before starting a new one
            keyboardCheckTask?.cancel()
            keyboardCheckTask = Task {
                // First check at 800ms
                try? await Task.sleep(for: .milliseconds(800))
                // Bail out if the task was cancelled (view disappeared or phase changed)
                if Task.isCancelled { return }
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    checkKeyboardInstalled()
                }

                // If not detected, retry at 2s (covers slow Settings sync)
                if !keyboardDetected && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(1200))
                    if Task.isCancelled { return }
                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        PersistentLog.log(.onboardingKeyboardRetry)
                        checkKeyboardInstalled()
                        isCheckingKeyboard = false
                    }
                } else {
                    await MainActor.run {
                        isCheckingKeyboard = false
                    }
                }
            }
            #if DEBUG
            print("[KeyboardSetupPage] scenePhase changed to: \(newPhase)")
            #endif
        }
        .onChange(of: keyboardDetected) { detected in
            if detected {
                // Stop animation loop once detected
                animationTimer?.invalidate()
                animationTimer = nil
                // Both switches on, nothing lit: the final success state.
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    litSettingsStep = 0
                    dictusToggleOn = true
                    fullAccessToggleOn = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: keyboardDetected)
    }

    // MARK: - Detection status

    /// Under the drawing: what happens next, then the confirmation once it has.
    ///
    /// WHY THE RESTART LINE STAYS: when the user enables "Allow Full Access", iOS's TCC
    /// daemon terminates Dictus to enforce the new permission. That looks like a crash;
    /// saying it is expected prevents support tickets and anxiety. The onboarding resumes
    /// on this step (`OnboardingStep` is persisted).
    @ViewBuilder
    private var detectionStatus: some View {
        if keyboardDetected {
            Label("Keyboard detected", systemImage: "checkmark.circle.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(Color.dictusSuccess)
                .frame(maxWidth: .infinity)
                .transition(.opacity)
        } else {
            VStack(spacing: 4) {
                Text("The keyboard will be detected automatically")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Dictus may restart on its own. This is normal.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
            // Never truncated (#635): with the pre-A14 notice below, this page is tight
            // in a 667 pt window.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Pre-A14 notice (#635)

    /// Tells a pre-A14 user, before they finish onboarding, that the keyboard they are
    /// adding will type but not dictate, and that dictating in the app still works.
    ///
    /// WHY here: this is the page that introduces the keyboard, so the limit is read
    /// at the moment the user decides what the keyboard is for, not discovered later
    /// as a greyed mic. Kept to one block that the onboarding rebuild (#649) can carry
    /// over as it is.
    ///
    /// WHY the device word comes from the hardware identifier and not
    /// `userInterfaceIdiom`: DictusApp is iPhone-only and runs on an iPad in
    /// compatibility mode, where the idiom reports `.phone` (same rule as
    /// `IncompatibilityReason.localizedText`, #612).
    private var keyboardDictationNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.dictusBody)
                .foregroundColor(.dictusAccent)

            Text(device.deviceModelIdentifier.hasPrefix("iPad")
                 ? String(
                    localized: "Because of its chip, this iPad cannot dictate from the keyboard. Dictation inside the Dictus app works.",
                    comment: "Onboarding notice on the keyboard setup page, shown only on an iPad whose chip predates the A14 (#635)."
                 )
                 : String(
                    localized: "Because of its chip, this iPhone cannot dictate from the keyboard. Dictation inside the Dictus app works.",
                    comment: "Onboarding notice on the keyboard setup page, shown only on an iPhone whose chip predates the A14 (#635)."
                 ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .onboardingCard(cornerRadius: 16)
    }

    // MARK: - Drawn Settings page

    /// The top of an iPhone showing Settings > Apps > Dictus, cropped at the bottom, inside
    /// a card (#675 mock-up `03-clavier-dans-les-reglages`).
    ///
    /// WHY THE KEYBOARDS ROW AND THE SWITCHES ON ONE PAGE: in Settings they are two pages,
    /// Dictus then Keyboards. Drawn side by side as two numbered groups, the three things to
    /// touch are seen at once, in order, which is what the old two-phase slide tried to say
    /// in seven seconds.
    private var settingsIllustration: some View {
        let phoneShape = UnevenRoundedRectangle(topLeadingRadius: 44, topTrailingRadius: 44, style: .continuous)
        let cardShape = UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                Text(verbatim: "Apps")
            }
            .font(.body)
            .foregroundStyle(Color.dictusAccent)
            .padding(.bottom, 12)

            Text(verbatim: "Dictus")
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.bottom, 16)

            OnboardingSectionLabel(text: Text("Allow Dictus to access"))
                .padding(.leading, 4)
                .padding(.bottom, 6)

            settingsGroup {
                HStack(spacing: 12) {
                    DictusIconTileSymbol(systemName: "keyboard", fill: .gray)
                    stepBadge(1)
                    Text("Keyboards")
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.dictusAccent.opacity(litSettingsStep == 1 ? 0.12 : 0))
            }
            .padding(.bottom, 16)

            OnboardingSectionLabel(text: Text("Keyboards"))
                .padding(.leading, 4)
                .padding(.bottom, 6)

            settingsGroup {
                VStack(spacing: 0) {
                    switchRow(step: 2, label: Text(verbatim: "Dictus"), isOn: dictusToggleOn)
                    Divider()
                        .padding(.leading, 50)
                    switchRow(step: 3, label: Text("Allow full access"), isOn: fullAccessToggleOn)
                }
            }

            // Why Full Access is asked for. Only where it is true: a pre-A14 keyboard has
            // no microphone (#635), and the notice below the drawing says so.
            if device.supportsKeyboardDictation {
                Text("Full Access is for the keyboard's microphone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 4)
                    .padding(.top, 8)
            }
        }
        .font(.body)
        .padding(.horizontal, 22)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        // The phone is drawn taller than the card (`padding(.bottom, -24)`) so the crop
        // below cuts through it: no bottom edge, the phone runs off the card.
        .background(phoneShape.fill(Color.dictusBackground).padding(.bottom, -24))
        .overlay(phoneShape.strokeBorder(Self.phoneFrame, lineWidth: 7).padding(.bottom, -24))
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .background(cardShape.fill(Color.dictusSurface))
        // Cropped at the bottom like the mock-up: rounded on top, cut straight below.
        .clipShape(cardShape)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("In Settings, open Keyboards, then turn on Dictus and Full Access."))
    }

    /// The phone's outline: a light grey on light, a slate on dark.
    private static let phoneFrame = Color(light: Color(hex: 0xD1D1D6), dark: Color(hex: 0x2A3346))

    /// A white (or dark surface) inset group, as in Settings.
    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(Color.dictusSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// A numbered row with a switch.
    private func switchRow(step: Int, label: Text, isOn: Bool) -> some View {
        HStack(spacing: 12) {
            stepBadge(step)
            label
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            DrawnSwitch(isOn: isOn, isLit: litSettingsStep == step)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// The step number in a circle: accent while it is the step the loop points at, grey
    /// otherwise.
    private func stepBadge(_ step: Int) -> some View {
        let isLit = litSettingsStep == step
        return Text(verbatim: "\(step)")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isLit ? Color.white : Color.secondary)
            .frame(width: 26, height: 26)
            .background(Circle().fill(isLit ? Color.dictusAccent : Color.primary.opacity(0.08)))
            .animation(.easeInOut(duration: 0.25), value: isLit)
    }

    // MARK: - Animation Loop

    /// Starts a repeating cycle (~6s per loop) that points at the three controls in order:
    ///
    /// 0.0s → Reset: nothing lit, both switches off
    /// 0.8s → 1 lit: the Keyboards row
    /// 2.0s → 2 lit, the Dictus switch turns on
    /// 3.2s → 3 lit, the Full Access switch turns on
    /// 4.6s → Nothing lit, hold the final state
    /// 6.0s → Restart cycle
    private func startToggleAnimation() {
        // Resumed after the Full Access kill with the keyboard already there: the final
        // state is the whole picture, and a loop would switch the toggles back off.
        guard !keyboardDetected else { return }
        resetAnimationState()
        runAnimationCycle()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            guard !keyboardDetected else { return }
            resetAnimationState()
            runAnimationCycle()
        }
    }

    private func resetAnimationState() {
        litSettingsStep = 0
        dictusToggleOn = false
        fullAccessToggleOn = false
    }

    private func runAnimationCycle() {
        let steps: [(TimeInterval, () -> Void)] = [
            (0.8, { litSettingsStep = 1 }),
            (2.0, { litSettingsStep = 2; dictusToggleOn = true }),
            (3.2, { litSettingsStep = 3; fullAccessToggleOn = true }),
            (4.6, { litSettingsStep = 0 })
        ]
        for (delay, change) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // The detection ends the loop on its final state; a step already scheduled
                // must not switch a toggle back off or relight a badge after it.
                guard !keyboardDetected else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    change()
                }
            }
        }
    }

    // MARK: - Private

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Check if the Dictus keyboard is installed by inspecting active input modes.
    ///
    /// WHY UITextInputMode.activeInputModes:
    /// This is the only public API to detect installed keyboards. It returns
    /// an array of UITextInputMode objects whose `value(forKey: "identifier")`
    /// contains the bundle identifier. We look for our keyboard extension's
    /// bundle ID "com.pivi.dictus.keyboard".
    ///
    /// WHY defensive coding:
    /// UITextInputMode.activeInputModes can be unstable during rapid scenePhase
    /// transitions (e.g., returning from Settings). value(forKey:) is KVO and
    /// can return unexpected types. Guard against both to prevent crashes.
    private func checkKeyboardInstalled() {
        let modes = UITextInputMode.activeInputModes
        PersistentLog.log(.onboardingKeyboardCheckStarted(modeCount: modes.count))

        for mode in modes {
            // value(forKey:) is KVO — guard against unexpected nil or type mismatch
            guard let identifier = mode.value(forKey: "identifier") as? String else {
                continue
            }
            if identifier.contains("com.pivi.dictus") {
                PersistentLog.log(.onboardingKeyboardDetected(identifier: identifier))
                keyboardDetected = true
                return
            }
        }

        PersistentLog.log(.onboardingKeyboardNotFound(modeCount: modes.count))
    }
}

// MARK: - Drawn Settings controls

/// An iOS switch, drawn: the Settings page in the illustration is a picture, not a form.
///
/// WHY NOT `Toggle`: the old card used real, non-interactive Toggles so iOS 26 would draw
/// them in Liquid Glass. A real Toggle cannot carry the accent ring the mock-up puts on the
/// switch to touch next, and VoiceOver read it as a control the user could not operate.
private struct DrawnSwitch: View {
    let isOn: Bool
    /// The ring around the switch the loop points at.
    let isLit: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Color(hex: 0x34C759) : Color.primary.opacity(0.12))
            .frame(width: 51, height: 31)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .padding(2)
            }
            .overlay(
                Capsule()
                    .strokeBorder(Color.dictusAccent, lineWidth: 3)
                    .padding(-4)
                    .opacity(isLit ? 1 : 0)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
            .animation(.easeInOut(duration: 0.25), value: isLit)
    }
}

/// A Settings row icon: a white symbol on a coloured rounded square.
private struct DictusIconTileSymbol: View {
    let systemName: String
    let fill: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(fill))
    }
}
