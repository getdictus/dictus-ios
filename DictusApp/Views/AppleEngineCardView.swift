// DictusApp/Views/AppleEngineCardView.swift
// "Apple (on-device)" on the Models screen, beside the downloaded models.
import DictusCore
import SwiftUI

/// The Apple card's state: availability for the chosen language, and an install in flight.
///
/// WHY AN OBJECT OF ITS OWN rather than more state on `ModelManager`: nothing here is
/// about Dictus's downloads. Apple's model is installed by iOS (`AssetInventory`), with
/// its own progress, and the rule deciding whether the card is greyed is in DictusCore
/// (`AppleEngineAvailability`).
@MainActor
final class AppleEngineCardModel: ObservableObject {
    @Published private(set) var availability: AppleEngineAvailability = .needsAsset(.unknown)
    /// Set while iOS installs Apple's model after a tap, or after the install failed.
    @Published private(set) var installState: AppleEngineAssetState?

    /// What the card draws: an install the card started wins over the last reading.
    var displayed: AppleEngineAvailability {
        guard let installState, availability.isSelectable, !availability.isReady else { return availability }
        return .needsAsset(installState)
    }

    func refresh() async {
        availability = await AppleEngineAssets.availability()
        if availability.isReady { installState = nil }
    }

    /// Pick the engine: at once when its model is installed, otherwise after iOS has
    /// installed it. A greyed card never reaches here (`.disabled`).
    func pick(_ modelManager: ModelManager) {
        switch displayed {
        case .unavailable, .needsAsset(.installing):
            return
        case .ready:
            modelManager.selectAppleEngine()
        case .needsAsset:
            guard let code = InKeyboardDictationRoute.activeDictationLanguageCode() else { return }
            installState = .installing(fraction: nil)
            Task {
                do {
                    try await AppleEngineAssets.install(languageCode: code) { fraction in
                        self.installState = .installing(fraction: fraction)
                    }
                    await refresh()
                    if availability.isReady {
                        modelManager.selectAppleEngine()
                    } else {
                        installState = .failed
                    }
                } catch {
                    AppleEngineAssets.log("installFailed", "lang=\(code) error=\(LoggedError.domainAndCode(error))")
                    installState = .failed
                }
            }
        }
    }
}

/// The card itself, drawn like `ModelCardView` (glass, engine badge, active border).
struct AppleEngineCardView: View {
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var model: AppleEngineCardModel

    private var state: AppleEngineAvailability { model.displayed }

    /// Selected AND ready: the engine dictations use now. Picked but greyed (the language
    /// changed since) is not active: the downloaded model dictates, and its card says so.
    private var isActive: Bool {
        modelManager.speechEngineChoice == .apple && state.isReady
    }

    var body: some View {
        Button {
            model.pick(modelManager)
        } label: {
            content.contentShape(Rectangle())
        }
        .buttonStyle(GlassPressStyle(pressedScale: 0.95))
        .disabled(!state.isSelectable)
        // Same recess as an incompatible model card (#369).
        .opacity(state.isSelectable ? 1 : 0.55)
        .accessibilityIdentifier("models.appleEngine")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Apple (on-device)", comment: "Models screen: name of Apple's speech recognition as an engine the user can pick.")
                    .font(.dictusSubheading)
                Text(SpeechEngine.apple.rawValue)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.dictusAccent)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }

            Text("Apple's speech recognition, built into iOS. Dictus downloads nothing.",
                 comment: "Models screen: description of the Apple engine card.")
                .font(.dictusCaption)
                .foregroundStyle(.secondary)

            statusRow
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 16).fill(Color.dictusAccent.opacity(0.10))
                }
            }
        )
        .dictusGlass()
        .overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 16).stroke(Color.dictusAccent.opacity(0.6), lineWidth: 2)
                }
            }
        )
    }

    @ViewBuilder
    private var statusRow: some View {
        switch state {
        case .unavailable(let reason):
            Label(Self.text(for: reason), systemImage: "exclamationmark.triangle")
                .font(.dictusCaption)
                .foregroundStyle(.secondary)
        case .needsAsset(.installing(let fraction)):
            VStack(spacing: 4) {
                if let fraction {
                    ProgressView(value: fraction, total: 1.0).tint(.dictusAccent)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
                Text("Preparing…", comment: "Apple engine card: iOS is installing Apple's speech model after the user picked it.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .needsAsset(.failed):
            Label {
                Text("Apple's model could not be installed. Tap to try again.",
                     comment: "Apple engine card: iOS failed to install Apple's speech model.")
            } icon: {
                Image(systemName: "arrow.clockwise.circle")
            }
            .font(.dictusCaption)
            .foregroundStyle(.orange)
        case .needsAsset, .ready:
            Label {
                Text("No download in Dictus", comment: "Apple engine card: where the size of a downloadable model is shown.")
            } icon: {
                Image(systemName: "iphone")
            }
            .font(.dictusCaption)
            .foregroundStyle(.secondary)
        }
    }

    /// The one explanation line under a greyed card.
    static func text(for reason: AppleEngineAvailability.Reason) -> String {
        switch reason {
        case .systemTooOld:
            return String(localized: "Requires iOS 26 or later.",
                          comment: "Greyed Apple engine card: the iPhone runs an iOS older than 26.")
        case .speechTranscriberUnavailable:
            return String(localized: "Not available on this iPhone or for this dictation language.",
                          comment: "Greyed Apple engine card: Apple's SpeechTranscriber is not available on this iPhone.")
        case .autoDetect:
            return String(localized: "Needs a transcription language, not automatic detection.",
                          comment: "Greyed Apple engine card: the transcription language is set to automatic detection.")
        case .languageNotCovered:
            return String(localized: "Not available for this dictation language.",
                          comment: "Greyed Apple engine card: Apple's recognizer does not support the chosen dictation language.")
        }
    }
}
