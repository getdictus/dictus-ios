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

    /// Normal is always the last sector, bottom right, whatever the count, and the other
    /// rows fill the sectors from the left in the fan's order.
    func testNormalIsAlwaysTheLastSegmentBottomRight() throws {
        let pinned = try pinnedThree()
        for count in 2...4 {
            let ring = try session(pinned: Array(pinned.prefix(count - 1)))
            XCTAssertEqual(ring.entries.count, count)
            XCTAssertEqual(ring.entries[0], .normal)
            XCTAssertEqual(ring.layout.slot(ofEntry: 0), count - 1, "count \(count)")
            XCTAssertEqual(ring.layout.angleRange(ofEntry: 0).lowerBound, 0, accuracy: 1e-9)
            // Just above the right-hand horizontal, and just under it, is Normal.
            XCTAssertEqual(ring.layout.entryIndex(at: finger(5)), 0, "count \(count)")
            XCTAssertEqual(ring.layout.entryIndex(at: finger(-10)), 0, "count \(count)")
            // The modes, left to right, in the fan's order.
            XCTAssertEqual((1..<count).map(ring.layout.slot(ofEntry:)), Array(0..<(count - 1)))
        }
    }

    /// A thumb sliding to the last mode overshoots the horizontal; just under the arc
    /// still counts, pulling the finger down under the mic does not.
    func testJustUnderTheArcEndsStillCountsButBelowTheMicDoesNot() throws {
        var ring = try session(pinned: [try mode(english), try mode(SmartModeCatalogue.notesIdentifier)])

        ring.move(to: finger(195))
        XCTAssertEqual(ring.targetEntry?.id, english)
        ring.move(to: finger(-15))
        XCTAssertEqual(ring.targetEntry, .normal)
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

    /// The band on the two reference phones, from `SmartModeRingLayout.radii`.
    private var devices: [(name: String, layout: (Int) -> SmartModeRingLayout)] {
        [("15 Pro Max", 430, 600), ("SE", 375, 400)].map { name, width, above in
            let radii = SmartModeRingLayout.radii(width: width, heightAbove: above)
            return (name, { SmartModeRingLayout(entryCount: $0, innerRadius: radii.inner, outerRadius: radii.outer) })
        }
    }

    /// The view's corner rule: 10 pt inner corners (at most a quarter of the inner edge),
    /// outer corners 0.3 of the thickness and at most 20 pt.
    private func corners(_ layout: SmartModeRingLayout) -> (inner: CGFloat, outer: CGFloat) {
        layout.fittedCorners(gap: gap, innerCorner: 10, innerEdgeShare: 0.25, outerShare: 0.3, outerMaximum: 20)
    }

    private func outline(_ layout: SmartModeRingLayout, _ index: Int) -> [CGPoint] {
        let corners = corners(layout)
        return layout.segmentOutline(ofEntry: index, gap: gap,
                                     innerCornerRadius: corners.inner, outerCornerRadius: corners.outer)
    }

    /// One rule for every count: the band starts just outside the grown mic and reaches
    /// to 12 pt from the screen's sides, 62–203 pt on an iPhone 15 Pro Max and 62–175 pt
    /// on an iPhone SE, and never closer than 12 pt to the content above.
    func testTheBandFillsTheRoomAroundTheMic() {
        let proMax = SmartModeRingLayout.radii(width: 430, heightAbove: 600)
        XCTAssertEqual(proMax.inner, 62)
        XCTAssertEqual(proMax.outer, 203)
        let se = SmartModeRingLayout.radii(width: 375, heightAbove: 400)
        XCTAssertEqual(se.inner, 62)
        XCTAssertEqual(se.outer, 175)

        XCTAssertEqual(SmartModeRingLayout.radii(width: 430, heightAbove: 150).outer, 138)
        XCTAssertEqual(SmartModeRingLayout.radii(width: 430, heightAbove: 50).outer,
                       SmartModeRingLayout.minimumOuterRadius)
        XCTAssertEqual(SmartModeRingLayout.radii(width: 1000, heightAbove: 1000).outer,
                       SmartModeRingLayout.maximumOuterRadius)

        for (width, radii) in [(CGFloat(430), proMax), (375, se)] {
            // 8 to 12 pt outside the grown mic's halo (46 pt × 1.12), 12 pt from the sides.
            let gapToMic = radii.inner - 46 * 1.12
            XCTAssertTrue((8...12).contains(gapToMic), "\(gapToMic)")
            XCTAssertLessThanOrEqual(radii.outer + SmartModeRingLayout.edgeMargin, width / 2)
        }
    }

    /// Inner and outer corners follow their own rules, and each stays valid: positive,
    /// within its arc's limit, and together within the band's thickness.
    func testInnerAndOuterCornersAreDistinctAndValid() {
        for device in devices {
            for count in 2...4 {
                let layout = device.layout(count)
                let fitted = corners(layout)
                XCTAssertEqual(fitted.inner, min(10, layout.innerEdgeLength(gap: gap) * 0.25), accuracy: 0.001)
                XCTAssertEqual(fitted.outer, min(20, layout.thickness * 0.3), accuracy: 0.001, "\(device.name) \(count)")
                XCTAssertGreaterThan(fitted.inner, 0)
                XCTAssertGreaterThan(fitted.outer, fitted.inner, "\(device.name) \(count)")
                XCTAssertLessThan(fitted.inner + fitted.outer, layout.thickness)
            }
        }
        // Asking for more than the geometry allows is clamped, never honoured: the arcs'
        // limits first, then the thickness shared between the two.
        let layout = SmartModeRingLayout(entryCount: 4, innerRadius: 79, outerRadius: 135)
        let clamped = layout.clampedCorners(gap: gap, inner: 500, outer: 500)
        XCTAssertLessThanOrEqual(clamped.inner + clamped.outer, layout.thickness - 1 + 0.001)
        XCTAssertGreaterThan(clamped.inner, 0)
        XCTAssertGreaterThan(clamped.outer, 0)
        XCTAssertEqual(layout.clampedCorners(gap: gap, inner: -3, outer: -3).inner, 0)
    }

    /// Each drawn segment lies over its own sector, between the band's radii, and at
    /// least half the gap from both of the sector's edges: neighbours never overlap.
    func testEachSegmentIsDrawnInsideItsOwnSector() {
        for device in devices {
            for count in 2...4 {
                let layout = device.layout(count)
                for index in 0..<count {
                    let range = layout.angleRange(ofEntry: index)
                    for point in outline(layout, index) {
                        let radius = hypot(point.x, point.y)
                        XCTAssertGreaterThanOrEqual(radius + 0.01, layout.innerRadius)
                        XCTAssertLessThanOrEqual(radius - 0.01, layout.outerRadius)
                        for edge in [range.lowerBound, range.upperBound] {
                            let radians = edge * .pi / 180
                            let distance = abs(Double(point.x) * sin(radians) + Double(point.y) * cos(radians))
                            XCTAssertGreaterThanOrEqual(distance + 0.01, Double(gap) / 2, "\(device.name) \(count) row \(index)")
                        }
                        let degrees = atan2(Double(-point.y), Double(point.x)) * 180 / .pi
                        XCTAssertTrue(range.contains(degrees), "\(device.name) \(count) row \(index) at \(degrees)°")
                    }
                }
            }
        }
    }

    /// The gap is constant in points: the straight part of every radial edge runs exactly
    /// half the gap from the sector's edge, measured perpendicular to it, along most of
    /// the band's thickness.
    func testTheGapIsConstantInPoints() {
        for device in devices {
            for count in 2...4 {
                let layout = device.layout(count)
                let fitted = corners(layout)
                for index in 0..<count {
                    let range = layout.angleRange(ofEntry: index)
                    for edge in [range.lowerBound, range.upperBound] {
                        let radians = edge * .pi / 180
                        let onEdge = outline(layout, index).filter { point in
                            let distance = abs(Double(point.x) * sin(radians) + Double(point.y) * cos(radians))
                            return abs(distance - Double(gap) / 2) < 0.01
                        }
                        let radii = onEdge.map { Double(hypot($0.x, $0.y)) }
                        XCTAssertGreaterThanOrEqual(onEdge.count, 2, "\(device.name) \(count) row \(index)")
                        XCTAssertGreaterThan((radii.max() ?? 0) - (radii.min() ?? 0),
                                             Double(layout.thickness - fitted.inner - fitted.outer) - 1,
                                             "\(device.name) \(count) row \(index)")
                    }
                }
            }
        }
    }

    /// The segments read as one continuous band: each reaches both radii and spans most of
    /// its sector, and together they run from the left end of the half-circle to the right.
    func testTheSegmentsFormOneContinuousBand() {
        for device in devices {
            for count in 2...4 {
                let layout = device.layout(count)
                var lowest = 180.0
                var highest = 0.0
                for index in 0..<count {
                    let points = outline(layout, index)
                    let radii = points.map { Double(hypot($0.x, $0.y)) }
                    XCTAssertEqual(radii.min() ?? 0, Double(layout.innerRadius), accuracy: 0.5)
                    XCTAssertEqual(radii.max() ?? 0, Double(layout.outerRadius), accuracy: 0.5)
                    let angles = points.map { atan2(Double(-$0.y), Double($0.x)) * 180 / .pi }
                    lowest = min(lowest, angles.min() ?? 180)
                    highest = max(highest, angles.max() ?? 0)
                    let range = layout.angleRange(ofEntry: index)
                    XCTAssertGreaterThan((angles.max() ?? 0) - (angles.min() ?? 0),
                                         (range.upperBound - range.lowerBound) * 0.9, "\(device.name) \(count) row \(index)")
                    // One simple loop, not a shape folded over itself.
                    var area = 0.0
                    for (a, b) in zip(points, Array(points.dropFirst()) + [points[0]]) {
                        area += Double(a.x * b.y - b.x * a.y) / 2
                    }
                    let ring = Double(layout.outerRadius * layout.outerRadius - layout.innerRadius * layout.innerRadius)
                    let sectorArea = ring * (range.upperBound - range.lowerBound) * .pi / 360
                    XCTAssertGreaterThan(abs(area), sectorArea * 0.8, "\(device.name) \(count) row \(index)")
                    XCTAssertLessThan(abs(area), sectorArea)
                }
                XCTAssertLessThan(lowest, 2.5, "\(device.name) \(count)")
                XCTAssertGreaterThan(highest, 177.5, "\(device.name) \(count)")
            }
        }
    }

    /// The corners are rounded: no point of the outline sits in the sharp corner a square
    /// segment would have, at the inner arc or at the outer one.
    func testTheCornersAreRounded() {
        let layout = SmartModeRingLayout(entryCount: 4, innerRadius: 90, outerRadius: 154)
        let fitted = corners(layout)
        let range = layout.angleRange(ofEntry: 1)
        let points = outline(layout, 1)
        for (radius, corner) in [(Double(layout.outerRadius), fitted.outer), (Double(layout.innerRadius), fitted.inner)] {
            let sharpDegrees = range.lowerBound + asin(Double(gap) / 2 / radius) * 180 / .pi
            let sharp = CGPoint(x: cos(sharpDegrees * .pi / 180) * radius, y: -sin(sharpDegrees * .pi / 180) * radius)
            let nearest = points.map { hypot($0.x - sharp.x, $0.y - sharp.y) }.min() ?? 0
            XCTAssertGreaterThan(Double(nearest), Double(corner) * 0.3)
        }
    }

    /// Labels sit at mid-angle of their sector and mid-radius of the band.
    func testLabelsAreCentredInTheirSegments() {
        for device in devices {
            for count in 2...4 {
                let layout = device.layout(count)
                for index in 0..<count {
                    let centre = layout.labelCenter(ofEntry: index)
                    XCTAssertEqual(Double(hypot(centre.x, centre.y)), Double(layout.labelRadius), accuracy: 0.01)
                    let degrees = atan2(Double(-centre.y), Double(centre.x)) * 180 / .pi
                    XCTAssertEqual(degrees, layout.centerAngle(ofEntry: index), accuracy: 0.01)
                }
            }
        }
    }

    /// At every boundary between two drawn segments the selection switches between exactly
    /// those two rows: what is drawn, and each half of the gap beside it, is that row.
    func testSelectionMatchesTheDrawnSegmentsAtTheirBoundaries() {
        for device in devices {
            for count in 2...4 {
                let layout = device.layout(count)
                for index in 0..<count {
                    let range = layout.angleRange(ofEntry: index)
                    let angles = outline(layout, index).map { atan2(Double(-$0.y), Double($0.x)) * 180 / .pi }
                    let drawnLow = angles.min() ?? 0
                    let drawnHigh = angles.max() ?? 0
                    for degrees in [drawnLow, (drawnLow + drawnHigh) / 2, drawnHigh,
                                    range.lowerBound + 0.01, range.upperBound - 0.01] {
                        XCTAssertEqual(layout.entryIndex(at: finger(degrees, distance: Double(layout.labelRadius))), index,
                                       "\(device.name) \(count) row \(index) at \(degrees)°")
                    }
                }
            }
        }
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
        XCTAssertEqual(ring.move(to: onRow(ring, 0, distance: 110)), .none)
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
