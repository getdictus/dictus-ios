// DictusCore/Sources/DictusCore/LiveActivityStateMachine.swift
// Extracted state machine for Live Activity phase transitions.
// Testable in isolation -- no ActivityKit dependency.

import Foundation

/// Validates Live Activity phase transitions.
///
/// WHY extracted from LiveActivityManager:
/// The transition rules (which phases can follow which) are pure logic with no
/// ActivityKit dependency. Extracting them into a value type in DictusCore enables
/// unit testing of all valid/invalid paths without needing a running app or simulator.
///
/// WHY a struct (not class):
/// Phase transitions are sequential -- no shared mutable state between callers.
/// A struct with mutating functions makes ownership explicit and prevents accidental
/// aliasing. LiveActivityManager owns a single instance and calls transition(to:).
public struct LiveActivityStateMachine {

    /// Phases of the Live Activity lifecycle.
    /// Maps 1:1 to the private LiveActivityPhase enum in LiveActivityManager.
    public enum Phase: String, Sendable {
        case idle, standby, recording, transcribing, ready, failed
    }

    /// The current phase. Read-only from outside; mutated only via transition(to:) or reset().
    public private(set) var currentPhase: Phase = .idle

    /// Allowed transitions for each phase.
    /// WHY a stored property (not computed): The map is constant and small (6 entries).
    /// Storing it avoids re-creating the dictionary on every transition call.
    private let validTransitions: [Phase: Set<Phase>] = [
        .idle: [.standby],
        .standby: [.recording, .idle],
        .recording: [.transcribing, .standby],
        .transcribing: [.ready, .failed],
        .ready: [.standby, .recording],
        .failed: [.standby, .recording, .idle]
    ]

    public init() {}

    /// Attempt to transition to `target`. Returns true if the transition is valid.
    /// On failure, currentPhase is unchanged.
    @discardableResult
    public mutating func transition(to target: Phase) -> Bool {
        let allowed = validTransitions[currentPhase] ?? []
        guard allowed.contains(target) else { return false }
        currentPhase = target
        return true
    }

    /// Returns true if phase is .recording -- used by watchdog logic to decide
    /// if the Dynamic Island is stuck on the recording indicator.
    public var needsWatchdog: Bool {
        currentPhase == .recording
    }

    /// Reset to idle (for teardown/recovery).
    public mutating func reset() {
        currentPhase = .idle
    }

    /// Force-set the phase without validation.
    /// WHY: LiveActivityManager has recovery/bootstrap paths that assign currentPhase
    /// directly (e.g., idle after crash, standby after orphan recovery). These bypass
    /// the normal transition rules. forcePhase keeps the state machine in sync.
    public mutating func forcePhase(_ phase: Phase) {
        currentPhase = phase
    }
}
