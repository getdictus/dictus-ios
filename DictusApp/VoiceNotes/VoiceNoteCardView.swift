// DictusApp/VoiceNotes/VoiceNoteCardView.swift
// One shared voice note, whatever state it is in: the one view every entry opens (#620).
import SwiftUI
import DictusCore

/// One voice note: its summary above its transcript once it has a result, its
/// progress while it is transcribed, or why it failed.
///
/// ### One view for every way in
///
/// The first device test (2026-10-01) lost the maintainer between a list sheet, a
/// result screen and History, which did not look alike. So a voice note has one
/// look: this card. `VoiceNoteStackView` lays several side by side when more than
/// one is unread; History pushes the same card on its own (`VoiceNoteResultView`).
///
/// ### Where the text comes from
///
/// A finished note lives in History under its own id (#620 decision 7). With
/// History switched off, the history refuses it and the note keeps its text in
/// the voice note queue instead, until the user has read it (`VoiceNoteQueue`).
/// This card reads whichever holds it and writes the summary back to the same place.
///
/// ### Why the summary is computed here
///
/// Apple Foundation Models refuse a backgrounded app (#315), and the warm path
/// transcribes in the background. So the summary runs when the card is on screen,
/// in the foreground, once, and is stored.
struct VoiceNoteCardView: View {

    let noteID: UUID

    /// Whether this card is the one the user is looking at. Only the visible card is
    /// marked read and summarised: a stack must not mark as read, or spend Apple
    /// Intelligence on, cards the user has not swiped to.
    let isActive: Bool

    @EnvironmentObject private var history: TranscriptionHistoryStore
    @ObservedObject private var queueStore = VoiceNoteQueueStore.shared
    @ObservedObject private var processor = VoiceNoteProcessor.shared

    @State private var summaryState: SummaryState = .idle
    @State private var copiedTarget: String?

    private enum SummaryState: Equatable {
        case idle
        case running
        case failed(String)
        /// The armed mode declined this transcript as too short for it (#650): under
        /// its `minimumInputCharacters` before anything ran, or, for `Liste`, a list of
        /// one item after the model ran. Not a failure, so no "Try again": the card
        /// shows the transcript alone, as it does for a short `Résumé`. Kept for the
        /// card's lifetime so the decline is neither recomputed nor logged again on
        /// every activation of a stack.
        case declined
    }

    /// A finished result, from either store.
    struct Content {
        let transcript: String
        let summary: String?
        let summaryModeIdentifier: String?
        let language: String
        let durationLabel: String?
        let durationSeconds: Int?
        let date: Date
        let engine: SpeechEngine?
    }

    private enum Resolution {
        case result(Content)
        case pending(VoiceNote)
        case failed(VoiceNote, VoiceNoteFailure)
        case missing
    }

    private var resolution: Resolution {
        if let record = history.record(id: noteID) {
            return .result(Content(transcript: record.text, summary: record.summary,
                                   summaryModeIdentifier: record.summaryModeIdentifier,
                                   language: record.language, durationLabel: record.durationLabel,
                                   durationSeconds: record.durationSeconds, date: record.createdAt,
                                   engine: record.engine))
        }
        guard let note = queueStore.queue.note(id: noteID) else { return .missing }
        switch note.state {
        case .done:
            guard let transcript = note.transcript else { return .missing }
            return .result(Content(transcript: transcript, summary: note.summary,
                                   summaryModeIdentifier: note.summaryModeIdentifier,
                                   language: note.language ?? TranscriptionRecord.autoDetectedCode,
                                   durationLabel: note.durationLabel, durationSeconds: note.durationSeconds,
                                   date: note.receivedAt, engine: nil))
        case .failed(let failure):
            return .failed(note, failure)
        case .waiting, .transcribing:
            return .pending(note)
        }
    }

    /// Changes when the card becomes visible or its note finishes, which is when it
    /// is marked read and, if due, summarised.
    private var activationKey: String {
        let stage: String
        switch resolution {
        case .result: stage = "result"
        case .failed: stage = "failed"
        case .pending: stage = "pending"
        case .missing: stage = "missing"
        }
        return "\(isActive)-\(stage)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch resolution {
                case .result(let content):
                    metadata(date: content.date, language: content.language, duration: content.durationLabel)
                    summarySection(content)
                    textBlock(title: Text("Transcript"), text: content.transcript, target: "transcript")
                case .pending(let note):
                    metadata(date: note.receivedAt, language: nil, duration: note.durationLabel)
                    pendingCard(note)
                case .failed(let note, let failure):
                    metadata(date: note.receivedAt, language: nil, duration: note.durationLabel)
                    failedCard(note, failure)
                case .missing:
                    missing
                }
            }
            .padding()
        }
        .task(id: activationKey) { await activate() }
    }

    // MARK: - Activation

    private func activate() async {
        guard isActive else { return }
        switch resolution {
        case .result(let content):
            markOpened()
            await summariseIfNeeded(content)
        case .failed:
            markOpened()
        case .pending, .missing:
            // Read means "the outcome was seen". A note still running has none yet.
            break
        }
    }

    private func markOpened() {
        if history.record(id: noteID) != nil {
            history.markOpened(id: noteID)
        } else {
            queueStore.mutate { $0.markOpened(noteID) }
        }
        processor.noteRead(noteID)
    }

    // MARK: - Sections

    private func metadata(date: Date, language: String?, duration: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ProFeature.voiceNotes.icon)
            Text(date.formatted(date: .abbreviated, time: .shortened))
            if let language {
                Text("·")
                Text(language.uppercased())
            }
            if let duration {
                Text("·")
                Text(duration)
            }
            Spacer()
        }
        .font(.dictusCaption)
        .foregroundColor(.secondary)
    }

    @ViewBuilder
    private func summarySection(_ content: Content) -> some View {
        if let summary = content.summary {
            textBlock(title: Text(modeTitle(content.summaryModeIdentifier)), text: summary, target: "summary")
        } else if summaryState != .declined,
                  let mode = VoiceNoteSettings.load().mode.smartMode,
                  mode.runs(onInputOfLength: content.transcript.count) {
            // A note too short for its mode shows its transcript alone, with no card
            // announcing a result that would only restate it (#620 rework). "Too short"
            // is the mode's answer since #650, not a voice note constant: a short
            // `Résumé` hides this card, a short `→ EN` translates.
            VStack(alignment: .leading, spacing: 8) {
                Text(modeTitle(mode.id))
                    .font(.dictusSubheading)
                summaryPlaceholder(content)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .dictusGlass()
        }
    }

    @ViewBuilder
    private func summaryPlaceholder(_ content: Content) -> some View {
        if let reason = summaryUnavailableReason {
            Text(VoiceNoteCopy.summaryUnavailable(reason))
                .font(.dictusCaption)
                .foregroundColor(.secondary)
        } else if !VoiceNoteAvailability.isEntitled {
            // Pro has ended (#593): the transcript stays, nothing new is generated.
            Text("Summaries are part of Dictus Pro. Your transcript stays available.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
        } else {
            switch summaryState {
            case .idle, .running:
                HStack(spacing: 8) {
                    ProgressView()
                    // Generic on purpose: the mode may be a translation or a list, not
                    // only Résumé (device test, 2026-10-01).
                    Text("Processing…")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                    Button("Try again") {
                        Task { await summarise(content) }
                    }
                    .font(.dictusCaption.weight(.semibold))
                }
            case .declined:
                // `summarySection` does not draw this card at all once declined.
                EmptyView()
            }
        }
    }

    private func pendingCard(_ note: VoiceNote) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                if case .transcribing = note.state {
                    Text(String(localized: "Transcribing…", comment: "Voice note card: being transcribed (#620)."))
                        .font(.dictusSubheading)
                } else {
                    Text(String(localized: "Waiting", comment: "Voice note card: queued, not started (#620)."))
                        .font(.dictusSubheading)
                }
            }
            if case .transcribing(let progress) = note.state {
                ProgressView(value: progress)
                    .tint(.dictusAccent)
            }
            if !VoiceNoteAvailability.isEntitled {
                Text("Transcribing voice notes is part of Dictus Pro. Waiting notes start again when Pro is active, and you can delete them at any time.")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                Button(role: .destructive) {
                    queueStore.delete(note.id)
                } label: {
                    Text("Delete")
                }
                .tint(.red)
                .font(.dictusCaption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .dictusGlass()
    }

    private func failedCard(_ note: VoiceNote, _ failure: VoiceNoteFailure) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(String(localized: "Not transcribed", comment: "Voice note card: failed; the reason follows (#620)."))
                    .font(.dictusSubheading)
            }
            Text(VoiceNoteCopy.failure(failure))
                .font(.dictusCaption)
                .foregroundColor(.secondary)
            if failure.isRetryable && note.audioFileName != nil {
                Button("Try again") { processor.retry(note.id) }
                    .font(.dictusCaption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .dictusGlass()
    }

    private func textBlock(title: Text, text: String, target: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                title.font(.dictusSubheading)
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                    HapticFeedback.recordingStopped()
                    copiedTarget = target
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedTarget == target { copiedTarget = nil }
                    }
                } label: {
                    Image(systemName: copiedTarget == target ? "checkmark" : "doc.on.doc")
                        .foregroundColor(.dictusAccent)
                }
                .accessibilityLabel(copiedTarget == target ? Text("Copied!") : Text("Copy"))
                ShareLink(item: text) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.dictusAccent)
                }
                .accessibilityLabel(Text("Share"))
            }

            Text(text)
                .font(.dictusBody)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding()
        .dictusGlass()
    }

    private var missing: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 40))
                .foregroundColor(.dictusAccent.opacity(0.7))
            Text("This voice note is no longer available.")
                .font(.dictusSubheading)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private func modeTitle(_ identifier: String?) -> String {
        guard let identifier, let mode = SmartModeCatalogue.builtIns.first(where: { $0.id == identifier }) else {
            return String(localized: "Summary", comment: "Fallback title of the voice note result's upper section (#620).")
        }
        return SmartModeListView.listName(for: mode)
    }

    // MARK: - Summary

    private var summaryUnavailableReason: SmartModeUnavailableReason? {
        VoiceNoteAvailability.summaryUnavailableReason(engineState: PolishAvailability.state)
    }

    private func summariseIfNeeded(_ content: Content) async {
        guard content.summary == nil, summaryState == .idle,
              let mode = VoiceNoteSettings.load().mode.smartMode,
              summaryUnavailableReason == nil,
              VoiceNoteAvailability.isEntitled else { return }
        // The mode's own floor, the one the keyboard applies (#650). Checked here,
        // before `polish`, rather than left to `PolishService`'s short-input branch:
        // that branch runs a Normal polish in the mode's place, which a voice note
        // would spend Apple Intelligence on and then not show. The skip is still
        // recorded, with the same event the keyboard writes, so an export tells a
        // short note that skipped its mode from one that never tried.
        guard mode.runs(onInputOfLength: content.transcript.count) else {
            summaryState = .declined
            await PolishCoordinator.shared.recordSkippedForLength(mode, raw: content.transcript)
            return
        }
        await summarise(content)
    }

    private func summarise(_ content: Content) async {
        guard let mode = VoiceNoteSettings.load().mode.smartMode else { return }
        summaryState = .running
        let policy = TranscriptionLanguagePolicy(
            mode: content.language == TranscriptionRecord.autoDetectedCode
                ? .autoDetect
                : SupportedLanguage(rawValue: content.language).map(TranscriptionLanguageMode.explicit) ?? .autoDetect,
            keyboardLanguage: SupportedLanguage.active,
            engine: content.engine ?? .parakeet,
            modelIdentifier: AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? ""
        )
        // Its own slot (#648): a dictation started while this runs must not cancel it.
        // Keyed by note: a card rebuilt while this note's mode is still running (the
        // stack dismissed in the background, the note reopened from History) attaches
        // to that run instead of starting a second one that would supersede it.
        let outcome = await PolishCoordinator.shared.polishVoiceNote(
            noteID: noteID,
            raw: content.transcript, languagePolicy: policy, smartMode: mode,
            // Smart tasks skip the duration gate; the value is the metrics' context.
            recordingDuration: TimeInterval(content.durationSeconds ?? 0)
        )
        // A degraded outcome hands back the transcript itself: never shown as a summary.
        if let failure = outcome.smartModeFailure {
            // A decline is not a failure (#650). On a voice note it is `Liste`'s output
            // check, now reachable since short notes run their mode: a one-item list
            // was turned down, and the service has already recorded why. "Could not
            // be produced" with a "Try again" would invite the same decline again.
            let declined = failure.outcome == PolishMetrics.Outcome.smartModeSkippedShortInput.rawValue
            PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "summary",
                                               action: declined ? "declined" : "failed",
                                               details: "mode=\(mode.id) outcome=\(failure.outcome) reason=\(failure.reason)"))
            summaryState = declined ? .declined : .failed(VoiceNoteCopy.summaryFailed(failure))
            return
        }
        guard let summary = outcome.text?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty else {
            summaryState = .failed(String(localized: "The summary could not be produced."))
            return
        }
        if history.record(id: noteID) != nil {
            history.updateSummary(id: noteID, to: summary, modeIdentifier: mode.id)
        } else {
            queueStore.mutate {
                $0.update(noteID) {
                    $0.summary = summary
                    $0.summaryModeIdentifier = mode.id
                }
            }
        }
        summaryState = .idle
    }
}
