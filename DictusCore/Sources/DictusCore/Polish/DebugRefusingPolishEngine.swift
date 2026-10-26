// DictusCore/Sources/DictusCore/Polish/DebugRefusingPolishEngine.swift
// A polish engine that always refuses, for Debug captures of #455.
import Foundation

#if DEBUG
/// Stands in for Apple Foundation Models refusing the text (#455), behind
/// `SharedKeys.debugPolishRefusalForced`.
///
/// WHY it exists: a refusal cannot be produced on demand. The simulator has no Apple
/// Intelligence, and on a device it takes a phrase Apple's safety filter happens to
/// refuse. This throws on every call and classifies the throw as Apple's
/// `guardrailViolation` would be, so everything after the engine (the floor, the
/// log line, the keyboard's sentence) runs for real. Compiled out of Release.
struct DebugRefusingPolishEngine: PolishEngineProtocol {
    let identifier = "debug-refusal"

    struct Refused: Error {}

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        throw Refused()
    }

    func failureReason(for error: Error) -> PolishFailureReason { .safetyRefusal }
}
#endif
