// DictusApp/Onboarding/ModelDownloadPage.swift
// Onboarding step: wait for the model the language screen started downloading (#649).
import SwiftUI
import DictusCore

/// Waits, with visible progress, for the model the onboarding is installing.
///
/// WHY A WAIT AND NOT AN INSTALL BUTTON (#649): the download starts when the language
/// screen is confirmed, two steps earlier, and `OnboardingView` only shows this page when
/// the model is still downloading or compiling by the time the keyboard is set up. So
/// there is normally nothing to ask: the page shows where the preparation is and offers
/// Continue once it is done. It starts the download itself only when nothing is moving —
/// iOS killed the app between the last byte and the compile, or an earlier attempt failed
/// and the user is retrying.
///
/// WHICH MODEL: `modelIdentifier` is the recommendation for the user's language and this
/// device (`ModelInfo.recommendedIdentifier(forSpokenLanguage:on:)`), chosen by the
/// language screen. The model card displays name, size, and description from the
/// ModelInfo catalog.
///
/// WHY @ObservedObject for ModelManager: `OnboardingView` owns the one manager the whole
/// flow shares, including the language page that started this download. Building a second
/// one here would only learn about that transfer second-hand.
struct ModelDownloadPage: View {
    @ObservedObject var modelManager: ModelManager

    /// The model being installed for this onboarding.
    let modelIdentifier: String

    let onNext: () -> Void

    /// Kept under its historical name: every expression below reads it.
    private var recommendedModel: String { modelIdentifier }

    @State private var isDownloading = false
    @State private var downloadComplete = false
    @State private var errorMessage: String?

    /// Issue #144: identifier currently being prepared. Drives a full-screen
    /// `ModelLoadingOverlay` while the model goes through download → compile →
    /// RAM load, so the onboarding shares the same wait UX as the in-app
    /// model manager.
    @State private var preparingModelID: String?

    /// The same #458 gate `ModelManagerView` uses, for the same reactive pair below.
    ///
    /// Onboarding cannot overlap a dictation today — `OnboardingView` is a `switch` on
    /// one page at a time and none of the pages before this one records. It is gated
    /// anyway because the rule belongs to the screen, not to the flow that happens to
    /// reach it, and because the comment on `liveActivePrepModel` promises this page
    /// behaves identically to the model manager.
    @State private var preparationGate = ModelPreparationGate()

    /// Set once this page has handed over to the next step, so the several triggers of
    /// `advanceIfReady()` cannot advance twice.
    @State private var hasAdvanced = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Download icon
            Image(systemName: downloadComplete ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(downloadComplete ? .dictusSuccess : .dictusAccent)
                .padding(.bottom, 24)

            // Title
            Text("Voice model")
                .font(.dictusHeading)
                .foregroundStyle(.primary)
                .padding(.bottom, 12)

            // Explanatory text
            Text("Your voice model is still getting ready. It only happens once.")
                .font(.dictusBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // Model card
            modelCard
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // Download progress (only show bar when we have actual progress data)
            if isDownloading, let progress = modelManager.downloadProgress[recommendedModel] {
                VStack(spacing: 8) {
                    ProgressView(value: Double(progress))
                        .tint(.dictusAccent)
                        .padding(.horizontal, 32)

                    Text("\(Int(progress * 100))%")
                        .font(.dictusCaption)
                        .foregroundStyle(.secondary)

                    // Moving byte counter — reads as alive even while the
                    // percentage crawls through the 445 MB Encoder file (#207).
                    if let bytes = modelManager.downloadByteInfo[recommendedModel] {
                        Text("\(bytes.downloadedMB) MB of \(bytes.totalMB) MB")
                            .font(.dictusCaption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.bottom, 16)
            }

            // Prewarming indicator
            if modelManager.modelStates[recommendedModel] == .prewarming {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.dictusAccent)
                    Text("Optimizing...")
                        .font(.dictusCaption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.dictusCaption)
                    .foregroundColor(.dictusRecording)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }

            Spacer()

            // Action button
            if downloadComplete {
                // Normally never tapped: the page moves on by itself the moment the model
                // is ready (`advanceIfReady`). Kept as the way out should the preparation
                // screen above it fail to close.
                Button(action: advance) {
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
                .padding(.bottom, 48)
            } else if !isDownloading {
                // Only reached after a failure (the page starts the download on its own
                // otherwise), so the action is a retry, worded as one.
                VStack(spacing: 16) {
                    Button(action: startDownload) {
                        Text("Try again")
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
                }
                .padding(.bottom, 48)
            } else {
                // Downloading — show nothing (progress is above)
                Spacer().frame(height: 48)
            }
        }
        .onAppear {
            // Whether the model is already downloaded, and whether one is in flight.
            syncWithPreparationState()
            // Nothing in flight, nothing ready, nothing failed: the transfer the language
            // screen started did not survive (iOS killed the app before the compile, which
            // waits for the foreground). Resume it; the downloader skips every file
            // already on disk, so this costs the missing bytes and the compile only.
            if !downloadComplete, !isDownloading, errorMessage == nil {
                startDownload()
            }
            // If the user backgrounded the app mid-prep, surface the overlay again.
            raisePreparationIfAllowed(liveActivePrepModel)
            advanceIfReady()
        }
        // The two halves of "nothing left to wait for": the model is ready, and the
        // preparation screen covering this page has closed.
        .onChange(of: downloadComplete) { _, _ in
            advanceIfReady()
        }
        .onChange(of: preparingModelID) { _, _ in
            advanceIfReady()
        }
        .onChange(of: liveActivePrepModel) { _, newValue in
            raisePreparationIfAllowed(newValue)
        }
        // A download this page did not start is the normal case since #649: the language
        // screen started it, and after a force quit the launch adoption resumes it
        // (issue #449). Without this the page would not follow the transfer's state, and
        // would offer a retry over a download that is already running.
        .onChange(of: modelManager.modelStates[recommendedModel]) { _, _ in
            syncWithPreparationState()
        }
        .fullScreenCover(item: Binding<PreparingItem?>(
            get: { preparingModelID.map(PreparingItem.init) },
            set: { preparingModelID = $0?.id }
        )) { item in
            ModelLoadingOverlay(
                modelManager: modelManager,
                modelIdentifier: item.id,
                context: .onboarding,
                isPresented: Binding(
                    get: { preparingModelID != nil },
                    set: { if !$0 { preparingModelID = nil } }
                )
            )
        }
    }

    // MARK: - Advancing

    /// Moves to the first dictation as soon as the model is ready (device test, 2026-10-06).
    ///
    /// WHY NO "READY, CONTINUE" STOP: this page exists only to wait. Once the wait is over,
    /// a screen announcing it and asking for a tap is a step with nothing to decide, and
    /// Pierre's device run found it useless. A failure still stops here, on "Try again".
    ///
    /// WHY IT ALSO WAITS FOR `preparingModelID` TO CLEAR: the preparation screen is a
    /// full-screen cover presented by this page, and it closes itself once the model is
    /// loaded. Replacing the page while its cover is still up would tear the cover down
    /// mid-animation; waiting for it lets the cover close and the page slide away after.
    private func advanceIfReady() {
        guard downloadComplete, preparingModelID == nil, !hasAdvanced else { return }
        advance()
    }

    private func advance() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        onNext()
    }

    /// Wrapper so `.fullScreenCover(item:)` works with a plain String identifier.
    private struct PreparingItem: Identifiable {
        let id: String
    }

    /// Raise the preparation screen for `liveModel`, unless #458's rule refuses it.
    /// Mirrors `ModelManagerView.raisePreparationIfAllowed`, including reading the
    /// status at the instant of the decision rather than observing it.
    private func raisePreparationIfAllowed(_ liveModel: String?) {
        if let id = preparationGate.modelToPresent(
            liveModel: liveModel,
            dictationStatus: DictationCoordinator.shared.status,
            isPresenting: preparingModelID != nil
        ) {
            preparingModelID = id
        }
    }

    /// First identifier currently in a user-facing prep phase. Mirrors the same
    /// computation as `ModelManagerView` so the overlay behavior is identical.
    private var liveActivePrepModel: String? {
        // Same order as `ModelManagerView`, for the same reason (audit finding 3): a
        // per-model state is evidence about a specific model, the global load flag is
        // not, so the specific evidence is consulted first. Onboarding only ever has one
        // model in flight, which makes this ordering invisible here — it is kept
        // identical because the comment on this property promises it is.
        switch modelManager.modelStates[recommendedModel] ?? .notDownloaded {
        case .prewarming, .downloading:
            return recommendedModel
        default:
            break
        }
        if modelManager.modelLoadState == .loading,
           let active = modelManager.activeModel {
            return active
        }
        return nil
    }

    // MARK: - Model Card

    /// Model card that displays name, size, and description from the ModelInfo catalog.
    /// WHY data-driven: On a 6GB+ device this shows "Parakeet v3 / ~800 MB / Rapide et precis (NVIDIA)"
    /// instead of the old hardcoded "Whisper Small / ~500 Mo / Bonne precision".
    private var modelCard: some View {
        let info = ModelInfo.forIdentifier(recommendedModel)
        return VStack(alignment: .leading, spacing: 12) {
            // WHY `String(localized:)` on the fallbacks (issue #661): a `String` passed
            // to `Text` or `Label` is shown verbatim, so a bare literal here bypassed
            // the string catalog.
            Text(info?.localizedDisplayName ?? String(localized: "Voice model"))
                .font(.dictusSubheading)
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                // No size without a catalogue entry: the old fallback was a guessed
                // "~500 Mo", in French whatever the language.
                if let size = info?.sizeLabel {
                    Label(size, systemImage: "internaldrive")
                        .font(.dictusCaption)
                        .foregroundStyle(.secondary)
                }

                // `localizedDescription`, not `description`: the latter is the
                // catalogue's English text and read in English on a French iPhone.
                Label(info?.localizedDescription ?? String(localized: "Accurate and balanced"), systemImage: "waveform")
                    .font(.dictusCaption)
                    .foregroundStyle(.secondary)
            }

            Text("Recommended for your language and iPhone")
                .font(.dictusCaption)
                .foregroundColor(.dictusAccent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dictusGlass()
    }

    // MARK: - Private

    /// Brings this page's local flags in line with the model's real lifecycle state.
    ///
    /// Issue #433: `downloadedModels.contains` on its own stopped meaning "onboarding got
    /// this far". The launch reconciliation now lists a model whose files are complete
    /// even when its compile was interrupted, and that model has never been selected —
    /// `activeModel` is still nil, and nothing has an engine to load. Letting onboarding
    /// move on would hand the user a keyboard whose mic answers "No model downloaded".
    /// `isModelReady` adds the missing half of the question: some model finished
    /// preparing. Starting the download again instead resumes at the interrupted compile,
    /// because the downloader skips every file already on disk. Since #649 the page does
    /// that on its own when nothing is moving (see `.onAppear`).
    private func syncWithPreparationState() {
        if modelManager.downloadedModels.contains(recommendedModel), modelManager.isModelReady {
            downloadComplete = true
            isDownloading = false
            return
        }
        switch modelManager.modelStates[recommendedModel] ?? .notDownloaded {
        case .downloading, .prewarming:
            isDownloading = true
        case .error(let message):
            isDownloading = false
            errorMessage = message
        case .notDownloaded, .ready:
            break
        }
    }

    private func startDownload() {
        isDownloading = true
        errorMessage = nil
        // Surface the full-screen overlay immediately so the user sees feedback
        // even before the first download progress callback fires.
        preparingModelID = recommendedModel

        Task {
            do {
                try await modelManager.downloadModel(recommendedModel)
                downloadComplete = true
                isDownloading = false
                // The overlay closes itself once preloadActiveModel reaches .ready;
                // we don't flip preparingModelID here.
            } catch is CancellationError {
                // Superseded by another attempt at the same model, which owns the
                // screen's state now (issue #449). Not a failure and not a success.
            } catch {
                errorMessage = error.localizedDescription
                isDownloading = false
                preparingModelID = nil
            }
        }
    }
}
