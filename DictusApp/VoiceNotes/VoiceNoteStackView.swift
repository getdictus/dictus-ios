// DictusApp/VoiceNotes/VoiceNoteStackView.swift
// The unread voice notes, side by side, in the order they were shared (#620 rework).
import SwiftUI
import DictusCore

/// What the voice note screen opens on.
struct VoiceNoteStackRequest: Identifiable, Equatable {
    /// The note the Live Activity link named, if any.
    let focus: UUID?
    /// What opened it, for the log: `auto`, `island` or `link`.
    let source: String
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
    @State private var session = VoiceNoteStackSession(stackable: [])
    @State private var loaded = false

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
        .onAppear {
            loadCards()
            loaded = true
        }
        .onReceive(queueStore.$queue) { _ in appendArrivals() }
        .onReceive(history.$records) { _ in appendArrivals() }
        .onDisappear {
            // Failures and History-off results the user has now seen leave the queue.
            queueStore.mutate { $0.removeOpenedFinished() }
            let unreadLeft = Set(stackable.map(\.id))
            log("dismiss", "shown=\(cards.count) unreadLeft=\(unreadLeft.count)")
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
    /// Unread and running notes from both stores. The ordering, de-duplication and
    /// append rules are `VoiceNoteStackSession`'s, tested in DictusCore.
    private var stackable: [VoiceNoteStackSession.Entry] {
        queueStore.queue.stackable.map { .init(id: $0.id, sharedAt: $0.receivedAt) }
            + history.unreadVoiceNotes.map { .init(id: $0.id, sharedAt: $0.createdAt) }
    }

    private func loadCards() {
        session = VoiceNoteStackSession(stackable: stackable, focus: request.focus)
        cards = session.cards
        // The stack opens on the oldest unread note, so a swipe to the left always
        // moves forward in the order things were shared.
        selection = cards.first
        log("present", "source=\(request.source) ids=\(Self.short(cards))")
    }

    private func appendArrivals() {
        // Before the first load, `onAppear` has not built the session yet.
        guard loaded else { return }
        let fresh = session.append(stackable: stackable)
        guard !fresh.isEmpty else { return }
        // An empty screen takes a note that arrives while it is open, and shows it.
        let wasEmpty = cards.isEmpty
        cards = session.cards
        if wasEmpty { selection = cards.first }
        log("append", "ids=\(Self.short(fresh))")
    }

    private func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "stack", action: action, details: details))
    }

    /// Ids as 8-character prefixes, the same form the queue lines use.
    static func short(_ ids: [UUID]) -> String {
        ids.map { String($0.uuidString.prefix(8)) }.joined(separator: ",")
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
