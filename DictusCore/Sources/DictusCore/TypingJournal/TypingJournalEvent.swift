// DictusCore/Sources/DictusCore/TypingJournal/TypingJournalEvent.swift
// What the typing journal records (#1001), and the one line each event becomes.
//
// Debug builds only, like AutocorrectDebugLog: typed text is user content, so none
// of this exists in a Release, TestFlight or App Store binary.
#if DEBUG
import Foundation

/// One tap on a key of the letter grid.
public struct TypingJournalTap: Equatable, Sendable {
    /// The key the touch resolved to: a lowercased letter, or `space`, `backspace`,
    /// `shift`, `return`, `123`, `accent` (the AZERTY key beside `n`), `emoji`...
    public let key: String
    /// Landing offset from the key's centre, in key units: one-unit key widths across,
    /// row heights down. The unit of tools/keyboard-bench runs (#954), so a recorded
    /// tap replays on a grid of another width.
    public let dx: Double
    public let dy: Double
    /// Milliseconds since the previous tap, nil for the first one of a field.
    public let sincePreviousMs: Int?
    /// Language and layout, `fr-azerty`.
    public let keyboard: String

    public init(key: String, dx: Double, dy: Double, sincePreviousMs: Int?, keyboard: String) {
        self.key = key
        self.dx = dx
        self.dy = dy
        self.sincePreviousMs = sincePreviousMs
        self.keyboard = keyboard
    }
}

/// What the suggestion bar showed.
public struct TypingJournalBar: Equatable, Sendable {
    /// `corrections`, `candidates`, `completions`, `predictions`, `undoAvailable`, `idle`.
    public let mode: String
    public let words: [String]

    public init(mode: String, words: [String]) {
        self.mode = mode
        self.words = words
    }
}

/// What became of a word when it was committed.
public enum TypingJournalOutcome: String, Equatable, Sendable {
    /// The keyboard replaced the typed word.
    case autocorrected
    /// Nothing was wrong with the word, or nothing better was found.
    case kept
    /// Candidates were offered in the bar and none was applied (#993).
    case offered
    /// The user had refused a correction at this place, so the word was kept (#872).
    case refusedHere = "refused-here"
    /// A correction was decided and then aborted by the boundary check (#191).
    case aborted
    /// Autocorrect did not run: switched off, or the field asks for none (#200).
    case off
}

/// A word committed by the space bar, return or a punctuation mark.
public struct TypingJournalWord: Equatable, Sendable {
    public let id: Int
    public let typed: String
    public let previous: String?
    public let final: String
    public let outcome: TypingJournalOutcome
    /// The key that committed the word: `space`, `return`, or the punctuation mark.
    public let committedBy: String
    /// The `branch=` of every autocorrect decision taken on the word, in order:
    /// `trie`, `language-override`, `accent`... and whatever a later pass adds.
    public let branches: [String]
    /// The bar as it stood when the word was committed.
    public let bar: TypingJournalBar?
    /// How many decision lines the suggestion bar's partial-word checks produced since
    /// the previous commit. They are counted here instead of written (#1001 point 5).
    public let previews: Int

    public init(id: Int, typed: String, previous: String?, final: String, outcome: TypingJournalOutcome,
                committedBy: String, branches: [String], bar: TypingJournalBar?, previews: Int) {
        self.id = id
        self.typed = typed
        self.previous = previous
        self.final = final
        self.outcome = outcome
        self.committedBy = committedBy
        self.branches = branches
        self.bar = bar
        self.previews = previews
    }
}

/// What the user did about a committed word. Each points at the commit it reacts to.
public enum TypingJournalReaction: Equatable, Sendable {
    /// An autocorrection undone, by the bar's undo chip or a backspace right after it.
    case undo(by: String)
    /// A backspace reached back into the word `taps` taps after it was committed.
    case deleted(afterTaps: Int)
    /// The word entered the personal dictionary.
    case learned(word: String)
}

public enum TypingJournalEvent: Equatable, Sendable {
    /// The keyboard is in a field the journal may record. Starts a replay sentence.
    case field(keyboard: String)
    case tap(TypingJournalTap)
    /// A held backspace deleted again, with no new touch.
    case repeatDelete
    case word(TypingJournalWord)
    /// One autocorrect debug line logged while `word` was being decided: the
    /// candidates with their cost, frequency and context score, the branch taken.
    case why(id: Int, line: String)
    /// A slot of the bar was tapped. A tap that puts a word in the text is a commit,
    /// with its own `id`; the undo chip commits nothing and has none.
    case barTap(id: Int?, slot: Int, bar: TypingJournalBar)
    /// `id` is nil when no recent commit matches.
    case reaction(id: Int?, TypingJournalReaction)
    /// An autocorrect debug line that belongs to no decision, written as it was.
    case passthrough(String)

    /// The body of the log line, after the `[timestamp] DEBUG   [keyboard] <source> ` prefix
    /// every autocorrect debug line carries. Journal lines start with `TJ `.
    public var line: String {
        switch self {
        case .field(let keyboard):
            return "TJ FIELD kb=\(keyboard)"
        case .tap(let tap):
            let since = tap.sincePreviousMs.map(String.init) ?? "-"
            return "TJ TAP k=\(tap.key) dx=\(Self.offset(tap.dx)) dy=\(Self.offset(tap.dy)) dt=\(since) kb=\(tap.keyboard)"
        case .repeatDelete:
            return "TJ REPEAT k=backspace"
        case .word(let word):
            var parts = ["TJ WORD #\(word.id)", "typed=\(Self.quote(word.typed))",
                         "prev=\(word.previous.map(Self.quote) ?? "nil")", "final=\(Self.quote(word.final))",
                         "outcome=\(word.outcome.rawValue)", "by=\(Self.committer(word.committedBy))"]
            if !word.branches.isEmpty { parts.append("branch=\(word.branches.joined(separator: ","))") }
            if let bar = word.bar { parts.append("bar=\(Self.bar(bar))") }
            parts.append("previews=\(word.previews)")
            return parts.joined(separator: " ")
        case .why(let id, let line):
            return "TJ WHY #\(id) \(Self.oneLine(line))"
        case .barTap(let id, let slot, let bar):
            let word = bar.words.indices.contains(slot) ? Self.quote(bar.words[slot]) : "nil"
            let target = id.map { "#\($0) " } ?? ""
            return "TJ BARTAP \(target)slot=\(slot) word=\(word) bar=\(Self.bar(bar))"
        case .reaction(let id, let reaction):
            let target = id.map { "#\($0)" } ?? "#?"
            switch reaction {
            case .undo(let by): return "TJ REACT \(target) undo by=\(by)"
            case .deleted(let taps): return "TJ REACT \(target) deleted taps=\(taps)"
            case .learned(let word): return "TJ REACT \(target) learned word=\(Self.quote(word))"
            }
        case .passthrough(let body):
            return Self.oneLine(body)
        }
    }

    /// A signed offset with four decimals, as in the bench's run files: `+0.0554`, `-0.4726`.
    static func offset(_ value: Double) -> String {
        String(format: "%+.4f", value)
    }

    /// A debug line quotes the document's tail, which in a multi-line field holds
    /// newlines. Kept on one line, every part of it carries the prefix Clear and the
    /// 7-day prune read.
    static func oneLine(_ body: String) -> String {
        body.replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n")
    }

    /// A quoted word, its own quotes and backslashes escaped so a parser reads it back whole.
    static func quote(_ word: String) -> String {
        "\"" + word.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// The committing key as a single token: a punctuation mark is quoted, a newline named.
    static func committer(_ key: String) -> String {
        switch key {
        case " ": return "space"
        case "\n": return "return"
        default: return quote(key)
        }
    }

    static func bar(_ bar: TypingJournalBar) -> String {
        "\(bar.mode)[\(bar.words.map(quote).joined(separator: ","))]"
    }
}
#endif
