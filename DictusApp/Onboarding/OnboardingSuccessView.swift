// DictusApp/Onboarding/OnboardingSuccessView.swift
// The completion step: the onboarding is done, and how to use Dictus from here.
import SwiftUI
import DictusCore

/// The last onboarding step: the app icon with a check, "You're all set", and the one
/// gesture to remember (#675 mock-up `12-termine`).
///
/// WHY A STEP AND NOT A COVER (#675): it used to be a full-screen cover raised by the first
/// dictation page. As a step it is persisted like the others, wears the shell, and leaves
/// room for the steps #649 adds after the first dictation (#681). Its button sets
/// `hasCompletedOnboarding`, which raises the trial announcement (#593) unchanged.
///
/// WHY spring animation for the check:
/// The overshoot (scale 0 -> 1.1 -> 1.0) with spring physics mimics Apple's
/// success checkmark from Apple Pay and other system confirmations. Users
/// recognize this pattern as "you're done" without reading any text.
struct OnboardingSuccessView: View {
    let onComplete: () -> Void

    @State private var checkmarkScale: CGFloat = 0
    @State private var showText = false

    /// Whether the keyboard can dictate on this device (#635). On a pre-A14 chip the
    /// keyboard's mic is disabled, so "hold the globe and speak" would promise what the
    /// keyboard cannot do; the message points to the app instead.
    private let keyboardCanDictate = DeviceCapabilities.current().supportsKeyboardDictation

    var body: some View {
        OnboardingCenteredPage(
            title: Text("You're all set"),
            message: keyboardCanDictate
                ? Text("Dictus is waiting in the keyboard of every app. Hold the globe, and speak.")
                : Text("Dictus is waiting in the keyboard of every app. To dictate, open the Dictus app.")
        ) {
            ZStack(alignment: .bottomTrailing) {
                DictusIconTile(logoHeight: 64)
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)

                // The check lands on the icon's corner, ringed in the page colour so it
                // reads as a badge on both backgrounds.
                ZStack {
                    Circle()
                        .fill(Color.dictusSuccess)
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(Color.dictusBackground, lineWidth: 4))
                .offset(x: 14, y: 14)
                .scaleEffect(checkmarkScale)
            }
            .accessibilityHidden(true)
        } bottom: {
            OnboardingPrimaryButton(Text("Get started"), action: onComplete)
                .opacity(showText ? 1 : 0)
                .accessibilityIdentifier("onboarding.primary")
        }
        .onAppear {
            // Step 1: Spring the check in (0 -> 1.1 -> 1.0)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                checkmarkScale = 1.0
            }
            // Step 2: Fade in the button after the check lands
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                showText = true
            }
        }
    }
}
