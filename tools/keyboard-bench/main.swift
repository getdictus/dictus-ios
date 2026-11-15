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
    /// A letter, or "space".
    let key: String
    /// Landing offset from the key centre, in one-unit key widths and in row heights.
    let dx: CGFloat
    let dy: CGFloat
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
              let dx = Double(f[3]), let dy = Double(f[4]) else { fatalError("bad run row: \(line)") }
        return Tap(sentence: s, index: i, key: f[2], dx: CGFloat(dx), dy: CGFloat(dy))
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
/// the point, if any.
func hitTest(_ point: CGPoint, cells: [Cell], width: CGFloat, height: CGFloat) -> Cell? {
    let margin: CGFloat = 4
    let p = CGPoint(x: min(max(point.x, margin), width - margin), y: min(max(point.y, margin), height - margin))
    return cells.first { $0.frame.contains(p) }
}

func target(of key: String, in cells: [Cell]) -> Cell {
    let found = cells.first { cell in
        switch cell.key.type {
        case .spacebar: return key == "space"
        case .input(let k, _): return k == key
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

/// Types one sentence: every tap goes through the grid, every letter triggers the
/// suggestion work `SuggestionState.updateAsync` does, every space the autocorrect
/// `DictusKeyboardBridge.autocorrectBeforeCursor` does.
func replay(_ taps: [Tap], cells: [Cell], width: CGFloat, height: CGFloat,
            tapRow: (Tap, String, CGPoint, Int) -> Void) -> (text: String, commits: [Commit]) {
    let field = Field()
    let memory = AutocorrectRejectionMemory()
    let mirror = MirrorSyncState()
    var commits: [Commit] = []
    var wordIndex = 0
    var tokenWords: [Int] = []

    for tap in taps {
        let aim = target(of: tap.key, in: cells)
        let point = CGPoint(x: aim.frame.midX + tap.dx * aim.unitWidth, y: aim.frame.midY + tap.dy * aim.frame.height)
        let hit = hitTest(point, cells: cells, width: width, height: height)
        let resolved = label(hit)
        if tap.key != "space", tokenWords.last != wordIndex { tokenWords.append(wordIndex) }

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
                let proposal = engine.spellCheck(word, previousWord: previous,
                                                 isAtSentenceStart: ProperNounGuard.isAtSentenceStart(context: field.text, word: word))?.correction
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
        tapRow(tap, resolved, point, cost)
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

var tapsOut = ["lang\tsentence\ttap\tintended\tresolved\tx\ty\tengine_us"]
var commitsOut = ["lang\tsentence\tintended\ttyped\tfinal"]
var textsOut = ["lang\tsentence\tintended\tfinal"]

// The engine starts loading French as soon as it exists. A `setLanguage` issued before
// that load lands overlaps it: in an English-only run the French load then reported
// the English trie's word count (40000; the French file holds 39622).
waitUntilLoaded("initial")

for code in langs {
    guard let lang = SupportedLanguage(rawValue: code) else { fatalError("unknown language \(code)") }
    load(lang)
    guard let page = KeyboardLayouts.current(needsGlobe: false).currentDeviceLayout?.normal else {
        fatalError("no letter page for \(code)")
    }
    let cells = grid(page, width: w, height: h)
    let sentences = readLines("\(benchDir)/corpus/\(code).txt")
    let run = readRun("\(benchDir)/runs/\(code).tsv")

    for (s, intended) in sentences.enumerated() {
        let intendedWords = intended.components(separatedBy: " ")
        let (text, commits) = replay(run.filter { $0.sentence == s }, cells: cells, width: w, height: h) { tap, resolved, p, us in
            tapsOut.append("\(code)\t\(s)\t\(tap.index)\t\(tap.key)\t\(resolved)\t\(String(format: "%.2f", p.x))\t\(String(format: "%.2f", p.y))\t\(us)")
        }
        for c in commits {
            let meant = c.intendedWords.map { intendedWords[$0] }.joined(separator: " ")
            commitsOut.append("\(code)\t\(s)\t\(meant)\t\(c.typed)\t\(c.final)")
        }
        textsOut.append("\(code)\t\(s)\t\(intended)\t\(text)")
    }
    FileHandle.standardError.write(Data("\(code): \(sentences.count) sentences replayed\n".utf8))
}

for (name, rows) in [("taps.tsv", tapsOut), ("commits.tsv", commitsOut), ("texts.tsv", textsOut)] {
    do {
        try (rows.joined(separator: "\n") + "\n").write(toFile: "\(outDir)/\(name)", atomically: true, encoding: .utf8)
    } catch {
        fatalError("cannot write \(outDir)/\(name): \(error)")
    }
}
