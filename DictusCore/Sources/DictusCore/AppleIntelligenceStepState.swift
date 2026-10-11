// DictusCore/Sources/DictusCore/AppleIntelligenceStepState.swift
// What the onboarding's Apple Intelligence step shows, and when it changes (#683).
import Foundation

/// The Apple Intelligence step's state machine: the instructions, the check that runs when
/// the user comes back, and the two ways it ends.
///
/// WHY IT EXISTS (device test of 2026-10-11): a user who had fixed Siri's language came
/// back to Dictus and found the very same screen. Apple Intelligence was still setting up
/// (`modelNotReady` for every check), nothing said a check was running, and the user
/// concluded it had failed. Coming back now starts a visible check with a countdown, and
/// the countdown ends on a calm screen that lets the user go on.
///
/// WHY IN DICTUSCORE: the transitions and the countdown are rules, the app target has no
/// test bundle, and the dates are passed in so a test can walk the fifteen seconds.
///
/// The copy behind every phase is independent of the not-ready reason: Apple reports a
/// Siri language mismatch as `modelNotReady`, so the reason cannot pick a sentence.
public struct AppleIntelligenceStepState: Equatable, Sendable {

    /// What the page shows.
    public enum Phase: Equatable, Sendable {
        /// The first visit: the drawn Settings path, Open Settings and Later.
        case instructions
        /// Back from Settings with Apple Intelligence not ready yet: a countdown while
        /// availability is read again every `recheckInterval`.
        case checking(startedAt: Date)
        /// Apple Intelligence is available: the green line and Continue.
        case ready
        /// The countdown ended without it: Apple Intelligence finishes in the background,
        /// Continue, and a way back to the instructions.
        case settingUp
    }

    /// A change worth a log line.
    public enum Transition: Equatable, Sendable {
        case checkingStarted
        /// `afterSeconds` is the time since the check started, or nil when availability
        /// was found outside a check.
        case becameAvailable(afterSeconds: Int?)
        case countdownElapsed
    }

    /// How long the check runs before the page stops waiting.
    public static let checkDuration: TimeInterval = 15

    /// How often availability is read during the check.
    public static let recheckInterval: TimeInterval = 2

    public private(set) var phase: Phase

    /// The state when the page appears, from the first availability read.
    public init(isAvailable: Bool) {
        phase = isAvailable ? .ready : .instructions
    }

    /// The app came back to the foreground while the step is on screen: back from
    /// Settings, or relaunched on the step after iOS ended it.
    ///
    /// Any return starts the check over when Apple Intelligence is still not available,
    /// whatever the page showed: the user may have changed something again.
    @discardableResult
    public mutating func appBecameActive(isAvailable: Bool, at now: Date) -> Transition? {
        if isAvailable { return markAvailable(at: now) }
        phase = .checking(startedAt: now)
        return .checkingStarted
    }

    /// A read of availability during the check (every `recheckInterval`, and once the
    /// countdown is over). Outside the check, only a newly available Apple Intelligence
    /// changes anything.
    @discardableResult
    public mutating func availabilityRead(isAvailable: Bool, at now: Date) -> Transition? {
        if isAvailable { return markAvailable(at: now) }
        guard case .checking(let startedAt) = phase else { return nil }
        guard now.timeIntervalSince(startedAt) >= Self.checkDuration else { return nil }
        phase = .settingUp
        return .countdownElapsed
    }

    /// "See the steps again" on the setting-up screen: back to the first-visit content.
    public mutating func showInstructionsAgain() {
        if phase == .settingUp { phase = .instructions }
    }

    /// Whole seconds left on the countdown, rounded up, so it reads 15 … 1 and only shows
    /// 0 once the time is over. 0 outside the check.
    public func secondsLeft(at now: Date) -> Int {
        guard case .checking(let startedAt) = phase else { return 0 }
        let left = Self.checkDuration - now.timeIntervalSince(startedAt)
        return max(0, Int(left.rounded(.up)))
    }

    /// The share of the countdown elapsed, from 0 to 1, for a ring. 0 outside the check.
    public func elapsedFraction(at now: Date) -> Double {
        guard case .checking(let startedAt) = phase else { return 0 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / Self.checkDuration))
    }

    private mutating func markAvailable(at now: Date) -> Transition? {
        let afterSeconds: Int?
        switch phase {
        case .ready:
            return nil
        case .checking(let startedAt):
            afterSeconds = Int(now.timeIntervalSince(startedAt).rounded())
        case .instructions, .settingUp:
            afterSeconds = nil
        }
        phase = .ready
        return .becameAvailable(afterSeconds: afterSeconds)
    }
}
