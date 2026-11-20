// DictusCore/Sources/DictusCore/TypingJournal/TypingJournal.swift
// The keyboard's typing journal (#1001): taps, the decision at each committed word,
// the suggestion bar, and what the user did next, one line per event.
//
// Debug builds only. It runs behind the existing "Autocorrect debug logs" toggle
// (SharedKeys.autocorrectDebugLogging) and writes into the same App Group file as
// AutocorrectDebugLog, so it is exported by Export logs, kept 7 days like every other
// line, and wiped by Clear. Nothing here touches the network.
//
// tools/keyboard-bench/journal_to_run.py turns an exported journal into a #954 touch run.
#if DEBUG
import Foundation

public enum TypingJournal {
    static let recorder = TypingJournalRecorder(
        isToggleOn: { AppGroup.defaults.bool(forKey: SharedKeys.autocorrectDebugLogging) },
        sink: writeToLog
    )

    /// Whether taps and words are being recorded right now.
    public static var isRecording: Bool { recorder.isRecording }

    /// The host field's traits were read (`DictusKeyboardBridge.refreshHostPolicy`).
    /// A secure, password, one-time-code or card field stops all recording.
    public static func observeField(isSecureEntry: Bool, content: TypingJournalFieldGate.Content?,
                                    document: String?, keyboard: String) {
        recorder.observeField(isSecureEntry: isSecureEntry, content: content, document: document, keyboard: keyboard)
    }

    public static func tap(_ key: String, dx: Double, dy: Double, time: TimeInterval, keyboard: String) {
        recorder.tap(key, dx: dx, dy: dy, time: time, keyboard: keyboard)
    }

    public static func repeatDelete() {
        recorder.repeatDelete()
    }

    public static func beginWord(typed: String, previous: String?, committedBy: String, bar: TypingJournalBar?) {
        recorder.beginWord(typed: typed, previous: previous, committedBy: committedBy, bar: bar)
    }

    public static func endWord(final: String, autocorrectRan: Bool) {
        recorder.endWord(final: final, autocorrectRan: autocorrectRan)
    }

    public static func barTapped(slot: Int, bar: TypingJournalBar, typed: String, commits: Bool) {
        recorder.barTapped(slot: slot, bar: bar, typed: typed, commits: commits)
    }

    /// AutocorrectDebugLog's way in. False: write the line directly, as before #1001.
    static func absorb(_ body: String) -> Bool {
        recorder.absorb(body)
    }

    /// Writes everything still in memory.
    public static func flush() {
        recorder.flush()
    }

    /// Sends the journal somewhere other than the log file. For tools only: the bench
    /// keeps the journal of a replay to check that it replays the same taps.
    public static func redirectOutput(_ sink: @escaping TypingJournalRecorder.Sink) {
        recorder.redirect(to: sink)
    }

    /// Deletes every line that holds typed text from the log file: the journal's and
    /// AutocorrectDebugLog's. The diagnostic lines, which hold none, stay.
    ///
    /// The batches already handed out are let through first, so none lands after the wipe.
    /// Clear runs in the app, while the keyboard's process may still hold events in
    /// memory: the time of the Clear goes in the App Group, and the keyboard drops every
    /// event older than it when it writes (`writable`).
    public static func clear() {
        AppGroup.defaults.set(Date().timeIntervalSince1970, forKey: clearedAtKey)
        recorder.clear()
        recorder.waitUntilWritten()
        PersistentLog.removeLines(where: isTypedTextLine)
    }

    /// When Clear typing journal was last used. Debug builds only, like the journal; a
    /// stray value in a Release install is never read.
    static let clearedAtKey = "dictus.typingJournalClearedAt"

    /// The entries of a batch that may still be written: none once the toggle is off,
    /// none from before the last Clear.
    static func writable(_ entries: [TypingJournalEntry], toggleOn: Bool, clearedAt: TimeInterval) -> [TypingJournalEntry] {
        guard toggleOn else { return [] }
        return entries.filter { $0.date.timeIntervalSince1970 > clearedAt }
    }

    /// Blocks until every batch handed out so far has been passed on. For tools.
    public static func waitUntilWritten() {
        recorder.waitUntilWritten()
    }

    /// The prefix AutocorrectDebugLog and the journal write before every body. No
    /// `LogEvent` line has it: their event name follows the subsystem directly.
    static let typedTextMarker = "] DEBUG   [keyboard] <"

    static func isTypedTextLine(_ line: Substring) -> Bool {
        line.contains(typedTextMarker)
    }

    /// One log line per entry, in AutocorrectDebugLog's format.
    ///
    /// WHY whole seconds: `PersistentLog.pruneOldEntries` keeps a line whose timestamp
    /// it cannot parse, and it parses without fractional seconds. A finer stamp would
    /// make every journal line outlive the 7 days. The taps carry their own intervals.
    public static func lines(for entries: [TypingJournalEntry], source: String) -> String {
        entries.map { "[\(timestampFormatter.string(from: $0.date))] DEBUG   [keyboard] <\(source)> \($0.event.line)\n" }
            .joined()
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let writeToLog: TypingJournalRecorder.Sink = { entries in
        let kept = writable(
            entries,
            toggleOn: AppGroup.defaults.bool(forKey: SharedKeys.autocorrectDebugLogging),
            clearedAt: AppGroup.defaults.double(forKey: clearedAtKey)
        )
        guard !kept.isEmpty else { return }
        PersistentLog.appendDebugText { lines(for: kept, source: PersistentLog.source) }
    }
}
#endif
