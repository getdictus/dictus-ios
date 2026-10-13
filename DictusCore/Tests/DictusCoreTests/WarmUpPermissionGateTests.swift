// DictusCore/Tests/DictusCoreTests/WarmUpPermissionGateTests.swift
// The warm-up's record-permission gate (#715): the rule, and the one place it is asked.
//
// WHY the second half reads the source: `UnifiedAudioEngine` is `@MainActor`, owns a live
// `AVAudioEngine` and lives in DictusApp, which has no test bundle, so the call site cannot
// be exercised. It can be read, which is the pattern `CallGuardCallSiteTests` established
// for the call guard in the same file.
import XCTest
@testable import DictusCore

final class WarmUpPermissionGateTests: XCTestCase {

    // MARK: - The rule

    func testAGrantedPermissionLetsTheWarmUpStartTheEngine() {
        XCTAssertTrue(WarmUpPermissionGate.mayStartEngine(.granted))
        XCTAssertNil(WarmUpPermissionGate.skipReason(for: .granted))
    }

    /// The case the issue was filed on: an input start with an undetermined permission is
    /// what makes iOS show the prompt.
    func testAnUndeterminedPermissionSkipsTheWarmUp() {
        XCTAssertFalse(WarmUpPermissionGate.mayStartEngine(.undetermined))
        XCTAssertEqual(WarmUpPermissionGate.skipReason(for: .undetermined), "micPermission=undetermined")
    }

    func testADeniedPermissionSkipsTheWarmUp() {
        XCTAssertFalse(WarmUpPermissionGate.mayStartEngine(.denied))
        XCTAssertEqual(WarmUpPermissionGate.skipReason(for: .denied), "micPermission=denied")
    }

    func testTheSkipLineSaysWhyTheEngineIsCold() {
        let formatted = LogEvent.engineWarmUpSkipped(
            context: "unifiedEngine-warmUp", reason: "micPermission=undetermined"
        ).formatted()
        XCTAssertTrue(formatted.contains("engineWarmUpSkipped"), formatted)
        XCTAssertTrue(formatted.contains("[audio]"), formatted)
        XCTAssertTrue(formatted.contains("reason=micPermission=undetermined"), formatted)
    }

    /// A skip is a deliberate state, not a problem: it must not read as a failure (#486),
    /// and it must not sit at debug where a reader filtering the log would lose it.
    func testTheSkipLineIsInfoNotAWarning() {
        XCTAssertEqual(LogEvent.engineWarmUpSkipped(context: "x", reason: "y").level, .info)
    }

    // MARK: - The call site

    private static let enginePath = "DictusApp/Audio/UnifiedAudioEngine.swift"
    private static let gateCall = "WarmUpPermissionGate.skipReason("

    func testWarmUpAsksTheGateBeforeStartingTheEngine() throws {
        let body = try body(of: "func warmUp() throws {", in: Self.enginePath)
        let gateIndex = try XCTUnwrap(body.range(of: Self.gateCall)?.lowerBound,
                                      "warmUp() no longer asks WarmUpPermissionGate")
        let startIndex = try XCTUnwrap(body.range(of: "startEngine(context:")?.lowerBound,
                                       "warmUp() no longer starts the engine")
        XCTAssertLessThan(gateIndex, startIndex,
                          "the permission gate must run before warmUp() starts the engine")
    }

    /// Both callers of `warmUp()` write the model's load state from a throw (#486), so the
    /// skip has to return. A `throw` between the gate and the engine start would report a
    /// healthy model as a failed load.
    func testTheSkipReturnsInsteadOfThrowing() throws {
        let body = try body(of: "func warmUp() throws {", in: Self.enginePath)
        let gateRange = try XCTUnwrap(body.range(of: Self.gateCall))
        let startRange = try XCTUnwrap(body.range(of: "startEngine(context:"))
        let skipBranch = body[gateRange.upperBound..<startRange.lowerBound]
        XCTAssertTrue(skipBranch.contains("return"), String(skipBranch))
        XCTAssertFalse(skipBranch.contains("throw "), String(skipBranch))
    }

    /// One gate for every warm-up door: the model-load seam the launch preload and the
    /// foreground return share must keep going through `warmUp()`, not around it.
    func testTheWarmUpDoorsReachTheEngineOnlyThroughWarmUp() throws {
        let body = try body(of: "func loadActiveModelIntoMemory(",
                            in: "DictusApp/DictationCoordinator.swift")
        XCTAssertTrue(body.contains("audioEngine.warmUp()"), body)
        XCTAssertFalse(body.contains("startRecording()"), body)
    }

    // MARK: - Reading the repo

    /// The text between a function's opening brace and its matching close, with comment
    /// lines removed (comments here name the very calls being ordered).
    private func body(of signature: String,
                      in path: String,
                      file: StaticString = #filePath,
                      line: UInt = #line) throws -> String {
        let source = try source(at: path, file: file, line: line)
        // The first brace from the signature on opens the body, whether or not the
        // signature quoted it.
        guard let signatureRange = source.range(of: signature),
              let openBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
            XCTFail("\(path) no longer declares `\(signature)`", file: file, line: line)
            throw CocoaError(.fileNoSuchFile)
        }
        let start = source.index(after: openBrace)

        var depth = 1
        var index = start
        while index < source.endIndex, depth > 0 {
            let character = source[index]
            if character == "{" { depth += 1 }
            if character == "}" { depth -= 1 }
            if depth == 0 { break }
            index = source.index(after: index)
        }
        return String(source[start..<index])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private func source(at path: String,
                        file: StaticString = #filePath,
                        line: UInt = #line) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // DictusCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // DictusCore
            .deletingLastPathComponent()  // repo root
        let url = root.appendingPathComponent(path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("Source not found at \(url.path)", file: file, line: line)
            throw CocoaError(.fileNoSuchFile)
        }
        return text
    }
}
