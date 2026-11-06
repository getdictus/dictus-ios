import XCTest
@testable import DictusCore

/// The app's stage watchdog after a call suspended the app (#851, device 2026-10-29):
/// a timer that fires late re-arms, a stuck stage still fails, and nothing re-arms forever.
final class StageWatchdogPolicyTests: XCTestCase {

    private func decide(sinceArm: TimeInterval, sinceStart: TimeInterval) -> StageWatchdogDecision {
        StageWatchdogPolicy.decide(armedFor: 30, elapsedSinceArm: sinceArm, elapsedSinceStageStart: sinceStart)
    }

    func testOnTimeFiringIsAStuckStage() {
        XCTAssertEqual(decide(sinceArm: 30, sinceStart: 30), .cancel)
    }

    func testOneSecondLateIsStillOnTime() {
        XCTAssertEqual(decide(sinceArm: 31, sinceStart: 31), .cancel)
    }

    func testFiftySecondsLateIsASuspension() {
        XCTAssertEqual(decide(sinceArm: 80, sinceStart: 80), .rearm)
    }

    func testPastTheCeilingCancelsEvenWhenLate() {
        XCTAssertEqual(decide(sinceArm: 80, sinceStart: 601), .cancel)
    }

    func testExactlyAtTheCeilingStillFollowsLateness() {
        XCTAssertEqual(decide(sinceArm: 80, sinceStart: 600), .rearm)
        XCTAssertEqual(decide(sinceArm: 30, sinceStart: 600), .cancel)
    }

    func testRearmedLogLine() {
        let event = LogEvent.stageWatchdogRearmed(status: "transcribing", lateBySeconds: 50, sinceStageStartSeconds: 81)
        XCTAssertEqual(event.name, "stageWatchdogRearmed")
        XCTAssertEqual(event.message, "status=transcribing lateBySeconds=50 sinceStageStart=81")
        XCTAssertEqual(event.level, .warning)
        XCTAssertEqual(event.subsystem, .dictation)
    }
}
