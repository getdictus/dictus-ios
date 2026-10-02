import XCTest
@testable import DictusCore

final class VoiceNoteStackPresentationPolicyTests: XCTestCase {

    private func decide(ready: Int = 1, onboarded: Bool = true, dictating: Bool = false,
                        presented: Bool = false, showing: Bool = false) -> VoiceNoteStackPresentationPolicy.Decision {
        VoiceNoteStackPresentationPolicy.decide(readyUnreadCount: ready, onboardingCompleted: onboarded,
                                                dictationActive: dictating, somethingPresented: presented,
                                                stackShowing: showing)
    }

    func testAReadyUnreadNotePresentsTheStackOnAnIdleApp() {
        XCTAssertEqual(decide(), .present)
        XCTAssertEqual(decide(ready: 3), .present)
    }

    func testNothingUnreadNothingToDo() {
        // In-progress notes alone do not count: the caller passes ready unread only.
        XCTAssertEqual(decide(ready: 0), .none)
        XCTAssertEqual(decide(ready: 0, dictating: true), .none)
    }

    func testItNeverInterruptsAndWaitsInstead() {
        XCTAssertEqual(decide(onboarded: false), .wait)
        XCTAssertEqual(decide(dictating: true), .wait)
        XCTAssertEqual(decide(presented: true), .wait)
    }

    func testItNeverStacksASecondPresentation() {
        XCTAssertEqual(decide(showing: true), .none)
        XCTAssertEqual(decide(dictating: true, showing: true), .none)
    }
}
