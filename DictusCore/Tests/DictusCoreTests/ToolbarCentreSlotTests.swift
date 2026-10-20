// DictusCore/Tests/DictusCoreTests/ToolbarCentreSlotTests.swift
// The centre slot's priority table (#79, #241, #266, #315, #639).
import XCTest
@testable import DictusCore

final class ToolbarCentreSlotTests: XCTestCase {

    /// Everything competing at once. Each test below removes the winner and asserts
    /// the next one down, which is what actually tests an ordering — asserting each
    /// case in isolation would pass against any order at all.
    private func resolve(isChoosingMode: Bool = false,
                         errorMessage: String? = nil,
                         offersDictationUndo: Bool = false,
                         hasSuggestions: Bool = false,
                         dictationUnavailable: Bool = false,
                         polishUnavailable: Bool = false,
                         armedModeName: String? = nil,
                         armedModeIsEffective: Bool = true,
                         offersPanelHint: Bool = false,
                         offersDiscoveryHint: Bool = false) -> ToolbarCentreSlot {
        ToolbarCentreSlot.resolve(
            isChoosingMode: isChoosingMode,
            errorMessage: errorMessage,
            offersDictationUndo: offersDictationUndo,
            hasSuggestions: hasSuggestions,
            dictationUnavailable: dictationUnavailable,
            polishUnavailable: polishUnavailable,
            armedModeName: armedModeName,
            armedModeIsEffective: armedModeIsEffective,
            offersPanelHint: offersPanelHint,
            offersDiscoveryHint: offersDiscoveryHint
        )
    }

    // MARK: - The ladder, one rung at a time

    /// The fan is open under the user's thumb, so the bar titles it — even over an
    /// error, which by then describes a dictation that already ended.
    func testChoosingAModeOutranksEverything() {
        XCTAssertEqual(
            resolve(
                isChoosingMode: true, errorMessage: "boom", offersDictationUndo: true,
                hasSuggestions: true, polishUnavailable: true,
                armedModeName: "List", offersDiscoveryHint: true
            ),
            .choosingMode
        )
    }

    func testErrorOutranksEverything() {
        XCTAssertEqual(
            resolve(
                errorMessage: "boom", offersDictationUndo: true, hasSuggestions: true,
                polishUnavailable: true, armedModeName: "List", offersDiscoveryHint: true
            ),
            .error("boom")
        )
    }

    func testUndoOutranksSuggestions() {
        XCTAssertEqual(
            resolve(
                offersDictationUndo: true, hasSuggestions: true,
                polishUnavailable: true, armedModeName: "List", offersDiscoveryHint: true
            ),
            .dictationUndo
        )
    }

    /// Mid-word the suggestions win and the panel hint yields (#639); it comes back
    /// as soon as the slot is free.
    func testSuggestionsOutrankThePanelHint() {
        XCTAssertEqual(
            resolve(hasSuggestions: true, offersPanelHint: true, offersDiscoveryHint: true),
            .suggestions
        )
    }

    /// Same rung as the Smart Mode hint, and everything above that rung keeps
    /// winning over it.
    func testThePanelHintYieldsToEverythingAboveTheHintRung() {
        XCTAssertEqual(resolve(isChoosingMode: true, offersPanelHint: true), .choosingMode)
        XCTAssertEqual(resolve(errorMessage: "boom", offersPanelHint: true), .error("boom"))
        XCTAssertEqual(resolve(offersDictationUndo: true, offersPanelHint: true), .dictationUndo)
        XCTAssertEqual(resolve(polishUnavailable: true, offersPanelHint: true), .polishUnavailable)
        XCTAssertEqual(resolve(armedModeName: "List", offersPanelHint: true), .armedMode("List"))
        XCTAssertEqual(
            resolve(armedModeName: "List", armedModeIsEffective: false, offersPanelHint: true),
            .armedModeInactive("List")
        )
    }

    /// When both hints apply, the panel one wins: it answers a change the user has
    /// just run into (#639).
    func testThePanelHintOutranksTheSmartModeHint() {
        XCTAssertEqual(resolve(offersPanelHint: true, offersDiscoveryHint: true), .panelHint)
        XCTAssertEqual(resolve(offersPanelHint: true), .panelHint)
    }

    /// No panel hint to give: the slot falls through to the Smart Mode hint, then
    /// nothing. There is no voice note occupant left in the slot — #637's chip is gone.
    func testNoPanelHintFallsThrough() {
        XCTAssertEqual(resolve(offersPanelHint: false, offersDiscoveryHint: true), .discoveryHint)
        XCTAssertEqual(resolve(offersPanelHint: false), .empty)
    }

    func testSuggestionsOutrankThePolishNotice() {
        XCTAssertEqual(
            resolve(
                hasSuggestions: true, polishUnavailable: true,
                armedModeName: "List", offersDiscoveryHint: true
            ),
            .suggestions
        )
    }

    /// #315's notice above the armed mode's name: when polish will not run, the mode
    /// will not run either, so naming it would advertise something this process has
    /// already stopped doing.
    func testThePolishNoticeOutranksTheArmedMode() {
        XCTAssertEqual(
            resolve(polishUnavailable: true, armedModeName: "List", offersDiscoveryHint: true),
            .polishUnavailable
        )
    }

    func testTheArmedModeOutranksTheHint() {
        XCTAssertEqual(
            resolve(armedModeName: "→ EN", offersDiscoveryHint: true),
            .armedMode("→ EN")
        )
    }

    func testTheHintIsTheLastThingBeforeNothing() {
        XCTAssertEqual(resolve(offersDiscoveryHint: true), .discoveryHint)
    }

    func testNothingToSayIsEmpty() {
        XCTAssertEqual(resolve(), .empty)
    }

    // MARK: - Who takes the hamburger's 32 pt

    /// The three occupants that arrive mid-task and are read at a glance take the
    /// whole bar; the three that describe a state share it, so the panel stays
    /// reachable (#241).
    func testOnlyTheWideOccupantsEvictTheHamburger() {
        XCTAssertTrue(ToolbarCentreSlot.error("x").evictsHamburger)
        XCTAssertTrue(ToolbarCentreSlot.dictationUndo.evictsHamburger)
        XCTAssertTrue(ToolbarCentreSlot.suggestions.evictsHamburger)

        XCTAssertFalse(ToolbarCentreSlot.choosingMode.evictsHamburger)
        XCTAssertFalse(ToolbarCentreSlot.dictationUnavailable.evictsHamburger)
        // It points at the ☰, and teaches a long press on the ☰ (#639).
        XCTAssertFalse(ToolbarCentreSlot.panelHint.evictsHamburger)
        XCTAssertFalse(ToolbarCentreSlot.polishUnavailable.evictsHamburger)
        XCTAssertFalse(ToolbarCentreSlot.armedMode("List").evictsHamburger)
        XCTAssertFalse(ToolbarCentreSlot.discoveryHint.evictsHamburger)
        XCTAssertFalse(ToolbarCentreSlot.empty.evictsHamburger)
    }

    // MARK: - Armed but not in force (#423)

    /// The defect: the bar named the armed mode as though it were running while
    /// every dictation went in as Normal. Same rung, different case, so the view
    /// cannot draw one as the other.
    func testAnArmedModeThatWillNotRunGetsItsOwnCase() {
        XCTAssertEqual(
            resolve(armedModeName: "\u{2192} EN", armedModeIsEffective: false),
            .armedModeInactive("\u{2192} EN")
        )
        XCTAssertEqual(
            resolve(armedModeName: "\u{2192} EN", armedModeIsEffective: true),
            .armedMode("\u{2192} EN")
        )
    }

    /// It keeps the slot rather than falling through: the choice is still there, and
    /// re-teaching the gesture to someone who has armed a mode would be absurd.
    func testAnInactiveArmedModeStillOutranksTheDiscoveryHint() {
        XCTAssertEqual(
            resolve(armedModeName: "List", armedModeIsEffective: false, offersDiscoveryHint: true),
            .armedModeInactive("List")
        )
    }

    /// And it loses to everything `armedMode` loses to, for the same reasons.
    func testAnInactiveArmedModeYieldsToTheNoticeAboveIt() {
        XCTAssertEqual(
            resolve(
                polishUnavailable: true, armedModeName: "List", armedModeIsEffective: false
            ),
            .polishUnavailable
        )
    }

    /// Both shapes share the bar with the hamburger: neither arrives mid-task.
    func testNeitherArmedModeShapeEvictsTheHamburger() {
        XCTAssertFalse(ToolbarCentreSlot.armedMode("List").evictsHamburger)
        XCTAssertFalse(ToolbarCentreSlot.armedModeInactive("List").evictsHamburger)
    }

    // MARK: - Dictation unavailable on a pre-A14 device (#635)

    /// The brief's one explicit precedence: suggestions win over the message.
    func testSuggestionsOutrankTheDictationUnavailableMessage() {
        XCTAssertEqual(
            resolve(hasSuggestions: true, dictationUnavailable: true),
            .suggestions
        )
    }

    /// It takes the idle bar's place, and everything about dictation below it would
    /// describe a feature the device does not have.
    func testTheMessageOutranksEveryDictationOccupantOfTheIdleBar() {
        XCTAssertEqual(
            resolve(
                dictationUnavailable: true, polishUnavailable: true,
                armedModeName: "List", offersDiscoveryHint: true
            ),
            .dictationUnavailable
        )
        XCTAssertEqual(
            resolve(dictationUnavailable: true, armedModeName: "List", armedModeIsEffective: false),
            .dictationUnavailable
        )
        XCTAssertEqual(resolve(dictationUnavailable: true), .dictationUnavailable)
    }

    /// The menu still works on these devices, so the hint teaching it may finish its
    /// job first; it retires after one long press and the message takes over.
    func testThePanelHintStillTeachesTheMenuBeforeTheMessage() {
        XCTAssertEqual(
            resolve(dictationUnavailable: true, offersPanelHint: true, offersDiscoveryHint: true),
            .panelHint
        )
    }

    /// Nothing changes for a device that can dictate.
    func testADeviceThatCanDictateKeepsTheUsualLadder() {
        XCTAssertEqual(resolve(polishUnavailable: true), .polishUnavailable)
        XCTAssertEqual(resolve(offersDiscoveryHint: true), .discoveryHint)
        XCTAssertEqual(resolve(), .empty)
    }
}
