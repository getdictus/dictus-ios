// tools/keyboard-bench/Bilingual.swift
// The bilingual replay (#1009): the same taps through two engines, one per language of a
// pair, with the DictusCore language window deciding which one corrects each word.
// `run.sh --pair fr,en` runs it; score_pair.py turns its rows into the report.
import Foundation
import UIKit
import DictusCore

/// One language's trie and n-grams, as `WordLanguageVote` and `BilingualKeepRule` ask
/// them. A second trie on the same files as the engine's, mounted for the same layout:
/// the engine keeps its own private.
final class TrieEvidence: LanguageEvidenceSource {
    let language: SupportedLanguage
    private let trie = AOSPTrieEngine()
    private let scale: TrieFrequencyScale

    init(_ language: SupportedLanguage) {
        self.language = language
        scale = TrieFrequencyScale(topCount: Self.topCount(language))
        trie.load(language: language.rawValue)
    }

    var isLoaded: Bool { trie.isLoaded && trie.ngramsLoaded && !trie.isLoading }

    func logFrequency(of word: String) -> Double? {
        trie.wordExists(word) ? scale.logFrequency(stored: trie.wordFrequency(word)) : nil
    }

    func accentExpansion(_ word: String) -> String? { trie.accentExpansion(word) }
    func contractionExpansion(_ word: String) -> String? { trie.contractionExpansion(word) }
    func correction(of word: String) -> String? { trie.spellCheck(word)?.correction }
    func bigram(_ word: String, after previous: String) -> Double {
        Double(trie.bigramScore(for: word, after: previous)) / 65535
    }

    /// The highest count of the corpus the trie was normalised by: the top of the
    /// frequency list built from the same counts (`tools/dict_builder.py`).
    private static func topCount(_ language: SupportedLanguage) -> Double {
        guard let path = Bundle.main.path(forResource: "\(language.rawValue)_frequency", ofType: "json"),
              let data = FileManager.default.contents(atPath: path),
              let counts = try? JSONSerialization.jsonObject(with: data) as? [String: NSNumber],
              let top = counts.values.map(\.doubleValue).max() else {
            fatalError("cannot read \(language.rawValue)_frequency.json")
        }
        return top
    }
}

/// The bilingual keyboard: at every space the word votes, the window decides the
/// language, that language's engine corrects the word, and the keep rule may leave it
/// as typed. Letters ask the window's language only.
final class DetectingCorrector: Corrector {
    private var window: LanguageWindow
    private let engines: [SupportedLanguage: TextPredictionEngine]
    private let evidence: [SupportedLanguage: TrieEvidence]

    init(pair: KeyboardLanguagePair, engines: [SupportedLanguage: TextPredictionEngine],
         evidence: [SupportedLanguage: TrieEvidence]) {
        window = LanguageWindow(pair: pair)
        self.engines = engines
        self.evidence = evidence
    }

    var language: SupportedLanguage { window.language }
    var typingEngine: TextPredictionEngine { engine(window.language) }

    func proposal(for word: String, previous: String?, isAtSentenceStart: Bool) -> CorrectionProposal? {
        let pair = window.pair
        window.push(WordLanguageVote.vote(for: word, after: previous, primary: source(pair.primary),
                                          secondary: source(pair.secondary)))
        let active = window.language
        guard let correction = engine(active).spellCheck(word, previousWord: previous,
                                                          isAtSentenceStart: isAtSentenceStart)?.correction
        else { return nil }
        let kept = BilingualKeepRule.keepsTyped(word, over: correction, active: source(active),
                                                other: source(pair.other(than: active)))
        return kept ? nil : .autocorrect(correction, alternatives: [])
    }

    private func engine(_ language: SupportedLanguage) -> TextPredictionEngine {
        guard let engine = engines[language] else { fatalError("no engine for \(language)") }
        return engine
    }

    private func source(_ language: SupportedLanguage) -> TrieEvidence {
        guard let source = evidence[language] else { fatalError("no trie for \(language)") }
        return source
    }
}

/// Runs `body`, then puts back the active language and the layouts it set in the
/// simulator's App Group, so a later monolingual replay types on the layouts it always did.
func restoringKeyboardPreferences(_ body: () -> Void) {
    let keys = [SharedKeys.language, SharedKeys.keyboardLayoutsByLanguage, SharedKeys.keyboardLayout]
    let saved = keys.map { AppGroup.defaults.object(forKey: $0) }
    body()
    for (key, value) in zip(keys, saved) { AppGroup.defaults.set(value, forKey: key) }
}

/// Both engines and both tries for the pair, loaded for `layout`. Fresh for every layout:
/// the trie's substitution costs are built for the layout active when it loads.
func loadPair(_ pair: KeyboardLanguagePair, layout: LayoutType)
    -> ([SupportedLanguage: TextPredictionEngine], [SupportedLanguage: TrieEvidence]) {
    SupportedLanguage.activate(pair.primary)
    KeyboardLayoutPreference.setLayout(layout, for: pair.primary)
    KeyboardLayoutPreference.setLayout(layout, for: pair.secondary)
    var engines: [SupportedLanguage: TextPredictionEngine] = [:]
    var evidence: [SupportedLanguage: TrieEvidence] = [:]
    for language in [pair.primary, pair.secondary] {
        let engine = TextPredictionEngine(language: language.rawValue)
        let source = TrieEvidence(language)
        waitUntilLoaded(engine, language.rawValue)
        wait("evidence trie \(language.rawValue)") { source.isLoaded }
        engines[language] = engine
        evidence[language] = source
    }
    return (engines, evidence)
}

/// `KB_PROBE`: what each language's dictionary answers for single words, the inputs of
/// the vote. Items are `word` or `previous|word`, comma-separated.
func probePair(_ pair: KeyboardLanguagePair, _ items: String) {
    let (_, evidence) = loadPair(pair, layout: pair.primary.defaultLayout)
    func show(_ value: Double?) -> String { value.map { String(format: "%.2f", $0) } ?? "-" }
    print("previous\tword\tlanguage\tlog frequency\taccent\tcontraction\tcorrection\tcorrection log frequency\t"
          + "bigram after previous\tvote")
    for item in items.components(separatedBy: ",") {
        let parts = item.components(separatedBy: "|")
        let previous = parts.count > 1 ? parts[0] : nil
        let word = parts[parts.count - 1]
        guard let primary = evidence[pair.primary], let secondary = evidence[pair.secondary] else { return }
        let vote = WordLanguageVote.vote(for: word, after: previous, primary: primary, secondary: secondary)
        for source in [primary, secondary] {
            let lowered = word.lowercased()
            let correction = source.correction(of: lowered)
            print("\(previous ?? "")\t\(word)\t\(source.language.rawValue)\t\(show(source.logFrequency(of: lowered)))\t"
                  + "\(source.accentExpansion(lowered) ?? "-")\t\(source.contractionExpansion(lowered) ?? "-")\t"
                  + "\(correction ?? "-")\t\(show(correction.flatMap { source.logFrequency(of: $0.lowercased()) }))\t"
                  + "\(show(previous.map { source.bigram(lowered, after: $0.lowercased()) }))\t" + String(format: "%.2f", vote))
        }
    }
}

/// Replays each run under three policies: the primary language alone and the secondary
/// alone (today's keyboard, set to one or the other), and detection. `runs` items are a
/// corpus name, optionally with the layout both engines load for (`en:qwerty`); the
/// default is the primary's. A run's gold languages are `<corpus>/<name>.lang` (`f` or
/// `e` per word), or, for a corpus named after a language of the pair, that language.
func replayPair(_ pair: KeyboardLanguagePair, runs: [String], corpusDir: String, runsDir: String, outDir: String,
                width: CGFloat, height: CGFloat) {
    UserDictionary.shared.resetAll()

    var rowsOut = ["run\tpolicy\tsentence\tgold\tdecided\tmeant\ttyped\tfinal"]
    var costOut = ["run\tpolicy\tkind\tus"]
    for spec in runs {
        let parts = spec.components(separatedBy: ":")
        let name = parts[0]
        guard let layout = parts.count > 1 ? LayoutType(rawValue: parts[1]) : pair.primary.defaultLayout else {
            fatalError("unknown layout in \(spec)")
        }
        let label = "\(name)@\(layout.rawValue)"
        let (engines, evidence) = loadPair(pair, layout: layout)
        guard let page = KeyboardLayouts.current(needsGlobe: false).currentDeviceLayout?.normal else {
            fatalError("no letter page for \(label)")
        }
        let cells = grid(page, width: width, height: height)
        let sentences = readLines("\(corpusDir)/\(name).txt")
        let gold = goldLanguages(name, sentences: sentences, corpusDir: corpusDir)
        let run = readRun("\(runsDir)/\(name).tsv")
        var order: [Int] = []
        for tap in run where order.last != tap.sentence { order.append(tap.sentence) }

        let policies: [(String, () -> Corrector)] = [pair.primary, pair.secondary].map { language in
            ("mono-\(language.rawValue)", {
                guard let engine = engines[language] else { fatalError("no engine for \(language)") }
                return SingleEngine(engine, language: language)
            })
        } + [("detect", { DetectingCorrector(pair: pair, engines: engines, evidence: evidence) })]
        for (policy, makeCorrector) in policies {
            // One corrector per run: the window carries over from sentence to sentence,
            // as in a conversation, and starts the run in the primary language.
            let corrector = makeCorrector()
            for s in order {
                let line = s % sentences.count
                let intendedWords = sentences[line].components(separatedBy: " ")
                let (_, commits) = replay(run.filter { $0.sentence == s }, cells: cells, width: width, height: height,
                                          picker: nil, journal: nil, corrector: corrector) { _, resolved, _, us, _, _ in
                    switch resolved {
                    case "space": costOut.append("\(label)\t\(policy)\tspace\t\(us)")
                    case "none", "backspace", "shift", "return", "123", "spacer", "other": break
                    default: costOut.append("\(label)\t\(policy)\tletter\t\(us)")
                    }
                }
                for c in commits {
                    let meant = c.intendedWords.map { intendedWords[$0] }.joined(separator: " ")
                    let wordGold = c.intendedWords.first.map { gold[line][$0] } ?? pair.primary
                    rowsOut.append("\(label)\t\(policy)\t\(s)\t\(wordGold.rawValue)\t\(c.language.rawValue)\t"
                                   + "\(meant)\t\(c.typed)\t\(c.final)")
                }
            }
            FileHandle.standardError.write(Data("\(label) \(policy): \(order.count) sentences replayed\n".utf8))
        }
    }

    UserDictionary.shared.resetAll()
    for (file, rows) in [("pair.tsv", rowsOut), ("pair-cost.tsv", costOut)] {
        do {
            try (rows.joined(separator: "\n") + "\n").write(toFile: "\(outDir)/\(file)", atomically: true, encoding: .utf8)
        } catch {
            fatalError("cannot write \(outDir)/\(file): \(error)")
        }
    }
}

private func goldLanguages(_ name: String, sentences: [String], corpusDir: String) -> [[SupportedLanguage]] {
    let path = "\(corpusDir)/\(name).lang"
    if !FileManager.default.fileExists(atPath: path) {
        guard let language = SupportedLanguage(rawValue: name) else { fatalError("no \(path) for corpus \(name)") }
        return sentences.map { $0.components(separatedBy: " ").map { _ in language } }
    }
    let tags: [String: SupportedLanguage] = ["f": .french, "e": .english]
    let lines = readLines(path)
    guard lines.count == sentences.count else { fatalError("\(path): \(lines.count) lines for \(sentences.count) sentences") }
    return zip(lines, sentences).map { line, sentence in
        let languages = line.components(separatedBy: " ").map { tag -> SupportedLanguage in
            guard let language = tags[tag] else { fatalError("\(path): unknown tag \(tag)") }
            return language
        }
        guard languages.count == sentence.components(separatedBy: " ").count else {
            fatalError("\(path): tags and words differ for \"\(sentence)\"")
        }
        return languages
    }
}
