// DictusApp/Onboarding/TestRecordingPage.swift
// Step 5 of onboarding: thin wrapper around shared RecordingView.
import SwiftUI
import DictusCore

/// Final onboarding step: test the dictation pipeline end-to-end.
///
/// WHY a thin wrapper instead of using RecordingView directly in OnboardingView:
/// This preserves the consistent onboarding page contract (each page is a separate
/// struct with an onComplete/onNext callback). The actual recording UI is fully
/// handled by the shared RecordingView, which is also used from HomeView.
///
/// WHY success overlay intercept:
/// When the user taps "Terminer" in RecordingView, instead of immediately dismissing
/// onboarding, we show OnboardingSuccessView with an animated checkmark. This gives
/// the user a professional "you're done" moment before entering the app, matching
/// the polished feel of Apple Pay confirmations and competitor onboarding flows.
struct TestRecordingPage: View {
    let onComplete: () -> Void

    @State private var showSuccess = false

    var body: some View {
        ZStack {
            RecordingView(mode: .onboarding, onComplete: {
                // Intercept completion: show success overlay instead of
                // immediately finishing onboarding
                withAnimation(.easeOut(duration: 0.3)) {
                    showSuccess = true
                }
            })

            if showSuccess {
                OnboardingSuccessView(onComplete: onComplete)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: showSuccess)
    }
}
