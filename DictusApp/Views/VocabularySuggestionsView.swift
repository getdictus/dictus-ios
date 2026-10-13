// DictusApp/Views/VocabularySuggestionsView.swift
// The review sheet for words the History suggests adding to the vocabulary (#512 trial).
import SwiftUI
import DictusCore

/// The top suggestions from History, each with **Add** and **Ignore**.
///
/// ### What the trial ships, and nothing more (#512, 2026-10-12 / 10-13)
///
/// The miner runs over History only, and the sheet has two actions. **Add** opens
/// #723's prefilled sheet with the spellings seen as the variants: the user types the
/// correct spelling, since nothing here can know it. **Ignore** hides the word for
/// good. No snooze, no diff screen, no model: the go/no-go is whether the top ten
/// are words worth adding, and that is what the sheet shows, numbered.
///
/// ### When it mines again
///
/// On open, after an **Ignore**, and when the vocabulary changes, which is how an
/// accepted word leaves the list: the miner excludes every stored variant. A sheet
/// cancelled on **Add** changes nothing, and the word stays.
struct VocabularySuggestionsView: View {

    @StateObject private var history = TranscriptionHistoryStore.shared
    @StateObject private var vocabulary = VocabularyStore.shared
    @Environment(\.dismiss) private var dismiss

    /// Nil until the first run has finished, so the first frame shows a spinner and
    /// not "no suggestions".
    @State private var suggestions: [VocabularySuggestion]?

    /// The term being added from a suggestion, or nil when that sheet is closed.
    @State private var editing: VocabularyEditorSubject?

    private let ignoreList = VocabularySuggestionIgnoreList()

    var body: some View {
        List {
            if let suggestions {
                if suggestions.isEmpty {
                    Text("No suggestions for now. A word appears here once it is missing from the dictionary and seen in at least two dictations.")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                } else {
                    Section {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            row(suggestion, rank: index + 1)
                        }
                    } header: {
                        Text("Not in the dictionary, seen in several dictations")
                    } footer: {
                        Text("Add opens a new term with this word as what Dictus writes instead: you type the correct spelling. Ignore hides the word for good.")
                    }
                }
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .navigationTitle("Suggestions from History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { mine() }
        .onChange(of: vocabulary.entries) { _, _ in mine() }
        .sheet(item: $editing) { subject in
            NavigationStack {
                VocabularyEditorView(subject: subject)
            }
        }
    }

    /// One suggestion: its rank, the spelling seen most, the others, and the count.
    private func row(_ suggestion: VocabularySuggestion, rank: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            // Verbatim: a bare number, not a localizable string.
            Text(verbatim: "\(rank)")
                .font(.dictusCaption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 18, alignment: .trailing)

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: suggestion.forms.first ?? suggestion.id)
                    .foregroundColor(.primary)
                if suggestion.forms.count > 1 {
                    Text("Also written: \(suggestion.forms.dropFirst().joined(separator: ", "))")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }
                Text("In \(suggestion.dictationCount) dictations")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Button("Add") {
                        editing = .observed(variant: suggestion.variantsLine)
                    }
                    Button("Ignore") {
                        ignore(suggestion)
                    }
                    .foregroundColor(.secondary)
                }
                // Borderless, or the whole row is one button and a tap anywhere on
                // it fires both actions.
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private func ignore(_ suggestion: VocabularySuggestion) {
        ignoreList.ignore(suggestion)
        mine()
    }

    /// Run the miner over the whole History.
    ///
    /// On the main actor because `UITextChecker` is UIKit. It is asked once per
    /// distinct unusual spelling, not once per word, and the time is logged so a slow
    /// History shows up in an export. Counts only: no word leaves this screen.
    private func mine() {
        let start = Date()
        let records = history.records
        let dictionary = VocabularySuggestionDictionary(records: records)
        let miner = VocabularySuggestionMiner { dictionary.isKnown($0) }
        let result = miner.suggestions(
            from: records,
            vocabulary: vocabulary.entries,
            ignored: ignoreList.keys
        )
        suggestions = result
        PersistentLog.log(.diagnosticProbe(
            component: "VocabularySuggestions",
            instanceID: "mine",
            action: "mined",
            details: "records=\(records.count) shown=\(result.count) ms=\(Int(Date().timeIntervalSince(start) * 1000))"
        ))
    }
}
