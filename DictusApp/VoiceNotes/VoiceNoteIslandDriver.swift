// DictusApp/VoiceNotes/VoiceNoteIslandDriver.swift
// Turns voice note events into the ring on the Live Activity (#620 island design).
import Foundation
import DictusCore

/// Drives the voice note ring: which notes it shows, when "received" appears, when
/// the batch alerts, and when the ready state goes.
///
/// The rules themselves are tested values in DictusCore (`VoiceNoteIsland`,
/// `VoiceNoteAlertPolicy`); this object only feeds them events and pushes the result
/// through `LiveActivityManager`. Process-scoped on purpose: a Live Activity does not
/// survive the process that drives it, and a ring rebuilt from disk after a relaunch
/// would re-announce notes the island has already announced.
@MainActor
final class VoiceNoteIslandDriver {

    static let shared = VoiceNoteIslandDriver()

    private var island = VoiceNoteIsland()
    /// The batch the success alert was raised for, so a replay never raises it again.
    private var alertedBatch: Int?
    /// Notes slower than `VoiceNoteIsland.receivedDelay`: the compact island says so.
    private var showsReceived = false
    private var receivedTask: Task<Void, Never>?
    /// When the last note was shared, and the alert waiting for the share sheet to go.
    private var lastArrivalAt: Date?
    private var alertTask: Task<Void, Never>?

    /// The success alert never fires sooner than this after a share (device test of
    /// a5345688). Fast notes now finish within a second, while WhatsApp's share sheet
    /// is still closing (1.2 s); an alert raised under it did not expand the island.
    /// ASSUMED cause, see the PR; the update log tells it from the update-order one.
    static let alertDelayAfterShare: TimeInterval = 2.5
    private var expiryTask: Task<Void, Never>?

    private init() {}

    // MARK: - Events

    /// Notes were shared and queued.
    func arrived(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let previousBatch = island.batch
        ids.forEach { island.add($0) }
        lastArrivalAt = Date()
        // A new batch supersedes an alert the last one left waiting behind a dictation:
        // it would otherwise fire on the next return to standby for the old batch, and
        // the new batch would alert a second time when it drains.
        if island.batch != previousBatch {
            LiveActivityManager.shared.discardPendingVoiceNoteAlert()
            alertTask?.cancel()
            alertTask = nil
        }
        // A new note keeps the ring alive past an earlier batch's ready deadline.
        expiryTask?.cancel()
        LiveActivityManager.shared.voiceNoteReadyDeadline = nil
        push()
        // "Voice note received" only for a note that is still running after 3 s
        // (decision 7): a fast note gives one moment, the haptic then the result.
        receivedTask?.cancel()
        receivedTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(VoiceNoteIsland.receivedDelay * 1_000_000_000))
            guard let self, !Task.isCancelled, self.island.hasPending else { return }
            self.showsReceived = true
            self.push()
        }
    }

    /// A note finished, with a result or without.
    func finished(_ id: UUID, succeeded: Bool) {
        let drained = island.finish(id, succeeded: succeeded)
        guard drained else {
            push()
            return
        }
        showsReceived = false
        receivedTask?.cancel()
        let decision = VoiceNoteAlertPolicy.decide(
            drained: true,
            batchSucceeded: island.batchSucceeded,
            alreadyAlerted: alertedBatch == island.batch,
            dictationActive: LiveActivityManager.shared.isDictationShowing
        )
        if decision != .none { alertedBatch = island.batch }
        scheduleExpiry()
        let wait = (lastArrivalAt?.addingTimeInterval(Self.alertDelayAfterShare).timeIntervalSinceNow) ?? 0
        guard decision != .none, wait > 0 else {
            push(alert: decision != .none)
            return
        }
        // The ring fills now; the alert follows once the share sheet is gone.
        push()
        alertTask?.cancel()
        alertTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.alertTask = nil
            self.push(alert: true)
        }
    }

    /// The user read a note's outcome on its card.
    func read(_ id: UUID) {
        guard island.contains(id) else { return }
        island.markRead(id)
        push()
    }

    /// The queue stopped without finishing (Pro lapsed): nothing it holds will move.
    func paused() {
        showsReceived = false
        push()
    }

    // MARK: - Ready lifetime

    /// The ready state goes after five minutes (decision 4), whatever the engine does.
    /// While the app lives this timer clears the ring; if the engine is released first,
    /// `LiveActivityManager` ends the activity with `.after(deadline)` instead.
    private func scheduleExpiry() {
        let deadline = Date().addingTimeInterval(VoiceNoteIsland.readyLifetime)
        LiveActivityManager.shared.voiceNoteReadyDeadline = deadline
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(VoiceNoteIsland.readyLifetime * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            self.island.expireFinished()
            LiveActivityManager.shared.voiceNoteReadyDeadline = nil
            self.push()
        }
    }

    // MARK: - Push

    /// The last ready count logged, so the line is written only when it changes.
    private var loggedReadyCount = 0

    private func push(alert: Bool = false) {
        if island.readyCount != loggedReadyCount {
            loggedReadyCount = island.readyCount
            PersistentLog.log(.diagnosticProbe(component: "VoiceNote", instanceID: "island", action: "readyCount",
                                               details: "ready=\(island.readyCount) segments=\(island.segments.count)"))
        }
        guard !island.isEmpty else {
            LiveActivityManager.shared.updateVoiceNote(nil)
            return
        }
        LiveActivityManager.shared.updateVoiceNote(VoiceNoteActivityContent(
            segments: island.segments,
            receivedLine: showsReceived && island.hasPending ? VoiceNoteCopy.received : nil,
            statusLine: VoiceNoteCopy.islandStatus(ready: island.readyCount, failed: island.failedCount)
        ), alert: alert)
    }
}
