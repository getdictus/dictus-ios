// DictusApp/Views/VocabularyPairReviewView.swift
// The change an accepted vocabulary suggestion will make, shown before it is made (#512).
import SwiftUI
import DictusCore

/// What **Accept** on a suggested variant opens: the term, the variants it already
/// replaces, and the one it would gain. **Add** stores it; **Cancel** stores nothing.
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

    /// The stored entry the variant joins. Nil if the term was deleted while the
    /// suggestion was on screen, and then there is nothing to add to.
    private var entry: VocabularyEntry? {
        store.entry(matchingTerm: pair.canonical)
    }

    var body: some View {
        Form {
            if let entry {
                Section {
                    Text(verbatim: entry.term)
                } header: {
                    Text("The correct spelling")
                }

                Section {
                    ForEach(entry.variants, id: \.self) { variant in
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
                    if saveFailed {
                        Text("Could not save. Your device may be out of storage.")
                            .foregroundColor(.red)
                    } else if entry.isEnabled {
                        Text("From now on, when Dictus writes “\(pair.observed)”, it writes “\(entry.term)” instead.")
                    } else {
                        Text("Already in your vocabulary, switched off. The variant is added but applies only once you switch the term back on.")
                            .foregroundColor(.orange)
                    }
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
                    .disabled(entry == nil)
                    .accessibilityIdentifier("vocabulary.pair.review.confirm")
            }
        }
    }

    private func add() {
        guard let entry else { return }
        // The store publishes only what it wrote; on a refusal the sheet stays open
        // and says so, rather than closing over a variant that was never stored.
        guard store.update(entry.addingVariants([pair.observed])) else {
            saveFailed = true
            return
        }
        dismiss()
    }
}
