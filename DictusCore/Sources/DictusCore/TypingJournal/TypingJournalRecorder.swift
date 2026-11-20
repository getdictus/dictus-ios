// DictusCore/Sources/DictusCore/TypingJournal/TypingJournalRecorder.swift
// The typing journal's state (#1001): which field it may record, the events waiting
// to be written, the word being decided, and the recent commits a reaction points at.
//
// The approach is Hex's typing log (anomalyco/hex, branch dev, MIT:
// ios/HEXShared/TypingLog/TypingLogger.swift, `typingLog` in
// ios/HEXShared/FullKeyboard/FullKeyboardView.swift): events go to an in-memory buffer
// on the keystroke and reach the file in batches, off the keystroke; a secure field
// is skipped whole. Dictus writes into its own debug log instead of NDJSON files, so
// the existing export, retention and Clear apply to it.
#if DEBUG
import Foundation

/// The rule that keeps the journal out of fields holding secrets: secure text entry,
/// passwords, one-time codes and card numbers. Pure, so it is tested without UIKit.
public enum TypingJournalFieldGate {
    /// The host's `textContentType`, reduced to what the rule reads. `HostInputTraits`
    /// maps the UIKit values in the keyboard.
    public enum Content: Equatable, Sendable {
        case password
        case newPassword
        case oneTimeCode
        case creditCard
        case other
    }

    /// Why the field must not be recorded, or nil when it may be.
    public static func skipReason(isSecureEntry: Bool, content: Content?) -> String? {
        if isSecureEntry { return "secureTextEntry" }
        switch content {
        case .password?: return "password"
        case .newPassword?: return "newPassword"
        case .oneTimeCode?: return "oneTimeCode"
        case .creditCard?: return "creditCard"
        case .other?, nil: return nil
        }
    }
}

/// One event and when it happened.
public struct TypingJournalEntry: Equatable, Sendable {
    public let date: Date
    public let event: TypingJournalEvent
}

public final class TypingJournalRecorder: @unchecked Sendable {
    public typealias Sink = @Sendable ([TypingJournalEntry]) -> Void

    /// Where the keyboard stands with the field it is typing into.
    private enum FieldState: Equatable {
        /// No field observed yet: the app's process, or a keyboard before its first
        /// trait read. Autocorrect debug lines are written directly, as before #1001.
        case unknown
        case recording(document: String?, keyboard: String)
        /// A field that must not be recorded. Nothing is kept, debug lines included.
        case skipped

        var isRecording: Bool {
            if case .recording = self { return true }
            return false
        }
    }

    /// The word between the space bar's press and the end of its decision.
    private struct OpenWord {
        let typed: String
        let previous: String?
        let committedBy: String
        let bar: TypingJournalBar?
        var whys: [String] = []
        var branches: [String] = []
    }

    /// A commit a reaction can point at.
    private struct RecentCommit {
        let id: Int
        let typed: String
        let final: String
    }

    /// Watches the taps after a commit for a backspace that reaches back into the word.
    private struct DeletionWatch {
        let id: Int
        var taps = 0
        /// Characters typed since the commit, which a backspace removes first.
        var typedSince = 0
        /// The space or mark that committed the word.
        var trailing = 1
    }

    /// A backspace this many taps after a commit no longer reads as a reaction to it.
    static let deletionWindow = 8
    /// The longest an event waits in memory before it is written.
    static let flushDelay: TimeInterval = 2
    /// Buffered events that trigger a write without waiting.
    static let maxBuffered = 64
    /// Commits a reaction can still point at.
    static let recentLimit = 16

    private let lock = NSLock()
    private let isToggleOn: @Sendable () -> Bool
    private let now: @Sendable () -> Date
    private var sink: Sink
    private let flushQueue = DispatchQueue(label: "com.pivi.dictus.typingjournal", qos: .utility)

    private var enabled = false
    private var field = FieldState.unknown
    private var buffer: [TypingJournalEntry] = []
    private var flushScheduled = false
    private var lastTapTime: TimeInterval?
    private var nextID = 1
    private var open: OpenWord?
    private var previews = 0
    private var recent: [RecentCommit] = []
    private var watch: DeletionWatch?

    public init(isToggleOn: @escaping @Sendable () -> Bool,
                now: @escaping @Sendable () -> Date = { Date() },
                sink: @escaping Sink) {
        self.isToggleOn = isToggleOn
        self.now = now
        self.sink = sink
    }

    /// Replaces where batches go. The bench uses it to keep the journal of a replay.
    public func redirect(to sink: @escaping Sink) {
        lock.withLock { self.sink = sink }
    }

    /// Whether taps and words are being recorded right now.
    public var isRecording: Bool {
        lock.withLock { enabled && field.isRecording }
    }

    // MARK: - Field

    /// The host field's traits were read. Reads the toggle too, so turning it on or off
    /// in the app takes effect at the next read, which every committed word triggers.
    public func observeField(isSecureEntry: Bool, content: TypingJournalFieldGate.Content?,
                             document: String?, keyboard: String) {
        lock.withLock {
            enabled = isToggleOn()
            if TypingJournalFieldGate.skipReason(isSecureEntry: isSecureEntry, content: content) != nil {
                // Dropped, not written: a host can move the focus into a code or password
                // field without a trait read, and the first key typed there is already in
                // the buffer when the gate learns where it is.
                buffer.removeAll()
                field = .skipped
                resetWordState()
                return
            }
            let next = FieldState.recording(document: document, keyboard: keyboard)
            guard next != field else { return }
            if case .recording(let previousDocument, _) = field, previousDocument != document {
                resetWordState()
            } else if !field.isRecording {
                resetWordState()
            }
            field = next
            if enabled { append(.field(keyboard: keyboard)) }
        }
    }

    // MARK: - Keys

    /// A touch resolved to `key`. `time` is the touch's timestamp, in seconds.
    public func tap(_ key: String, dx: Double, dy: Double, time: TimeInterval, keyboard: String) {
        lock.withLock {
            guard enabled, field.isRecording else { return }
            let since = lastTapTime.map { Int(((time - $0) * 1000).rounded()) }
            lastTapTime = time
            append(.tap(TypingJournalTap(key: key, dx: dx, dy: dy, sincePreviousMs: since, keyboard: keyboard)))
            observeForDeletion(key)
        }
    }

    /// A held backspace deleted once more.
    public func repeatDelete() {
        lock.withLock {
            guard enabled, field.isRecording else { return }
            append(.repeatDelete)
            observeForDeletion("backspace")
        }
    }

    // MARK: - Words

    /// The space bar, return or a punctuation mark is about to commit `typed`. Every
    /// autocorrect debug line logged on this thread until `endWord` belongs to it.
    public func beginWord(typed: String, previous: String?, committedBy: String, bar: TypingJournalBar?) {
        lock.withLock {
            guard enabled, field.isRecording else { return }
            open = OpenWord(typed: typed, previous: previous, committedBy: committedBy, bar: bar)
        }
    }

    /// The word is committed as `final`. `autocorrectRan` is false when autocorrect is
    /// switched off or the field asks for none.
    public func endWord(final: String, autocorrectRan: Bool) {
        lock.withLock {
            guard let word = open else { return }
            open = nil
            let id = takeID()
            append(.word(TypingJournalWord(
                id: id, typed: word.typed, previous: word.previous, final: final,
                outcome: Self.outcome(of: word, final: final, autocorrectRan: autocorrectRan),
                committedBy: word.committedBy, branches: word.branches, bar: word.bar, previews: previews
            )))
            for line in word.whys { append(.why(id: id, line: line)) }
            previews = 0
            remember(id: id, typed: word.typed, final: final)
            watch = DeletionWatch(id: id)
        }
        flush()
    }

    /// A slot of the bar was tapped. `commits` is false for the undo chip, which puts
    /// back a word rather than committing one.
    public func barTapped(slot: Int, bar: TypingJournalBar, typed: String, commits: Bool) {
        lock.withLock {
            guard enabled, field.isRecording else { return }
            guard commits, bar.words.indices.contains(slot) else {
                append(.barTap(id: nil, slot: slot, bar: bar))
                return
            }
            let id = takeID()
            append(.barTap(id: id, slot: slot, bar: bar))
            previews = 0
            remember(id: id, typed: typed, final: bar.words[slot])
            watch = DeletionWatch(id: id)
        }
        flush()
    }

    // MARK: - Autocorrect debug lines

    /// Takes an autocorrect debug line, already past its own toggle check. Returns
    /// false when the line is not the journal's to handle and must be written directly.
    ///
    /// While a word is open, a line logged on the main thread is part of its decision.
    /// Otherwise the decision lines come from the bar's partial-word checks and are
    /// only counted. A reaction becomes a journal line pointing at its commit.
    func absorb(_ body: String, onMainThread: Bool = Thread.isMainThread) -> Bool {
        lock.withLock {
            switch field {
            case .unknown: return false
            case .skipped: return true
            case .recording: break
            }
            // The toggle was turned on after the last trait read: write as before.
            guard enabled else { return false }
            let tag = body.prefix { $0 != " " }

            if onMainThread, open != nil {
                open?.whys.append(body)
                if tag == "AUTOCORRECT", let branch = Self.field("branch", in: body) {
                    open?.branches.append(branch)
                }
                return true
            }
            if Self.isPartialWordCheck(tag: tag, body: body) {
                previews += 1
                return true
            }
            switch tag {
            case "UNDO":
                append(.reaction(id: commitID(final: Self.quotedField("rejected", in: body)), .undo(by: "chip")))
            case "REFUSED":
                switch Self.field("by", in: body) {
                case "backspace":
                    append(.reaction(id: commitID(final: Self.quotedField("corrected", in: body)), .undo(by: "backspace")))
                case "undo":
                    // The same tap as the UNDO line before it.
                    break
                default:
                    append(.passthrough(body))
                }
            case "USERDICT-LEARN":
                let word = Self.quotedField("word", in: body) ?? ""
                append(.reaction(id: commitID(typed: word), .learned(word: word)))
                append(.passthrough(body))
            default:
                append(.passthrough(body))
            }
            return true
        }
    }

    // MARK: - Writing

    /// Hands every buffered event to the sink.
    ///
    /// WHY every batch goes through one serial queue, dispatched under the lock: a batch
    /// written from the caller's thread could overtake one already queued, and the
    /// file would hold the lines out of order.
    public func flush() {
        lock.withLock { sendBuffer() }
    }

    /// Blocks until every batch handed out so far has reached the sink.
    public func waitUntilWritten() {
        flushQueue.sync {}
    }

    /// Forgets everything not yet written and every commit a reaction could point at.
    public func clear() {
        lock.withLock {
            buffer.removeAll()
            previews = 0
            recent.removeAll()
            resetWordState()
        }
    }

    // MARK: - Private (called with the lock held)

    private func append(_ event: TypingJournalEvent) {
        buffer.append(TypingJournalEntry(date: now(), event: event))
        if buffer.count >= Self.maxBuffered {
            sendBuffer()
        } else if !flushScheduled {
            flushScheduled = true
            flushQueue.asyncAfter(deadline: .now() + Self.flushDelay) { [weak self] in
                self?.lock.withLock { self?.flushScheduled = false }
                self?.flush()
            }
        }
    }

    private func sendBuffer() {
        guard !buffer.isEmpty else { return }
        let batch = buffer
        let sink = self.sink
        buffer.removeAll()
        flushQueue.async { sink(batch) }
    }

    private func takeID() -> Int {
        defer { nextID += 1 }
        return nextID
    }

    private func remember(id: Int, typed: String, final: String) {
        recent.append(RecentCommit(id: id, typed: typed, final: final))
        if recent.count > Self.recentLimit { recent.removeFirst() }
    }

    private func commitID(final: String?) -> Int? {
        guard let final = final else { return nil }
        return recent.last { $0.final == final }?.id
    }

    private func commitID(typed word: String) -> Int? {
        let lowered = word.lowercased()
        return recent.last { $0.typed.lowercased() == lowered || $0.final.lowercased() == lowered }?.id
    }

    private func resetWordState() {
        open = nil
        watch = nil
        lastTapTime = nil
    }

    private func observeForDeletion(_ key: String) {
        guard var current = watch else { return }
        current.taps += 1
        guard current.taps <= Self.deletionWindow else {
            watch = nil
            return
        }
        switch key {
        case "backspace":
            if current.typedSince > 0 {
                current.typedSince -= 1
            } else if current.trailing > 0 {
                current.trailing -= 1
            } else {
                append(.reaction(id: current.id, .deleted(afterTaps: current.taps)))
                watch = nil
                return
            }
        case "shift", "123", "emoji", "globe":
            break
        default:
            current.typedSince += 1
        }
        watch = current
    }

    private static func outcome(of word: OpenWord, final: String, autocorrectRan: Bool) -> TypingJournalOutcome {
        if final != word.typed { return .autocorrected }
        if word.whys.contains(where: { $0.hasPrefix("AUTOCORRECT-ABORT ") }) { return .aborted }
        if word.whys.contains(where: { $0.hasPrefix("AUTOCORRECT-SKIP ") && $0.hasSuffix("reason=refused-here") }) {
            return .refusedHere
        }
        if !autocorrectRan { return .off }
        if word.bar?.mode == "candidates" { return .offered }
        return .kept
    }

    /// The lines the engine logs while it decides a word. Outside a commit they come
    /// from the suggestion bar checking the partial word on every keystroke.
    private static func isPartialWordCheck(tag: Substring, body: String) -> Bool {
        switch tag {
        case "AUTOCORRECT", "AUTOCORRECT-SKIP", "SPLIT", "BIGRAM-RERANK", "TRIE-CANDIDATES":
            return true
        case "NOTE":
            return body.hasPrefix("NOTE bigram-rerank ") || body.hasPrefix("NOTE split ")
        default:
            return false
        }
    }

    /// The unquoted value of `name=` in a debug line.
    static func field(_ name: String, in body: String) -> String? {
        guard let range = body.range(of: " \(name)=") else { return nil }
        let value = body[range.upperBound...].prefix { $0 != " " }
        return value.isEmpty ? nil : String(value)
    }

    /// The value of `name="..."` in a debug line. The debug lines do not escape quotes,
    /// so a word holding one is cut there.
    static func quotedField(_ name: String, in body: String) -> String? {
        guard let range = body.range(of: "\(name)=\"") else { return nil }
        return String(body[range.upperBound...].prefix { $0 != "\"" })
    }
}
#endif
