// DictusKeyboard/KeyboardVoiceNotes.swift
// Shared voice note transcripts waiting in the keyboard: the chip's count and the reader (issue #637).
import Foundation
import UIKit
import Combine
import DictusCore

/// What the keyboard knows about voice notes shared to Dictus: which transcripts are
/// waiting for it, and the reader while it is open.
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
/// here survives the process, and nothing has to — the receipts and the presented
/// markers are files too.
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
    /// A snapshot taken when it opens rather than a live view of `waiting`: a copied
    /// note is acknowledged at once and leaves `waiting`, and decision 7 keeps its
    /// page on screen until the reader closes.
    struct Reader: Equatable {
        var pages: [VoiceNoteKeyboardDelivery]
        /// The page that just answered `Copy`, for its brief "Copied" state.
        var copiedID: UUID?
    }

    /// Transcripts the keyboard may offer, oldest share first. Drives the chip.
    @Published private(set) var waiting: [VoiceNoteKeyboardDelivery] = []

    /// The reader, or nil when it is closed.
    @Published private(set) var reader: Reader?

    /// Bumped once per arrival on a visible keyboard, so the chip pulses once.
    @Published private(set) var arrivalPulse = 0

    /// Ids that have already pulsed, or were already waiting when the keyboard
    /// appeared. In memory on purpose: "never repeated" is about one arrival, and the
    /// signal that causes the pulse is delivered once.
    private var announced: Set<UUID> = []

    /// Ids inserted by this process. The receipt on disk is what hides a note from
    /// every later read; this covers a receipt that failed to write, so a second tap
    /// can never insert the same transcript twice.
    private var inserted: Set<UUID> = []

    private var lastMode: KeyboardAreaMode = .keys
    private var modeCancellable: AnyCancellable?
    private var copiedReset: DispatchWorkItem?

    private let instanceID = String(UUID().uuidString.prefix(8))

    /// Recomputed each time: the container is unreachable without Full Access, and
    /// toggling Full Access rebuilds the extension anyway.
    private var store: VoiceNoteKeyboardDeliveryStore? { .appGroup }

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
        // nothing to pulse for.
        announced.formUnion(waiting.map(\.id))
        guard !waiting.isEmpty else { return }

        let presented = store?.presentedIDs() ?? []
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

    /// Open the reader on every waiting note. From the chip, or from an appearance.
    func open(source: String) {
        guard reader == nil else { return }
        reload(reason: "open")
        guard !waiting.isEmpty else { return }
        // Before the mode, so the first body evaluated in `.voiceNoteResult` has pages.
        reader = Reader(pages: waiting)
        KeyboardState.shared.presentAreaMode(.voiceNoteResult)
        guard KeyboardState.shared.areaMode == .voiceNoteResult else {
            // Refused: a dictation owns the area. Nothing was shown.
            reader = nil
            log("openRefused", "source=\(source) status=\(KeyboardState.shared.dictationStatus.rawValue)")
            return
        }
        // Shown, so it never opens on its own for these notes again (decision 2).
        // Viewing is not reading: nothing is acknowledged here (decision 6).
        store?.markPresented(waiting.map(\.id))
        log("readerOpened", "source=\(source) pages=\(waiting.count) ids=\(Self.short(waiting))")
    }

    /// `✕`, and every way out that is not an insertion of the last page. The notes
    /// stay waiting (decision 4).
    ///
    /// The mode change is what clears `reader`, in `areaModeChanged`: one path, so a
    /// dictation taking the area and a `✕` leave the same state behind.
    func close(reason: String) {
        guard KeyboardState.shared.areaMode == .voiceNoteResult else { return }
        log("readerClosed", "reason=\(reason) waiting=\(waiting.count)")
        KeyboardState.shared.presentAreaMode(.keys)
    }

    // MARK: - Actions

    /// `Insert`: hand the visible page's transcript to `write`, once.
    ///
    /// `write` is the caller's, because the caller is the view that knows which
    /// controller it belongs to and holds the bridge the insertion has to be reported
    /// to (#548). It returns whether it wrote.
    ///
    /// The receipt is written **after** the text, deliberately. A process killed
    /// between the two shows the note again on the next appearance, which the user can
    /// dismiss; the other order would lose a transcript that never reached the field.
    func insert(_ id: UUID, write: (String) -> Bool) {
        guard var reader, let page = reader.pages.first(where: { $0.id == id }),
              !inserted.contains(id) else {
            log("insertIgnored", "id=\(id.uuidString.prefix(8)) reason=consumedOrClosed")
            return
        }
        guard write(page.transcript) else {
            log("insertIgnored", "id=\(id.uuidString.prefix(8)) reason=notWritten")
            return
        }
        inserted.insert(id)
        let receipt = store?.acknowledge(id, action: .inserted) ?? false
        HapticFeedback.textInserted()
        log("inserted", "id=\(id.uuidString.prefix(8)) chars=\(page.transcript.count) receipt=\(receipt)")

        // The page goes; the keys come back only with the last one (decision 7).
        reader.pages.removeAll { $0.id == id }
        if reader.copiedID == id { reader.copiedID = nil }
        reload(reason: "inserted")
        if reader.pages.isEmpty {
            close(reason: "lastInserted")
        } else {
            self.reader = reader
        }
    }

    /// `Copy`: the visible page's transcript to the pasteboard. Marks the note read
    /// and leaves the reader open on it, with a brief "Copied" (decision 7).
    func copy(_ id: UUID) {
        guard reader != nil, let page = reader?.pages.first(where: { $0.id == id }) else { return }
        UIPasteboard.general.string = page.transcript
        let receipt = store?.acknowledge(id, action: .copied) ?? false
        HapticFeedback.keyTapped()
        log("copied", "id=\(id.uuidString.prefix(8)) chars=\(page.transcript.count) receipt=\(receipt)")
        reader?.copiedID = id
        reload(reason: "copied")

        copiedReset?.cancel()
        let reset = DispatchWorkItem { [weak self] in
            guard let self, self.reader?.copiedID == id else { return }
            self.reader?.copiedID = nil
        }
        copiedReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: reset)
    }

    /// `Open in Dictus`: the app's result screen on this note.
    ///
    /// No receipt: the note leaves the keyboard when the app actually shows it, which
    /// withdraws the delivery (decisions 5 and 6). If the app never gets there, the
    /// note is still waiting here, which is the safe failure. The reader closes first
    /// for the panel's reason (#241): the trip out of the keyboard ends the task.
    func openInDictus(_ id: UUID) {
        log("openInDictus", "id=\(id.uuidString.prefix(8))")
        close(reason: "openInDictus")
        KeyboardState.shared.openDictusApp(intent: .voiceNote, voiceNoteID: id)
    }

    // MARK: - Disk and signal

    /// Reread the delivery directory.
    private func reload(reason: String) {
        let pending = (store?.pending() ?? []).filter { !inserted.contains($0.id) }
        guard pending.map(\.id) != waiting.map(\.id) else { return }
        log("waitingChanged", "reason=\(reason) from=\(waiting.count) to=\(pending.count) ids=\(Self.short(pending))")
        waiting = pending
    }

    /// DictusApp wrote a delivery. A keyboard on screen shows the chip — never the
    /// reader (decision 1) — and says so once: one pulse, one light haptic.
    ///
    /// An open reader takes the new note as a last page rather than leaving it to the
    /// chip behind it: appended, so the page under the user's eyes does not move.
    private func resultReadySignalled() {
        reload(reason: "signal")
        let fresh = waiting.filter { !announced.contains($0.id) }
        announced.formUnion(fresh.map(\.id))
        guard !fresh.isEmpty else { return }
        if var reader {
            let shown = Set(reader.pages.map(\.id))
            reader.pages.append(contentsOf: fresh.filter { !shown.contains($0.id) })
            self.reader = reader
            store?.markPresented(fresh.map(\.id))
        }
        let visible = KeyboardState.shared.isKeyboardVisible
        log("arrived", "count=\(fresh.count) ids=\(Self.short(fresh)) visible=\(visible) readerOpen=\(reader != nil)")
        guard visible else { return }
        arrivalPulse += 1
        HapticFeedback.voiceNoteArrived()
    }

    /// Follow the area mode, whoever moved it.
    ///
    /// Leaving `.voiceNoteResult` clears the reader — `✕`, the last `Insert`, and a
    /// dictation taking the area all arrive here. Leaving `.recording` rereads the
    /// directory: a note may have landed during the dictation, and the chip comes back
    /// with the keys. The reader does not reopen on its own then; the user is looking
    /// at the keyboard (decision 1).
    private func areaModeChanged(to mode: KeyboardAreaMode) {
        if mode != .voiceNoteResult, reader != nil {
            reader = nil
            copiedReset?.cancel()
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
