// DictusCore/Sources/DictusCore/StageWatchdogPolicy.swift
// Whether the app's stage watchdog that just fired caught a stuck stage or a suspended
// process (#851). Testable in isolation -- the coordinator supplies the clock readings.

import Foundation

/// The stage watchdog's answer when its timer fires.
public enum StageWatchdogDecision: String, Equatable, Sendable {
    /// The stage is stuck: end the dictation, as every firing did before #851.
    case cancel
    /// The timer fired late because iOS suspended the app: arm it again.
    case rearm
}

public enum StageWatchdogPolicy {

    /// How late a timer may fire and still count as on time. A run loop that is merely
    /// busy delivers a timer within a fraction of a second; a suspension delays it by
    /// however long the call lasted.
    public static let suspensionSlack: TimeInterval = 2

    /// The longest a stage may run in total, suspensions included, before it is
    /// cancelled whatever its timer says.
    public static let maximumStageDuration: TimeInterval = 600

    /// The decision for a watchdog armed for `timeout` that just fired.
    ///
    /// WHY lateness tells a suspension apart: a call stops the engine and iOS suspends
    /// the app (#851, device 2026-10-29). The transcription and the timer freeze
    /// together, so on return the timer fires late and the transcription is a second
    /// from finishing. Cancelling there threw away a transcript nothing was wrong with.
    /// A stage that is really stuck keeps the process running, so its timer is on time.
    ///
    /// WHY a ceiling: a process suspended over and over would re-arm forever. Past
    /// `maximum` the stage fails, late or not, so a dictation always ends.
    ///
    /// - Parameters:
    ///   - elapsedSinceArm: wall-clock time since this timer was armed.
    ///   - elapsedSinceStageStart: wall-clock time since the stage began, across re-arms.
    public static func decide(
        armedFor timeout: TimeInterval,
        elapsedSinceArm: TimeInterval,
        elapsedSinceStageStart: TimeInterval,
        maximum: TimeInterval = maximumStageDuration
    ) -> StageWatchdogDecision {
        guard elapsedSinceStageStart <= maximum else { return .cancel }
        return elapsedSinceArm > timeout + suspensionSlack ? .rearm : .cancel
    }
}
