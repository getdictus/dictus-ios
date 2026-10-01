// DictusApp/VoiceNotes/VoiceNotesView.swift
// The shared voice notes: what is in the queue, and what came out of it (#620).
import SwiftUI
import DictusCore

/// The voice note sheet.
///
/// Opened by a tap on the Live Activity, and by the cold path: the share extension
/// told the user to open Dictus, and this is what they see when they do — the note
/// going through, then its result. #620 decision 6 asks for each item's state to be
/// visible; this list is that, and the History card of a finished note carries a
/// voice note mark as well.
struct VoiceNotesView: View {

    /// Where the sheet opened: the list, or straight on one result.
    let initial: VoiceNotePresentation

    @EnvironmentObject private var history: TranscriptionHistoryStore
    @EnvironmentObject private var proStatus: ProStatusManager
    @ObservedObject private var queueStore = VoiceNoteQueueStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var path: [UUID] = []

    /// Finished notes the history holds, newest first. Shown only while the history
    /// may be read, which is the history's own rule (`HistoryAvailability`).
    private var savedResults: [TranscriptionRecord] {
        _ = proStatus.isProActive
        guard HistoryAvailability.isEntitled else { return [] }
        return Array(history.records.filter { $0.source == .sharedFile }.prefix(20))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if queueStore.queue.notes.isEmpty && savedResults.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(Color.dictusBackground.ignoresSafeArea())
            .navigationTitle("Voice notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                VoiceNoteResultView(noteID: id)
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if case .note(let id) = initial, path.isEmpty { path = [id] }
        }
    }

    private var list: some View {
        List {
            let pending = queueStore.queue.notes.filter { !$0.state.isFinished }
            if !pending.isEmpty {
                Section {
                    ForEach(pending) { note in
                        VoiceNoteRow(note: note)
                    }
                } header: {
                    let counts = queueStore.queue.activityCounts
                    Text(VoiceNoteCopy.queueLine(inProgress: counts.inProgress, waiting: counts.waiting))
                }
            }

            let finished = queueStore.queue.notes.filter(\.state.isFinished)
            if !finished.isEmpty || !savedResults.isEmpty {
                Section {
                    ForEach(finished) { note in
                        if note.state == .done {
                            NavigationLink(value: note.id) { VoiceNoteRow(note: note) }
                                .swipeActions { deleteAction { queueStore.delete(note.id) } }
                        } else {
                            VoiceNoteRow(note: note)
                                .swipeActions { deleteAction { queueStore.delete(note.id) } }
                        }
                    }
                    ForEach(savedResults) { record in
                        NavigationLink(value: record.id) { SavedVoiceNoteRow(record: record) }
                    }
                } header: {
                    Text("Finished")
                }
            }

            if !VoiceNoteAvailability.isEntitled && queueStore.queue.hasPendingWork {
                Section {
                    Text("Transcribing voice notes is part of Dictus Pro. Waiting notes start again when Pro is active, and you can delete them at any time.")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func deleteAction(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Label("Delete", systemImage: "trash")
        }
        // Same reason as HistoryView: the tab hierarchy's tint wins over the role.
        .tint(.red)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: ProFeature.voiceNotes.icon)
                .font(.system(size: 44))
                .foregroundColor(.dictusAccent.opacity(0.7))
            Text("No voice notes yet")
                .font(.dictusSubheading)
            Text("Share a voice message or an audio file to Dictus from any app, and its transcript appears here.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One note in the queue.
private struct VoiceNoteRow: View {

    let note: VoiceNote

    @ObservedObject private var processor = VoiceNoteProcessor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.dictusBody)
                    .lineLimit(2)
                Spacer()
            }
            if case .transcribing(let progress) = note.state {
                ProgressView(value: progress)
                    .tint(.dictusAccent)
            }
            HStack(spacing: 6) {
                Text(note.receivedAt.formatted(date: .omitted, time: .shortened))
                if let duration = note.durationLabel {
                    Text("·")
                    Text(duration)
                }
            }
            .font(.dictusCaption)
            .foregroundColor(.secondary)

            if case .failed(let failure) = note.state {
                Text(VoiceNoteCopy.failure(failure))
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                if failure.isRetryable && note.audioFileName != nil {
                    Button("Try again") { processor.retry(note.id) }
                        .font(.dictusCaption.weight(.semibold))
                        .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        switch note.state {
        case .waiting:
            return String(localized: "Waiting", comment: "Voice note row: queued, not started (#620).")
        case .transcribing:
            return String(localized: "Transcribing…", comment: "Voice note row: being transcribed (#620).")
        case .done:
            return note.transcript ?? ""
        case .failed:
            return String(localized: "Not transcribed", comment: "Voice note row: failed; the reason follows (#620).")
        }
    }

    private var icon: String {
        switch note.state {
        case .waiting: return "clock"
        case .transcribing: return "waveform"
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch note.state {
        case .waiting: return .secondary
        case .transcribing: return .dictusAccent
        case .done: return .dictusSuccess
        case .failed: return .orange
        }
    }
}

/// A finished note the history holds.
private struct SavedVoiceNoteRow: View {

    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.dictusSuccess)
                Text(record.summary ?? record.text)
                    .font(.dictusBody)
                    .lineLimit(2)
                Spacer()
            }
            HStack(spacing: 6) {
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                Text("·")
                Text(record.durationLabel)
            }
            .font(.dictusCaption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
