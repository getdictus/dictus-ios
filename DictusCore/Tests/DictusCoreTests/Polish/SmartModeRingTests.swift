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

    /// The finger at the centre of row `index`'s sector, from the layout's own angles.
    private func onRow(_ ring: SmartModeRingSession, _ index: Int, distance: Double = 90) -> CGPoint {
        finger(ring.layout.centerAngle(ofEntry: index), distance: distance)
    }

    private func index(_ ring: SmartModeRingSession, _ identifier: String) throws -> Int {
        try XCTUnwrap(ring.entries.firstIndex { $0.id == identifier })
    }

    // MARK: - Where the rows sit

    /// 2, 3 and 4 rows each take an equal share of the half-circle, and together their
    /// sectors tile it end to end: no hole, no overlap.
    func testTheRowsTileTheWholeHalfCircleForTwoThreeAndFourRows() {
        for count in 2...4 {
            let layout = SmartModeRingLayout(entryCount: count)
            XCTAssertEqual(layout.slotWidth, 180 / Double(count), accuracy: 1e-9)
            let ranges = (0..<count).map(layout.angleRange(ofEntry:)).sorted { $0.lowerBound < $1.lowerBound }
            XCTAssertEqual(ranges.first?.lowerBound ?? -1, 0, accuracy: 1e-9, "count \(count)")
            XCTAssertEqual(ranges.last?.upperBound ?? -1, 180, accuracy: 1e-9, "count \(count)")
            for (left, right) in zip(ranges, ranges.dropFirst()) {
                XCTAssertEqual(left.upperBound, right.lowerBound, accuracy: 1e-9, "count \(count)")
            }
            XCTAssertEqual(Set((0..<count).map(layout.slot(ofEntry:))), Set(0..<count))
        }
    }

    /// Every angle of the arc selects a row: sweeping a finger along it degree by degree
    /// never points at nothing, and each row is reached.
    func testEveryAngleOfTheArcSelectsARow() {
        for count in 2...4 {
            let layout = SmartModeRingLayout(entryCount: count)
            var seen = Set<Int>()
            for degrees in stride(from: 0.0, through: 180.0, by: 0.5) {
                let index = layout.entryIndex(at: finger(degrees))
                XCTAssertNotNil(index, "count \(count) at \(degrees)°")
                if let index { seen.insert(index) }
            }
            XCTAssertEqual(seen, Set(0..<count), "count \(count)")
        }
    }

    /// The boundary between two sectors is where the selection changes, whatever is drawn
    /// there: just either side of it selects the row on that side.
    func testTheSelectionChangesExactlyAtTheSectorBoundary() {
        let layout = SmartModeRingLayout(entryCount: 3)
        // Sectors from the left: [120, 180], [60, 120], [0, 60].
        XCTAssertEqual(layout.entryIndex(at: finger(120.5)), layout.entryIndex(at: finger(150)))
        XCTAssertEqual(layout.entryIndex(at: finger(119.5)), layout.entryIndex(at: finger(90)))
        XCTAssertEqual(layout.entryIndex(at: finger(60.5)), layout.entryIndex(at: finger(90)))
        XCTAssertEqual(layout.entryIndex(at: finger(59.5)), layout.entryIndex(at: finger(30)))
    }

    /// Normal is the row nearest straight up: centred on an odd count, just left of the
    /// top on an even one, with the first mode just right of it.
    func testNormalTakesTheSectorNearestTheTop() {
        let three = SmartModeRingLayout(entryCount: 3)
        XCTAssertEqual(three.centerAngle(ofEntry: 0), 90, accuracy: 1e-9)
        XCTAssertEqual(three.entryIndex(at: finger(90)), 0)

        let two = SmartModeRingLayout(entryCount: 2)
        XCTAssertEqual(two.centerAngle(ofEntry: 0), 135, accuracy: 1e-9)
        XCTAssertEqual(two.centerAngle(ofEntry: 1), 45, accuracy: 1e-9)

        let four = SmartModeRingLayout(entryCount: 4)
        XCTAssertEqual(four.centerAngle(ofEntry: 0), 112.5, accuracy: 1e-9)
        XCTAssertEqual(four.centerAngle(ofEntry: 1), 67.5, accuracy: 1e-9)
    }

    /// The modes follow the fan's order outward from Normal, nearest first, left first on
    /// a tie.
    func testTheModesAlternateOutwardInTheFansOrder() throws {
        let ring = try session(pinned: try pinnedThree())
        XCTAssertEqual(ring.entries.count, 4)
        let slots = (0..<4).map(ring.layout.slot(ofEntry:))
        // Slots from the left: Liste (2nd mode, outer left), Normal, → EN, Message.
        XCTAssertEqual(slots, [1, 2, 0, 3])

        let three = try session(pinned: [try mode(english), try mode(SmartModeCatalogue.notesIdentifier)])
        XCTAssertEqual((0..<3).map(three.layout.slot(ofEntry:)), [1, 0, 2])
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

    /// A little past the band's outer edge still points at the segment; well past it,
    /// nothing, and lifting there cancels.
    func testTheRadialHitRangeEndsABitPastTheBand() throws {
        var ring = try session(pinned: [try mode(english)])
        let row = try index(ring, english)
        let outer = Double(ring.layout.outerRadius)

        ring.move(to: onRow(ring, row, distance: Double(SmartModeRingLayout.micRadius) + 2))
        XCTAssertEqual(ring.targetEntry?.id, english)
        ring.move(to: onRow(ring, row, distance: outer + Double(SmartModeRingLayout.outerSlack) - 2))
        XCTAssertEqual(ring.targetEntry?.id, english)
        ring.move(to: onRow(ring, row, distance: outer + Double(SmartModeRingLayout.outerSlack) + 30))
        XCTAssertNil(ring.targetEntry)
        XCTAssertEqual(ring.commit(), .cancel)
    }

    // MARK: - What is drawn

    private let gap: CGFloat = 4
    private let corner: CGFloat = 10

    /// Each drawn segment lies over its own sector, between the band's radii, and at
    /// least half the gap from both of the sector's edges at every radius: neighbours are
    /// separated by a constant gap and never overlap.
    func testEachSegmentIsDrawnInsideItsOwnSectorWithAConstantGap() {
        for count in 2...4 {
            let layout = SmartModeRingLayout(entryCount: count, innerRadius: 62, outerRadius: 160)
            for index in 0..<count {
                let range = layout.angleRange(ofEntry: index)
                let outline = layout.segmentOutline(ofEntry: index, gap: gap, cornerRadius: corner)
                XCTAssertGreaterThan(outline.count, 8)
                for point in outline {
                    let radius = (point.x * point.x + point.y * point.y).squareRoot()
                    XCTAssertGreaterThanOrEqual(radius + 0.01, layout.innerRadius)
                    XCTAssertLessThanOrEqual(radius - 0.01, layout.outerRadius)
                    for edge in [range.lowerBound, range.upperBound] {
                        let radians = edge * .pi / 180
                        let distance = abs(Double(point.x) * sin(radians) + Double(point.y) * cos(radians))
                        XCTAssertGreaterThanOrEqual(distance + 0.01, Double(gap) / 2, "count \(count) row \(index)")
                    }
                    let degrees = atan2(Double(-point.y), Double(point.x)) * 180 / .pi
                    XCTAssertTrue(range.contains(degrees), "count \(count) row \(index) at \(degrees)°")
                }
            }
        }
    }

    /// The segments are band pieces, not bubbles: each reaches both radii, its straight
    /// edges run the band's full thickness bar the corners, and together they span the
    /// half-circle from left to right with only the gaps missing.
    func testTheSegmentsFormOneContinuousBand() {
        for count in 2...4 {
            let layout = SmartModeRingLayout(entryCount: count, innerRadius: 62, outerRadius: 160)
            var lowest = 180.0
            var highest = 0.0
            for index in 0..<count {
                let outline = layout.segmentOutline(ofEntry: index, gap: gap, cornerRadius: corner)
                let radii = outline.map { Double(($0.x * $0.x + $0.y * $0.y).squareRoot()) }
                XCTAssertEqual(radii.min() ?? 0, Double(layout.innerRadius), accuracy: 0.5)
                XCTAssertEqual(radii.max() ?? 0, Double(layout.outerRadius), accuracy: 0.5)
                let angles = outline.map { atan2(Double(-$0.y), Double($0.x)) * 180 / .pi }
                lowest = min(lowest, angles.min() ?? 180)
                highest = max(highest, angles.max() ?? 0)
                // The outer arc covers the sector less the gap and the corners, nothing
                // more: the segment is as wide as its share of the half-circle.
                let range = layout.angleRange(ofEntry: index)
                let span = (angles.max() ?? 0) - (angles.min() ?? 0)
                XCTAssertGreaterThan(span, (range.upperBound - range.lowerBound) * 0.9, "count \(count) row \(index)")
            }
            // Only half a gap is missing at each end of the half-circle.
            XCTAssertLessThan(lowest, 2.5, "count \(count)")
            XCTAssertGreaterThan(highest, 177.5, "count \(count)")
        }
    }

    /// The corners are rounded with the given radius: no point of the outline sits in the
    /// sharp corner a square segment would have.
    func testTheCornersAreRounded() {
        let layout = SmartModeRingLayout(entryCount: 3, innerRadius: 62, outerRadius: 160)
        let range = layout.angleRange(ofEntry: 0)
        let outline = layout.segmentOutline(ofEntry: 0, gap: gap, cornerRadius: corner)
        // The sharp outer corner: on the outer arc, half a gap from the low edge.
        let sharpDegrees = range.lowerBound + asin(Double(gap) / 2 / 160) * 180 / .pi
        let sharp = CGPoint(x: cos(sharpDegrees * .pi / 180) * 160, y: -sin(sharpDegrees * .pi / 180) * 160)
        let nearest = outline.map { hypot($0.x - sharp.x, $0.y - sharp.y) }.min() ?? 0
        // A corner of radius r cuts the sharp point by r(√2 − 1) at a right angle.
        XCTAssertGreaterThan(Double(nearest), Double(corner) * 0.35)
    }

    /// Labels sit at mid-angle of their sector and mid-radius of the band.
    func testLabelsAreCentredInTheirSegments() {
        for count in 2...4 {
            let layout = SmartModeRingLayout(entryCount: count, innerRadius: 62, outerRadius: 160)
            for index in 0..<count {
                let centre = layout.labelCenter(ofEntry: index)
                XCTAssertEqual(Double(hypot(centre.x, centre.y)), 111, accuracy: 0.01)
                let degrees = atan2(Double(-centre.y), Double(centre.x)) * 180 / .pi
                XCTAssertEqual(degrees, layout.centerAngle(ofEntry: index), accuracy: 0.01)
            }
        }
    }

    /// The band is sized from the screen: about three quarters of the width, clamped, and
    /// never taller than the room above the mic. The inner radius does not move.
    func testTheRadiiFollowTheScreen() {
        let proMax = SmartModeRingLayout.radii(width: 430, heightAbove: 600)
        XCTAssertEqual(proMax.outer, 430 * SmartModeRingLayout.widthShare / 2, accuracy: 0.01)
        XCTAssertEqual(proMax.inner, SmartModeRingLayout.fittedInnerRadius)

        let se = SmartModeRingLayout.radii(width: 375, heightAbove: 400)
        XCTAssertEqual(se.outer, 375 * SmartModeRingLayout.widthShare / 2, accuracy: 0.01)
        XCTAssertLessThan(se.outer, proMax.outer)

        let short = SmartModeRingLayout.radii(width: 430, heightAbove: 100)
        XCTAssertEqual(short.outer, SmartModeRingLayout.minimumOuterRadius)

        let wide = SmartModeRingLayout.radii(width: 1000, heightAbove: 1000)
        XCTAssertEqual(wide.outer, SmartModeRingLayout.maximumOuterRadius)
    }

    // MARK: - Release

    /// The keyboard fan's commitment: lifting on a mode arms it and records in it.
    func testReleasingOnAModeArmsItAndRecords() throws {
        let translate = try mode(english)
        var ring = try session(pinned: [translate])
        ring.move(to: onRow(ring, 1))

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

        ring.move(to: onRow(ring, 0))
        ring.move(to: onRow(ring, 1))
        XCTAssertEqual(ring.commit(), .cancel)
        XCTAssertEqual(SmartModeStore.armedIdentifier, english)
    }

    /// From an armed mode, Normal is a real choice: it disarms and records in Normal.
    func testReleasingOnNormalFromAnArmedModeDisarmsAndRecords() throws {
        let translate = try mode(english)
        SmartModeStore.arm(translate)
        var ring = try session(pinned: [translate], armed: translate)
        ring.move(to: onRow(ring, 0))

        XCTAssertEqual(ring.commit(), .record(.normal))
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    /// Sliding off the arc and lifting there cancels too.
    func testReleasingBelowTheArcCancels() throws {
        var ring = try session(pinned: [try mode(english)])
        ring.move(to: onRow(ring, 1))
        ring.move(to: finger(270))
        XCTAssertEqual(ring.commit(), .cancel)
        XCTAssertNil(SmartModeStore.armedIdentifier)
    }

    // MARK: - Unavailable modes

    /// A mode that cannot run is on the ring but never lights, never moves the mic, and
    /// lifting on it writes nothing and records nothing.
    func testAnUnavailableModeCannotBeSelected() throws {
        var ring = try session(pinned: [try mode(english)], armability: .unavailable(.switchedOff))
        let cue = ring.move(to: onRow(ring, 1))

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
        ring.move(to: onRow(ring, proIndex))

        XCTAssertEqual(ring.commit(), .openPaywall)
        XCTAssertNil(SmartModeStore.armedIdentifier)

        ring.move(to: onRow(ring, 1))
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
        XCTAssertEqual(ring.move(to: onRow(ring, 0)), .tick)
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

        ring.move(to: onRow(ring, 1))
        XCTAssertEqual(ring.micEntry, .mode(translate))
        XCTAssertEqual(SmartModeMicTint.tint(for: ring.micEntry), .deep)

        ring.move(to: .zero)
        XCTAssertEqual(ring.micEntry, .normal)
    }

    func testTheLineSaysWhatTheReleaseWillDoAndHowToCancel() throws {
        let translate = try mode(english)
        var ring = try session(pinned: [translate])
        XCTAssertEqual(ring.hint, .slide)

        ring.move(to: onRow(ring, 1))
        XCTAssertEqual(ring.hint, .release(.mode(translate), cancelOn: .normal))

        ring.move(to: onRow(ring, 0))
        XCTAssertEqual(ring.hint, .slide)
    }

    func testNothingPinnedSaysSo() throws {
        var ring = try session(pinned: [])
        XCTAssertEqual(ring.entries, [.normal])
        ring.move(to: onRow(ring, 0))
        XCTAssertEqual(ring.hint, .nothingPinned)
        XCTAssertEqual(ring.commit(), .cancel)
    }
}
