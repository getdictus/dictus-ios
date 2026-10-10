// DictusApp/Onboarding/AppleIntelligencePage.swift
// Onboarding step: how to turn on Apple Intelligence, when it is not ready (#683).
import SwiftUI
import UIKit
import DictusCore

/// Tells the user how to turn on Apple Intelligence, which the Smart Modes run on.
///
/// Shown only on a capable iPhone where Apple Intelligence is not ready (#649 decision 7,
/// `AppleIntelligenceOnboarding.isStepNeeded`); `OnboardingView` passes over it otherwise.
///
/// WHY THE PATH IS WRITTEN OUT: there is no public deep link to the Apple Intelligence page
/// of Settings, and private `App-Prefs:` URLs get apps rejected. The only link an app may
/// open is its own settings page (`openSettingsURLString`), so the page spells out the path.
///
/// WHY ONE PAGE FOR EVERY "NOT READY" REASON: a reported Apple bug makes Apple Intelligence
/// switched off read as `modelNotReady`, so the reason cannot be trusted to pick the copy.
/// The text covers both: how to turn it on, and that Apple then downloads its model.
///
/// WHY NO DURATION: Apple's model is up to several GB and takes from minutes to hours.
/// Any number would be wrong for someone, so the page says "sometimes a long time" and
/// re-checks when the user comes back.
///
/// WHY "LATER" IS AS LARGE AS THE MAIN BUTTON: dictation does not need Apple Intelligence.
/// The step must never feel like a gate, so leaving it is as easy as following it.
struct AppleIntelligencePage: View {
    @ObservedObject var modelManager: ModelManager
    /// The model the onboarding is downloading, for the progress pill.
    let modelIdentifier: String
    let onNext: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    /// Whether Apple Intelligence was found ready by the last check. The page then offers
    /// Continue instead of the path.
    @State private var isReady = false

    /// The delayed second check after a return to the app.
    @State private var recheckTask: Task<Void, Never>?

    var body: some View {
        OnboardingPage(
            title: Text("Turn on Apple Intelligence"),
            subtitle: Text("Smart Modes rely on Apple's model, on your iPhone. Dictation already works without it.")
        ) {
            VStack(alignment: .leading, spacing: 20) {
                settingsPath

                siriLanguageWarning

                if isReady {
                    Label("Apple Intelligence is ready", systemImage: "checkmark.circle.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.dictusSuccess)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                } else {
                    Text("Apple then downloads its model, sometimes for a long time. Dictus checks again when you come back.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } bottom: {
            OnboardingDownloadPill(modelManager: modelManager, modelIdentifier: modelIdentifier)

            if isReady {
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
        .onAppear {
            check(trigger: "appear")
        }
        .onDisappear {
            recheckTask?.cancel()
            recheckTask = nil
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else {
                recheckTask?.cancel()
                recheckTask = nil
                return
            }
            check(trigger: "active")
            // A second look shortly after: a switch just flipped in Settings may not be
            // reflected by the time the app is active again. Same reasoning as the
            // keyboard step's retry.
            recheckTask?.cancel()
            recheckTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    check(trigger: "active")
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isReady)
    }

    // MARK: - Settings path

    /// The three steps in Settings, numbered, with the icons Settings draws for them.
    /// Only iOS system UI is drawn this way (#649 decision 13).
    private var settingsPath: some View {
        VStack(spacing: 0) {
            pathRow(
                number: 1,
                icon: DictusIconTileSymbol(systemName: "gearshape", fill: .gray),
                label: Text("Open the Settings app")
            )
            Divider()
                .padding(.leading, 62)
                .padding(.trailing, 16)
            pathRow(
                number: 2,
                // iOS's system purple, as Settings draws this row in the mock-up. Not the
                // Smart Mode purple token: Smart Modes are blue in the onboarding.
                icon: DictusIconTileSymbol(systemName: Self.appleIntelligenceSymbol, fill: Color(hex: 0xAF52DE)),
                label: Text("Apple Intelligence & Siri")
            )
            Divider()
                .padding(.leading, 62)
                .padding(.trailing, 16)
            pathRow(
                number: 3,
                icon: DictusIconTileSymbol(systemName: "switch.2", fill: Color(hex: 0x34C759)),
                label: Text("Turn on Apple Intelligence")
            )
        }
        .padding(.vertical, 4)
        .onboardingCard()
        // One sentence for VoiceOver instead of three rows of icons and bare numbers.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("In Settings, open Apple Intelligence & Siri, then turn on Apple Intelligence."))
    }

    private func pathRow(number: Int, icon: DictusIconTileSymbol, label: Text) -> some View {
        HStack(spacing: 16) {
            icon
            label
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(verbatim: "\(number)")
                .font(.body.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Settings' own glyph for the Apple Intelligence row where the system has it (SF
    /// Symbols 6, iOS 18), sparkles before. A missing symbol would draw an empty tile.
    private static let appleIntelligenceSymbol =
        UIImage(systemName: "apple.intelligence") != nil ? "apple.intelligence" : "sparkles"

    // MARK: - Siri language warning

    /// Apple's support page still requires it on iOS 27: Apple Intelligence stays off
    /// when Siri speaks another language than the iPhone. It is the most common reason the
    /// switch "does nothing", so it is said before the user goes looking.
    private var siriLanguageWarning: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.body.weight(.medium))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Siri's language must be your iPhone's language, otherwise Apple Intelligence stays unavailable.")
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Self.warningFill)
        )
    }

    /// A warm beige on light, the dark surface on dark (mock-up `04-apple-intelligence`).
    private static let warningFill = Color(light: Color(hex: 0xF2E9DE), dark: Color(hex: 0x1F2533))

    // MARK: - Actions

    /// Reads the availability and records what it found.
    private func check(trigger: String) {
        let state = PolishAvailability.state
        PersistentLog.log(.onboardingAppleIntelligenceChecked(trigger: trigger, state: String(describing: state)))
        // `.available` rather than `!isStepNeeded`: a device that can never run Apple
        // Intelligence is not "ready", and only lands here if its state changed under a
        // resumed onboarding. It keeps the path and Later.
        isReady = state == .available
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func later() {
        PersistentLog.log(.onboardingAppleIntelligenceDeferred(state: String(describing: PolishAvailability.state)))
        onNext()
    }
}
