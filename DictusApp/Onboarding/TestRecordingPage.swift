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
struct TestRecordingPage: View {
    let onComplete: () -> Void

    var body: some View {
        RecordingView(mode: .onboarding, onComplete: onComplete)
    }
}
