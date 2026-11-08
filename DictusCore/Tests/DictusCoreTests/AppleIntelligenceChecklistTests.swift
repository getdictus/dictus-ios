// DictusCore/Tests/DictusCoreTests/AppleIntelligenceChecklistTests.swift
// The Apple Intelligence step's checklist over Settings: its lines and its end (#706).
import XCTest
@testable import DictusCore

final class AppleIntelligenceChecklistTests: XCTestCase {

    private typealias Checklist = AppleIntelligenceChecklist

    // MARK: - Lines

    func testIOS27GoesThroughSiri() {
        XCTAssertEqual(Checklist.lines(for: .siri), [.openSiri, .tapLanguage, .chooseIPhoneLanguage])
    }

    func testIOS26GoesThroughAppleIntelligenceAndSiri() {
        XCTAssertEqual(
            Checklist.lines(for: .appleIntelligenceAndSiri),
            [.openAppleIntelligenceAndSiri, .tapLanguage, .chooseIPhoneLanguage]
        )
    }

    /// The window names the row the step's drawing names, for every iOS version the route
    /// knows about.
    func testTheFirstLineFollowsTheRouteOfTheRunningIOS() {
        XCTAssertEqual(Checklist.lines(for: AppleIntelligenceOnboarding.settingsRoute(osMajorVersion: 26)).first, .openAppleIntelligenceAndSiri)
        XCTAssertEqual(Checklist.lines(for: AppleIntelligenceOnboarding.settingsRoute(osMajorVersion: 27)).first, .openSiri)
        XCTAssertEqual(Checklist.lines(for: AppleIntelligenceOnboarding.settingsRoute(osMajorVersion: 28)).first, .openSiri)
    }

    /// Three rows, as the keyboard step's, so the window keeps the frame #682 measured.
    func testThreeLinesWhateverTheRoute() {
        XCTAssertEqual(Checklist.lines(for: .siri).count, 3)
        XCTAssertEqual(Checklist.lines(for: .appleIntelligenceAndSiri).count, 3)
    }

    // MARK: - States

    /// Nothing the app can observe tells which line the user is on, so none is singled out.
    func testEveryLineIsToDoUntilTheEnd() {
        XCTAssertEqual(Checklist.states(lineCount: 3, isComplete: false), [.current, .current, .current])
    }

    func testCompleteTicksEverything() {
        XCTAssertEqual(Checklist.states(lineCount: 3, isComplete: true), [.done, .done, .done])
    }

    // MARK: - The end

    func testOnlyAvailableEndsIt() {
        XCTAssertTrue(Checklist.isComplete(engineState: .available))
        let notYet: [PolishAvailabilityState] = [
            .appleIntelligenceNotEnabled, .modelNotReady, .deviceNotEligible, .osTooOld, .sdkMissing,
            .other("aReasonAddedLater")
        ]
        for state in notYet {
            XCTAssertFalse(Checklist.isComplete(engineState: state), "\(state)")
        }
    }
}
