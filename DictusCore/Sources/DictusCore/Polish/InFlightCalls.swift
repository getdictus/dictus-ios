// DictusCore/Sources/DictusCore/Polish/InFlightCalls.swift
// One call per key: a second caller for the same key awaits the first (issue #648).
import Foundation

/// Runs at most one operation per key at a time. A caller that asks for a key already
/// running awaits that run's result instead of starting another.
///
/// ### Why it exists: the voice note card re-ran its own Smart Mode
///
/// A voice note runs its mode when its card is on screen, and the card remembered that
/// it had started in its SwiftUI `@State`. That state belongs to one instance of the
/// view. On device (#648, 2026-10-09) the note stack was dismissed while DictusApp was
/// in the background, the user reopened the same note from History, and the new card
/// started from `.idle`: the summary was not stored yet, so it ran the mode again. On
/// its slot that superseded the first call, 16 s and four of seven Translate chunks in
/// (`polishCallSuperseded inflightMs=16347`), and the note then took 32.5 s more from
/// zero. Any mode does the same; Translate on a long note is where it shows.
///
/// The fix keeps the record outside the view, keyed by note and mode, so a new card
/// attaches to the call already running.
///
/// The operation runs in an unstructured task owned by this object, not by the caller:
/// a card that disappears stops waiting, and the work goes on for the next one.
@MainActor
public final class InFlightCalls<Key: Hashable, Value: Sendable> {

    private var running: [Key: Task<Value, Never>] = [:]

    public init() {}

    /// Whether a run for `key` is in flight.
    public func isRunning(_ key: Key) -> Bool {
        running[key] != nil
    }

    /// The result of the run for `key`: the one in flight if there is one, otherwise a
    /// new run of `operation`.
    public func run(_ key: Key, _ operation: @escaping @MainActor () async -> Value) async -> Value {
        if let task = running[key] {
            return await task.value
        }
        let task = Task { await operation() }
        running[key] = task
        let value = await task.value
        // Only forget the run this call started: a later one under the same key, which
        // can start once this one has finished, must keep its entry.
        if running[key] == task { running[key] = nil }
        return value
    }
}
