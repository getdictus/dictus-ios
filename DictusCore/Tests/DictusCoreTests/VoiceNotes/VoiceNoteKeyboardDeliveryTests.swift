// DictusCore/Tests/DictusCoreTests/VoiceNotes/VoiceNoteKeyboardDeliveryTests.swift
// The keyboard delivery of shared voice note transcripts, and when the reader opens (#637).
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

    /// Insert and Copy hide the note from the keyboard at once, before the app has
    /// run: the receipt is what `pending` filters on.
    func testAnAcknowledgedNoteLeavesThePendingList() throws {
        let kept = delivery(sharedSecondsAgo: 100)
        let inserted = delivery(sharedSecondsAgo: 50)
        try store.publish(kept)
        try store.publish(inserted)
        XCTAssertTrue(store.acknowledge(inserted.id, action: .inserted, at: now))
        XCTAssertEqual(store.pending(at: now), [kept])
        // The delivery itself is the app's to delete; the keyboard only dropped a receipt.
        XCTAssertEqual(store.allDeliveries().count, 2)
    }

    /// A copy then an insert of the same note leave one receipt, the latest.
    func testASecondAcknowledgementReplacesTheFirst() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        store.acknowledge(note.id, action: .copied, at: now)
        store.acknowledge(note.id, action: .inserted, at: now.addingTimeInterval(5))
        XCTAssertEqual(store.acknowledgements(), [
            VoiceNoteKeyboardAcknowledgement(id: note.id, action: .inserted, at: now.addingTimeInterval(5))
        ])
    }

    /// The app reconciles a receipt by withdrawing the note: delivery, receipt and
    /// presented marker all go, and a second withdrawal is harmless.
    func testWithdrawRemovesEverythingAndIsIdempotent() throws {
        let note = delivery(sharedSecondsAgo: 50)
        try store.publish(note)
        store.acknowledge(note.id, action: .copied, at: now)
        store.markPresented([note.id])
        store.withdraw(note.id)
        store.withdraw(note.id)
        XCTAssertEqual(store.allDeliveries(), [])
        XCTAssertEqual(store.acknowledgements(), [])
        XCTAssertEqual(store.presentedIDs(), [])
    }

    // MARK: - 24 h expiry (#637 decision 5)

    func testTheLifetimeIsTwentyFourHours() {
        XCTAssertEqual(VoiceNoteKeyboardDelivery.lifetime, 86_400)
    }

    /// Measured from the transcription. One second inside the day it is offered; at
    /// the day it is not, History on or off.
    func testANoteExpiresTwentyFourHoursAfterItsTranscription() throws {
        let fresh = delivery(sharedSecondsAgo: 86_500, transcribedSecondsAgo: 86_399)
        let expired = delivery(sharedSecondsAgo: 86_500, transcribedSecondsAgo: 86_400)
        try store.publish(fresh)
        try store.publish(expired)
        XCTAssertEqual(store.pending(at: now), [fresh])
    }

    /// The keyboard filters on read; the app deletes the file when it next runs.
    func testPruneExpiredDeletesOnlyExpiredDeliveries() throws {
        let fresh = delivery(sharedSecondsAgo: 60)
        let expired = delivery(sharedSecondsAgo: 90_000, transcribedSecondsAgo: 90_000)
        try store.publish(fresh)
        try store.publish(expired)
        store.markPresented([expired.id])
        XCTAssertEqual(store.pruneExpired(now: now), [expired.id])
        XCTAssertEqual(store.allDeliveries(), [fresh])
        XCTAssertEqual(store.presentedIDs(), [])
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

    /// Once per note: a note the reader already showed is the chip's.
    func testANoteAlreadyShownIsOnlyReachableFromTheChip() {
        let note = delivery(sharedSecondsAgo: 10)
        XCTAssertEqual(decide(pending: [note], presented: [note.id]), .chipOnly)
    }

    /// A new note among shown ones is reason enough to open.
    func testANewNoteAmongShownOnesOpensTheReader() {
        let shown = delivery(sharedSecondsAgo: 100)
        let fresh = delivery(sharedSecondsAgo: 10)
        XCTAssertEqual(decide(pending: [shown, fresh], presented: [shown.id]), .openReader)
    }

    func testNothingWaitingIsChipOnly() {
        XCTAssertEqual(decide(pending: []), .chipOnly)
    }

    /// Decision 3's Debug switch: the same build, chip only.
    func testTheDebugSwitchTurnsAutoOpenOff() {
        XCTAssertEqual(decide(pending: [delivery(sharedSecondsAgo: 10)], autoOpen: false), .chipOnly)
    }

    /// Dictation stays first: nothing opens over a dictation that owns the area.
    func testNothingOpensOverADictation() {
        XCTAssertEqual(decide(pending: [delivery(sharedSecondsAgo: 10)], dictation: true), .chipOnly)
    }

    /// Nor over a picker the user left open and the keyboard restores.
    func testNothingOpensOverARestoredPicker() {
        XCTAssertEqual(decide(pending: [delivery(sharedSecondsAgo: 10)], mode: .emoji), .chipOnly)
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
        XCTAssertEqual(decide(pending: rebuilt.pending(at: now), presented: rebuilt.presentedIDs()), .chipOnly)
    }
}
