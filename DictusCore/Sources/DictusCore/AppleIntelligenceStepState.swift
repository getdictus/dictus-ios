// DictusCore/Sources/DictusCore/AppleIntelligenceStepState.swift
// What the onboarding's Apple Intelligence step shows, and when it changes (#683).
import Foundation

/// The Apple Intelligence step's state machine: the instructions, what a return to the app
/// shows, and when the page turns ready.
///
/// WHY IT EXISTS (device test of 2026-10-11): a user who had fixed Siri's language came
/// back to Dictus and found the very same screen. Apple Intelligence was still setting up
/// (`modelNotReady` for every check), and the user concluded it had failed. A return now
/// says either that Apple Intelligence is ready, or that it is getting ready and the user
/// can go on.
///
/// WHY NO COUNTDOWN (device tests of 2026-10-10 and 2026-10-11): when Apple's model was in
/// place, the very first check on return already read `available`; when it was not,
/// fifteen seconds were not enough and it turned ready later, while the user was using the
/// app. A countdown only added a wait in both cases. The setting-up screen re-checks
/// quietly instead (`settingUpRecheckInterval`).
///
/// WHY IN DICTUSCORE: the transitions are rules, the app target has no test bundle, and
/// the dates are passed in so a test can measure the time since the return.
///
/// The reason picks only where the page opens, never a sentence: Apple reports a Siri
/// language mismatch as `modelNotReady` too, so `modelNotReady` opens on the setting-up
/// screen, whose copy says Apple is getting ready AND keeps the Siri language hint, with
/// "See the steps again" back to the instructions (Pierre's decision of 2026-10-28, #846).
/// Every other not-ready reason opens on the instructions.
public struct AppleIntelligenceStepState: Equatable, Sendable {

    /// What the page shows.
    public enum Phase: Equatable, Sendable {
        /// The first visit: the drawn Settings path, Open Settings and Later.
        case instructions
        /// Apple Intelligence is available: the green line and Continue.
        case ready
        /// Back in the app and not available, or `modelNotReady` from the first read:
        /// Apple Intelligence finishes in the background, Continue, and a way back to the
        /// instructions.
        case settingUp
    }

    /// A change worth a log line.
    public enum Transition: Equatable, Sendable {
        /// The page entered the setting-up screen.
        case settingUpShown
        /// `afterSeconds` is the time since the last return to the app, or nil when
        /// availability was found before any return.
        case becameAvailable(afterSeconds: Int?)
    }

    /// After a return, the delay before the second read: a language just changed in
    /// Settings may not be reflected by the time the app is active again.
    public static let returnRecheckDelay: TimeInterval = 2

    /// How often the setting-up screen reads availability again while it is on screen.
    public static let settingUpRecheckInterval: TimeInterval = 3

    public private(set) var phase: Phase

    /// When the app last came back to the foreground on this step.
    public private(set) var returnedAt: Date?

    /// The state when the page appears, from the first availability read.
    public init(isAvailable: Bool) {
        phase = isAvailable ? .ready : .instructions
    }

    /// The state when the page appears, from the first read of the engine state.
    ///
    /// `modelNotReady` opens on the setting-up screen rather than the instructions
    /// (decision of 2026-10-28, #846): Apple is most often downloading its model, and
    /// telling that user to change Siri's language was wrong. The setting-up screen still
    /// names the Siri language as the thing to check, which covers the mismatch Apple
    /// also reports as `modelNotReady`.
    public init(engineState: PolishAvailabilityState) {
        switch engineState {
        case .available: phase = .ready
        case .modelNotReady: phase = .settingUp
        default: phase = .instructions
        }
    }

    /// The app came back to the foreground while the step is on screen: back from
    /// Settings, or relaunched on the step after iOS ended it.
    ///
    /// Not available goes straight to the setting-up screen, whatever the page showed:
    /// the reads that follow turn it ready if Apple Intelligence comes up.
    @discardableResult
    public mutating func appBecameActive(isAvailable: Bool, at now: Date) -> Transition? {
        returnedAt = now
        if isAvailable { return markAvailable(at: now) }
        guard phase != .settingUp else { return nil }
        phase = .settingUp
        return .settingUpShown
    }

    /// A later read of availability: the second read after a return, and the quiet
    /// re-reads of the setting-up screen. Only a newly available Apple Intelligence
    /// changes anything.
    @discardableResult
    public mutating func availabilityRead(isAvailable: Bool, at now: Date) -> Transition? {
        guard isAvailable else { return nil }
        return markAvailable(at: now)
    }

    /// Whether the page keeps reading availability on its own: only on the setting-up
    /// screen.
    public var rechecksQuietly: Bool {
        phase == .settingUp
    }

    /// "See the steps again" on the setting-up screen: back to the first-visit content.
    public mutating func showInstructionsAgain() {
        if phase == .settingUp { phase = .instructions }
    }

    private mutating func markAvailable(at now: Date) -> Transition? {
        guard phase != .ready else { return nil }
        phase = .ready
        let afterSeconds = returnedAt.map { Int(now.timeIntervalSince($0).rounded()) }
        return .becameAvailable(afterSeconds: afterSeconds)
    }
}
