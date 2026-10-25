// DictusApp/Views/VocabularySuggestionsView.swift
// The review sheet for words the History suggests adding to the vocabulary (#512).
import SwiftUI
import DictusCore

/// The top suggestions from History: what **Analyze my transcriptions** opens.
///
/// ### Three sections, one numbering (#512)
///
/// First, step 2: spans History wrote near one of the user's own terms (`cloud code`
/// for `Claude Code`), from `VocabularyPairGenerator`. The term is certain, so each
/// row offers **Accept**, which shows the change before storing the variant
/// (`VocabularyPairReviewView`), **Edit**, which opens the term's sheet with the
/// variant filled in, and **Ignore**. Then the words the keyboard learned from the user's typing that the engine
/// wrote differently: **Add** opens #723's sheet with both the term and the
/// spellings seen filled in. Then the unknown words History alone turned up, weaker
/// evidence: **Add** fills only the spellings, and the user types the correct one.
/// **Ignore** hides a suggestion for good. The numbering runs across both sections,
/// because the go/no-go reads the top ten whatever their kind.
///
/// ### When it mines again
///
/// On open, after an **Ignore**, and when the vocabulary changes, which is how an
/// accepted word leaves the list: both miners exclude every stored variant. A sheet
/// cancelled on **Add** or **Accept** changes nothing, and the suggestion stays.
struct VocabularySuggestionsView: View {

    @StateObject private var history = TranscriptionHistoryStore.shared
    @StateObject private var vocabulary = VocabularyStore.shared
    @Environment(\.dismiss) private var dismiss

    /// Nil until the first run has finished, so the first frame shows a spinner and
    /// not "no suggestions".
    @State private var suggestions: [VocabularySuggestion]?

    /// Step 2's variants of the user's terms, mined with `suggestions`.
    @State private var pairs: [VocabularyPair] = []

    /// The term being added from a suggestion, or nil when that sheet is closed.
    @State private var editing: VocabularyEditorSubject?

    /// The variant whose change is on screen before it is stored, or nil.
    @State private var reviewing: VocabularyPair?

    private let ignoreList = VocabularySuggestionIgnoreList()

    var body: some View {
        List {
            if let suggestions {
                if suggestions.isEmpty && pairs.isEmpty {
                    Text("No suggestions for now. A suggestion appears here when Dictus writes one of your terms differently in at least two dictations, writes differently a word you typed on the keyboard, or when an unknown word comes back in at least two dictations.")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                } else {
                    let paired = suggestions.filter(\.isPaired)
                    let historyOnly = suggestions.filter { !$0.isPaired }
                    if !pairs.isEmpty {
                        Section {
                            ForEach(Array(pairs.enumerated()), id: \.element.id) { index, pair in
                                row(pair, rank: index + 1)
                            }
                        } header: {
                            Text("Variants of your terms")
                        } footer: {
                            Text("Accept shows the change before adding it. Edit opens the term so you can adjust the variant. Ignore hides the suggestion for good.")
                        }
                    }
                    if !paired.isEmpty {
                        Section {
                            ForEach(Array(paired.enumerated()), id: \.element.id) { index, suggestion in
                                row(suggestion, rank: pairs.count + index + 1)
                            }
                        } header: {
                            Text("Words you typed that Dictus writes differently")
                        } footer: {
                            Text("Add opens a new term with your spelling and what Dictus wrote instead, both filled in. Ignore hides the suggestion for good.")
                        }
                    }
                    if !historyOnly.isEmpty {
                        Section {
                            ForEach(Array(historyOnly.enumerated()), id: \.element.id) { index, suggestion in
                                row(suggestion, rank: pairs.count + paired.count + index + 1)
                            }
                        } header: {
                            Text("Not in the dictionary, seen in several dictations")
                        } footer: {
                            Text("Add opens a new term with this word as what Dictus writes instead: you type the correct spelling. Ignore hides the word for good.")
                        }
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
        .sheet(item: $reviewing) { pair in
            NavigationStack {
                VocabularyPairReviewView(pair: pair)
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// One variant of a term: the term, what Dictus wrote, the count, three actions.
    private func row(_ pair: VocabularyPair, rank: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(verbatim: "\(rank)")
                .font(.dictusCaption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(minWidth: 18, alignment: .trailing)

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: pair.canonical)
                    .foregroundColor(.primary)
                Text("Written as: \(pair.observed)")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)
                Text("In \(pair.dictationCount) dictations")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Button("Accept") { reviewing = pair }
                        .accessibilityIdentifier("vocabulary.pair.accept")
                    Button("Edit") {
                        editing = .observed(variant: pair.observed, term: pair.canonical)
                    }
                    Button("Ignore") {
                        ignoreList.ignore(pair)
                        mine()
                    }
                    .foregroundColor(.secondary)
                }
                // Borderless, or the whole row is one button and a tap fires all three.
                .buttonStyle(.borderless)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
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
                if let term = suggestion.term {
                    // Paired: the user's spelling, then what the engine wrote.
                    Text(verbatim: term)
                        .foregroundColor(.primary)
                    Text("Written as: \(suggestion.variantsLine)")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                } else {
                    Text(verbatim: suggestion.forms.first ?? suggestion.id)
                        .foregroundColor(.primary)
                    if suggestion.forms.count > 1 {
                        Text("Also written: \(suggestion.forms.dropFirst().joined(separator: ", "))")
                            .font(.dictusCaption)
                            .foregroundColor(.secondary)
                    }
                }
                Text("In \(suggestion.dictationCount) dictations")
                    .font(.dictusCaption)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Button("Add") {
                        editing = .observed(variant: suggestion.variantsLine, term: suggestion.term ?? "")
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
    ///
    /// The learned words are re-read first: the keyboard writes them from its own
    /// process, and this one's copy is from whenever the app launched.
    private func mine() {
        let start = Date()
        UserDictionary.shared.reload()
        let learnedWords = Array(UserDictionary.shared.allLearnedWords.keys)
        let records = history.records
        let dictionary = VocabularySuggestionDictionary(records: records)
        let ignored = ignoreList.keys
        let generator = VocabularyPairGenerator { dictionary.isKnown($0) }
        let found = generator.suggestions(from: records, vocabulary: vocabulary.entries, ignored: ignored)
        let miner = VocabularySuggestionMiner { dictionary.isKnown($0) }
        // A spelling already offered as a variant of a term is not offered again
        // below as a word on its own.
        let offered = Set(found.map { VocabularySuggestionMiner.fold($0.observed) })
        let result = miner.suggestions(
            from: records,
            learnedWords: learnedWords,
            vocabulary: vocabulary.entries,
            ignored: ignored
        ).filter { !$0.forms.contains { offered.contains(VocabularySuggestionMiner.fold($0)) } }
        pairs = found
        suggestions = result
        // `learned` is logged so a device run with no paired suggestion can be told
        // apart: an empty learned set, or learned words the engine already spells right.
        let paired = result.filter(\.isPaired).count
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        PersistentLog.log(.diagnosticProbe(
            component: "VocabularySuggestions",
            instanceID: "mine",
            action: "mined",
            details: "records=\(records.count) learned=\(learnedWords.count) shown=\(result.count) paired=\(paired) termVariants=\(found.count) ms=\(elapsed)"
        ))
    }
}
