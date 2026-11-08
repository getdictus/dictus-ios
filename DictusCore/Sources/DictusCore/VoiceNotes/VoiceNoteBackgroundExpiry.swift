// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteBackgroundExpiry.swift
// Whether the queue's background task expired under a voice note mode run (#627).
import Foundation

/// Tracks voice note mode runs from the moment they are requested, and whether the
/// queue's background task expired while any was pending (#627, PR #689 review).
///
/// ### Why from the request, not from the engine call
///
/// A run is requested, then started in an unstructured task (`InFlightCalls`), then
/// reaches the engine. Counting only from the engine call left a window: an expiry
/// between the request and the start found nothing to cancel, and the run then called
/// Apple FM after `endBackgroundTask()` and logged an ordinary outcome. Counting from
/// the request closes it: the expiry is recorded, and the run checks it before calling
/// the engine.
///
/// The flag clears when the last pending run ends, so it never reaches a run requested
/// after the expiry was dealt with.
public struct VoiceNoteBackgroundExpiry: Equatable, Sendable {

    /// Runs requested and not yet ended.
    public private(set) var pendingRuns = 0

    /// Whether the background task expired while a run was pending.
    public private(set) var expired = false

    public init() {}

    /// A run was requested (not an attach to a run already in flight).
    public mutating func runRequested() {
        pendingRuns += 1
    }

    /// A requested run ended, whatever its outcome.
    public mutating func runEnded() {
        pendingRuns = max(0, pendingRuns - 1)
        if pendingRuns == 0 { expired = false }
    }

    /// The background task is expiring. Returns whether a run was pending, so the
    /// caller knows whether there is an engine call to cancel.
    @discardableResult
    public mutating func expire() -> Bool {
        guard pendingRuns > 0 else { return false }
        expired = true
        return true
    }
}
