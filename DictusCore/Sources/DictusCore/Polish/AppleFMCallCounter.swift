// DictusCore/Sources/DictusCore/Polish/AppleFMCallCounter.swift
// How many Apple Foundation Models calls this process has made (issue #627).
import Foundation
import os

/// The number of `LanguageModelSession.respond` calls this process has started since
/// it launched.
///
/// ### Why it exists (#627)
///
/// Apple's background rate limit is a budget per process, not a ban: #315 and #357
/// measured roughly twelve successful calls from a backgrounded DictusApp before it
/// latches, and only a fresh process refunds it. Running a voice note's Smart Mode in
/// the background spends that budget, and the device probe on #627 decides whether
/// that is viable by reading, on every attempt, how many calls the process had already
/// made. No other number answers "refused at call 1" versus "refused after a dozen".
///
/// ### What it counts
///
/// Every call that reaches Apple's model, refused ones included: a `rateLimited`
/// answer is a call the budget was asked about. Nothing the pipeline turns away before
/// the engine (context budget, input language, the #315 gate) is counted, and neither
/// is a translation the Translation framework served (#648).
///
/// Per process by construction, like the budget it mirrors: the keyboard extension has
/// its own count, which nothing reads.
public enum AppleFMCallCounter {

    private static let count = OSAllocatedUnfairLock(initialState: 0)

    /// Record one call about to be made, and return its 1-based index.
    @discardableResult
    public static func recordCall() -> Int {
        count.withLock { value in
            value += 1
            return value
        }
    }

    /// Calls recorded so far in this process.
    public static var current: Int {
        count.withLock { $0 }
    }
}
