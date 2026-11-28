// DictusApp/Onboarding/AppleModelPreparationPage.swift
// Onboarding step: wait for Apple's model, on the Apple route (#1057).
import DictusCore
import SwiftUI

/// The preparation step on the Apple route: iOS is still installing Apple's model.
///
/// Shown only while there is something to wait for: an install that finished during the
/// earlier steps passes this step over (`OnboardingView.satisfiedSteps`). It moves on by
/// itself once Apple's model is picked, as `ModelDownloadPage` does for a Dictus model.
///
/// WHY NO ERROR STATE: an install that fails falls back to the recommended model's download
/// (`OnboardingAppleEngineSetup.start`), and `OnboardingView` puts `ModelDownloadPage` in
/// this page's place, with its progress and its retry.
///
/// Same layout and strings as the Dictus model's page and the Models screen's Apple card,
/// so no copy is new here.
struct AppleModelPreparationPage: View {
    @ObservedObject var setup: OnboardingAppleEngineSetup
    let onNext: () -> Void

    @State private var hasAdvanced = false

    var body: some View {
        OnboardingPage(
            title: Text("Voice model"),
            subtitle: Text("Your voice model is getting ready.")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                card
                progress
            }
        } bottom: {
            EmptyView()
        }
        .onAppear(perform: advanceIfReady)
        .onChange(of: setup.phase) { _, _ in advanceIfReady() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple (on-device)", comment: "Models screen: name of Apple's speech recognition as an engine the user can pick.")
                .font(.dictusSubheading)
                .foregroundStyle(.primary)
            Text("Apple's speech recognition, built into iOS. Dictus downloads nothing.",
                 comment: "Models screen: description of the Apple engine card.")
                .font(.dictusCaption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Recommended for your language and \(DeviceNoun.current)")
                .font(.dictusCaption)
                .foregroundColor(.dictusAccent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingCard()
        .accessibilityIdentifier("onboarding.appleModel")
    }

    @ViewBuilder
    private var progress: some View {
        if case .installing(let fraction?) = setup.phase {
            VStack(spacing: 6) {
                ProgressView(value: fraction)
                    .tint(.dictusAccent)
                Text("\(Int(fraction * 100)) %")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.dictusAccent)
                Text("Preparing…", comment: "Apple engine card: iOS is installing Apple's speech model after the user picked it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func advanceIfReady() {
        guard setup.phase == .ready, !hasAdvanced else { return }
        hasAdvanced = true
        onNext()
    }
}
