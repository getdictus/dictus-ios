// DictusApp/Views/VocabularySuggestionsView.swift
// The review sheet for words the History suggests adding to the vocabulary (#512).
import SwiftUI
import DictusCore

/// The top suggestions from History: what **Analyze my transcriptions** opens.
///
/// ### Three sections, one numbering (#512)
///
/// First, step 2: spans History wrote near a spelling the user wrote themselves
/// (`cloud code` for the term `Claude Code`, `grok boat` for the learned word
/// `grokbot`), from `VocabularyPairGenerator.suggestions`: terms first, then learned
/// words step 1 does not already suggest. The spelling is certain, so each row offers
/// **Accept**, which shows the change, editable, before storing it
/// (`VocabularyPairReviewView`: a variant added to a term, or a new term from a
/// learned word), and **Ignore**. Then the words
/// the keyboard learned from the user's typing that the engine wrote differently: **Add** opens #723's sheet with both the term and the
/// spellings seen filled in. Then the unknown words History alone turned up, weaker
/// evidence: **Add** fills only the spellings, and the user types the correct one.
/// **Ignore** hides a suggestion for good. The numbering runs across both sections,
/// because the go/no-go reads the top ten whatever their kind.
///
/// ### When it mines again, and where
///
/// On open, after an **Ignore**, when the review sheet closes, and when the
/// vocabulary changes (debounced), which is how an accepted word leaves the list:
/// both miners exclude every stored variant.
///
/// Off the main actor (`VocabularySuggestionAnalysis`): on device it took 0.5 to 2 s
/// at 50 to 80 dictations, and the screen froze for all of it. Only the dictionary
/// verdicts touch the main thread (`KnownWordVerdicts`). A new run cancels the one in
/// flight, and the list on screen stays usable until the new result replaces it.
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

    /// The analysis in flight, cancelled when a newer one starts.
    @State private var analysis: Task<Void, Never>?

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
                            Text("Your spellings, written differently")
                        } footer: {
                            Text("Accept shows the change before adding it, and lets you adjust it. Ignore hides the suggestion for good.")
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
        .task { analyze() }
        // Debounced: one edit of the vocabulary can publish more than once.
        .onChange(of: vocabulary.entries) { _, _ in analyze(after: 300) }
        .sheet(item: $editing) { subject in
            NavigationStack {
                VocabularyEditorView(subject: subject)
            }
        }
        // Re-mined on close as well: an Add that stored nothing new publishes no change.
        .sheet(item: $reviewing, onDismiss: { analyze() }, content: { pair in
            NavigationStack {
                VocabularyPairReviewView(pair: pair)
            }
            .presentationDetents([.medium, .large])
        })
    }

    /// One pair: the user's spelling, what Dictus wrote, the count, two actions.
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
                if pair.source == .learned {
                    Text("Typed on your keyboard, not yet a term")
                        .font(.dictusCaption)
                        .foregroundColor(.secondary)
                }

                // Ids carry the row's rank, so a screen of several rows never holds two
                // equal ids: `vocabulary.pair.<rank>.accept`, `.ignore`. No Edit: the
                // review sheet Accept opens is editable.
                HStack(spacing: 20) {
                    Button("Accept") { reviewing = pair }
                        .accessibilityIdentifier("vocabulary.pair.\(rank).accept")
                    Button("Ignore") {
                        ignoreList.ignore(pair)
                        analyze()
                    }
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("vocabulary.pair.\(rank).ignore")
                }
                // Borderless, or the whole row is one button and a tap fires both.
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
        analyze()
    }

    /// Run both miners over the whole History, off the main actor.
    ///
    /// The inputs are read here, on the main actor: the learned words re-read first
    /// (the keyboard writes them from its own process, and this one's copy is from
    /// whenever the app launched), the History, the vocabulary and the ignore list.
    /// The time is logged so a slow History shows up in an export; counts only, no
    /// word leaves this screen. DEBUG builds also log the longest stretch the main
    /// thread went without running during the analysis (`mainGapMs`).
    ///
    /// - Parameter delay: milliseconds to wait first, cancelled by a newer call.
    private func analyze(after delay: UInt64 = 0) {
        analysis?.cancel()
        UserDictionary.shared.reload()
        let learnedWords = Array(UserDictionary.shared.allLearnedWords.keys)
        let records = history.records
        let entries = vocabulary.entries
        let ignored = ignoreList.keys
        let verdicts = KnownWordVerdicts(records: records)
        analysis = Task {
            if delay > 0 { try? await Task.sleep(nanoseconds: delay * 1_000_000) }
            guard !Task.isCancelled else { return }
            let start = Date()
            #if DEBUG
            let watch = MainThreadWatch()
            #endif
            let result = await Self.run(records: records, vocabulary: entries, learnedWords: learnedWords,
                                        ignored: ignored, verdicts: verdicts)
            #if DEBUG
            let mainGap = " mainGapMs=\(watch.stop())"
            #else
            let mainGap = ""
            #endif
            guard let result, !Task.isCancelled else { return }
            pairs = result.pairs
            suggestions = result.stepOne
            // `learned` is logged so a device run with no paired suggestion can be told
            // apart: an empty learned set, or learned words the engine already spells right.
            let paired = result.stepOne.filter(\.isPaired).count
            let elapsed = Int(Date().timeIntervalSince(start) * 1000)
            PersistentLog.log(.diagnosticProbe(
                component: "VocabularySuggestions",
                instanceID: "mine",
                action: "mined",
                details: "records=\(records.count) learned=\(learnedWords.count) shown=\(result.stepOne.count) paired=\(paired) termVariants=\(result.pairs.filter { $0.source == .vocabulary }.count) learnedPairs=\(result.pairs.filter { $0.source == .learned }.count) ms=\(elapsed)\(mainGap)"
            ))
        }
    }

    /// The analysis itself. `nonisolated` and `async`, so it runs on the cooperative
    /// pool rather than the main actor, and stays a child of the task that awaits it:
    /// cancelling that task cancels this one.
    private nonisolated static func run(records: [TranscriptionRecord],
                                        vocabulary: [VocabularyEntry],
                                        learnedWords: [String],
                                        ignored: Set<String>,
                                        verdicts: KnownWordVerdicts) async -> VocabularySuggestionAnalysis? {
        VocabularySuggestionAnalysis.run(records: records, vocabulary: vocabulary, learnedWords: learnedWords,
                                         ignored: ignored, isKnownWord: verdicts.isKnown)
    }
}

#if DEBUG
/// How long the main thread went without running, while an analysis ran: a 10 ms
/// heartbeat on the main actor, and the longest gap between two beats. A frozen main
/// thread shows as one gap as long as the freeze.
@MainActor
private final class MainThreadWatch {

    private var beat: Task<Void, Never>?
    private var longestGap: TimeInterval = 0

    init() {
        beat = Task { @MainActor [weak self] in
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000)
                let now = Date()
                self?.longestGap = max(self?.longestGap ?? 0, now.timeIntervalSince(last))
                last = now
            }
        }
    }

    /// Stops the heartbeat and returns the longest gap, in milliseconds.
    func stop() -> Int {
        beat?.cancel()
        return Int(longestGap * 1000)
    }
}
#endif
