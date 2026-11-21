// tools/keyboard-bench/main.swift
// Replays recorded touch runs through the Dictus keyboard as it ships: its key grid,
// then the autocorrect the space bar runs, then the suggestion work every keystroke
// triggers (#954). Writes what happened, tap by tap and word by word; score.py turns
// that into the report.
//
// Compiled by run.sh with the unmodified layout and engine sources and DictusCore,
// then run on an iOS Simulator with `simctl spawn`.
import Foundation
import UIKit
import DictusCore

// MARK: - Input

struct Tap {
    let sentence: Int
    let index: Int
    /// A letter, or "space". A run converted from a typing journal (#1001) also has
    /// "backspace", "shift", "return", "123" and "accent".
    let key: String
    /// Landing offset from the key centre, in one-unit key widths and in row heights.
    let dx: CGFloat
    let dy: CGFloat
    /// Milliseconds since the sentence's first tap.
    let ms: Double
}

func readLines(_ path: String) -> [String] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("cannot read \(path)")
    }
    return text.components(separatedBy: "\n").filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

func readRun(_ path: String) -> [Tap] {
    readLines(path).dropFirst().map { line in
        let f = line.components(separatedBy: "\t")
        guard f.count == 6, let s = Int(f[0]), let i = Int(f[1]),
              let dx = Double(f[3]), let dy = Double(f[4]), let ms = Double(f[5]) else {
            fatalError("bad run row: \(line)")
        }
        return Tap(sentence: s, index: i, key: f[2], dx: CGFloat(dx), dy: CGFloat(dy), ms: ms)
    }
}

// MARK: - Key grid

/// One cell of the letter page, where the collection view puts it.
struct Cell {
    let key: KeyDefinition
    let frame: CGRect
    /// Width of one key unit in this cell's row.
    let unitWidth: CGFloat
}

/// The grid `GiellaKeyboardView` lays out: every row the same height, every key as wide
/// as its share of `width - 1` (`collectionView(_:layout:sizeForItemAt:)`). The flow
/// layout then spreads the point left over between the keys of the row, so the keys
/// sit up to 1 pt right of a left-aligned grid and a tap in one of the 1/9 pt gaps
/// between two keys reaches no cell. Measured on the simulator: the drawn key centres
/// of the top row match this to within a pixel, and a tap the replay put in such a gap
/// typed nothing on the real keyboard either.
func grid(_ page: [[KeyDefinition]], width: CGFloat, height: CGFloat) -> [Cell] {
    let rowHeight = height / CGFloat(page.count)
    var cells: [Cell] = []
    for (r, row) in page.enumerated() {
        let units = row.reduce(0) { $0 + $1.size.width }
        let unitWidth = (width - 1) / units
        let gap = row.count > 1 ? 1 / CGFloat(row.count - 1) : 0
        var x: CGFloat = 0
        for key in row {
            let w = key.size.width * unitWidth
            cells.append(Cell(key: key, frame: CGRect(x: x, y: CGFloat(r) * rowHeight, width: w, height: rowHeight),
                              unitWidth: unitWidth))
            x += w + gap
        }
    }
    return cells
}

/// `GiellaKeyboardView.handleTouches`: clamp 4 pt inside the view, then the cell under
/// the point, if any. The clamp only applies to touches the view receives: one above
/// the grid lands in the toolbar, and on the simulator typed nothing.
func hitTest(_ point: CGPoint, cells: [Cell], width: CGFloat, height: CGFloat) -> Cell? {
    guard CGRect(x: 0, y: 0, width: width, height: height).contains(point) else { return nil }
    let margin: CGFloat = 4
    let p = CGPoint(x: min(max(point.x, margin), width - margin), y: min(max(point.y, margin), height - margin))
    return cells.first { $0.frame.contains(p) }
}

func target(of key: String, in cells: [Cell]) -> Cell {
    let found = cells.first { cell in
        switch cell.key.type {
        case .spacebar: return key == "space"
        case .backspace: return key == "backspace"
        case .shift: return key == "shift"
        case .returnkey: return key == "return"
        case .symbols: return key == "123"
        case .input(let k, let alternate): return k == key || (alternate == "accent" && key == "accent")
        default: return false
        }
    }
    guard let cell = found else { fatalError("no key \(key) on this layout") }
    return cell
}

/// What a resolved cell types, in the vocabulary of the run file.
func label(_ cell: Cell?) -> String {
    guard let cell = cell else { return "none" }
    switch cell.key.type {
    case .input(let k, _): return k
    case .spacebar: return "space"
    case .backspace: return "backspace"
    case .shift: return "shift"
    case .returnkey: return "return"
    case .symbols: return "123"
    case .spacer: return "spacer"
    default: return "other"
    }
}

// MARK: - Document

/// The host text field: what the keyboard writes, and what it reads back.
final class Field: TextDocumentEditing {
    var text = ""
    var contextBeforeInput: String? { text }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
    func insertText(_ s: String) { text += s }
}

func words(_ context: String) -> [String] {
    var out: [String] = []
    context.enumerateSubstrings(in: context.startIndex..., options: .byWords) { sub, _, _, _ in
        if let s = sub { out.append(s) }
    }
    return out
}

// MARK: - Engine

func wait(_ what: String, timeout: TimeInterval = 30, until condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else { fatalError("timed out waiting for \(what)") }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}

let engine = TextPredictionEngine.shared

/// Same readiness checks as tools/split-pass-bench: the trie and the n-grams load on
/// a background queue and report on the main one.
func waitUntilLoaded(_ what: String) {
    wait("trie \(what)") { engine.isUnknownToDictionary("qzxqzxwq") }
    let fallback = engine.predictNextWords(after: ["qzxqzxwq"])
    wait("n-grams \(what)") {
        engine.predictNextWords(after: ["de"]) != fallback || engine.predictNextWords(after: ["the"]) != fallback
    }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
}

func load(_ lang: SupportedLanguage) {
    SupportedLanguage.activate(lang)
    engine.setLanguage(lang.rawValue)
    waitUntilLoaded(lang.rawValue)
}

/// Puts the learned words of `corpus/<code>.words` in the user dictionary, or empties it
/// when the file does not exist, so every run starts from the state it names (#498).
/// One row per word: the word, then how many times it has been used. `learn` is called
/// that many times, which is how the keyboard's own count reaches it.
func seedLearnedWords(_ path: String) {
    UserDictionary.shared.resetAll()
    guard FileManager.default.fileExists(atPath: path) else { return }
    for line in readLines(path) {
        let f = line.components(separatedBy: "\t")
        guard f.count == 2, let uses = Int(f[1]), uses > 0 else { fatalError("bad learned row: \(line)") }
        // A word the trie knows is never learned by the keyboard (#287), and the
        // load-time prune would remove it. Seeding one would measure a state no
        // device can reach.
        guard engine.isUnknownToDictionary(f[0]) else { fatalError("\(f[0]) is in the dictionary") }
        for _ in 0..<uses { UserDictionary.shared.learn(f[0]) }
    }
}

func microseconds(_ work: () -> Void) -> Int {
    let start = DispatchTime.now().uptimeNanoseconds
    work()
    return Int((DispatchTime.now().uptimeNanoseconds - start) / 1000)
}

// MARK: - Replay

struct Commit {
    let intendedWords: [Int]
    let typed: String
    let final: String
}

/// What a space tap runs: `DictusKeyboardBridge.autocorrectBeforeCursor` on the word
/// before the cursor, then the space, then the next-word prediction. Returns the word as
/// typed and as committed, or nil when there was no word before the cursor.
func commitWord(in field: Field, memory: AutocorrectRejectionMemory,
                mirror: MirrorSyncState) -> (typed: String, final: String)? {
    guard let (prefix, word) = AutocorrectRejectionMemory.wordAtCursor(context: field.text) else {
        field.insertText(" ")
        return nil
    }
    var final = word
    let ws = words(field.text)
    let previous = ws.count >= 2 ? ws[ws.count - 2] : nil
    let proposal = engine.spellCheck(word, previousWord: previous,
                                     isAtSentenceStart: ProperNounGuard.isAtSentenceStart(context: field.text, word: word))?.correction
    var applied = false
    if memory.commit(prefix: prefix, word: word, proposedCorrection: proposal,
                     allowsCasingChange: proposal != nil && engine.lexiconDecision(for: word) != nil) == .correct,
       let correction = proposal,
       case .applied = AutocorrectCountingSite.apply(editor: field, word: word, correction: correction,
                                                     trailing: " ", previousWord: previous, mirror: mirror) {
        memory.correctionApplied(prefix: prefix, corrected: correction)
        final = correction
        applied = true
    }
    if !applied { field.insertText(" ") }
    _ = engine.predictNextWords(after: Array(words(field.text).suffix(2)))
    return (word, final)
}

/// Picks the cell a tap types, from the point, today's answer (the cell under the
/// point), the word being typed and the word before it (#949). Also returns the trie
/// nodes the pick visited.
typealias Picker = (CGPoint, Cell?, String, String?) -> (Cell?, Int)

/// What the pick of one tap did: the key the plain hit test gives, the time the pick
/// took in nanoseconds, and the trie nodes it visited (#949).
struct PickCost {
    let plain: String
    let ns: Int
    let visited: Int
}

/// Types one sentence: every tap goes through the grid (or the picker), every letter
/// triggers the suggestion work `SuggestionState.updateAsync` does, every space the
/// autocorrect `DictusKeyboardBridge.autocorrectBeforeCursor` does.
func replay(_ taps: [Tap], cells: [Cell], width: CGFloat, height: CGFloat, picker: Picker?, journal: Journal?,
            tapRow: (Tap, String, CGPoint, Int, PickCost, Int) -> Void) -> (text: String, commits: [Commit]) {
    let field = Field()
    let memory = AutocorrectRejectionMemory()
    let mirror = MirrorSyncState()
    var commits: [Commit] = []
    var wordIndex = 0
    var tokenWords: [Int] = []

    for tap in taps {
        let aim = target(of: tap.key, in: cells)
        let point = CGPoint(x: aim.frame.midX + tap.dx * aim.unitWidth, y: aim.frame.midY + tap.dy * aim.frame.height)
        // The word being typed and the one before it. The keyboard tracks these as it
        // types; the replay reads them off the field, outside the timed pick.
        let current = field.text.split(separator: " ", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        let ws = words(field.text)
        let previous = current.isEmpty ? ws.last : ws.dropLast().last
        // After an apostrophe (`l'`, `d'`) a new word starts.
        let word = current.split(separator: "'", omittingEmptySubsequences: false).last.map(String.init) ?? ""

        let start = DispatchTime.now().uptimeNanoseconds
        let plain = hitTest(point, cells: cells, width: width, height: height)
        var hit = plain
        var visited = 0
        // A touch outside the grid never reaches the keyboard view: no model sees it.
        if let picker = picker, CGRect(x: 0, y: 0, width: width, height: height).contains(point) {
            (hit, visited) = picker(point, plain, word, previous)
        }
        let pickCost = PickCost(plain: label(plain), ns: Int(DispatchTime.now().uptimeNanoseconds - start),
                                visited: visited)
        let resolved = label(hit)
        if tap.key != "space", tokenWords.last != wordIndex { tokenWords.append(wordIndex) }
        // The keyboard records a tap where the touch resolves to a key, from the touch point.
        let journalNs = hit.map { journal?.tap($0, at: point, ms: tap.ms) ?? 0 } ?? 0

        var cost = 0
        switch hit?.key.type {
        case .input(let k, let alternate)?:
            if alternate == "accent" {
                // The AZERTY key beside "n": accents the vowel before it, or types an
                // apostrophe (`DictusKeyboardBridge.handleAdaptiveAccentKey`).
                let last = field.text.last.map(String.init)
                let before = field.text.dropLast().last.map(String.init)
                let accent = FrenchAdaptiveKey.label(afterTyping: last, precedingChar: before)
                if FrenchAdaptiveKey.shouldReplace(afterTyping: last, precedingChar: before) { field.deleteBackward() }
                field.insertText(accent)
            } else {
                // Auto-capitalisation: the field starts a sentence, so its first letter is a capital.
                field.insertText(field.text.isEmpty ? k.uppercased() : k)
            }
            let context = field.text
            cost = microseconds {
                guard let (_, partial) = AutocorrectRejectionMemory.wordAtCursor(context: context) else { return }
                let previous = words(context).dropLast().last
                if memory.previewsCorrection(context: context) {
                    _ = engine.spellCheck(partial, previousWord: previous,
                                          isAtSentenceStart: ProperNounGuard.isAtSentenceStart(context: context, word: partial))
                }
                _ = engine.suggestions(for: partial)
            }
        case .spacebar?:
            var typed = ""
            var final = ""
            cost = microseconds {
                guard let (prefix, word) = AutocorrectRejectionMemory.wordAtCursor(context: field.text) else {
                    field.insertText(" ")
                    return
                }
                typed = word
                final = word
                let ws = words(field.text)
                let previous = ws.count >= 2 ? ws[ws.count - 2] : nil
                journal?.beginWord(word, previous: previous)
                var offered = false
                defer { journal?.endWord(final, offered: offered) }
                // `spellCheck` is this proposal's autocorrection; the journal also needs to
                // know when corrections were only offered, as the keyboard's commit does.
                let checked = engine.correctionProposal(
                    for: word, previousWord: previous,
                    isAtSentenceStart: ProperNounGuard.isAtSentenceStart(context: field.text, word: word)
                )
                let proposal = checked?.autocorrection?.correction
                offered = checked?.suggestionRow(typedWord: word) != nil
                var applied = false
                if memory.commit(prefix: prefix, word: word, proposedCorrection: proposal) == .correct,
                   let correction = proposal,
                   case .applied = AutocorrectCountingSite.apply(editor: field, word: word, correction: correction,
                                                                 trailing: " ", previousWord: previous, mirror: mirror) {
                    memory.correctionApplied(prefix: prefix, corrected: correction)
                    final = correction
                    applied = true
                }
                if !applied { field.insertText(" ") }
                _ = engine.predictNextWords(after: Array(words(field.text).suffix(2)))
            }
            if !typed.isEmpty { commits.append(Commit(intendedWords: tokenWords, typed: typed, final: final)) }
            tokenWords = []
        case .backspace?:
            field.deleteBackward()
        default:
            // Shift, return, 123, a spacer, or no cell: nothing reaches the field.
            break
        }
        if tap.key == "space" { wordIndex += 1 }
        tapRow(tap, resolved, point, cost, pickCost, journalNs)
    }
    return (field.text.trimmingCharacters(in: .whitespaces), commits)
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count == 6, let width = Double(args[4]), let height = Double(args[5]) else {
    fatalError("usage: keyboard-bench <bench dir> <lang,lang> <out dir> <keyboard width pt> <key grid height pt>")
}
let benchDir = args[1]
let langs = args[2].components(separatedBy: ",")
let outDir = args[3]
let w = CGFloat(width)
let h = CGFloat(height)

// #949 spike: the runs to replay and the hit test to replay them through. run.sh sets
// these; unset, the bench replays its committed runs through today's hit test.
let env = ProcessInfo.processInfo.environment
let corpusDir = env["KB_CORPUS"] ?? "\(benchDir)/corpus"
let runsDir = env["KB_RUNS"] ?? "\(benchDir)/runs"
let hitMode = env["KB_HIT"] ?? "plain"
guard ["plain", "model"].contains(hitMode) else { fatalError("KB_HIT must be plain or model") }
let modelParameters = ModelParameters(env["KB_MODEL"] ?? "")
// #1001: the typing journal. A bench built with DEBUG (`run.sh --debug`) records it, its
// toggle on with KB_JOURNAL=1 and off without; the default build has none.
let journal = Journal.start(toggle: env["KB_JOURNAL"] == "1")

var tapsOut = ["lang\tsentence\ttap\tintended\tresolved\tx\ty\tengine_us\tplain\thit_ns\tvisited\tjournal_ns"]
var commitsOut = ["lang\tsentence\tintended\ttyped\tfinal"]
var textsOut = ["lang\tsentence\tintended\tfinal"]
var registerOut = ["lang\tbefore\ttyped\texpected\treported\tlexicon\tfinal"]
let register = readLines("\(benchDir)/register.tsv").dropFirst().map { $0.components(separatedBy: "\t") }

// The engine starts loading French as soon as it exists. A `setLanguage` issued before
// that load lands overlaps it: in an English-only run the French load then reported
// the English trie's word count (40000; the French file holds 39627).
waitUntilLoaded("initial")

for code in langs {
    // "fr-learned" is the French keyboard on the fr-learned corpus and its learned words.
    let langCode = code.components(separatedBy: "-")[0]
    guard let lang = SupportedLanguage(rawValue: langCode) else { fatalError("unknown language \(code)") }
    load(lang)
    seedLearnedWords("\(benchDir)/corpus/\(code).words")
    guard let page = KeyboardLayouts.current(needsGlobe: false).currentDeviceLayout?.normal else {
        fatalError("no letter page for \(code)")
    }
    let cells = grid(page, width: w, height: h)
    let sentences = readLines("\(corpusDir)/\(code).txt")
    let run = readRun("\(runsDir)/\(code).tsv")

    var model: KeyTargetModel?
    if hitMode == "model" {
        // Bundle.main is the directory run.sh copied the shipped dictionaries into.
        guard let trie = PrefixMass(path: "\(Bundle.main.bundlePath)/\(code)_spellcheck.dict") else {
            fatalError("cannot read \(code)_spellcheck.dict")
        }
        // The engine keeps its n-grams private: the spike opens the same file a second time.
        var ngrams: AOSPTrieBridge?
        if modelParameters.ngram {
            let bridge = AOSPTrieBridge()
            guard bridge.loadNgrams(atPath: "\(Bundle.main.bundlePath)/\(code)_ngrams.dict") else {
                fatalError("cannot read \(code)_ngrams.dict")
            }
            ngrams = bridge
        }
        model = KeyTargetModel(parameters: modelParameters, trie: trie, ngrams: ngrams)
    }
    let picker: Picker? = model.map { m in
        { (m.pick($0, plain: $1, cells: cells, word: $2, previous: $3), m.visited) }
    }

    var order: [Int] = []
    for tap in run where order.last != tap.sentence { order.append(tap.sentence) }
    for s in order {
        // A run of several passes keeps numbering its sentences: sentence s is corpus line s modulo its length.
        let intended = sentences[s % sentences.count]
        let intendedWords = intended.components(separatedBy: " ")
        journal?.startSentence(keyboard: "\(langCode)-\(LayoutType.active.rawValue)", document: "\(code)-\(s)")
        let (text, commits) = replay(run.filter { $0.sentence == s }, cells: cells, width: w, height: h,
                                     picker: picker, journal: journal) { tap, resolved, p, us, pick, journalNs in
            tapsOut.append("\(code)\t\(s)\t\(tap.index)\t\(tap.key)\t\(resolved)\t\(String(format: "%.2f", p.x))\t"
                           + "\(String(format: "%.2f", p.y))\t\(us)\t\(pick.plain)\t\(pick.ns)\t\(pick.visited)\t\(journalNs)")
        }
        for c in commits {
            let meant = c.intendedWords.map { intendedWords[$0] }.joined(separator: " ")
            commitsOut.append("\(code)\t\(s)\t\(meant)\t\(c.typed)\t\(c.final)")
        }
        textsOut.append("\(code)\t\(s)\t\(intended)\t\(text)")
    }
    // The register of real cases (#500): each one in a fresh field holding what was
    // typed before it, committed by the same space bar as the runs.
    for f in register where f[0] == code {
        let entries = f[6].split(separator: ",").map { entry -> (userInput: String, documentText: String) in
            let parts = entry.split(separator: "=", maxSplits: 1).map(String.init)
            return (parts[0], parts.last ?? parts[0])
        }
        engine.setSupplementaryLexicon(SupplementaryLexicon(entries: entries))
        let field = Field()
        field.text = f[1] + f[2]
        let final = commitWord(in: field, memory: AutocorrectRejectionMemory(), mirror: MirrorSyncState())?.final ?? f[2]
        registerOut.append("\(code)\t\(f[1])\t\(f[2])\t\(f[3])\t\(f[4])\t\(f[6])\t\(final)")
    }
    engine.setSupplementaryLexicon(.empty)
    FileHandle.standardError.write(Data("\(code): \(order.count) sentences replayed, hit test \(hitMode)\n".utf8))
}

// The user dictionary is the simulator's App Group store: leave it as empty as it was found.
UserDictionary.shared.resetAll()
journal?.finish(writingTo: "\(outDir)/journal.log")

for (name, rows) in [("taps.tsv", tapsOut), ("commits.tsv", commitsOut), ("texts.tsv", textsOut),
                     ("register.tsv", registerOut)] {
    do {
        try (rows.joined(separator: "\n") + "\n").write(toFile: "\(outDir)/\(name)", atomically: true, encoding: .utf8)
    } catch {
        fatalError("cannot write \(outDir)/\(name): \(error)")
    }
}
