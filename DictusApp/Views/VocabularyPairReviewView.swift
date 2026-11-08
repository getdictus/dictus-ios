// DictusApp/Views/VocabularyPairReviewView.swift
// The change an accepted vocabulary suggestion will make, shown before it is made (#512).
import SwiftUI
import DictusCore

/// What **Accept** on a suggested pair opens: one sentence saying which change it is
/// (a variant added to a term, or a new term from a word typed on the keyboard), then
/// the term and the new variant in two fields, filled in and editable, with the
/// term's existing variants listed. **Add** stores exactly what the sentence says;
/// **Cancel** stores nothing.
///
/// ### Why a screen and not a direct write
///
/// A variant rewrites every future dictation that contains it, and a wrong one is
/// noticed only when it has already changed someone's text. So nothing is added
/// silently (#512): the user sees exactly what the entry becomes before it does, and
/// can fix a suggestion that is nearly right (capitals of a learned word, one word
/// too many) instead of refusing it.
struct VocabularyPairReviewView: View {

    @StateObject private var store = VocabularyStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var term: String
    @State private var variant: String
    @State private var saveFailed = false

    init(pair: VocabularyPair) {
        _term = State(initialValue: pair.canonical)
        _variant = State(initialValue: pair.observed)
    }

    /// What Add would store from the two fields, against the vocabulary as it is now.
    /// Nil when it would change nothing: Add is then disabled and the sheet says so.
    private var acceptance: VocabularyPairAcceptance? {
        VocabularyPairAcceptance(term: term, variant: variant, vocabulary: store.entries)
    }

    /// The stored term the variant would join, for its existing variants.
    private var stored: VocabularyEntry? {
        store.entry(matchingTerm: term)
    }

    /// A new term needs room; a variant added to a term does not.
    private var exceedsLimit: Bool {
        if case .newTerm = acceptance { return store.isFull }
        return false
    }

    var body: some View {
        Form {
            Section {
                summary
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("vocabulary.pair.review.summary")
            }

            Section {
                TextField("Which term?", text: $term)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("vocabulary.pair.review.term")
            } header: {
                Text("The correct spelling")
            }

            Section {
                ForEach(stored?.variants ?? [], id: \.self) { existing in
                    Text(verbatim: existing)
                        .foregroundColor(.secondary)
                }
                Label {
                    TextField("How does Dictus write it instead?", text: $variant)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("vocabulary.pair.review.variant")
                } icon: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
            } header: {
                Text("What Dictus writes instead")
            } footer: {
                footer
            }
        }
        .navigationTitle("Check the change")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { add() }
                    .disabled(acceptance == nil || exceedsLimit)
                    .accessibilityIdentifier("vocabulary.pair.review.confirm")
            }
        }
    }

    private var summary: Text {
        switch acceptance {
        case .newTerm(let entry):
            return Text("New term “\(entry.term)”, with the variant “\(variantText)”.")
        case .addVariant(let entry):
            return Text("Variant “\(variantText)” added to “\(entry.term)”.")
        case nil:
            return Text("Nothing would change. Check the term and the variant.")
        }
    }

    private var variantText: String {
        variant.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var footer: some View {
        if saveFailed {
            Text("Could not save. Your device may be out of storage.")
                .foregroundColor(.red)
        } else if exceedsLimit {
            Text("You have reached the limit of \(VocabularyStore.maxEntries) terms. Delete one to add another.")
                .foregroundColor(.red)
        } else if let entry = acceptance?.entry {
            if entry.isEnabled {
                Text("From now on, when Dictus writes “\(variantText)”, it writes “\(entry.term)” instead.")
            } else {
                Text("Already in your vocabulary, switched off. The variant is added but applies only once you switch the term back on.")
                    .foregroundColor(.orange)
            }
        }
    }

    private func add() {
        guard let acceptance else { return }
        // The store publishes only what it wrote; on a refusal the sheet stays open
        // and says so, rather than closing over a change that was never stored.
        let stored: Bool
        switch acceptance {
        case .newTerm(let entry): stored = store.add(entry)
        case .addVariant(let entry): stored = store.update(entry)
        }
        guard stored else {
            saveFailed = true
            return
        }
        dismiss()
    }
}
