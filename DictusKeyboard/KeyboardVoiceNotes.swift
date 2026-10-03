// DictusKeyboard/KeyboardVoiceNotes.swift
// Shared voice note transcripts waiting in the keyboard: the ☰ ring, the hint and the reader (issues #637, #639).
import Foundation
import Combine
import DictusCore

/// What the keyboard knows about voice notes shared to Dictus: which transcripts are
/// waiting for it, which of them it has never shown, whether the long press on ☰
/// still needs teaching, and the reader while it is open.
///
/// ### Why a separate object rather than properties on `KeyboardState`
///
/// `KeyboardSmartModeState`'s argument, unchanged: `KeyboardState` sits at SwiftLint's
/// budget, and nothing here belongs to the dictation state machine. The reader is
/// opened, drawn and closed by the keyboard's own UI; the only thing it needs from
/// `KeyboardState` is the area mode, which it moves through `presentAreaMode` like the
/// pickers do and follows through `areaModePublisher` like the view controller does.
///
/// ### Where the truth is
///
/// On disk, in `VoiceNoteKeyboardDeliveryStore`, reread every time this asks. The
/// Darwin signal is only a hint that a keyboard on screen should look now: iOS
/// suspends this process freely, and a note that lands while it is suspended is found
/// on the next appearance instead (#637, "persist first, signal second"). Nothing in
/// here survives the process, and nothing has to — the receipts, the presented
/// markers and the last uses are files too.
///
/// ### How long a note stays (#639)
///
/// 15 minutes after its last use: shown in the reader, inserted, quoted. Each use is
/// written to disk here, and the store filters on it; `Insert` no longer removes the
/// note, so a long one can be quoted in several passes (#640).
///
/// ### What it never does
///
/// Insert on its own, or write History or the queue. The user taps `Insert`; the
/// keyboard then drops a receipt, and DictusApp turns it into "read" (decision 6).
@MainActor
final class KeyboardVoiceNoteState: ObservableObject {

    static let shared = KeyboardVoiceNoteState()

    /// The reader's contents while it is open.
    ///
    /// A snapshot taken when it opens rather than a live view of `waiting`, so a note
    /// that lands while it is open is appended as a last page instead of reshuffling
    /// the pages under the user's eyes. Empty when the long press found nothing to
    /// show: the reader then draws its empty state, the one place the keyboard
    /// explains the feature (#639).
    struct Reader: Equatable {
        var pages: [VoiceNoteKeyboardDelivery]
    }

    /// Transcripts the keyboard may offer, oldest share first.
    @Published private(set) var waiting: [VoiceNoteKeyboardDelivery] = []

    /// The waiting notes the reader has already shown. The ☰ wears its ring while
    /// any waiting note is not in here (#639).
    @Published private(set) var presentedIDs: Set<UUID> = []

    /// Whether the user has ever long-pressed ☰ (#639). Cached: the flag only ever
    /// moves once, and from this process.
    @Published private(set) var longPressUsed = VoiceNoteDiscovery.hasUsedLongPress

    /// The reader, or nil when it is closed.
    @Published private(set) var reader: Reader?

    /// At least one waiting note has never been shown in the keyboard: the ☰ capsule
    /// gets its accent ring (#639). No count — the reader's dots say how many.
    var hasUnshownNotes: Bool {
        waiting.contains { !presentedIDs.contains($0.id) }
    }

    /// Whether the toolbar still teaches the long press on ☰ (#639).
    var offersLongPressHint: Bool {
        VoiceNoteDiscovery.offersHint(notesWaiting: waiting.count, longPressUsed: longPressUsed)
    }

    /// Ids that have already buzzed, or were already waiting when the keyboard
    /// appeared. In memory on purpose: "never repeated" is about one arrival, and the
    /// signal that causes the haptic is delivered once.
    private var announced: Set<UUID> = []

    /// Ids inserted since the reader last opened. `Insert` closes the reader, so a
    /// second tap normally finds nothing to act on; this is the guarantee that one
    /// opening can never write the same transcript twice, whatever order the taps and
    /// the close are delivered in. Reset on every opening: since #639 a note can be
    /// inserted again from a later one.
    private var insertedThisOpening: Set<UUID> = []

    /// Rereads the directory when the earliest waiting note leaves its window, so the
    /// ring and the hint do not outlive the note while the keyboard sits on screen.
    /// A suspended keyboard misses it and rereads on its next appearance instead.
    private var expiryRefresh: DispatchWorkItem?

    private var lastMode: KeyboardAreaMode = .keys
    private var modeCancellable: AnyCancellable?

    private let instanceID = String(UUID().uuidString.prefix(8))

    /// Nil without Full Access, so nothing is offered: no ring, no hint, no reader.
    ///
    /// WHY explicit rather than left to the container: on a device the App Group is
    /// unreachable without Full Access and this would be nil anyway, but the
    /// simulator resolves the container regardless (`docs/agents/simulator.md`), and
    /// it opened the reader under a toolbar saying "Full access required" (measured
    /// 2026-10-03). The toolbar's own branch already hides the ☰ there; this keeps
    /// the reader to the same rule on every runtime. Recomputed each time: toggling
    /// Full Access rebuilds the extension anyway.
    private var store: VoiceNoteKeyboardDeliveryStore? {
        guard KeyboardState.shared.controller?.hasFullAccess == true else { return nil }
        return .appGroup
    }

    private init() {
        DarwinNotificationCenter.addObserver(for: DarwinNotificationName.voiceNoteResultReady) {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { KeyboardVoiceNoteState.shared.resultReadySignalled() }
            }
        }
        // `areaModePublisher` emits on the main thread, synchronously from the
        // assignment (see `KeyboardState.areaMode`).
        modeCancellable = KeyboardState.shared.areaModePublisher.sink { [weak self] mode in
            MainActor.assumeIsolated { self?.areaModeChanged(to: mode) }
        }
    }

    // MARK: - Appearance

    /// Called by the controller iOS just brought on screen, after it registered.
    ///
    /// A reader left open by an earlier appearance is closed first — switching
    /// keyboards or leaving the field closes it, and the notes stay waiting. Then, for
    /// a note this keyboard has never shown, the reader opens by itself, once
    /// (decisions 2 and 3). Never mid-dictation, never over a picker.
    func keyboardWillAppear(controllerID: String) {
        if KeyboardState.shared.areaMode == .voiceNoteResult {
            close(reason: "reappeared")
        }
        reload(reason: "appearance")
        // Waiting when the keyboard appears is not an arrival under the user's thumb:
        // nothing to buzz for.
        announced.formUnion(waiting.map(\.id))
        guard !waiting.isEmpty else { return }

        let presented = presentedIDs
        let autoOpen = VoiceNoteKeyboardPresentation.autoOpenEnabled
        let decision = VoiceNoteKeyboardPresentation.onAppearance(
            pending: waiting,
            presentedIDs: presented,
            autoOpenEnabled: autoOpen,
            dictationOwnsArea: KeyboardState.shared.dictationStatus.ownsKeyboardArea,
            currentMode: KeyboardState.shared.areaMode
        )
        log("appearanceDecision", "controllerID=\(controllerID) waiting=\(waiting.count) unshown=\(waiting.filter { !presented.contains($0.id) }.count) autoOpen=\(autoOpen) mode=\(KeyboardState.shared.areaMode.rawValue) decision=\(decision)")
        if decision == .openReader {
            open(source: "appearance")
        }
    }

    // MARK: - Opening and closing

    /// A long press on ☰ was recognised (#639): open the reader, whatever is waiting.
    ///
    /// Called at the **recognition**, not the release. The reader replaces the toolbar
    /// in `KeyboardRootView.body`, so the view carrying the recogniser is destroyed by
    /// this very call and nothing after it is delivered (the #79 identity trap). The
    /// first long press ever retires the hint, whether the reader could open or not:
    /// the user has found the gesture. Returns whether the reader is on screen.
    @discardableResult
    func openFromLongPress() -> Bool {
        VoiceNoteDiscovery.noteLongPressUsed()
        if !longPressUsed { longPressUsed = true }
        return open(source: "longPress")
    }

    /// Open the reader on every waiting note, or on its empty state when there is none
    /// (#639). From a long press on ☰, or from an appearance.
    @discardableResult
    func open(source: String) -> Bool {
        guard reader == nil else { return KeyboardState.shared.areaMode == .voiceNoteResult }
        reload(reason: "open")
        insertedThisOpening = []
        // Before the mode, so the first body evaluated in `.voiceNoteResult` has pages.
        reader = Reader(pages: waiting)
        KeyboardState.shared.presentAreaMode(.voiceNoteResult)
        guard KeyboardState.shared.areaMode == .voiceNoteResult else {
            // Refused: a dictation owns the area. Nothing was shown.
            reader = nil
            log("openRefused", "source=\(source) status=\(KeyboardState.shared.dictationStatus.rawValue)")
            return false
        }
        // Shown, so it never opens on its own for these notes again (decision 2), and
        // the ☰ loses its ring. Viewing is not reading: nothing is acknowledged here
        // (decision 6). The page on screen is a use, and restarts its 15 minutes.
        markPresented(waiting.map(\.id))
        if let first = waiting.first { pageShown(first.id) }
        log("readerOpened", "source=\(source) pages=\(waiting.count) ids=\(Self.short(waiting))")
        return true
    }

    /// `✕`, and every other way out. The notes stay waiting (decision 4).
    ///
    /// The mode change is what clears `reader`, in `areaModeChanged`: one path, so a
    /// dictation taking the area and a `✕` leave the same state behind.
    func close(reason: String) {
        guard KeyboardState.shared.areaMode == .voiceNoteResult else { return }
        log("readerClosed", "reason=\(reason) waiting=\(waiting.count)")
        KeyboardState.shared.presentAreaMode(.keys)
    }

    /// The reader put this page on screen — on opening, or after a swipe. A use
    /// (#639): its 15 minutes start again.
    func pageShown(_ id: UUID) {
        guard reader?.pages.contains(where: { $0.id == id }) == true else { return }
        store?.noteUsed(id)
    }

    // MARK: - Actions

    /// `Insert`: hand the visible page's transcript to `write`, once per opening, then
    /// give the keys back.
    ///
    /// `write` is the caller's, because the caller is the view that knows which
    /// controller it belongs to and holds the bridge the insertion has to be reported
    /// to (#548). It returns whether it wrote.
    ///
    /// The note **stays** (#639): the receipt marks it read in DictusApp and the use
    /// restarts its 15 minutes, so a long press on ☰ finds it again for another
    /// passage. The reader closes rather than staying on the page it just inserted —
    /// the user goes back to writing, and a second tap on the same `Insert` would
    /// only be a duplicate.
    ///
    /// A note whose window ran out while the reader sat open is refused: the reader
    /// shows a snapshot, and the disk is what says whether the text may still be
    /// offered.
    func insert(_ id: UUID, write: (String) -> Bool) {
        guard let reader, let page = reader.pages.first(where: { $0.id == id }),
              !insertedThisOpening.contains(id) else {
            log("insertIgnored", "id=\(id.uuidString.prefix(8)) reason=insertedOrClosed")
            return
        }
        reload(reason: "insert")
        guard waiting.contains(where: { $0.id == id }) else {
            log("insertIgnored", "id=\(id.uuidString.prefix(8)) reason=expired")
            close(reason: "expired")
            return
        }
        guard write(page.transcript) else {
            log("insertIgnored", "id=\(id.uuidString.prefix(8)) reason=notWritten")
            return
        }
        insertedThisOpening.insert(id)
        // After the text, deliberately: a process killed between the two leaves the
        // note unread in DictusApp, which is the safe failure.
        let receipt = store?.acknowledge(id, action: .inserted) ?? false
        let used = store?.noteUsed(id) ?? false
        HapticFeedback.textInserted()
        log("inserted", "id=\(id.uuidString.prefix(8)) chars=\(page.transcript.count) receipt=\(receipt) used=\(used)")
        reload(reason: "inserted")
        close(reason: "inserted")
    }

    /// `Open in Dictus`: the app's result screen on this note.
    ///
    /// No receipt: the app marks the note read when it actually shows it. The note
    /// stays in the keyboard for the rest of its window either way (#639). The reader
    /// closes first for the panel's reason (#241): the trip out of the keyboard ends
    /// the task.
    func openInDictus(_ id: UUID) {
        log("openInDictus", "id=\(id.uuidString.prefix(8))")
        close(reason: "openInDictus")
        KeyboardState.shared.openDictusApp(intent: .voiceNote, voiceNoteID: id)
    }

    // MARK: - Disk and signal

    /// Reread the delivery directory: what is waiting, what was already shown, and
    /// when the next one leaves.
    private func reload(reason: String) {
        let pending = store?.pending() ?? []
        let presented = store?.presentedIDs() ?? []
        if presented != presentedIDs { presentedIDs = presented }
        scheduleExpiryRefresh(for: pending)
        guard pending.map(\.id) != waiting.map(\.id) else { return }
        log("waitingChanged", "reason=\(reason) from=\(waiting.count) to=\(pending.count) ids=\(Self.short(pending))")
        waiting = pending
    }

    /// Write the presented markers and mirror them in memory, so the ring goes at once.
    private func markPresented(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        store?.markPresented(ids)
        presentedIDs.formUnion(ids)
    }

    /// One pending work item, at the earliest expiry among `pending`. Replaced on
    /// every reload, so a use that pushed the expiry back moves it too.
    private func scheduleExpiryRefresh(for pending: [VoiceNoteKeyboardDelivery]) {
        expiryRefresh?.cancel()
        expiryRefresh = nil
        guard let next = store?.nextExpiry(of: pending) else { return }
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.reload(reason: "expiry") }
        }
        expiryRefresh = item
        // A second past the boundary, so the reread is on the far side of it.
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, next.timeIntervalSinceNow) + 1, execute: item)
    }

    /// DictusApp wrote a delivery. A keyboard on screen rings the ☰ — never takes the
    /// surface over (decision 1) — and says so once with one light haptic.
    ///
    /// An open reader takes the new note as a last page rather than leaving it behind
    /// the ring: appended, so the page under the user's eyes does not move. An empty
    /// reader shows it in place of the empty state.
    private func resultReadySignalled() {
        reload(reason: "signal")
        let fresh = waiting.filter { !announced.contains($0.id) }
        announced.formUnion(fresh.map(\.id))
        guard !fresh.isEmpty else { return }
        if var reader {
            let wasEmpty = reader.pages.isEmpty
            let shown = Set(reader.pages.map(\.id))
            reader.pages.append(contentsOf: fresh.filter { !shown.contains($0.id) })
            self.reader = reader
            markPresented(fresh.map(\.id))
            // It replaced the empty state, so it is the page on screen: a use.
            if wasEmpty, let first = reader.pages.first { pageShown(first.id) }
        }
        let visible = KeyboardState.shared.isKeyboardVisible
        log("arrived", "count=\(fresh.count) ids=\(Self.short(fresh)) visible=\(visible) readerOpen=\(reader != nil)")
        guard visible else { return }
        HapticFeedback.voiceNoteArrived()
    }

    /// Follow the area mode, whoever moved it.
    ///
    /// Leaving `.voiceNoteResult` clears the reader — `✕`, `Insert`, and a dictation
    /// taking the area all arrive here. Leaving `.recording` rereads the directory: a
    /// note may have landed during the dictation, and the ring comes back with the
    /// keys. The reader does not reopen on its own then; the user is looking at the
    /// keyboard (decision 1).
    private func areaModeChanged(to mode: KeyboardAreaMode) {
        if mode != .voiceNoteResult, reader != nil {
            reader = nil
        }
        if lastMode == .recording, mode != .recording {
            reload(reason: "dictationEnded")
            announced.formUnion(waiting.map(\.id))
        }
        lastMode = mode
    }

    // MARK: - Logging

    /// Ids, counts and states. Never a transcript (#637).
    private func log(_ action: String, _ details: String) {
        PersistentLog.log(.diagnosticProbe(
            component: "KeyboardVoiceNotes", instanceID: instanceID, action: action, details: details
        ))
    }

    private static func short(_ deliveries: [VoiceNoteKeyboardDelivery]) -> String {
        deliveries.map { String($0.id.uuidString.prefix(8)) }.joined(separator: ",")
    }
}
