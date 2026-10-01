// DictusApp/VoiceNotes/VoiceNoteResultView.swift
// One shared voice note: the summary, then the transcript (#620 decision 5).
import SwiftUI
import DictusCore

/// The result screen, MacWhisper's shape: Summary above, Transcript below.
///
/// ### Where the text comes from
///
/// A finished note lives in the history (#620 decision 7), under the note's own id.
/// When History is switched off, the history refuses it and the note keeps its text
/// in the voice note queue instead (`VoiceNoteQueue.complete`). This screen reads
/// whichever holds it, and writes the summary back to the same place.
///
/// ### Why the summary is computed here
///
/// Apple Foundation Models refuse a backgrounded app (#315), and the warm path
/// transcribes in the background. So the summary runs when the user opens the
/// result, in the foreground, once, and is stored. A summary inside the Dynamic
/// Island is out of scope for 2.0.0 for that reason.
struct VoiceNoteResultView: View {

    let noteID: UUID

    @EnvironmentObject private var history: TranscriptionHistoryStore
    @ObservedObject private var queueStore = VoiceNoteQueueStore.shared

    @State private var summaryState: SummaryState = .idle
    @State private var copiedTarget: String?

    private enum SummaryState: Equatable {
        case idle
        case running
        case failed(String)
    }

    /// What the screen shows, from either store.
    private struct Content {
        let transcript: String
        let summary: String?
        let summaryModeIdentifier: String?
        let language: String
        let durationLabel: String?
        let durationSeconds: Int?
        let date: Date
    }

    private var content: Content? {
        if let record = history.record(id: noteID) {
            return Content(transcript: record.text, summary: record.summary,
                           summaryModeIdentifier: record.summaryModeIdentifier,
                           language: record.language, durationLabel: record.durationLabel,
                           durationSeconds: record.durationSeconds, date: record.createdAt)
        }
        if let note = queueStore.queue.note(id: noteID), let transcript = note.transcript {
            return Content(transcript: transcript, summary: note.summary,
                           summaryModeIdentifier: note.summaryModeIdentifier,
                           language: note.language ?? TranscriptionRecord.autoDetectedCode,
                           durationLabel: note.durationLabel, durationSeconds: note.durationSeconds,
                           date: note.receivedAt)
        }
        return nil
    }

    var body: some View {
        Group {
            if let content {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        metadata(content)
                        summarySection(content)
                        textBlock(title: Text("Transcript"), text: content.transcript, target: "transcript")
                    }
                    .padding()
                }
                .task { await summariseIfNeeded(content) }
            } else {
                missing
            }
        }
        .background(Color.dictusBackground.ignoresSafeArea())
        .navigationTitle("Voice note")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private func metadata(_ content: Content) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ProFeature.voiceNotes.icon)
            Text(content.date.formatted(date: .abbreviated, time: .shortened))
            Text("·")
            Text(content.language.uppercased())
            if let duration = content.durationLabel {
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
        } else if let mode = VoiceNoteSettings.load().mode.smartMode {
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
                    Text("Summarising…")
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
            }
        }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
              VoiceNoteSettings.load().mode.smartMode != nil,
              summaryUnavailableReason == nil,
              VoiceNoteAvailability.isEntitled else { return }
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
            engine: history.record(id: noteID)?.engine ?? .parakeet,
            modelIdentifier: AppGroup.defaults.string(forKey: SharedKeys.activeModel) ?? ""
        )
        let outcome = await PolishCoordinator.shared.polish(
            raw: content.transcript, languagePolicy: policy, smartMode: mode,
            // Smart tasks skip the duration gate; the value is the metrics' context.
            recordingDuration: TimeInterval(content.durationSeconds ?? 0)
        )
        // A degraded outcome hands back the transcript itself: never shown as a summary.
        if let failure = outcome.smartModeFailure {
            PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "summary", action: "failed",
                                               details: "mode=\(mode.id) outcome=\(failure.outcome) reason=\(failure.reason)"))
            summaryState = .failed(VoiceNoteCopy.summaryFailed(failure))
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
