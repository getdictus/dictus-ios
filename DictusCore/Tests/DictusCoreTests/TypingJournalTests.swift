import XCTest
@testable import DictusCore

/// The typing journal (#1001): what it records, the lines it writes, and where it
/// records nothing.
///
/// WHY a recorder per test rather than `TypingJournal`'s shared one: the shared one
/// reads the App Group toggle and writes to the App Group file. These tests hand it a
/// toggle and collect what it would write.
final class TypingJournalTests: XCTestCase {

    /// What a recorder handed to its sink, in order.
    private final class Collected: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [TypingJournalEntry] = []
        func add(_ batch: [TypingJournalEntry]) { lock.withLock { entries += batch } }
        var lines: [String] { lock.withLock { entries.map(\.event.line) } }
    }

    /// Everything `journal` has recorded, once written.
    private func written(_ journal: TypingJournalRecorder) -> [String] {
        journal.flush()
        journal.waitUntilWritten()
        return collected.lines
    }

    private var collected = Collected()

    override func setUp() {
        super.setUp()
        collected = Collected()
    }

    private func recorder(toggle: Bool = true) -> TypingJournalRecorder {
        let collected = collected
        return TypingJournalRecorder(isToggleOn: { toggle }, sink: { collected.add($0) })
    }

    /// A recorder already in a field it may record, its FIELD line written.
    private func recording(toggle: Bool = true) -> TypingJournalRecorder {
        let journal = recorder(toggle: toggle)
        journal.observeField(isSecureEntry: false, content: nil, document: "doc", keyboard: "fr-azerty")
        return journal
    }

    private func type(_ word: String, on journal: TypingJournalRecorder, from time: TimeInterval = 0) {
        for (i, letter) in word.enumerated() {
            journal.tap(String(letter), dx: 0.1, dy: -0.2, time: time + Double(i) * 0.15, keyboard: "fr-azerty")
        }
    }

    // MARK: - Secure fields

    func testSecretFieldsAreSkipped() {
        XCTAssertEqual(TypingJournalFieldGate.skipReason(isSecureEntry: true, content: nil), "secureTextEntry")
        XCTAssertEqual(TypingJournalFieldGate.skipReason(isSecureEntry: true, content: .other), "secureTextEntry")
        XCTAssertEqual(TypingJournalFieldGate.skipReason(isSecureEntry: false, content: .password), "password")
        XCTAssertEqual(TypingJournalFieldGate.skipReason(isSecureEntry: false, content: .newPassword), "newPassword")
        XCTAssertEqual(TypingJournalFieldGate.skipReason(isSecureEntry: false, content: .oneTimeCode), "oneTimeCode")
        XCTAssertEqual(TypingJournalFieldGate.skipReason(isSecureEntry: false, content: .creditCard), "creditCard")
    }

    func testOrdinaryFieldsAreRecorded() {
        XCTAssertNil(TypingJournalFieldGate.skipReason(isSecureEntry: false, content: nil))
        XCTAssertNil(TypingJournalFieldGate.skipReason(isSecureEntry: false, content: .other))
    }

    func testNothingIsRecordedInASecureField() {
        let journal = recorder()
        journal.observeField(isSecureEntry: true, content: nil, document: "doc", keyboard: "fr-azerty")
        type("secret", on: journal)
        journal.beginWord(typed: "secret", previous: nil, committedBy: " ", bar: nil)
        XCTAssertTrue(journal.absorb("AUTOCORRECT branch=trie orig=\"secret\" corr=\"secrets\" prev=nil"))
        XCTAssertTrue(journal.absorb("MIRROR-PROBE seq=1 ev=space off=0 mir=\"secret \""))
        journal.endWord(final: "secret", autocorrectRan: true)
        journal.barTapped(slot: 1, bar: TypingJournalBar(mode: "predictions", words: ["a", "b"]), typed: "", commits: true)
        journal.repeatDelete()

        XCTAssertFalse(journal.isRecording)
        XCTAssertEqual(written(journal), [], "a secure field writes nothing, debug lines included")
    }

    func testAPasswordFieldStopsARecordingInProgress() {
        let journal = recording()
        type("ab", on: journal)
        journal.flush()
        // The first key of a code field the host moved to without a trait read.
        type("1", on: journal, from: 5)
        journal.observeField(isSecureEntry: false, content: .oneTimeCode, document: "otp", keyboard: "fr-azerty")
        type("23456", on: journal, from: 6)

        XCTAssertEqual(written(journal).filter { $0.hasPrefix("TJ TAP") }.map { $0.components(separatedBy: " ")[2] },
                       ["k=a", "k=b"], "the taps written before the code field, and none typed in it")
    }

    func testAWriteBySizeLeavesTheNewestTapsToTheGate() {
        final class Clock: @unchecked Sendable { var now = Date(timeIntervalSince1970: 1000) }
        let clock = Clock()
        let collected = collected
        let journal = TypingJournalRecorder(isToggleOn: { true }, now: { clock.now }, sink: { collected.add($0) })
        journal.observeField(isSecureEntry: false, content: nil, document: "doc", keyboard: "fr-azerty")
        // A burst far past the size limit, inside the settle delay: nothing may leave.
        for i in 0..<(TypingJournalRecorder.maxBuffered + 10) {
            journal.tap("a", dx: 0, dy: 0, time: Double(i) * 0.005, keyboard: "fr-azerty")
        }
        journal.waitUntilWritten()
        XCTAssertEqual(collected.lines, [], "the burst may be the first keys of a code field")
        journal.observeField(isSecureEntry: false, content: .password, document: "pw", keyboard: "fr-azerty")
        XCTAssertEqual(written(journal), [])

        // Settled events do leave by size.
        journal.observeField(isSecureEntry: false, content: nil, document: "doc2", keyboard: "fr-azerty")
        for i in 0..<TypingJournalRecorder.maxBuffered {
            clock.now += 1
            journal.tap("b", dx: 0, dy: 0, time: Double(i), keyboard: "fr-azerty")
        }
        journal.waitUntilWritten()
        XCTAssertGreaterThan(collected.lines.filter { $0.hasPrefix("TJ TAP k=b") }.count, 0)
    }

    func testOnlyEventsAfterTheLastClearAreWrittenAndOnlyWithTheToggleOn() {
        let before = TypingJournalEntry(date: Date(timeIntervalSince1970: 100), event: .field(keyboard: "fr-azerty"))
        let after = TypingJournalEntry(date: Date(timeIntervalSince1970: 200), event: .field(keyboard: "en-qwerty"))
        XCTAssertEqual(TypingJournal.writable([before, after], toggleOn: true, clearedAt: 150), [after])
        XCTAssertEqual(TypingJournal.writable([before, after], toggleOn: true, clearedAt: 0), [before, after])
        XCTAssertEqual(TypingJournal.writable([before, after], toggleOn: false, clearedAt: 0), [])
    }

    func testADebugLineQuotingSeveralLinesStaysOnOne() {
        let body = "AUTOCORRECT-APPLY-BEFORE word=\"helo\" corr=\"hello\" prev=nil ctx=\"Dear Ann,\nhelo\""
        XCTAssertEqual(TypingJournalEvent.passthrough(body).line,
                       "AUTOCORRECT-APPLY-BEFORE word=\"helo\" corr=\"hello\" prev=nil ctx=\"Dear Ann,\\nhelo\"")
        XCTAssertFalse(TypingJournalEvent.why(id: 1, line: body).line.contains("\n"))
    }

    func testNothingIsRecordedWithTheToggleOff() {
        let journal = recording(toggle: false)
        type("bonjour", on: journal)
        XCTAssertEqual(written(journal), [])
        XCTAssertFalse(journal.absorb("AUTOCORRECT branch=trie orig=\"a\" corr=\"b\" prev=nil"),
                       "the toggle turned on since the last trait read: AutocorrectDebugLog writes the line itself")
    }

    func testTheAppProcessKeepsWritingDebugLinesDirectly() {
        XCTAssertFalse(recorder().absorb("USERDICT-RESET words=[\"a\"]"), "no field was ever observed")
    }

    // MARK: - Lines

    func testTapLine() {
        let tap = TypingJournalTap(key: "e", dx: 0.0554, dy: -0.4726, sincePreviousMs: 176, keyboard: "fr-azerty")
        XCTAssertEqual(TypingJournalEvent.tap(tap).line, "TJ TAP k=e dx=+0.0554 dy=-0.4726 dt=176 kb=fr-azerty")
        let first = TypingJournalTap(key: "space", dx: 0, dy: 0, sincePreviousMs: nil, keyboard: "en-qwerty")
        XCTAssertEqual(TypingJournalEvent.tap(first).line, "TJ TAP k=space dx=+0.0000 dy=+0.0000 dt=- kb=en-qwerty")
    }

    func testWordLine() {
        let word = TypingJournalWord(
            id: 3, typed: "tres", previous: "je", final: "très", outcome: .autocorrected, committedBy: " ",
            branches: ["accent"], bar: TypingJournalBar(mode: "corrections", words: ["tres", "très", "trop"]),
            previews: 4
        )
        XCTAssertEqual(
            TypingJournalEvent.word(word).line,
            "TJ WORD #3 typed=\"tres\" prev=\"je\" final=\"très\" outcome=autocorrected by=space branch=accent "
                + "bar=corrections[\"tres\",\"très\",\"trop\"] previews=4"
        )
        let first = TypingJournalWord(id: 1, typed: "Ok", previous: nil, final: "Ok", outcome: .kept, committedBy: ",",
                                      branches: [], bar: nil, previews: 0)
        XCTAssertEqual(TypingJournalEvent.word(first).line,
                       "TJ WORD #1 typed=\"Ok\" prev=nil final=\"Ok\" outcome=kept by=\",\" previews=0")
    }

    func testQuotesInAWordAreEscaped() {
        XCTAssertEqual(TypingJournalEvent.quote("a\"b\\c"), "\"a\\\"b\\\\c\"")
    }

    func testReactionAndBarLines() {
        XCTAssertEqual(TypingJournalEvent.reaction(id: 3, .undo(by: "chip")).line, "TJ REACT #3 undo by=chip")
        XCTAssertEqual(TypingJournalEvent.reaction(id: nil, .deleted(afterTaps: 2)).line, "TJ REACT #? deleted taps=2")
        XCTAssertEqual(TypingJournalEvent.reaction(id: 5, .learned(word: "dictus")).line,
                       "TJ REACT #5 learned word=\"dictus\"")
        let bar = TypingJournalBar(mode: "candidates", words: ["helo", "hello", "help"])
        XCTAssertEqual(TypingJournalEvent.barTap(id: 6, slot: 1, bar: bar).line,
                       "TJ BARTAP #6 slot=1 word=\"hello\" bar=candidates[\"helo\",\"hello\",\"help\"]")
        XCTAssertEqual(TypingJournalEvent.barTap(id: nil, slot: 0, bar: TypingJournalBar(mode: "undoAvailable", words: ["tres"])).line,
                       "TJ BARTAP slot=0 word=\"tres\" bar=undoAvailable[\"tres\"]")
    }

    func testLogLinesUseTheAutocorrectDebugFormat() {
        let entry = TypingJournalEntry(date: Date(timeIntervalSince1970: 0), event: .field(keyboard: "fr-azerty"))
        XCTAssertEqual(TypingJournal.lines(for: [entry], source: "keyboard"),
                       "[1970-01-01T00:00:00Z] DEBUG   [keyboard] <keyboard> TJ FIELD kb=fr-azerty\n")
    }

    // MARK: - One block per word

    func testAWordIsItsTapsThenItsDecision() {
        let journal = recording()
        type("tres", on: journal, from: 10)
        journal.tap("space", dx: 0, dy: 0.1, time: 10.8, keyboard: "fr-azerty")
        // The bar's partial-word checks, off the main thread, between the taps.
        for partial in ["tr", "tre", "tres"] {
            XCTAssertTrue(journal.absorb("TRIE-CANDIDATES word=\"\(partial)\" kept ranked=[]", onMainThread: false))
        }
        journal.beginWord(typed: "tres", previous: "je", committedBy: " ",
                          bar: TypingJournalBar(mode: "corrections", words: ["tres", "très", "trop"]))
        XCTAssertTrue(journal.absorb("TRIE-CANDIDATES word=\"tres\" winner=\"très\" ranked=[\"très\"(cost=1.20 freq=230 ctx=12)]"))
        XCTAssertTrue(journal.absorb("AUTOCORRECT branch=accent orig=\"tres\" corr=\"très\" prev=\"je\""))
        journal.endWord(final: "très", autocorrectRan: true)

        XCTAssertEqual(written(journal), [
            "TJ FIELD kb=fr-azerty",
            "TJ TAP k=t dx=+0.1000 dy=-0.2000 dt=- kb=fr-azerty",
            "TJ TAP k=r dx=+0.1000 dy=-0.2000 dt=150 kb=fr-azerty",
            "TJ TAP k=e dx=+0.1000 dy=-0.2000 dt=150 kb=fr-azerty",
            "TJ TAP k=s dx=+0.1000 dy=-0.2000 dt=150 kb=fr-azerty",
            "TJ TAP k=space dx=+0.0000 dy=+0.1000 dt=350 kb=fr-azerty",
            "TJ WORD #1 typed=\"tres\" prev=\"je\" final=\"très\" outcome=autocorrected by=space branch=accent "
                + "bar=corrections[\"tres\",\"très\",\"trop\"] previews=3",
            "TJ WHY #1 TRIE-CANDIDATES word=\"tres\" winner=\"très\" ranked=[\"très\"(cost=1.20 freq=230 ctx=12)]",
            "TJ WHY #1 AUTOCORRECT branch=accent orig=\"tres\" corr=\"très\" prev=\"je\"",
        ])
    }

    func testOtherDebugLinesKeepTheirPlaceAmongTheTaps() {
        let journal = recording()
        type("a", on: journal)
        XCTAssertTrue(journal.absorb("MIRROR-SUSPECT surplus=+1 before=3 after=4", onMainThread: false))
        type("b", on: journal, from: 1)
        XCTAssertEqual(Array(written(journal).dropFirst()), [
            "TJ TAP k=a dx=+0.1000 dy=-0.2000 dt=- kb=fr-azerty",
            "MIRROR-SUSPECT surplus=+1 before=3 after=4",
            "TJ TAP k=b dx=+0.1000 dy=-0.2000 dt=1000 kb=fr-azerty",
        ])
    }

    func testALongSessionIsWrittenInOrder() {
        let journal = recording()
        let keys = (0..<150).map { String(UnicodeScalar(UInt8(97 + $0 % 26))) }
        for (i, key) in keys.enumerated() {
            journal.tap(key, dx: 0, dy: 0, time: Double(i), keyboard: "fr-azerty")
            if i == 70 { journal.flush() }
        }
        let taps = written(journal).filter { $0.hasPrefix("TJ TAP") }
        XCTAssertEqual(taps.map { $0.components(separatedBy: " ")[2] }, keys.map { "k=\($0)" },
                       "batches sent by size and by flush land in tap order")
    }

    func testOutcomes() {
        func outcome(typed: String = "helo", final: String = "helo", whys: [String] = [], ran: Bool = true,
                     bar: String = "completions", offered: Bool = false) -> String {
            collected = Collected()
            let journal = recording()
            journal.beginWord(typed: typed, previous: nil, committedBy: " ",
                              bar: TypingJournalBar(mode: bar, words: []))
            for why in whys { _ = journal.absorb(why) }
            journal.endWord(final: final, autocorrectRan: ran, offered: offered)
            return written(journal).first { $0.hasPrefix("TJ WORD") }?
                .components(separatedBy: " ").first { $0.hasPrefix("outcome=") } ?? "none"
        }
        XCTAssertEqual(outcome(final: "hello"), "outcome=autocorrected")
        XCTAssertEqual(outcome(), "outcome=kept")
        XCTAssertEqual(outcome(offered: true), "outcome=offered")
        // The commit's decision says what was offered, not the bar, which can still show
        // the previous keystroke's row when the space comes fast (#993).
        XCTAssertEqual(outcome(bar: "candidates"), "outcome=kept")
        XCTAssertEqual(outcome(whys: ["AUTOCORRECT-SKIP word=\"reserve\" reason=ambiguous-accent"], offered: true),
                       "outcome=offered", "two accented spellings offered (#994)")
        XCTAssertEqual(outcome(final: "arrive", offered: false), "outcome=autocorrected",
                       "a close reading picked (#997)")
        XCTAssertEqual(outcome(ran: false), "outcome=off")
        XCTAssertEqual(outcome(whys: ["AUTOCORRECT-SKIP word=\"helo\" reason=refused-here"]), "outcome=refused-here")
        XCTAssertEqual(outcome(whys: ["AUTOCORRECT-ABORT word=\"helo\" reason=boundary ctx=\"x\""]), "outcome=aborted")
    }

    func testEveryBranchOfTheDecisionIsKept() {
        let journal = recording()
        journal.beginWord(typed: "ill", previous: "tomorrow", committedBy: " ", bar: nil)
        _ = journal.absorb("AUTOCORRECT branch=contextual-contraction orig=\"ill\" corr=\"I'll\" prev=\"tomorrow\"")
        _ = journal.absorb("AUTOCORRECT branch=trie orig=\"ill\" corr=\"I'll\" prev=\"tomorrow\"")
        journal.endWord(final: "I'll", autocorrectRan: true)
        XCTAssertTrue(written(journal).contains { $0.contains(" branch=contextual-contraction,trie ") })
    }

    // MARK: - Reactions

    func testUndoPointsAtTheCorrectionItUndoes() {
        let journal = recording()
        journal.beginWord(typed: "tres", previous: nil, committedBy: " ", bar: nil)
        journal.endWord(final: "très", autocorrectRan: true)
        journal.beginWord(typed: "bien", previous: "très", committedBy: " ", bar: nil)
        journal.endWord(final: "bien", autocorrectRan: true)
        XCTAssertTrue(journal.absorb("UNDO orig=\"tres\" rejected=\"très\""))
        XCTAssertTrue(journal.absorb("REFUSED corrected=\"très\" by=undo"))
        XCTAssertTrue(journal.absorb("REFUSED corrected=\"très\" by=backspace"))
        XCTAssertEqual(written(journal).filter { $0.hasPrefix("TJ REACT") },
                       ["TJ REACT #1 undo by=chip", "TJ REACT #1 undo by=backspace"])
    }

    func testALearnedWordPointsAtItsCommit() {
        let journal = recording()
        journal.beginWord(typed: "Dictus", previous: nil, committedBy: " ", bar: nil)
        journal.endWord(final: "Dictus", autocorrectRan: true)
        XCTAssertTrue(journal.absorb("USERDICT-LEARN word=\"dictus\" count=2 learnedCount=1"))
        XCTAssertEqual(Array(written(journal).suffix(2)), [
            "TJ REACT #1 learned word=\"dictus\"",
            "USERDICT-LEARN word=\"dictus\" count=2 learnedCount=1",
        ])
    }

    func testABackspaceIntoTheCommittedWordIsAReaction() {
        let journal = recording()
        journal.beginWord(typed: "helo", previous: nil, committedBy: " ", bar: nil)
        journal.endWord(final: "hello", autocorrectRan: true)
        type("x", on: journal, from: 5)
        // x, then the space, then a letter of "hello".
        for i in 0..<3 { journal.tap("backspace", dx: 0, dy: 0, time: 6 + Double(i) * 0.1, keyboard: "fr-azerty") }
        XCTAssertEqual(written(journal).filter { $0.hasPrefix("TJ REACT") }, ["TJ REACT #1 deleted taps=4"])
    }

    func testABackspaceLongAfterTheCommitIsNotAReaction() {
        let journal = recording()
        journal.beginWord(typed: "helo", previous: nil, committedBy: ",", bar: nil)
        journal.endWord(final: "hello", autocorrectRan: true)
        type("abcdefgh", on: journal, from: 5)
        for _ in 0..<10 { journal.repeatDelete() }
        XCTAssertEqual(written(journal).filter { $0.hasPrefix("TJ REACT") }, [])
    }

    func testABarTapIsACommitWithTheBarItTookItsWordFrom() {
        let journal = recording()
        let bar = TypingJournalBar(mode: "candidates", words: ["helo", "hello", "help"])
        journal.barTapped(slot: 1, bar: bar, typed: "helo", commits: true)
        journal.barTapped(slot: 0, bar: TypingJournalBar(mode: "undoAvailable", words: ["helo"]), typed: "", commits: false)
        XCTAssertEqual(Array(written(journal).dropFirst()), [
            "TJ BARTAP #1 slot=1 word=\"hello\" bar=candidates[\"helo\",\"hello\",\"help\"]",
            "TJ BARTAP slot=0 word=\"helo\" bar=undoAvailable[\"helo\"]",
        ])
    }

    func testANewFieldStartsANewSentence() {
        let journal = recording()
        journal.observeField(isSecureEntry: false, content: nil, document: "doc", keyboard: "fr-azerty")
        journal.observeField(isSecureEntry: false, content: nil, document: "other", keyboard: "fr-azerty")
        journal.observeField(isSecureEntry: false, content: nil, document: "other", keyboard: "en-qwerty")
        XCTAssertEqual(written(journal), ["TJ FIELD kb=fr-azerty", "TJ FIELD kb=fr-azerty", "TJ FIELD kb=en-qwerty"])
    }

    // MARK: - The log file

    func testJournalLinesAgeOutWithTheRestOfTheLog() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tj_prune_\(UUID().uuidString).log")
        defer { try? FileManager.default.removeItem(at: url) }
        let old = TypingJournalEntry(date: Date(timeIntervalSinceNow: -8 * 24 * 3600), event: .field(keyboard: "fr-azerty"))
        let new = TypingJournalEntry(date: Date(), event: .field(keyboard: "en-qwerty"))
        try TypingJournal.lines(for: [old, new], source: "keyboard").write(to: url, atomically: true, encoding: .utf8)

        PersistentLog.pruneOldEntries(url: url, cutoffDate: Date().addingTimeInterval(-PersistentLog.retentionPeriod))

        let kept = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(kept.contains("fr-azerty"), "older than 7 days")
        XCTAssertTrue(kept.contains("en-qwerty"))
    }

    func testClearingTheJournalKeepsTheDiagnostics() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tj_clear_\(UUID().uuidString).log")
        PersistentLog.fileURLOverrideForTesting = url
        defer {
            PersistentLog.fileURLOverrideForTesting = nil
            try? FileManager.default.removeItem(at: url)
        }
        let diagnostic = "[2026-11-20T10:00:00Z] INFO    [keyboard] keyboardDidAppear instance=1"
        let lines = [
            diagnostic,
            "[2026-11-20T10:00:01Z] DEBUG   [keyboard] <keyboard> TJ TAP k=a dx=+0.1000 dy=+0.0000 dt=- kb=fr-azerty",
            "[2026-11-20T10:00:02Z] DEBUG   [keyboard] <keyboard> AUTOCORRECT branch=trie orig=\"a\" corr=\"à\" prev=nil",
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        TypingJournal.clear()

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), diagnostic + "\n")
    }
}
