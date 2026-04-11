// DictusApp/Onboarding/KeyboardSetupPage.swift
// Step 3 of onboarding: guide user to add the Dictus keyboard with auto-detection.
import SwiftUI
import UIKit
import DictusCore

/// Guides the user through adding the Dictus keyboard in iOS Settings.
///
/// WHY animated fake Settings card:
/// Users need to enable two toggles in iOS Settings (add keyboard + Full Access).
/// A visual simulation showing exactly what to toggle reduces friction and support
/// requests. The toggles animate in sequence on a loop so the user sees the steps
/// before opening Settings. Inspired by Wispr Flow / Super Whisper onboarding.
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

    // Animation state for the two-phase fake Settings card
    /// WHY two phases: The real iOS flow requires tapping "Keyboards" row first,
    /// then toggling the switches. The animation shows both steps so the user
    /// knows to look for the "Keyboards" row (the most common point of confusion).
    @State private var showKeyboardsScreen = false   // false = Dictus settings page, true = Keyboards toggles page
    @State private var keyboardsRowHighlighted = false // tap highlight on the "Keyboards" row
    @State private var dictusToggleOn = false
    @State private var fullAccessToggleOn = false
    @State private var animationTimer: Timer?

    var body: some View {
        // WHY VStack(spacing:0) at root instead of ScrollView:
        // The Continue button should always sit at the bottom of the screen
        // (consistent with the other onboarding pages). Using a top VStack
        // with Spacer() pushes it down. The content above is short enough
        // to never need scrolling.
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            // Keyboard icon
            Image(systemName: "keyboard")
                .font(.system(size: 64))
                .foregroundColor(.dictusAccent)
                .padding(.bottom, 24)

            // Title
            Text("Add keyboard")
                .font(.dictusHeading)
                .foregroundStyle(.primary)
                .padding(.bottom, 28)

            // Fake Settings card
            fakeSettingsCard
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // Open Settings link — plain text, no card wrapper
            Button(action: openSettings) {
                Label("Open Settings", systemImage: "arrow.up.right")
                    .font(.dictusBody)
                    .foregroundColor(.dictusAccent)
            }
            .padding(.bottom, 20)

            // Auto-detection helper text
            Text("The keyboard will be detected automatically")
                .font(.dictusCaption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            // Reassuring note about the TCC-triggered app restart.
            // WHY this text: When the user enables "Allow Full Access" in iOS
            // Settings, iOS's TCC daemon forcibly terminates Dictus to enforce
            // the new permission. This can look like a crash. Telling the user
            // it's expected prevents support tickets and reduces anxiety.
            Text("Dictus may restart automatically — this is normal")
                .font(.dictusCaption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

            // Detection feedback (green checkmark) stays just above the content
            if keyboardDetected {
                Label("Keyboard detected", systemImage: "checkmark.circle.fill")
                    .font(.dictusBody)
                    .foregroundColor(.dictusSuccess)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }

            // Spacer pushes the Continue button to the bottom of the screen
            Spacer()

            // Continue button — fixed at the bottom, matching other onboarding pages.
            // Hidden until the keyboard is detected (opacity 0), but the layout
            // space is reserved so the screen doesn't jump when it appears.
            Button(action: onNext) {
                Text("Continue")
                    .font(.dictusSubheading)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.dictusAccent)
                    )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
            .opacity(keyboardDetected ? 1 : 0)
            .allowsHitTesting(keyboardDetected)
            .animation(.easeInOut(duration: 0.3), value: keyboardDetected)
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
                // Show the toggles page with both toggles ON (final success state)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showKeyboardsScreen = true
                    keyboardsRowHighlighted = false
                    dictusToggleOn = true
                    fullAccessToggleOn = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: keyboardDetected)
    }

    // MARK: - Fake Settings Card

    /// Simulates the iOS Settings screen for Dictus keyboard configuration.
    ///
    /// WHY two phases:
    /// Phase 1 shows the Dictus settings page with a "Keyboards" row — the user
    /// needs to know they must tap this row first (this is where most users get stuck).
    /// Phase 2 shows the toggles screen (existing animation). Both phases loop
    /// in sequence so the user sees the complete flow before opening Settings.
    private var fakeSettingsCard: some View {
        VStack(spacing: 0) {
            // Header — changes to show navigation breadcrumb
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
                Text(showKeyboardsScreen ? "Settings > Dictus > Keyboards" : "Settings > Dictus")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .animation(.none, value: showKeyboardsScreen)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Two-phase content area with slide transition
            // WHY clipped: Without clipping, the outgoing phase slides visibly
            // outside the card bounds during the transition. Clipping keeps the
            // animation contained within the glass card.
            ZStack {
                if !showKeyboardsScreen {
                    // Phase 1: Dictus settings page — shows "Keyboards" row to tap
                    dictusSettingsPhase
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    // Phase 2: Keyboards toggles page — shows Dictus + Full Access toggles
                    keyboardsTogglesPhase
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }
            }
            .clipped()
            .animation(.easeInOut(duration: 0.3), value: showKeyboardsScreen)
        }
        .padding(.bottom, 4)
        .dictusGlass(in: RoundedRectangle(cornerRadius: 16))
    }

    /// Phase 1: Fake "Dictus" settings page with Keyboards row + placeholder rows.
    /// The "Keyboards" row gets a highlight overlay to show the user where to tap.
    ///
    /// WHY iOS Settings-style icons:
    /// The real Dictus page in iOS Settings shows rows with colored square icons
    /// (keyboard icon on gray, globe on blue, etc.). Matching this visual pattern
    /// helps the user recognize the screen when they open the real Settings.
    private var dictusSettingsPhase: some View {
        VStack(spacing: 0) {
            // "Keyboards" row — the one the user needs to tap
            settingsRow(
                icon: "keyboard",
                iconColor: .gray,
                label: "Keyboards",
                showChevron: true
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dictusAccent.opacity(keyboardsRowHighlighted ? 0.15 : 0))
                    .padding(.horizontal, 4)
            )

            Divider().opacity(0.3).padding(.leading, 52)

            // Placeholder rows for realism — makes it look like a real Settings page
            settingsRow(
                icon: "bell.badge.fill",
                iconColor: .red,
                label: "Notifications",
                showChevron: true,
                dimmed: true
            )

            Divider().opacity(0.3).padding(.leading, 52)

            settingsRow(
                icon: "globe",
                iconColor: .blue,
                label: "Siri & Search",
                showChevron: true,
                dimmed: true
            )
        }
        .allowsHitTesting(false)
        .padding(.vertical, 4)
    }

    /// A single row matching the iOS Settings visual style: colored icon square + label + chevron.
    ///
    /// WHY a reusable helper: The three rows in Phase 1 share the same layout
    /// (icon + label + chevron). Extracting it avoids repeating the same HStack/ZStack
    /// structure three times and makes it easy to adjust the visual style in one place.
    private func settingsRow(
        icon: String,
        iconColor: Color,
        label: LocalizedStringKey,
        showChevron: Bool,
        dimmed: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            // Colored square icon — matches iOS Settings style
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.body)
                .foregroundStyle(dimmed ? .secondary : .primary)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    /// Phase 2: Keyboards toggles page — the existing Dictus + Full Access toggles.
    /// Uses real SwiftUI Toggle components (non-interactive) so they automatically
    /// adopt the native Liquid Glass style on iOS 26.
    private var keyboardsTogglesPhase: some View {
        VStack(spacing: 0) {
            Toggle("Dictus", isOn: $dictusToggleOn)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dictusToggleOn)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()
                .opacity(0.3)
                .padding(.leading, 16)

            Toggle("Allow full access", isOn: $fullAccessToggleOn)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fullAccessToggleOn)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .allowsHitTesting(false)
        .padding(.vertical, 4)
    }

    // MARK: - Toggle Animation Loop

    /// Starts a repeating two-phase animation cycle (~7s per loop):
    ///
    /// 0.0s → Reset: show Dictus settings page, all OFF
    /// 1.0s → Highlight "Keyboards" row (spring)
    /// 1.8s → Transition to toggles page (slide)
    /// 2.8s → Dictus toggle ON
    /// 3.8s → Full Access toggle ON
    /// 5.5s → Hold for user to absorb
    /// 7.0s → Restart cycle
    ///
    /// WHY 7s instead of 4s: The animation now has two phases (settings page + toggles),
    /// so it needs more time. 7s gives enough time to see each step clearly without
    /// feeling slow. The 1.7s hold at the end lets the user absorb the final state.
    private func startToggleAnimation() {
        // Reset all state
        showKeyboardsScreen = false
        keyboardsRowHighlighted = false
        dictusToggleOn = false
        fullAccessToggleOn = false

        // Run first cycle
        runAnimationCycle()

        // Repeat every 7 seconds
        animationTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            // Reset to phase 1 (no animation — instant reset before new cycle)
            showKeyboardsScreen = false
            keyboardsRowHighlighted = false
            dictusToggleOn = false
            fullAccessToggleOn = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                runAnimationCycle()
            }
        }
    }

    private func runAnimationCycle() {
        // Step 1: Highlight the "Keyboards" row
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                keyboardsRowHighlighted = true
            }
        }

        // Step 2: Transition to toggles screen (simulates tapping "Keyboards")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            keyboardsRowHighlighted = false
            showKeyboardsScreen = true
        }

        // Step 3: Dictus toggle ON
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            dictusToggleOn = true
        }

        // Step 4: Full Access toggle ON
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            fullAccessToggleOn = true
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
