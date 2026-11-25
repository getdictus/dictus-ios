// DictusCore/Tests/DictusCoreTests/LoggedErrorTests.swift
// A foreign error reaches the log as domain and code only (#939).
import XCTest
@testable import DictusCore

final class LoggedErrorTests: XCTestCase {

    private enum ModelError: Error {
        case missing(String)
        case corrupt
    }

    func testACocoaFileErrorKeepsNoPathOrMessage() {
        let path = "/Users/someone/Library/Developer/CoreSimulator/Devices/X/Documents/model.mlmodelc"
        let posix = NSError(domain: NSPOSIXErrorDomain, code: 2, userInfo: [NSFilePathErrorKey: path])
        let cocoa = NSError(domain: NSCocoaErrorDomain, code: 260, userInfo: [
            NSFilePathErrorKey: path,
            NSLocalizedDescriptionKey: "The file “model.mlmodelc” couldn’t be opened at \(path).",
            NSUnderlyingErrorKey: posix
        ])
        let logged = LoggedError.domainAndCode(cocoa)
        XCTAssertEqual(logged, "domain=NSCocoaErrorDomain code=260 underlying=NSPOSIXErrorDomain:2")
        XCTAssertFalse(logged.contains("Users"))
        XCTAssertFalse(logged.contains("model"))
    }

    func testASwiftErrorKeepsItsTypeAndCaseIndexButNotItsPayload() {
        let logged = LoggedError.domainAndCode(ModelError.missing("/private/var/mobile/secret.json"))
        XCTAssertTrue(logged.hasPrefix("domain="), logged)
        XCTAssertTrue(logged.contains("ModelError"), logged)
        XCTAssertFalse(logged.contains("secret"), logged)
        XCTAssertNotEqual(logged, LoggedError.domainAndCode(ModelError.corrupt))
    }

    func testTheUnderlyingChainIsBounded() {
        var error = NSError(domain: "leaf", code: 0)
        for depth in 1...10 {
            error = NSError(domain: "level\(depth)", code: depth, userInfo: [NSUnderlyingErrorKey: error])
        }
        XCTAssertEqual(LoggedError.domainAndCode(error),
                       "domain=level10 code=10 underlying=level9:9 underlying=level8:8 underlying=level7:7")
    }
}
