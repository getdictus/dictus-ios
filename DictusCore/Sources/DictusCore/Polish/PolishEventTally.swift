// DictusCore/Sources/DictusCore/Polish/PolishEventTally.swift
// The polish debug export's aggregates, computed where a test can reach them (#747).
import Foundation

/// The counts the polish debug export prints above its events.
///
/// Moved out of `PolishDebugExporter` (DictusApp) for #747, which added an outcome
/// that every count over polish runs has to leave alone: `skippedToggleOff`, a
/// dictation the toggle stopped before any polish was attempted. The exporter
/// cannot be reached from `swift test`, so the rule lived nowhere a test could pin it.
///
/// The rule itself is structural rather than a filter: a toggle-off event carries no
/// failure reason, no guardrail check and no length skip, so it lands in `outcomes`
/// under its own key and in nothing else. A rate a reader computes over the other
/// keys is the rate over polish runs, whatever the toggle was set to.
public struct PolishEventTally: Equatable, Sendable {

    /// Every outcome, by raw value. Seeded with zeros so a zero reads as "did not
    /// happen" rather than as "this build does not know about it" (#587).
    public private(set) var outcomes: [String: Int]
    /// Per-reason counts over the `engineFailed` events (#315).
    public private(set) var failureReasons: [String: Int] = [:]
    /// The same counts split by writing process (#361). Absent writers are absent.
    public private(set) var failureReasonsByWriter: [String: [String: Int]] = [:]
    /// Rejections per output check (#466).
    public private(set) var guardrailChecks: [String: Int] = [:]
    /// Length skips per armed mode (#587).
    public private(set) var smartModesSkippedForLength: [String: Int] = [:]

    /// The outcomes the export seeds at zero. `skippedAutoMode` stays: events from
    /// pre-#239 builds can still sit in the seven-day ring.
    public static let seededOutcomes: [PolishMetrics.Outcome] = [
        .success, .rejectedGuardrail, .skipped, .skippedShort, .skippedAutoMode,
        .cancelled, .engineFailed, .engineUnavailable, .exceededContextBudget,
        .unsupportedInputLanguage, .smartModeSkippedShortInput, .skippedToggleOff
    ]

    public init(entries: [PolishDebugEntry]) {
        outcomes = Dictionary(uniqueKeysWithValues: Self.seededOutcomes.map { ($0.rawValue, 0) })
        for e in entries {
            if let skip = e.metrics.smartModeLengthSkip {
                smartModesSkippedForLength[skip.mode, default: 0] += 1
            }
            outcomes[e.metrics.outcome.rawValue, default: 0] += 1
            if let reason = e.metrics.failureReason {
                failureReasons[reason.slug, default: 0] += 1
                failureReasonsByWriter[e.writer ?? "unrecorded", default: [:]][reason.slug, default: 0] += 1
            }
            if let check = e.metrics.guardrailCheck {
                guardrailChecks[check.rawValue, default: 0] += 1
            }
        }
    }
}
