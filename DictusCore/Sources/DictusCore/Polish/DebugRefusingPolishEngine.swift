// DictusCore/Sources/DictusCore/Polish/DebugRefusingPolishEngine.swift
// A polish engine that always refuses, for Debug captures of #455.
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if DEBUG
/// Stands in for Apple Foundation Models refusing the text (#455), behind
/// `SharedKeys.debugPolishRefusalForced`.
///
/// WHY it exists: a refusal cannot be produced on demand. The simulator has no Apple
/// Intelligence, and on a device it takes a phrase Apple's safety filter happens to
/// refuse. This throws on every call and classifies the throw as Apple's
/// `guardrailViolation` would be, so everything after the engine (the floor, the
/// log line, the keyboard's sentence) runs for real. Compiled out of Release.
///
/// On iOS 27 it throws Apple's own `LanguageModelError.guardrailViolation` and
/// classifies it through the shipping engine's mapping (#826), so a capture there
/// also proves the new error type reaches the refusal path.
struct DebugRefusingPolishEngine: PolishEngineProtocol {
    let identifier = "debug-refusal"

    struct Refused: Error {}

    func polish(raw: String, targetLanguage: SupportedLanguage, task: PolishTask) async throws -> String {
        #if canImport(FoundationModels) && compiler(>=6.4)
        if #available(iOS 27.0, macOS 27.0, *) {
            throw LanguageModelError.guardrailViolation(.init(debugDescription: "debug-refusal"))
        }
        #endif
        throw Refused()
    }

    func failureReason(for error: Error) -> PolishFailureReason {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *), !(error is Refused) {
            return AppleFoundationModelsPolishEngine.failureReason(for: error)
        }
        #endif
        return .safetyRefusal
    }
}
#endif
