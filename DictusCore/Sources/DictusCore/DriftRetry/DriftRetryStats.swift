// DictusCore/Sources/DictusCore/DriftRetry/DriftRetryStats.swift
// What the debug log records of a Parakeet drift retry (#623).
import Foundation

/// The retry's footprint on one dictation, for `transcriptionCompleted`.
///
/// Counters and a duration only, never text: the debug log carries no transcript. Its reader
/// is an agent comparing dictations, and these three numbers are what it needs to tell a
/// clean dictation (`spans` 0), a drift the retry repaired (`wins` above 0) and what the
/// repair cost on the device, which nobody has measured yet.
public struct DriftRetryStats: Equatable, Sendable {

    /// Spans re-decoded.
    public let spans: Int

    /// Spans where a re-decode replaced the first pass.
    public let wins: Int

    /// Wall time of the whole retry stage: detection, re-decodes and splice.
    public let durationMs: Int

    public init(spans: Int, wins: Int, durationMs: Int) {
        self.spans = spans
        self.wins = wins
        self.durationMs = durationMs
    }

    /// The fields as they appear on the log line.
    public var logFields: String { "retrySpans=\(spans) retryWins=\(wins) retryMs=\(durationMs)" }
}
