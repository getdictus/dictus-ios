// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteKeyboardDeliveryTests.swift
// The keyboard delivery of shared voice note transcripts, how long it stays, and when the reader opens (#637, #639).
import XCTest
@testable import DictusCore

final class VoiceNoteKeyboardDeliveryTests: XCTestCase {

    private var root: URL!
    private var store: VoiceNoteKeyboardDeliveryStore!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceNoteKeyboardDeliveryTests-\(UUID().uuidString)", isDirectory: true)
        store = VoiceNoteKeyboardDeliveryStore(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func delivery(sharedSecondsAgo: TimeInterval, transcribedSecondsAgo: TimeInterval = 0,
                          id: UUID = UUID(), text: String = "Salut") -> VoiceNoteKeyboardDelivery {
        VoiceNoteKeyboardDelivery(
            id: id, transcript: text,
            sharedAt: now.addingTimeInterval(-sharedSecondsAgo),
            transcribedAt: now.addingTimeInterval(-transcribedSecondsAgo),
            language: "fr", durationSeconds: 102
        )
    }

    // MARK: - Write and read

    func testAPublishedDeliveryIsReadBackWhole() throws {
        let note = delivery(sharedSecondsAgo: 60, text: "Salut, pour samedi c'est bon.\nÀ plus 👋")
        try store.publish(note)
        XCTAssertEqual(store.pending(at: now), [note])
    }

    func testNothingPublishedReadsEmptyRatherThanFailing() {
        XCTAssertEqual(store.pending(at: now), [])
        XCTAssertEqual(store.acknowledgements(), [])
        XCTAssertEqual(store.presentedIDs(), [])
        XCTAssertEqual(store.lastUsedDates(), [:])
    }

    /// Publishing the same note twice (a retry, a relaunch) leaves one delivery.
    func testRepublishingANoteReplacesIt() throws {
        let id = UUID()
        try store.publish(delivery(sharedSecondsAgo: 60, id: id, text: "first"))
        try store.publish(delivery(sharedSecondsAgo: 60, id: id, text: "second"))
        XCTAssertEqual(store.pending(at: now).map(\.transcript), ["second"])
    }

    /// A file the keyboard cannot decode is skipped, not fatal for the others.
    func testAnUnreadableFileIsSkipped() throws {
        let good = delivery(sharedSecondsAgo: 10)
        try store.publish(good)
        try Data("not json".utf8).write(to: store.deliveriesDirectory.appendingPathComponent("\(UUID().uuidString).json"))
        XCTAssertEqual(store.pending(at: now), [good])
    }

    // MARK: - Order

    /// Oldest share first, whatever order the files were written in: the reader's
    /// pages are in the order the user shared the notes.
    func testPendingIsOldestShareFirst() throws {
        let newest = delivery(sharedSecondsAgo: 10)
        let oldest = delivery(sharedSecondsAgo: 300)
        let middle = delivery(sharedSecondsAgo: 120)
        for note in [newest, oldest, middle] { try store.publish(note) }
        XCTAssertEqual(store.pending(at: now).map(\.id), [oldest.id, middle.id, newest.id])
    }

    /// Several notes shared in the same instant fall back to the transcription order,
    /// which is the queue's own.
    func testASameInstantShareFallsBackToTranscriptionOrder() throws {
        let second = delivery(sharedSecondsAgo: 60, transcribedSecondsAgo: 5)
        let first = delivery(sharedSecondsAgo: 60, transcribedSecondsAgo: 30)
        try store.publish(second)
        try store.publish(first)
        XCTAssertEqual(store.pending(at: now).map(\.id), [first.id, second.id])
    }

    // MARK: - Acknowledgement

    /// Since #639 an insertion no longer takes the note out of the keyboard: the user
    /// can come back and quote another passage. The receipt is only what DictusApp
    /// turns into "read".
    func testAnInsertedNoteStaysPending() throws {
        let kept = delivery(sharedSecondsAgo: 100)
        let inserted = delivery(sharedSecondsAgo: 50)
        try store.publish(kept)
        try store.publish(inserted)
        XCTAssertTrue(store.acknowledge(inserted.id, action: .inserted, at: now))
        XCTAssertEqual(store.pending(at: now), [kept, inserted])
        XCTAssertEqual(store.acknowledgements().map(\.id), [inserted.id])
    }

    /// #639 decision A: a note shown in the reader leaves a receipt too. Inserting it
    /// afterwards replaces that receipt rather than adding a second, so DictusApp
    /// marks it read once.
    func testShownThenInsertedLeavesOneReceipt() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        XCTAssertTrue(store.acknowledge(note.id, action: .shown, at: now))
        XCTAssertEqual(store.acknowledgements().map(\.action), [.shown])
        store.acknowledge(note.id, action: .inserted, at: now.addingTimeInterval(3))
        XCTAssertEqual(store.acknowledgements(), [
            VoiceNoteKeyboardAcknowledgement(id: note.id, action: .inserted, at: now.addingTimeInterval(3))
        ])
        // A receipt says "read"; it does not take the note out of the keyboard.
        XCTAssertEqual(store.pending(at: now), [note])
    }

    /// A second receipt for the same note leaves one receipt, the latest.
    func testASecondAcknowledgementReplacesTheFirst() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        store.acknowledge(note.id, action: .inserted, at: now)
        store.acknowledge(note.id, action: .inserted, at: now.addingTimeInterval(5))
        XCTAssertEqual(store.acknowledgements(), [
            VoiceNoteKeyboardAcknowledgement(id: note.id, action: .inserted, at: now.addingTimeInterval(5))
        ])
    }

    /// The build that had a `Copy` button (rev cd2d96b4) wrote `copied` receipts. One
    /// left on a device still decodes and still reaches the app; like any receipt
    /// since #639, it no longer hides its note.
    func testAReceiptFromTheBuildWithCopyStillDecodes() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        try FileManager.default.createDirectory(at: store.acknowledgementsDirectory, withIntermediateDirectories: true)
        let legacy = #"{"action":"copied","at":"2026-10-03T13:20:33.120Z","id":"\#(note.id.uuidString)"}"#
        try Data(legacy.utf8).write(to: store.acknowledgementsDirectory.appendingPathComponent("\(note.id.uuidString).json"))
        XCTAssertEqual(store.acknowledgements().map(\.action), [.copied])
        XCTAssertEqual(store.pending(at: now), [note])
    }

    /// The app turns a receipt into "read" and drops the receipt; the delivery stays
    /// in the keyboard (#639: reading in DictusApp no longer removes it).
    func testClearingAReceiptKeepsTheDelivery() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        store.acknowledge(note.id, action: .inserted, at: now)
        store.clearAcknowledgement(note.id)
        store.clearAcknowledgement(note.id)
        XCTAssertEqual(store.acknowledgements(), [])
        XCTAssertEqual(store.pending(at: now), [note])
    }

    /// Deleting the note in DictusApp withdraws it: delivery, receipt, presented
    /// marker and last use all go, and a second withdrawal is harmless.
    func testWithdrawRemovesEverythingAndIsIdempotent() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        store.acknowledge(note.id, action: .inserted, at: now)
        store.markPresented([note.id])
        store.noteUsed(note.id, at: now)
        store.withdraw(note.id)
        store.withdraw(note.id)
        XCTAssertEqual(store.allDeliveries(), [])
        XCTAssertEqual(store.pending(at: now), [])
        XCTAssertEqual(store.acknowledgements(), [])
        XCTAssertEqual(store.presentedIDs(), [])
        XCTAssertEqual(store.lastUsedDates(), [:])
    }

    // MARK: - Deleted from the keyboard (#639)

    /// The reader's Delete takes the note out of the keyboard at once, before the app
    /// has run, without touching the delivery file — that is the app's.
    func testADeletedNoteLeavesThePendingListAtOnce() throws {
        let kept = delivery(sharedSecondsAgo: 100)
        let deleted = delivery(sharedSecondsAgo: 50)
        try store.publish(kept)
        try store.publish(deleted)
        XCTAssertTrue(store.deleteFromKeyboard(deleted.id))
        XCTAssertTrue(store.deleteFromKeyboard(deleted.id), "idempotent")
        XCTAssertEqual(store.pending(at: now), [kept])
        XCTAssertEqual(store.deletedIDs(), [deleted.id])
        XCTAssertEqual(store.allDeliveries().count, 2)
    }

    /// A new store value (a new keyboard process) still hides it.
    func testADeletionSurvivesANewProcess() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        store.deleteFromKeyboard(note.id)
        XCTAssertEqual(VoiceNoteKeyboardDeliveryStore(root: root).pending(at: now), [])
    }

    /// The app cleans up by withdrawing it, which removes the marker with the rest.
    func testWithdrawingADeletedNoteClearsItsMarker() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        store.deleteFromKeyboard(note.id)
        store.withdraw(note.id)
        XCTAssertEqual(store.deletedIDs(), [])
        XCTAssertEqual(store.allDeliveries(), [])
    }

    // MARK: - 15 minutes after the last use (#639)

    func testTheIdleWindowIsFifteenMinutes() {
        XCTAssertEqual(VoiceNoteKeyboardDelivery.idleWindow, 900)
    }

    /// A note never opened: 15 minutes after it was transcribed. One second inside
    /// the window it is offered; at the window it is not.
    func testANeverOpenedNoteExpiresFifteenMinutesAfterItsTranscription() throws {
        let fresh = delivery(sharedSecondsAgo: 1_000, transcribedSecondsAgo: 899)
        let expired = delivery(sharedSecondsAgo: 1_000, transcribedSecondsAgo: 900)
        try store.publish(fresh)
        try store.publish(expired)
        XCTAssertEqual(store.pending(at: now), [fresh])
    }

    /// Opening the reader on a note is a use: its 15 minutes start again from there.
    func testOpeningANoteRestartsItsWindow() throws {
        let note = delivery(sharedSecondsAgo: 1_000, transcribedSecondsAgo: 1_000)
        try store.publish(note)
        let openedAt = now.addingTimeInterval(-600)
        XCTAssertTrue(store.noteUsed(note.id, at: openedAt))
        XCTAssertEqual(store.pending(at: now), [note])
        XCTAssertEqual(store.pending(at: openedAt.addingTimeInterval(899)), [note])
        XCTAssertEqual(store.pending(at: openedAt.addingTimeInterval(900)), [])
    }

    /// Inserting is a use too, and a later one wins: the window slides.
    func testInsertingExtendsTheWindowAgain() throws {
        let note = delivery(sharedSecondsAgo: 2_000, transcribedSecondsAgo: 2_000)
        try store.publish(note)
        let opened = now.addingTimeInterval(-1_400)
        let inserted = now.addingTimeInterval(-800)
        store.noteUsed(note.id, at: opened)
        store.acknowledge(note.id, action: .inserted, at: inserted)
        store.noteUsed(note.id, at: inserted)
        // The open alone would have expired 500 s ago; the insert keeps it 100 s more.
        XCTAssertEqual(store.pending(at: now), [note])
        XCTAssertEqual(store.pending(at: inserted.addingTimeInterval(900)), [])
    }

    /// A quoted passage (#640) is the same kind of use: it extends the window the
    /// same way, through the same call.
    func testQuotingExtendsTheWindow() throws {
        let note = delivery(sharedSecondsAgo: 2_500, transcribedSecondsAgo: 2_500)
        try store.publish(note)
        // Untouched, it would have left 1 600 s ago.
        let quotes = [now.addingTimeInterval(-1_700), now.addingTimeInterval(-900), now.addingTimeInterval(-100)]
        for quote in quotes {
            XCTAssertEqual(store.pending(at: quote), [note], "each quote lands inside the window the previous use opened")
            store.noteUsed(note.id, at: quote)
        }
        XCTAssertEqual(store.lastUsedDates()[note.id], quotes[2])
        XCTAssertEqual(store.pending(at: now), [note])
        XCTAssertEqual(store.pending(at: quotes[2].addingTimeInterval(900)), [])
    }

    /// An older use written after a newer one never moves the clock back.
    func testAnOlderUseNeverShortensTheWindow() throws {
        let note = delivery(sharedSecondsAgo: 2_000, transcribedSecondsAgo: 2_000)
        try store.publish(note)
        store.noteUsed(note.id, at: now.addingTimeInterval(-100))
        store.noteUsed(note.id, at: now.addingTimeInterval(-1_500))
        XCTAssertEqual(store.lastUsedDates()[note.id], now.addingTimeInterval(-100))
    }

    /// Each note keeps its own clock.
    func testUsesAreTrackedPerNote() throws {
        let used = delivery(sharedSecondsAgo: 2_000, transcribedSecondsAgo: 2_000)
        let untouched = delivery(sharedSecondsAgo: 2_000, transcribedSecondsAgo: 2_000)
        try store.publish(used)
        try store.publish(untouched)
        store.noteUsed(used.id, at: now.addingTimeInterval(-60))
        XCTAssertEqual(store.pending(at: now), [used])
    }

    /// The keyboard rereads at the earliest expiry so its ring and hint go with the note.
    func testNextExpiryIsTheEarliestEffectiveOne() throws {
        let early = delivery(sharedSecondsAgo: 600, transcribedSecondsAgo: 600)
        let extended = delivery(sharedSecondsAgo: 800, transcribedSecondsAgo: 800)
        try store.publish(early)
        try store.publish(extended)
        store.noteUsed(extended.id, at: now)
        XCTAssertEqual(store.nextExpiry(of: store.pending(at: now)), now.addingTimeInterval(300))
        XCTAssertNil(store.nextExpiry(of: []))
    }

    /// The keyboard filters on read; the app deletes the file when it next runs,
    /// counting uses like the keyboard does.
    func testPruneExpiredDeletesOnlyExpiredDeliveries() throws {
        let fresh = delivery(sharedSecondsAgo: 60, transcribedSecondsAgo: 60)
        let expired = delivery(sharedSecondsAgo: 2_000, transcribedSecondsAgo: 2_000)
        let keptByAUse = delivery(sharedSecondsAgo: 2_000, transcribedSecondsAgo: 2_000)
        try store.publish(fresh)
        try store.publish(expired)
        try store.publish(keptByAUse)
        store.markPresented([expired.id])
        store.noteUsed(expired.id, at: now.addingTimeInterval(-1_000))
        store.noteUsed(keptByAUse.id, at: now.addingTimeInterval(-300))
        XCTAssertEqual(store.pruneExpired(now: now), [expired.id])
        XCTAssertEqual(Set(store.allDeliveries().map(\.id)), [fresh.id, keptByAUse.id])
        XCTAssertEqual(store.presentedIDs(), [])
        XCTAssertNil(store.lastUsedDates()[expired.id])
    }

    /// Uses survive a new process, like the markers: the keyboard is rebuilt constantly.
    func testUsesAreReadBackByANewStoreValue() throws {
        let note = delivery(sharedSecondsAgo: 2_000, transcribedSecondsAgo: 2_000)
        try store.publish(note)
        store.noteUsed(note.id, at: now.addingTimeInterval(-60))
        XCTAssertEqual(VoiceNoteKeyboardDeliveryStore(root: root).pending(at: now), [note])
    }

    // MARK: - Header labels

    func testTheHeaderLabels() {
        let note = delivery(sharedSecondsAgo: 0)
        XCTAssertEqual(note.durationLabel, "1:42")
        XCTAssertEqual(note.languageBadge, "FR")
        let auto = VoiceNoteKeyboardDelivery(id: UUID(), transcript: "x", sharedAt: now, transcribedAt: now,
                                             language: "auto", durationSeconds: nil)
        XCTAssertNil(auto.languageBadge)
        XCTAssertNil(auto.durationLabel)
    }

    // MARK: - When the reader opens by itself (#637 decisions 1 to 3)

    private func decide(pending: [VoiceNoteKeyboardDelivery], presented: Set<UUID> = [],
                        autoOpen: Bool = true, dictation: Bool = false,
                        mode: KeyboardAreaMode = .keys) -> VoiceNoteKeyboardPresentation.Decision {
        VoiceNoteKeyboardPresentation.onAppearance(
            pending: pending, presentedIDs: presented, autoOpenEnabled: autoOpen,
            dictationOwnsArea: dictation, currentMode: mode
        )
    }

    func testAnAppearanceWithANoteNeverShownOpensTheReader() {
        XCTAssertEqual(decide(pending: [delivery(sharedSecondsAgo: 10)]), .openReader)
    }

    /// Once per note: a note the reader already showed opens from a long press on ☰ only.
    func testANoteAlreadyShownIsOnlyReachableFromTheLongPress() {
        let note = delivery(sharedSecondsAgo: 10)
        XCTAssertEqual(decide(pending: [note], presented: [note.id]), .keysOnly)
    }

    /// A new note among shown ones is reason enough to open.
    func testANewNoteAmongShownOnesOpensTheReader() {
        let shown = delivery(sharedSecondsAgo: 100)
        let fresh = delivery(sharedSecondsAgo: 10)
        XCTAssertEqual(decide(pending: [shown, fresh], presented: [shown.id]), .openReader)
    }

    func testNothingWaitingLeavesTheKeys() {
        XCTAssertEqual(decide(pending: []), .keysOnly)
    }

    /// Decision 3's Debug switch: the same build, long press only.
    func testTheDebugSwitchTurnsAutoOpenOff() {
        XCTAssertEqual(decide(pending: [delivery(sharedSecondsAgo: 10)], autoOpen: false), .keysOnly)
    }

    /// Dictation stays first: nothing opens over a dictation that owns the area.
    func testNothingOpensOverADictation() {
        XCTAssertEqual(decide(pending: [delivery(sharedSecondsAgo: 10)], dictation: true), .keysOnly)
    }

    /// Nor over a picker the user left open and the keyboard restores.
    func testNothingOpensOverARestoredPicker() {
        XCTAssertEqual(decide(pending: [delivery(sharedSecondsAgo: 10)], mode: .emoji), .keysOnly)
    }

    /// Markers survive a new process: the keyboard is rebuilt constantly, and "once"
    /// must not mean "once per process".
    func testPresentedMarkersAreReadBackByANewStoreValue() throws {
        let note = delivery(sharedSecondsAgo: 10)
        try store.publish(note)
        store.markPresented([note.id])
        store.markPresented([note.id])
        let rebuilt = VoiceNoteKeyboardDeliveryStore(root: root)
        XCTAssertEqual(rebuilt.presentedIDs(), [note.id])
        XCTAssertEqual(decide(pending: rebuilt.pending(at: now), presented: rebuilt.presentedIDs()), .keysOnly)
    }
}
