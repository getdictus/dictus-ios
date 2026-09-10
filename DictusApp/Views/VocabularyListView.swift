// DictusApp/Views/VocabularyListView.swift
// The one screen custom vocabulary gets (issue #80, decision 11).
import SwiftUI
import DictusCore

/// The user's terms: what they are called, what the engine writes instead.
///
/// ### One screen, not two (#80 decision 11)
///
/// An entry is a term plus its variants, and splitting "manage terms" from "manage
/// replacements" would ask the user to hold a distinction the data does not make.
/// The list edits both; the add sheet asks two questions.
///
/// ### Why the second field is required (#536, amending #80 decision 6)
///
/// It used to be optional, because a term alone still joined the polish prompt. #536
/// measured that on device and the prompt was ignored, so a term alone now changes
/// nothing at all — and the paywall sentence, "Teach Dictus your technical terms",
/// rests entirely on the replacement pass. The sheet therefore refuses to save an
/// entry with no variant, which is the one state that would make the sentence false.
///
/// **Entries stored before that are kept.** Nothing migrates, nothing is deleted, and
/// no edit is forced at load: a variant-less entry loads, lists, and says on its own
/// row what it needs (`VocabularyEntry.hasEffect`).
struct VocabularyListView: View {

    @StateObject private var store = VocabularyStore.shared

    /// The entry being added or edited, or nil when the sheet is closed.
    @State private var editing: VocabularyEditorSubject?

    /// Confirmation for the destructive reset, on the model of "Reset learned words".
    @State private var showResetConfirmation = false

    /// Set when the store refused a write. It publishes nothing it could not put on
    /// disk, so the row simply stays — and a row that snaps back with no explanation
    /// is the second-worst outcome after one that disappears and returns tomorrow.
    @State private var writeFailed = false

    var body: some View {
        List {
            Section {
                if store.isEmpty {
                    Text("No terms yet. Add the words Dictus gets wrong.")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(store.entries) { entry in
                        row(entry)
                    }
                    .onDelete { offsets in
                        writeFailed = !store.delete(atOffsets: offsets)
                    }
                }
            } header: {
                Text("Your terms")
            } footer: {
                // Deliberately narrow, and now exactly the whole truth. The sentence
                // before it said Dictus "corrects these in your transcriptions",
                // which was false for an entry with no variants; the sentence after
                // it named the polish prompt, which #536 measured as doing nothing.
                // A replacement is what the feature does, so it is what the footer
                // describes.
                if writeFailed {
                    Text("Could not save. Your device may be out of storage.")
                        .foregroundColor(.red)
                } else {
                    Text("When Dictus writes one of these variants, it is replaced by your spelling.")
                }
            }

            Section {
                Button {
                    editing = .new
                } label: {
                    Label("Add a term", systemImage: "plus")
                }
                .disabled(store.isFull)
            } footer: {
                if store.isFull {
                    Text("You have reached the limit of \(VocabularyStore.maxEntries) terms. Delete one to add another.")
                }
            }

            if !store.isEmpty {
                Section {
                    Button("Reset vocabulary", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("Vocabulary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.isEmpty {
                EditButton()
            }
        }
        .sheet(item: $editing) { subject in
            NavigationStack {
                VocabularyEditorView(subject: subject)
            }
        }
        .confirmationDialog(
            "Reset vocabulary?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Forget \(store.count) terms", role: .destructive) {
                writeFailed = !store.resetAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every term and every variant will be deleted. Your transcriptions will no longer be corrected.")
        }
    }

    /// One term. Tapping opens the editor; the trailing switch is the per-entry
    /// disable (#80 decision 8), which keeps the entry while stopping its rewrites.
    private func row(_ entry: VocabularyEntry) -> some View {
        HStack(spacing: 12) {
            Button {
                editing = .existing(entry)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.term)
                        .foregroundColor(.primary)
                    // "Replaces:" and not the bare list. The row used to read
                    // `pomme` over `banane` with nothing saying which was which,
                    // and the person who wrote this feature's spec hesitated in
                    // front of it twice. One word carries the direction, and the
                    // second line was already there so the row does not grow.
                    //
                    // The other branch is #536's: an entry saved before the second
                    // field became required does nothing, and the row is where that
                    // is visible. Orange, the app's warning tint, and never red —
                    // nothing is broken and no data is at risk, there is one thing
                    // left to type. The sentence names it rather than saying "no
                    // variants", which describes the field and not the fix.
                    if entry.hasEffect {
                        Text("Replaces: \(entry.variantsLine)")
                            .font(.dictusCaption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Does nothing yet. Add what Dictus writes instead.")
                            .font(.dictusCaption)
                            .foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(
                get: { entry.isEnabled },
                set: { writeFailed = !store.update(entry.enabled($0)) }
            ))
            .labelsHidden()
            .accessibilityLabel(Text(entry.term))
        }
    }
}

/// What the editor sheet is working on. `Identifiable` so `sheet(item:)` can drive
/// it, and an enum rather than an optional entry plus a boolean because "adding" and
/// "editing nothing" are the same state in that spelling and behave differently.
enum VocabularyEditorSubject: Identifiable {
    case new
    case existing(VocabularyEntry)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let entry): return entry.id.uuidString
        }
    }

    var entry: VocabularyEntry? {
        switch self {
        case .new: return nil
        case .existing(let entry): return entry
        }
    }
}

/// The add and edit sheet: two fields, and nothing else (#80).
struct VocabularyEditorView: View {

    let subject: VocabularyEditorSubject

    @StateObject private var store = VocabularyStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var term: String
    @State private var variantsLine: String

    /// Set when the store refused to write. The sheet then stays open rather than
    /// dismissing over a term that was never stored — losing what the user typed is
    /// the one outcome worse than telling them it failed.
    @State private var saveFailed = false

    init(subject: VocabularyEditorSubject) {
        self.subject = subject
        _term = State(initialValue: subject.entry?.term ?? "")
        _variantsLine = State(initialValue: subject.entry?.variantsLine ?? "")
    }

    /// What the two fields would produce, or nil when the term is empty or too long.
    /// Building the real entry rather than validating a copy of its rules keeps the
    /// Save button and the model from ever disagreeing.
    private var candidate: VocabularyEntry? {
        VocabularyEntry(
            term: term,
            variants: VocabularyEntry.variants(fromLine: variantsLine),
            isEnabled: subject.entry?.isEnabled ?? true,
            id: subject.entry?.id ?? UUID(),
            dateAdded: subject.entry?.dateAdded ?? Date()
        )
    }

    private var duplicatesAnotherTerm: Bool {
        !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && store.contains(term: term, excluding: subject.entry?.id)
    }

    /// Whether the second field is still empty, on a sheet the user has started
    /// filling. It drives the explanation under that field, so it stays false on an
    /// untouched new-term sheet: telling someone what is missing before they have
    /// typed anything is scolding, not helping.
    private var variantsMissing: Bool {
        candidate?.hasEffect == false
    }

    private var canSave: Bool {
        guard let candidate else { return false }
        // `hasEffect` and not `variants.isEmpty` (#536): the rule is "this entry
        // would change a transcript", the model owns it, and a unit test can reach
        // it. A line of nothing but commas is refused here for the same reason —
        // `VocabularyEntry` cleans it away to no variants at all.
        return candidate.hasEffect && !duplicatesAnotherTerm
    }

    var body: some View {
        Form {
            // Both sections carry a header as well as a placeholder, and that is the
            // point: a placeholder disappears the moment the field has text, so once
            // both are filled nothing on screen says which one holds the correct
            // spelling. A header stays.
            Section {
                TextField("Which term?", text: $term)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("The correct spelling")
            } footer: {
                if duplicatesAnotherTerm {
                    Text("This term is already in your vocabulary.")
                        .foregroundColor(.red)
                } else {
                    Text("The spelling Dictus should write.")
                }
            }

            Section {
                TextField("How does Dictus write it instead?", text: $variantsLine)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("What Dictus writes instead")
            } footer: {
                // Three states, in the order they can occur. The middle one is #536's
                // and it is why Save is greyed out: without it the button refuses
                // with no reason on screen, which is the failure this feature's own
                // device test already produced once.
                if saveFailed {
                    Text("Could not save. Your device may be out of storage.")
                        .foregroundColor(.red)
                } else if variantsMissing {
                    Text("Add at least one. A term on its own changes nothing Dictus writes.")
                        .foregroundColor(.orange)
                } else {
                    Text("Separated by commas. Dictus replaces each of them with your spelling.")
                }
            }
        }
        .navigationTitle(subject.entry == nil ? "New term" : "Edit term")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
    }

    private func save() {
        guard let candidate else { return }
        let stored = subject.entry == nil ? store.add(candidate) : store.update(candidate)
        // The store only publishes what it managed to write (#80 review). A refusal
        // here means the file was not updated, so dismissing would show a list that
        // disagrees with the disk and lose the entry at the next launch.
        guard stored else {
            saveFailed = true
            return
        }
        dismiss()
    }
}
