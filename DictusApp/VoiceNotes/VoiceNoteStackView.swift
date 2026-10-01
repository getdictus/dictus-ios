// DictusApp/VoiceNotes/VoiceNoteStackView.swift
// The unread voice notes, side by side, in the order they were shared (#620 rework).
import SwiftUI
import DictusCore

/// What the voice note screen opens on.
struct VoiceNoteStackRequest: Identifiable, Equatable {
    /// The note the Live Activity link named, if any.
    let focus: UUID?
    let id = UUID()
}

/// The voice note screen: one card per unread note, swiped left and right.
///
/// ### Why this replaced the list (device test, 2026-10-01)
///
/// The first build opened a list of notes with green checks on a tap of the island.
/// The maintainer got lost in it: a list he could not find again, that did not look
/// like History, between him and the text. Decided instead:
///
/// - **One screen for a voice note**, whatever opened it: the island, a link, or
///   History (which pushes the same card on its own).
/// - **Unread notes are stacked**, oldest first, the order they were shared; reading
///   one is opening it. Read notes live in History only.
/// - Notes still being transcribed are cards too, so the cold path — "Open Dictus,
///   your voice note is waiting" — opens on the note itself, turning from progress
///   into its result.
///
/// The cards are captured when the screen opens and only ever added to while it is
/// open: a card read a second ago must not vanish from under the user's finger.
struct VoiceNoteStackView: View {

    let request: VoiceNoteStackRequest

    @EnvironmentObject private var history: TranscriptionHistoryStore
    @ObservedObject private var queueStore = VoiceNoteQueueStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var cards: [UUID] = []
    @State private var selection: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyState
                } else {
                    TabView(selection: $selection) {
                        ForEach(cards, id: \.self) { id in
                            VoiceNoteCardView(noteID: id, isActive: id == selection)
                                .tag(Optional(id))
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: cards.count > 1 ? .always : .never))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }
            }
            .background(Color.dictusBackground.ignoresSafeArea())
            .navigationTitle(title)
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
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: loadCards)
        .onReceive(queueStore.$queue) { _ in appendArrivals() }
        .onReceive(history.$records) { _ in appendArrivals() }
        .onDisappear {
            // Failures and History-off results the user has now seen leave the queue.
            queueStore.mutate { $0.removeOpenedFinished() }
        }
    }

    /// "Voice note", or "Voice note 2 of 3" when there are several.
    private var title: String {
        guard cards.count > 1, let selection, let index = cards.firstIndex(of: selection) else {
            return String(localized: "Voice note", comment: "Title of the voice note screen (#620).")
        }
        return String(localized: "Voice note \(index + 1) of \(cards.count)",
                      comment: "Title of the voice note screen when several unread notes are stacked; swipe to move between them (#620).")
    }

    /// Unread and pending notes, oldest first. Without them, the note the link named.
    private var stackable: [UUID] {
        let queued = queueStore.queue.stackable.map { ($0.id, $0.receivedAt) }
        let saved = history.unreadVoiceNotes.map { ($0.id, $0.createdAt) }
        var seen = Set<UUID>()
        return (queued + saved)
            .sorted { $0.1 < $1.1 }
            .compactMap { seen.insert($0.0).inserted ? $0.0 : nil }
    }

    private func loadCards() {
        var ids = stackable
        // A note already read is still what the link asked for: it opens alone.
        if let focus = request.focus, !ids.contains(focus) { ids = [focus] }
        cards = ids
        // The stack opens on the oldest unread note, so a swipe to the left always
        // moves forward in the order things were shared.
        selection = ids.first
    }

    private func appendArrivals() {
        let fresh = stackable.filter { !cards.contains($0) }
        guard !fresh.isEmpty else { return }
        // An empty screen takes a note that arrives while it is open, and shows it.
        let wasEmpty = cards.isEmpty
        cards.append(contentsOf: fresh)
        if wasEmpty { selection = cards.first }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: ProFeature.voiceNotes.icon)
                .font(.system(size: 44))
                .foregroundColor(.dictusAccent.opacity(0.7))
            Text("No unread voice notes")
                .font(.dictusSubheading)
            Text("Voice notes you have read are in History.")
                .font(.dictusCaption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
