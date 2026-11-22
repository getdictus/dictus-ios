// tools/keyboard-bench/Journal.swift
// The typing journal (#1001) during a replay: the calls the keyboard makes, at the
// moments it makes them, so the bench measures what the journal costs a keystroke and
// checks that it changes nothing the keyboard types.
//
// The journal only exists in a DEBUG build (`run.sh --debug`). The default build, the
// one every before/after report uses, has no journal and replays exactly as before.
import Foundation
import UIKit
import DictusCore

final class Journal {
    #if DEBUG
    private let lock = NSLock()
    private var entries: [TypingJournalEntry] = []
    #endif
    /// The language and layout, which the keyboard's grid reads once when it is built.
    private var keyboard = ""

    /// The journal of a DEBUG bench, its toggle set to `toggle`; nil in the default build.
    static func start(toggle: Bool) -> Journal? {
        #if DEBUG
        AppGroup.defaults.set(toggle, forKey: SharedKeys.autocorrectDebugLogging)
        let journal = Journal()
        TypingJournal.redirectOutput { batch in journal.lock.withLock { journal.entries += batch } }
        return journal
        #else
        if toggle { fatalError("KB_JOURNAL=1 needs a bench built with run.sh --debug") }
        return nil
        #endif
    }

    /// A sentence is typed into a new field, as on the keyboard.
    func startSentence(keyboard: String, document: String) {
        self.keyboard = keyboard
        #if DEBUG
        TypingJournal.observeField(isSecureEntry: false, content: nil, document: document, keyboard: keyboard)
        #endif
    }

    /// What `GiellaKeyboardView.recordJournalTap` does for a touch at `point` that
    /// resolved to `cell`, timed. Returns the nanoseconds it took.
    func tap(_ cell: Cell, at point: CGPoint, ms: Double) -> Int {
        #if DEBUG
        let start = DispatchTime.now().uptimeNanoseconds
        if TypingJournal.isRecording {
            TypingJournal.tap(
                Self.name(of: cell.key.type),
                dx: Double((point.x - cell.frame.midX) / cell.unitWidth),
                dy: Double((point.y - cell.frame.midY) / cell.frame.height),
                time: ms / 1000,
                keyboard: keyboard
            )
        }
        return Int(DispatchTime.now().uptimeNanoseconds - start)
        #else
        return 0
        #endif
    }

    /// The space bar opens the word, as `autocorrectBeforeCursor` does. The replay has no
    /// suggestion bar.
    func beginWord(_ word: String, previous: String?) {
        #if DEBUG
        TypingJournal.beginWord(typed: word, previous: previous, committedBy: " ", bar: nil)
        #endif
    }

    /// `offered`: the corrector kept the word and offered corrections for it.
    func endWord(_ final: String, offered: Bool) {
        #if DEBUG
        TypingJournal.endWord(final: final, autocorrectRan: true, offered: offered)
        #endif
    }

    /// Writes what the journal recorded, as the keyboard would have written it to the
    /// log, and puts the toggle back off.
    func finish(writingTo path: String) {
        #if DEBUG
        TypingJournal.flush()
        TypingJournal.waitUntilWritten()
        AppGroup.defaults.set(false, forKey: SharedKeys.autocorrectDebugLogging)
        let text = lock.withLock { TypingJournal.lines(for: entries, source: "keyboard") }
        do {
            try text.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            fatalError("cannot write \(path): \(error)")
        }
        #endif
    }

    #if DEBUG
    /// `GiellaKeyboardView.journalName(of:)`, which the bench does not compile.
    private static func name(of type: KeyType) -> String {
        switch type {
        case .input(let key, let alternate): return alternate == "accent" ? "accent" : key.lowercased()
        case .spacebar: return "space"
        case .backspace: return "backspace"
        case .shift, .caps: return "shift"
        case .returnkey: return "return"
        case .symbols: return "123"
        case .shiftSymbols: return "#+="
        case .keyboard: return "globe"
        case .comma: return ","
        case .fullStop: return "."
        default: return "other"
        }
    }
    #endif
}
