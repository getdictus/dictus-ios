// DictusCore/Sources/polish-harness/VocabularyPairsRound.swift
// `vocabpairs` (#512 step 2): the first twenty candidate pairs of a device journal, to label.
// macOS only, like main.swift, whose `args` and `optionValue` this uses: the package
// also builds for the iOS Simulator destination of `swift test` (#301).
#if os(macOS)
import AppKit
import Foundation
import DictusCore
import PolishFidelity

// Step 2 brief, decisions 4 and 5. The spike runs on the Mac over the polish journal's
// JSON export (Polish debug screen → Export JSON), which since #749 records every
// dictation, polish on or off. This command runs the DictusCore pair generator over it
// and writes the first twenty pairs, ranked by similarity with no hand curation, to a
// file OUTSIDE any repository for the maintainer to label `v`/`f`. `vocabjudge` reads
// that file back. Drives no model.
//
// What it prints is counts only. The pairs file holds dictation text, so it is the only
// place the text goes.

/// The part of a polish journal export this command reads (`PolishDebugExport` in
/// DictusApp). Decoded leniently: every other field of the export is ignored, so an
/// export from an older or newer build still reads.
struct JournalExport: Decodable {
    struct Settings: Decodable {
        let keyboardLanguage: String?
    }

    struct Event: Decodable {
        let id: String
        let timestamp: String
        /// The speech engine's output.
        let raw: String
        /// The text after the vocabulary pass, when it changed something (#80).
        let vocabularyCorrected: String?
        let detectedLanguage: String?
        let sttEngine: String?
    }

    let settings: Settings?
    let events: [Event]
}

enum VocabularyPairsRound {

    /// Two events of one dictation: a Smart Mode declining a short input writes its own
    /// event, then the dictation's (#587). Same text within this many seconds is one.
    static let duplicateWindow: TimeInterval = 60

    /// The History the generator reads, one record per dictation, newest last.
    ///
    /// The text is `vocabularyCorrected ?? raw`: what History holds before polish, so a
    /// variant the user already taught Dictus is gone and its term is there, exactly as
    /// in the app. Polish output is not used: it is the engine's mistakes being hunted,
    /// and a polish can rewrite them.
    static func records(from export: JournalExport) -> (records: [TranscriptionRecord], duplicates: Int) {
        let formatter = ISO8601DateFormatter()
        let fallbackLanguage = export.settings?.keyboardLanguage ?? TranscriptionRecord.autoDetectedCode
        let dated = export.events.compactMap { event -> (event: JournalExport.Event, date: Date)? in
            guard let date = formatter.date(from: event.timestamp) else { return nil }
            return (event, date)
        }.sorted { $0.date < $1.date }

        var records: [TranscriptionRecord] = []
        var duplicates = 0
        for (event, date) in dated {
            let text = event.vocabularyCorrected ?? event.raw
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            if let previous = records.last, previous.text == text,
               date.timeIntervalSince(previous.createdAt) <= duplicateWindow {
                duplicates += 1
                continue
            }
            records.append(TranscriptionRecord(
                id: UUID(uuidString: event.id) ?? UUID(),
                text: text,
                language: event.detectedLanguage ?? fallbackLanguage,
                durationSeconds: 0,
                createdAt: date,
                sttProvider: event.sttEngine ?? SpeechEngine.parakeet.rawValue
            ))
        }
        return (records, duplicates)
    }

    /// The Personal Vocabulary as the maintainer types it: one entry per line,
    /// `Term` or `Term = variant, variant`. The variants are the ones the device's
    /// entry holds; a span that is one of them is skipped, as in the app. `#` lines
    /// are comments. The export carries no vocabulary, hence a file.
    static func vocabulary(fromFile path: String) -> [VocabularyEntry] {
        lines(ofFile: path).compactMap { line in
            let halves = line.split(separator: "=", maxSplits: 1).map(String.init)
            let term = halves[0].trimmingCharacters(in: .whitespaces)
            guard VocabularyPairsFile.isWritable(canonical: term) else {
                print("error: the term `\(term)` holds a `|`, which the pairs file uses as its separator")
                exit(2)
            }
            let variants = halves.count > 1 ? VocabularyEntry.variants(fromLine: halves[1]) : []
            guard let entry = VocabularyEntry(term: term, variants: variants) else {
                print("error: `\(line)` in \(path) is not a vocabulary entry")
                exit(2)
            }
            return entry
        }
    }

    /// Non-empty, non-comment lines of a text file, trimmed.
    static func lines(ofFile path: String) -> [String] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("error: cannot read \(path)")
            exit(1)
        }
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }

    /// Whether `url` would land inside a git working tree, this repository or any
    /// other. The pairs file holds dictation text and must never be one `git add .`
    /// away from a commit (decision 5).
    static func isInsideGitWorkTree(_ url: URL) -> Bool {
        var directory = url.deletingLastPathComponent().resolvingSymlinksInPath()
        while true {
            // `.git` is a directory in a clone and a file in a worktree: both count.
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path) {
                return true
            }
            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { return false }
            directory = parent
        }
    }
}

/// `isKnownWord` on the Mac: `NSSpellChecker`, the AppKit twin of the `UITextChecker`
/// the app uses (`VocabularySuggestionDictionary`). Same languages rule: English always,
/// the keyboard language, and every language the journal's dictations were detected in.
///
/// Not identical to the iPhone's dictionary, and the Mac user's own learned spellings
/// (System Settings → Keyboard → Text Input) count as known here. A difference in what
/// counts as a dictionary word only moves which single-word spans are refused.
@MainActor
struct MacSpellingDictionary {
    let languages: [String]
    private let checker = NSSpellChecker.shared

    init(records: [TranscriptionRecord], keyboardLanguage: String?) {
        var wanted: Set<String> = ["en"]
        if let keyboardLanguage { wanted.insert(keyboardLanguage) }
        for record in records where record.language != TranscriptionRecord.autoDetectedCode {
            wanted.insert(record.language)
        }
        let available = NSSpellChecker.shared.availableLanguages
        languages = wanted.sorted().compactMap { code in
            available.first { $0 == code } ?? available.first { $0.hasPrefix(code) }
        }
    }

    /// Known as written or in lowercase, in any of the languages.
    func isKnown(_ word: String) -> Bool {
        let candidates = word == word.lowercased() ? [word] : [word, word.lowercased()]
        for candidate in candidates {
            for language in languages {
                let misspelled = checker.checkSpelling(
                    of: candidate, startingAt: 0, language: language, wrap: false,
                    inSpellDocumentWithTag: 0, wordCount: nil
                )
                if misspelled.location == NSNotFound { return true }
            }
        }
        return false
    }
}

/// `polish-harness vocabpairs <export.json> --terms <terms.txt> [--learned <words.txt>] --out <pairs.txt>`
@MainActor
func runVocabularyPairs() {
    let exportPath = args[1]
    guard let termsPath = optionValue("--terms", in: args), let outPath = optionValue("--out", in: args) else {
        print("error: vocabpairs needs --terms <terms.txt> and --out <pairs.txt>")
        exit(2)
    }
    let outURL = URL(fileURLWithPath: outPath)
    guard !VocabularyPairsRound.isInsideGitWorkTree(outURL) else {
        print("error: \(outURL.path) is inside a git working tree. The pairs file holds dictation text: write it elsewhere (e.g. ~/Documents).")
        exit(2)
    }
    guard !FileManager.default.fileExists(atPath: outURL.path) else {
        print("error: \(outURL.path) exists. It may hold your labels: move or delete it first.")
        exit(2)
    }

    let export: JournalExport
    do {
        guard let data = FileManager.default.contents(atPath: exportPath) else {
            print("error: cannot read \(exportPath)")
            exit(1)
        }
        export = try JSONDecoder().decode(JournalExport.self, from: data)
    } catch {
        // The decoding error names a key path, never a value, so no text is printed.
        print("error: \(exportPath) is not a polish journal export: \(error)")
        exit(1)
    }

    let (records, duplicates) = VocabularyPairsRound.records(from: export)
    let vocabulary = VocabularyPairsRound.vocabulary(fromFile: termsPath)
    let learned = optionValue("--learned", in: args).map(VocabularyPairsRound.lines(ofFile:)) ?? []
    let dictionary = MacSpellingDictionary(records: records, keyboardLanguage: export.settings?.keyboardLanguage)
    let generator = VocabularyPairGenerator { word in
        MainActor.assumeIsolated { dictionary.isKnown(word) }
    }

    let started = Date()
    let pairs = generator.pairs(from: records, vocabulary: vocabulary, learnedWords: learned, ignored: [])
    let elapsed = Int(Date().timeIntervalSince(started) * 1000)

    let lines = pairs.enumerated().map { index, pair in
        VocabularyPairsFile.line(
            id: VocabularyPairsFile.pairID(index), canonical: pair.canonical,
            observed: pair.observed, sentence: pair.sentence
        )
    }
    do {
        try (VocabularyPairsFile.header + "\n" + lines.joined(separator: "\n") + "\n")
            .write(to: outURL, atomically: true, encoding: .utf8)
    } catch {
        print("error: cannot write \(outURL.path): \(error)")
        exit(1)
    }

    // Counts only: the text is in the file and nowhere else.
    let fromLearned = pairs.filter { $0.source == .learned }.count
    print("""
    events=\(export.events.count) records=\(records.count) duplicatesDropped=\(duplicates)
    terms=\(vocabulary.count) learned=\(learned.count) spellcheck=\(dictionary.languages.joined(separator: ","))
    pairs=\(pairs.count) (vocabulary=\(pairs.count - fromLearned) learned=\(fromLearned)) ms=\(elapsed)
    scores=\(pairs.map { String($0.score) }.joined(separator: ","))
    wrote \(outURL.path)
    """)
    if pairs.count < VocabularyJudgeVerdict.sampleSize {
        print("note: \(pairs.count) pairs, fewer than the \(VocabularyJudgeVerdict.sampleSize) the brief's thresholds are written for.")
    }
    print("next: prefix every pair line with v or f, then run `vocabjudge \(outURL.path)`.")
}

#endif
