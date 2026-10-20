// DictusCore/Tests/DictusCoreTests/Polish/PolishServiceFakes.swift
// A clock, an engine and a sink for driving `PolishService` end to end without Apple FM.
import Foundation
@testable import DictusCore

// Moved out of `SmartModeListCheckTests` (#573) when #650 needed the same three to pin
// `Résumé`'s input floor on the service: one set of fakes, two suites.

/// A clock the fake engine advances, so elapsed time is decided by the test.
final class FakeClock: @unchecked Sendable {
    private var current = Date(timeIntervalSince1970: 1_000_000)
    func advance(by seconds: TimeInterval) { current += seconds }
    var now: () -> Date { { [unowned self] in self.current } }
}

/// Answers the `Liste` call and the Normal call with fixed text, advancing the clock.
final class ScriptedEngine: PolishEngineProtocol, @unchecked Sendable {
    let identifier = "scripted"
    let announcesProcessingStage = true
    private let clock: FakeClock
    private let secondsPerCall: TimeInterval
    private let listAnswer: String
    private let normalAnswer: String
    private(set) var calls: [String] = []

    init(clock: FakeClock, secondsPerCall: TimeInterval, listAnswer: String, normalAnswer: String) {
        self.clock = clock
        self.secondsPerCall = secondsPerCall
        self.listAnswer = listAnswer
        self.normalAnswer = normalAnswer
    }

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        calls.append(task.identifier)
        clock.advance(by: secondsPerCall)
        return task.isSmart ? listAnswer : normalAnswer
    }
}

actor RecordingSink: PolishEventSink {
    private var recorded: [PolishDebugEntry] = []
    func record(_ entry: PolishDebugEntry) async { recorded.append(entry) }
    func entries() -> [PolishDebugEntry] { recorded }
    func outcomes() -> [PolishMetrics.Outcome] { recorded.map(\.metrics.outcome) }
}
