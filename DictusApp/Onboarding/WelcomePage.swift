// DictusApp/Onboarding/WelcomePage.swift
// The intro step of onboarding: animated waveform, wordmark, tagline, and "Get started".
import SwiftUI
import DictusCore

/// Welcome page shown on first launch with animated brand waveform and tagline.
///
/// WHY IT IS STILL THIS PAGE (#675): the intro slot of the new shell will hold the
/// three-scene carousel (#676). Until then, the existing welcome wears the shell: the
/// centred layout the mock-ups draw for the intro, and the shell's primary button. No
/// progress bar: the intro is before the work starts.
///
/// WHY BrandWaveform with processing (sinusoidal) animation:
/// A smooth traveling sine wave creates a polished first impression instead of
/// random jittery bars. The sinusoidal mode is inherently fluid (60fps via
/// TimelineView) and requires no Timer — simpler code, better visual result.
struct WelcomePage: View {
    let onNext: () -> Void

    @State private var showContent = false

    var body: some View {
        OnboardingCenteredPage(
            title: Text(verbatim: "Dictus"),
            message: Text("Voice dictation, 100% offline")
        ) {
            // Smooth sinusoidal waveform — same as the transcription processing animation
            BrandWaveform(maxHeight: 120, animation: .sweep)
                .opacity(0.6)
                .accessibilityHidden(true)
        } bottom: {
            OnboardingPrimaryButton(Text("Get started"), action: onNext)
                .opacity(showContent ? 1 : 0)
                .accessibilityIdentifier("onboarding.primary")
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.6).delay(0.5)) {
                showContent = true
            }
        }
    }
}
