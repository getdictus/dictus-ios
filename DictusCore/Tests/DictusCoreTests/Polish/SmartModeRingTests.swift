// DictusCore/Tests/DictusCoreTests/Polish/SmartModeRingTests.swift
// The home mic's Smart Mode dial: hold, slide onto a sector, release (issue #489).
//
// Points are relative to the mic's centre with y pointing down, as a drag reports them.
// The commit tests write the real App Group suite, so setUp/tearDown remove the keys, as
// `SmartModeHomePickerTests` does.
import CoreGraphics
import XCTest
@testable import DictusCore

final class SmartModeRingTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults }

    private let keys = [
        SharedKeys.smartModeArmed, SharedKeys.smartModePinned, SharedKeys.smartModeSkipAnnounced
    ]

    override func setUp() {
        super.setUp()
        keys.forEach { defaults.removeObject(forKey: $0) }
    }

    override func tearDown() {
        keys.forEach { defaults.removeObject(forKey: $0) }
        super.tearDown()
    }

    // MARK: - Fixtures

    private func mode(_ identifier: String) throws -> SmartMode {
        try XCTUnwrap(SmartModeCatalogue.mode(withIdentifier: identifier))
    }

    private var english: String { SmartModeCatalogue.translateIdentifier(target: .english) }

    private func pinnedThree() throws -> [SmartMode] {
        [try mode(english), try mode(SmartModeCatalogue.notesIdentifier),
         try mode(SmartModeCatalogue.messageIdentifier)]
    }

    private func session(pinned: [SmartMode],
                         armed: SmartMode? = nil,
                         armability: SmartModeArmability = .armable) throws -> SmartModeRingSession {
        let picker = try XCTUnwrap(SmartModeHomePicker.resolve(
            pinned: pinned, armed: armed, armability: armability, dictation: armability,
            paywallVisible: true, marksTrialPro: false
        ))
        return SmartModeRingSession(picker: picker)
    }

    /// A finger `distance` points from the mic's centre at `degrees` (0 right, 90 up).
    private func finger(_ degrees: Double, distance: Double = 90) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: cos(radians) * distance, y: -sin(radians) * distance)
    }

    private let straightUp = CGPoint(x: 0, y: -90)

    // MARK: - Where the rows sit

    /// Normal is straight above the finger, the first pinned mode just left of it, the
    /// second just right: the nearest sectors go to the first rows, as in the fan.
    func testNormalIsOnTopAndTheModesAlternateLeftThenRight() throws {
        var ring = try session(pinned: try pinnedThree())

        ring.move(to: straightUp)
        XCTAssertEqual(ring.targetEntry, .normal)

        let w = ring.layout.slotWidth
        ring.move(to: finger(90 + w))
        XCTAssertEqual(ring.targetEntry?.id, english)
        ring.move(to: finger(90 - w))
        XCTAssertEqual(ring.targetEntry?.id, SmartModeCatalogue.notesIdentifier)
        ring.move(to: finger(90 + 2 * w))
        XCTAssertEqual(ring.targetEntry?.id, SmartModeCatalogue.messageIdentifier)
    }

    /// With an even number of rows Normal stays centred and the outermost right slot is
    /// empty, pointing at nothing.
    func testAnEvenRowCountLeavesTheOuterRightSlotEmpty() throws {
        var ring = try session(pinned: try pinnedThree())
        XCTAssertEqual(ring.entries.count, 4)

        ring.move(to: finger(5))
        XCTAssertNil(ring.targetEntry)
        ring.move(to: finger(175))
        XCTAssertEqual(ring.targetEntry?.id, SmartModeCatalogue.messageIdentifier)
    }

    /// A thumb sliding to the last mode overshoots the horizontal; just under the arc
    /// still counts, pulling the finger down under the mic does not.
    func testJustUnderTheArcEndsStillCountsButBelowTheMicDoesNot() throws {
        var ring = try session(pinned: [try mode(english), try mode(SmartModeCatalogue.notesIdentifier)])

        ring.move(to: finger(195))
        XCTAssertEqual(ring.targetEntry?.id, english)
        ring.move(to: finger(-15))
        XCTAssertEqual(ring.targetEntry?.id, SmartModeCatalogue.notesIdentifier)
        ring.move(to: finger(270))
        XCTAssertNil(ring.targetEntry)
    }

    /// A finger that slid past the ring's outer edge still points along its sector.
    func testFarPastTheRingStillPointsAlongTheSector() throws {
        var ring = try session(pinned: [try mode(english)])
        ring.move(to: finger(90 + ring.layout.slotWidth, distance: 400))
        XCTAssertEqual(ring.targetEntry?.id, english)
    }

    // MARK: - Release

    /// The keyboard fan's commitment: lifting on a mode arms it and records in it.
    func testReleasingOnAModeArmsItAndRecords() throws {
        let translate = try mode(english)
        var ring = try session(pinned: [translate])
        ring.move(to: finger(90 + ring.layout.slotWidth))

        XCTAssertEqual(ring.commit(), .record(.mode(translate)))
        XCTAssertEqual(SmartModeStore.armedIdentifier, english)
    }

    /// Lifting without having left the mic is a plain long press: nothing happens.
    func testReleasingWithoutLeavingTheMicCancels() throws {
        let translate = try mode(english)
        var ring = try session(pinned: [translate])
        ring.move(to: CGPoint(x: 10, y: -20))

        XCTAssertEqual(ring.commit(), .cancel)
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    /// Back on the mode the mic started on is the way out.
    func testReleasingBackOnTheStartingModeCancels() throws {
        let translate = try mode(english)
        SmartModeStore.arm(translate)
        var ring = try session(pinned: [translate], armed: translate)
        XCTAssertEqual(ring.startEntry, .mode(translate))

        ring.move(to: straightUp)
        ring.move(to: finger(90 + ring.layout.slotWidth))
        XCTAssertEqual(ring.commit(), .cancel)
        XCTAssertEqual(SmartModeStore.armedIdentifier, english)
    }

    /// From an armed mode, Normal is a real choice: it disarms and records in Normal.
    func testReleasingOnNormalFromAnArmedModeDisarmsAndRecords() throws {
        let translate = try mode(english)
        SmartModeStore.arm(translate)
        var ring = try session(pinned: [translate], armed: translate)
        ring.move(to: straightUp)

        XCTAssertEqual(ring.commit(), .record(.normal))
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    /// Sliding off the arc and lifting there cancels too.
    func testReleasingBelowTheArcCancels() throws {
        var ring = try session(pinned: [try mode(english)])
        ring.move(to: finger(90 + ring.layout.slotWidth))
        ring.move(to: finger(270))
        XCTAssertEqual(ring.commit(), .cancel)
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    // MARK: - Unavailable modes

    /// A mode that cannot run is on the ring but never lights, never moves the mic, and
    /// lifting on it writes nothing and records nothing.
    func testAnUnavailableModeCannotBeSelected() throws {
        var ring = try session(pinned: [try mode(english)], armability: .unavailable(.switchedOff))
        let cue = ring.move(to: finger(90 + ring.layout.slotWidth))

        XCTAssertEqual(ring.targetEntry?.id, english)
        XCTAssertEqual(cue, .none)
        XCTAssertNil(ring.highlightedIndex)
        XCTAssertEqual(ring.micEntry, .normal)
        XCTAssertEqual(ring.hint, .unavailable(.switchedOff))
        XCTAssertEqual(ring.commit(), .refused)
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    /// The non-subscriber's ring: modes are greyed, the Dictus Pro sector leads to the
    /// paywall and writes nothing.
    func testANonSubscriberReachesThePaywallAndArmsNothing() throws {
        var ring = try session(pinned: [], armability: .unavailable(.notSubscribed))
        let proIndex = try XCTUnwrap(ring.entries.firstIndex(of: .pro))
        ring.move(to: finger(ring.layout.centerAngle(ofEntry: proIndex)))

        XCTAssertEqual(ring.commit(), .openPaywall)
        XCTAssertNil(SmartModeStore.armedIdentifier)

        ring.move(to: finger(ring.layout.centerAngle(ofEntry: 1)))
        XCTAssertEqual(ring.hint, .unavailable(nil))
        XCTAssertEqual(ring.commit(), .refused)
    }

    // MARK: - Haptics

    /// One tick per sector entered, none while the finger stays on the same sector, none
    /// while it is on the mic or on a sector it may not release on.
    func testOneTickPerSelectableSectorChange() throws {
        var ring = try session(pinned: [try mode(english), try mode(SmartModeCatalogue.notesIdentifier)])
        let w = ring.layout.slotWidth

        XCTAssertEqual(ring.move(to: CGPoint(x: 0, y: -10)), .none)
        XCTAssertEqual(ring.move(to: straightUp), .tick)
        XCTAssertEqual(ring.move(to: CGPoint(x: 3, y: -100)), .none)
        XCTAssertEqual(ring.move(to: finger(90 + w)), .tick)
        XCTAssertEqual(ring.move(to: finger(90 - w)), .tick)
        XCTAssertEqual(ring.move(to: finger(270)), .none)
        XCTAssertEqual(ring.move(to: finger(90 - w)), .tick)
    }

    // MARK: - What the mic and the line show

    /// The mic takes the lit mode's look, and goes back to the starting one off the arc.
    func testTheMicTakesTheTargetedModeAndItsDeepTint() throws {
        let translate = try mode(english)
        var ring = try session(pinned: [translate])
        XCTAssertEqual(ring.micEntry, .normal)
        XCTAssertEqual(SmartModeMicTint.tint(for: ring.micEntry), .accent)

        ring.move(to: finger(90 + ring.layout.slotWidth))
        XCTAssertEqual(ring.micEntry, .mode(translate))
        XCTAssertEqual(SmartModeMicTint.tint(for: ring.micEntry), .deep)

        ring.move(to: .zero)
        XCTAssertEqual(ring.micEntry, .normal)
    }

    func testTheLineSaysWhatTheReleaseWillDoAndHowToCancel() throws {
        let translate = try mode(english)
        var ring = try session(pinned: [translate])
        XCTAssertEqual(ring.hint, .slide)

        ring.move(to: finger(90 + ring.layout.slotWidth))
        XCTAssertEqual(ring.hint, .release(.mode(translate), cancelOn: .normal))

        ring.move(to: straightUp)
        XCTAssertEqual(ring.hint, .slide)
    }

    func testNothingPinnedSaysSo() throws {
        var ring = try session(pinned: [])
        XCTAssertEqual(ring.entries, [.normal])
        ring.move(to: straightUp)
        XCTAssertEqual(ring.hint, .nothingPinned)
        XCTAssertEqual(ring.commit(), .cancel)
    }
}
