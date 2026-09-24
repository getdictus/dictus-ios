// DictusCore/Sources/DictusCore/Subscription/ProTrial.swift
// The reverse trial's values: how long it lasts, what one looks like, where it stands (#593).
import Foundation

/// The reverse trial's fixed terms (#593).
///
/// Every user gets Dictus Pro unlocked for a fixed period without subscribing to
/// anything; when it ends, Pro switches off and the paywall asks them to keep it.
/// This replaced the 7-day StoreKit introductory offer on the yearly plan (#215),
/// because nobody tries a feature that sits behind a subscription screen and the
/// Smart Modes only show their value over a week of real messages.
///
/// WHY a caseless enum: a namespace for constants, like `PremiumFlags`.
public enum ProTrial {

    /// Decision 1, confirmed by Pierre on 2026-09-23. A keyboard habit forms over
    /// more than one week, many users do not dictate every day, and the trial costs
    /// Dictus nothing to run because everything is on-device.
    public static let durationDays = 14

    /// Decision 3: the in-app notice and the keyboard pill appear this many days
    /// before the end, and not earlier. No push notification: Dictus does not ask
    /// for that permission.
    public static let reminderLeadDays = 2

    /// One day, in seconds.
    ///
    /// WHY seconds and not `Calendar` arithmetic: the trial is a duration the user
    /// was promised, not a calendar event. Fourteen 24-hour days is the same length
    /// on either side of a daylight-saving change, and the date shown to the user
    /// is formatted from the stored instant, so it cannot disagree with it.
    static let secondsPerDay: TimeInterval = 86_400

    /// The whole trial, in seconds.
    public static var duration: TimeInterval { TimeInterval(durationDays) * secondsPerDay }
}

/// One reverse trial, as it was granted.
///
/// Both instants are stored rather than the start alone, so a future change to
/// `ProTrial.durationDays` cannot lengthen or shorten a trial somebody is already
/// running: what they were told on the day it started is what they get.
public struct ProTrialRecord: Codable, Equatable, Sendable {
    public let startedAt: Date
    public let endsAt: Date

    public init(startedAt: Date, endsAt: Date) {
        self.startedAt = startedAt
        self.endsAt = endsAt
    }

    /// A trial starting at `now`, for the fixed duration.
    public static func starting(at now: Date) -> ProTrialRecord {
        ProTrialRecord(startedAt: now, endsAt: now.addingTimeInterval(ProTrial.duration))
    }
}

/// Where the reverse trial stands at a given instant.
///
/// Three states and not an optional end date, because "never started" and "ended"
/// are the two cases every surface has to tell apart: one is owed an announcement,
/// the other an end-of-trial paywall, and neither may ever get a second trial.
public enum ProTrialState: Equatable, Sendable {
    case neverStarted
    case running(endsAt: Date)
    case expired(endedAt: Date)

    /// Resolve a stored record against a clock.
    ///
    /// The end instant itself counts as expired: at `endsAt` the user has had the
    /// whole period they were promised.
    public init(record: ProTrialRecord?, now: Date) {
        guard let record else {
            self = .neverStarted
            return
        }
        self = now < record.endsAt ? .running(endsAt: record.endsAt) : .expired(endedAt: record.endsAt)
    }

    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    public var isExpired: Bool {
        if case .expired = self { return true }
        return false
    }

    /// Whether a trial was ever granted on this install or a previous one.
    ///
    /// What "no second trial" is keyed on, including for StoreKit: a user who has
    /// finished the reverse trial must never be offered "7 more days free" (#215).
    public var hasEverStarted: Bool { self != .neverStarted }

    /// Whole days left, rounded up, or nil when no trial is running.
    ///
    /// Rounded up so the badge never reads "0 days left" while Pro is still on, and
    /// so a trial that started a minute ago reads the full fourteen it was announced
    /// with.
    public func daysLeft(now: Date) -> Int? {
        guard case .running(let endsAt) = self else { return nil }
        let remaining = endsAt.timeIntervalSince(now)
        return max(1, Int((remaining / ProTrial.secondsPerDay).rounded(.up)))
    }

    /// Whether the end is close enough for the reminder (decision 3).
    public func isInReminderWindow(now: Date) -> Bool {
        guard let daysLeft = daysLeft(now: now) else { return false }
        return daysLeft <= ProTrial.reminderLeadDays
    }
}
