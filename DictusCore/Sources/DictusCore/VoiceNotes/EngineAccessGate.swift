// DictusCore/Sources/DictusCore/VoiceNotes/EngineAccessGate.swift
// One transcription at a time on the shared engine, and dictations first (#620).
import Foundation

/// Serialises use of the speech engine between dictations and shared voice notes.
///
/// ### Why a gate at all
///
/// Until #620 the only thing that ever transcribed was a dictation, and
/// `DictationCoordinator`'s re-entry flag (#144) was enough to keep two `transcribe`
/// calls off the same engine — #144 is what two concurrent calls cost: they cancelled
/// each other with `CancellationError`. A voice note transcribed in the background is
/// a second caller the flag knows nothing about, so the rule moves here and both
/// callers go through it.
///
/// ### Why dictations outrank voice notes
///
/// A dictation is the user waiting on a keyboard, text field open, now. A voice note
/// is something they asked for and walked away from. So a dictation that arrives
/// while a voice note holds the engine waits only for the chunk in flight (see
/// `VoiceNoteChunker`), and when both are waiting the dictation is served first,
/// whatever the order they arrived in.
///
/// ### What it does not do
///
/// It does not interrupt the holder. Neither engine promises to return promptly from
/// a cancellation, which is #267's whole finding, so pre-emption would be a promise
/// this type cannot keep. Bounding the holder's turn — one chunk — is what makes the
/// wait acceptable instead.
@MainActor
public final class EngineAccessGate {

    /// Who is asking. The raw value is the priority: higher is served first.
    public enum Claimant: Int, Sendable, Comparable, CustomStringConvertible {
        case voiceNote = 0
        case dictation = 1

        public static func < (lhs: Claimant, rhs: Claimant) -> Bool { lhs.rawValue < rhs.rawValue }

        public var description: String {
            switch self {
            case .voiceNote: return "voiceNote"
            case .dictation: return "dictation"
            }
        }
    }

    /// The app's gate. One engine, one gate.
    public static let shared = EngineAccessGate()

    /// Who holds the engine right now, or nil when it is free.
    public private(set) var holder: Claimant?

    private struct Waiter {
        let claimant: Claimant
        let continuation: CheckedContinuation<Void, Never>
    }
    private var waiters: [Waiter] = []

    public init() {}

    /// Whether anyone is waiting with the given claim.
    public func isWaiting(_ claimant: Claimant) -> Bool {
        waiters.contains { $0.claimant == claimant }
    }

    /// Take the engine, waiting for it if needed. Every return must be balanced by
    /// exactly one `release()`; `withAccess` is the form that cannot forget.
    public func acquire(_ claimant: Claimant) async {
        if holder == nil && waiters.isEmpty {
            holder = claimant
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(Waiter(claimant: claimant, continuation: continuation))
        }
    }

    /// Hand the engine to the highest-priority waiter, first come first served
    /// within a priority, or free it.
    public func release() {
        guard let next = nextWaiterIndex() else {
            holder = nil
            return
        }
        let waiter = waiters.remove(at: next)
        holder = waiter.claimant
        waiter.continuation.resume()
    }

    /// Run `work` holding the engine.
    public func withAccess<T>(_ claimant: Claimant, _ work: () async throws -> T) async rethrows -> T {
        await acquire(claimant)
        defer { release() }
        return try await work()
    }

    private func nextWaiterIndex() -> Int? {
        guard let top = waiters.map(\.claimant).max() else { return nil }
        return waiters.firstIndex { $0.claimant == top }
    }
}
