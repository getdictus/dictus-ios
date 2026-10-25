// DictusApp/Views/VocabularyPairReviewView.swift
// The change an accepted vocabulary suggestion will make, shown before it is made (#512).
import SwiftUI
import DictusCore

/// What **Accept** on a suggested pair opens: one sentence saying which change it is
/// (a variant added to a term, or a new term from a word typed on the keyboard), then
/// the term and its variants with the new one marked. **Add** stores exactly that;
/// **Cancel** stores nothing.
///
/// ### Why a screen and not a direct write
///
/// A variant rewrites every future dictation that contains it, and a wrong one is
/// noticed only when it has already changed someone's text. So nothing is added
/// silently (#512): the user sees exactly what the entry becomes before it does.
struct VocabularyPairReviewView: View {

    let pair: VocabularyPair

    @StateObject private var store = VocabularyStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var saveFailed = false

    /// What Add would store, from the vocabulary as it is now. Nil if a term the pair
    /// belonged to was deleted while the suggestion was on screen.
    private var acceptance: VocabularyPairAcceptance? {
        VocabularyPairAcceptance(pair, vocabulary: store.entries)
    }

    /// A new term needs room; a variant added to a term does not.
    private var exceedsLimit: Bool {
        if case .newTerm = acceptance { return store.isFull }
        return false
    }

    var body: some View {
        Form {
            if let acceptance {
                let entry = acceptance.entry
                Section {
                    summary(acceptance)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("vocabulary.pair.review.summary")
                }

                Section {
                    Text(verbatim: entry.term)
                } header: {
                    Text("The correct spelling")
                }

                Section {
                    ForEach(entry.variants.filter { $0 != pair.observed }, id: \.self) { variant in
                        Text(verbatim: variant)
                            .foregroundColor(.secondary)
                    }
                    Label {
                        Text(verbatim: pair.observed)
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("What Dictus writes instead")
                } footer: {
                    footer(entry)
                }
            } else {
                Text("This term is no longer in your vocabulary.")
                    .foregroundColor(.secondary)
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

    private func summary(_ acceptance: VocabularyPairAcceptance) -> Text {
        switch acceptance {
        case .newTerm(let entry):
            return Text("New term “\(entry.term)”, with the variant “\(pair.observed)”.")
        case .addVariant(let entry):
            return Text("Variant “\(pair.observed)” added to “\(entry.term)”.")
        }
    }

    @ViewBuilder
    private func footer(_ entry: VocabularyEntry) -> some View {
        if saveFailed {
            Text("Could not save. Your device may be out of storage.")
                .foregroundColor(.red)
        } else if exceedsLimit {
            Text("You have reached the limit of \(VocabularyStore.maxEntries) terms. Delete one to add another.")
                .foregroundColor(.red)
        } else if entry.isEnabled {
            Text("From now on, when Dictus writes “\(pair.observed)”, it writes “\(entry.term)” instead.")
        } else {
            Text("Already in your vocabulary, switched off. The variant is added but applies only once you switch the term back on.")
                .foregroundColor(.orange)
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
