// DictusCore/Sources/DictusCore/Polish/SmartModeRing.swift
// The home mic's Smart Mode dial: sector geometry and the hold-slide-release rules (issue #489).
import CoreGraphics
import Foundation

/// Where each row of the home picker sits on the half-ring around the mic, which row a
/// finger is on, and the outline each row is drawn with.
///
/// ### The rows share the whole half-circle
///
/// The upper half-circle is cut into one equal sector per row, whatever the number of
/// rows (2 to 4: Normal and up to three pinned modes). Adjacent sectors touch, so every
/// angle of the arc belongs to exactly one row: a finger on the small gap drawn between
/// two rows selects the nearer one, never nothing.
///
/// ### Normal always last, bottom right
///
/// Normal takes the last sector, at the right end of the arc, whatever the number of
/// rows: the thumb of a right hand reaches it with the shortest slide, and it is in the
/// same place every time the dial opens (device feedback, 2026-10-25). The other rows
/// keep the fan's order and fill the sectors from the left. Row 0 is Normal, as in
/// `SmartModeFanLayout.entries`.
///
/// ### One function for touching and for drawing
///
/// `angleRange(ofEntry:)` is the sector a finger selects, and `segmentOutline(ofEntry:…)`
/// is the band segment the view draws over that same sector. The view adds no geometry of its
/// own: it only strokes and fills the outline it is given.
///
/// Angles are in degrees, counter-clockwise from the right-hand horizontal, with the y
/// axis pointing up: 0 is right, 90 is straight above the mic, 180 is left. Points are in
/// screen points relative to the mic's centre, with y pointing **down**, as SwiftUI
/// reports a drag.
public struct SmartModeRingLayout: Equatable, Sendable {

    /// The ring covers the upper half of the circle.
    public static let sweep: Double = 180

    /// How far below either end of the arc a finger still counts as on the end sector.
    /// A thumb sliding to the outermost mode naturally overshoots the horizontal.
    public static let endTolerance: Double = 30

    /// The radius inside which the finger is still on the mic, and points at nothing:
    /// the halo of the mic grown for the dial (92 pt × `HomeSmartModeRingStyle.openMicScale`).
    public static let micRadius: CGFloat = 52

    /// How far past the band's outer edge a finger still points at its segment. Further
    /// out, it points at nothing and lifting there cancels.
    public static let outerSlack: CGFloat = 48

    /// The band's default radii, as on an iPhone 15 Pro Max. On a device, `radii(…)`
    /// derives them from the room the Home screen has.
    public static let defaultInnerRadius: CGFloat = 90
    public static let defaultOuterRadius: CGFloat = 154

    /// The band's outer diameter as a share of the screen's width, and its bounds.
    public static let widthShare: CGFloat = 0.718
    public static let minimumOuterRadius: CGFloat = 125
    public static let maximumOuterRadius: CGFloat = 166

    /// The inner radius as a share of the outer one. The band is thin and stands clear of
    /// the mic, so that even a quarter of the half-circle (four rows, 45°) has an inner
    /// edge longer than the band is thick: a segment then reads as a piece of one ring,
    /// not as a wedge (device feedback on round 4, 2026-10-25).
    public static let innerShare: CGFloat = 90.0 / 154.0

    /// The band's radii for a Home screen `width` points wide, with `heightAbove` points
    /// between the mic's centre and the top of the area the band may cover.
    ///
    /// The outer diameter is `widthShare` of the width, no taller than the room above the
    /// mic, clamped to `minimumOuterRadius...maximumOuterRadius`, rounded to the point;
    /// the inner radius is `innerShare` of it. 90–154 pt on an iPhone 15 Pro Max, 79–135
    /// pt on an iPhone SE, whatever the number of rows.
    public static func radii(width: CGFloat, heightAbove: CGFloat) -> (inner: CGFloat, outer: CGFloat) {
        let byWidth = width * widthShare / 2
        let outer = min(maximumOuterRadius, max(minimumOuterRadius, min(byWidth, heightAbove))).rounded()
        return ((outer * innerShare).rounded(), outer)
    }

    /// The band's inner and outer radii as drawn.
    public let innerRadius: CGFloat
    public let outerRadius: CGFloat

    /// The radius a row's label is centred on: the middle of the band.
    public var labelRadius: CGFloat { (innerRadius + outerRadius) / 2 }

    /// The number of rows on the ring.
    public let entryCount: Int

    public init(entryCount: Int,
                innerRadius: CGFloat = SmartModeRingLayout.defaultInnerRadius,
                outerRadius: CGFloat = SmartModeRingLayout.defaultOuterRadius) {
        self.entryCount = max(0, entryCount)
        self.innerRadius = innerRadius
        self.outerRadius = max(outerRadius, innerRadius + 1)
    }

    /// The angular width of one row's sector: the half-circle split evenly.
    public var slotWidth: Double {
        Self.sweep / Double(max(1, entryCount))
    }

    /// Sectors numbered from the left end of the arc (0) to the right end.
    private func slotCenter(_ slot: Int) -> Double {
        Self.sweep - (Double(slot) + 0.5) * slotWidth
    }

    /// The sector each row takes, row order in, slot out: Normal (row 0) in the last
    /// sector, the other rows from the left in their order. See the type's comment.
    private var slotOfEntry: [Int] {
        guard entryCount > 0 else { return [] }
        return [entryCount - 1] + Array(0..<(entryCount - 1))
    }

    /// The sector, numbered from the left end, row `index` sits in.
    public func slot(ofEntry index: Int) -> Int {
        slotOfEntry[index]
    }

    /// The angle at the centre of row `index`'s sector.
    public func centerAngle(ofEntry index: Int) -> Double {
        slotCenter(slot(ofEntry: index))
    }

    /// The sector row `index` selects, lower angle first. The sectors of all rows tile
    /// `0...sweep` with no gap and no overlap.
    public func angleRange(ofEntry index: Int) -> ClosedRange<Double> {
        let center = centerAngle(ofEntry: index)
        return (center - slotWidth / 2)...(center + slotWidth / 2)
    }

    /// The row under a finger at `point`, relative to the mic's centre, or nil when the
    /// finger is still on the mic, well below the arc, or well past the band
    /// (`outerSlack`). The gaps drawn between segments belong to the segments: the
    /// sectors touch.
    public func entryIndex(at point: CGPoint) -> Int? {
        guard entryCount > 0 else { return nil }
        let distance = (point.x * point.x + point.y * point.y).squareRoot()
        guard distance > Self.micRadius, distance <= outerRadius + Self.outerSlack else { return nil }

        var angle = atan2(Double(-point.y), Double(point.x)) * 180 / .pi
        // Lower-left quadrant reads as just past 180, not as just past -90.
        if angle < -90 { angle += 360 }
        if angle < 0 {
            guard angle >= -Self.endTolerance else { return nil }
            angle = 0
        } else if angle > Self.sweep {
            guard angle <= Self.sweep + Self.endTolerance else { return nil }
            angle = Self.sweep
        }

        let slot = min(entryCount - 1, max(0, Int((Self.sweep - angle) / slotWidth)))
        return slotOfEntry.firstIndex(of: slot)
    }

    /// Where a row's icon and name are centred: mid-angle of its sector, mid-radius of
    /// the band. Relative to the mic's centre, y down.
    public func labelCenter(ofEntry index: Int) -> CGPoint {
        Self.point(angle: centerAngle(ofEntry: index), radius: labelRadius)
    }

    /// The width a row's label may take: the chord of its segment at the label's radius,
    /// less the gap and `padding` on each side, never more than `maximum`.
    ///
    /// Measured at mid-radius because that is where a segment is widest once its corners
    /// are nearly fully round: the corner circles are centred close to that radius.
    public func labelWidth(gap: CGFloat, padding: CGFloat, maximum: CGFloat) -> CGFloat {
        let chord = 2 * labelRadius * CGFloat(sin(slotWidth * .pi / 360))
        return max(0, min(maximum, chord - gap - 2 * padding))
    }

    /// The band's radial thickness.
    public var thickness: CGFloat { outerRadius - innerRadius }

    /// The length of a segment's inner edge, between its two radial edges, before its
    /// corners are rounded.
    public func innerEdgeLength(gap: CGFloat) -> CGFloat {
        innerRadius * CGFloat(slotWidth * .pi / 180) - gap
    }

    /// The corner radii a segment is drawn with: small inner corners, larger outer ones.
    ///
    /// - **Inner:** `innerCorner`, but never more than `innerEdgeShare` of the inner
    ///   edge, so a short inner edge keeps a straight part and the segment does not turn
    ///   into a wedge.
    /// - **Outer:** `outerShare` of the band's thickness.
    ///
    /// Both then go through `clampedCorners(gap:inner:outer:)`.
    public func fittedCorners(gap: CGFloat,
                              innerCorner: CGFloat,
                              innerEdgeShare: CGFloat,
                              outerShare: CGFloat) -> (inner: CGFloat, outer: CGFloat) {
        clampedCorners(
            gap: gap,
            inner: min(innerCorner, innerEdgeLength(gap: gap) * innerEdgeShare),
            outer: thickness * outerShare
        )
    }

    /// The inner and outer corner radii, each clamped so the outline never folds over
    /// itself.
    ///
    /// - **The inner arc.** The two inner corners must not cross: each is a circle of
    ///   radius `c` centred at `innerRadius + c`, `gap / 2 + c` from its edge, so they
    ///   meet when `gap / 2 + c = (innerRadius + c) · sin(slot / 2)`, i.e.
    ///   `c ≤ (innerRadius · sin(slot / 2) − gap / 2) / (1 − sin(slot / 2))`.
    /// - **The outer arc**, the same way with centres at `outerRadius − c`:
    ///   `c ≤ (outerRadius · sin(slot / 2) − gap / 2) / (1 + sin(slot / 2))`.
    /// - **The thickness.** An inner and an outer corner share each radial edge: together
    ///   they leave at least a point of it, or both shrink in proportion.
    ///
    /// Half a point is kept back from each arc limit so the arcs between corners never
    /// vanish.
    public func clampedCorners(gap: CGFloat, inner: CGFloat, outer: CGFloat) -> (inner: CGFloat, outer: CGFloat) {
        let half = Double(gap) / 2
        let sine = sin(slotWidth * .pi / 360)
        let byInnerArc = sine < 1 ? (Double(innerRadius) * sine - half) / (1 - sine) : Double(thickness)
        let byOuterArc = (Double(outerRadius) * sine - half) / (1 + sine)
        var innerCorner = max(0, min(Double(inner), byInnerArc - 0.5))
        var outerCorner = max(0, min(Double(outer), byOuterArc - 0.5))
        let room = Double(thickness) - 1
        if innerCorner + outerCorner > room {
            let ratio = room / (innerCorner + outerCorner)
            innerCorner *= ratio
            outerCorner *= ratio
        }
        return (CGFloat(innerCorner), CGFloat(outerCorner))
    }

    /// The outline of row `index`'s band segment, relative to the mic's centre, y down.
    ///
    /// A segment is the annulus between `innerRadius` and `outerRadius` over the row's
    /// sector, with two changes:
    ///
    /// - **A constant gap, in points.** Each radial edge is the sector's edge moved
    ///   `gap / 2` into the segment, parallel to it. Two neighbours' facing edges are then
    ///   `gap` points apart, measured perpendicular to them, at every radius — the chord
    ///   across the gap, not an angle (an angular inset would widen toward the outside).
    /// - **Rounded corners.** Each of the four corners is a circle tangent to its edge
    ///   and to its arc: `outerCornerRadius` inside the outer arc, `innerCornerRadius`
    ///   outside the inner one, both clamped by `clampedCorners(gap:inner:outer:)`.
    ///
    /// The arcs and corners are sampled every `stepDegrees`, so the outline is a closed
    /// polygon the view fills as is. Every point lies inside the sector, between the
    /// radii, and at least `gap / 2` from both of the sector's edges.
    public func segmentOutline(ofEntry index: Int,
                               gap: CGFloat,
                               innerCornerRadius: CGFloat,
                               outerCornerRadius: CGFloat,
                               stepDegrees: Double = 1) -> [CGPoint] {
        let range = angleRange(ofEntry: index)
        let half = Double(gap) / 2
        let corners = clampedCorners(gap: gap, inner: innerCornerRadius, outer: outerCornerRadius)
        let innerCorner = Double(corners.inner)
        let outerCorner = Double(corners.outer)
        let outer = Double(outerRadius)
        let inner = Double(innerRadius)

        typealias Vector = (x: Double, y: Double)
        func unit(_ degrees: Double) -> Vector {
            (cos(degrees * .pi / 180), sin(degrees * .pi / 180))
        }
        func add(_ a: Vector, _ b: Vector, _ k: Double) -> Vector { (a.x + b.x * k, a.y + b.y * k) }
        func scale(_ a: Vector, _ k: Double) -> Vector { (a.x * k, a.y * k) }
        func length(_ a: Vector) -> Double { (a.x * a.x + a.y * a.y).squareRoot() }
        func angle(_ a: Vector) -> Double { atan2(a.y, a.x) * 180 / .pi }

        /// The corner on the edge at `edge`, `inward` pointing into the segment, touching
        /// the circle of `radius` from inside (outer arc) or outside (inner arc).
        struct Corner { let center: Vector; let onArc: Vector; let onEdge: Vector }
        func makeCorner(edge: Double, inward: Double, radius: Double, insideCircle: Bool) -> Corner {
            let corner = insideCircle ? outerCorner : innerCorner
            let along = unit(edge)
            let normal = scale(unit(edge + 90), inward)
            let toCenter = insideCircle ? radius - corner : radius + corner
            let offset = half + corner
            let distance = max(0, toCenter * toCenter - offset * offset).squareRoot()
            let center = add(scale(along, distance), normal, offset)
            let onArc = scale(center, radius / max(length(center), 1e-9))
            let onEdge = add(scale(along, distance), normal, half)
            return Corner(center: center, onArc: onArc, onEdge: onEdge)
        }
        /// The short way round `center` from `start` to `end`.
        func sweep(from start: Vector, to end: Vector, around center: Vector, radius: Double) -> [Vector] {
            let from = angle((start.x - center.x, start.y - center.y))
            var delta = angle((end.x - center.x, end.y - center.y)) - from
            while delta > 180 { delta -= 360 }
            while delta < -180 { delta += 360 }
            let steps = max(1, Int((abs(delta) / stepDegrees).rounded(.up)))
            return (0...steps).map { step in
                add(center, unit(from + delta * Double(step) / Double(steps)), radius)
            }
        }
        func arc(radius: Double, from start: Double, to end: Double) -> [Vector] {
            let steps = max(1, Int((abs(end - start) / stepDegrees).rounded(.up)))
            return (0...steps).map { scale(unit(start + (end - start) * Double($0) / Double(steps)), radius) }
        }

        let lowOuter = makeCorner(edge: range.lowerBound, inward: 1, radius: outer, insideCircle: true)
        let highOuter = makeCorner(edge: range.upperBound, inward: -1, radius: outer, insideCircle: true)
        let highInner = makeCorner(edge: range.upperBound, inward: -1, radius: inner, insideCircle: false)
        let lowInner = makeCorner(edge: range.lowerBound, inward: 1, radius: inner, insideCircle: false)

        var points: [Vector] = []
        points += arc(radius: outer, from: angle(lowOuter.onArc), to: angle(highOuter.onArc))
        points += sweep(from: highOuter.onArc, to: highOuter.onEdge, around: highOuter.center, radius: outerCorner)
        points += sweep(from: highInner.onEdge, to: highInner.onArc, around: highInner.center, radius: innerCorner)
        points += arc(radius: inner, from: angle(highInner.onArc), to: angle(lowInner.onArc))
        points += sweep(from: lowInner.onArc, to: lowInner.onEdge, around: lowInner.center, radius: innerCorner)
        points += sweep(from: lowOuter.onEdge, to: lowOuter.onArc, around: lowOuter.center, radius: outerCorner)
        return points.map { CGPoint(x: $0.x, y: -$0.y) }
    }

    /// The point at `angle` and `radius` from the mic's centre, y down.
    static func point(angle: Double, radius: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: CGFloat(cos(radians)) * radius, y: -CGFloat(sin(radians)) * radius)
    }
}

/// What the haptic engine should do after the finger moved.
public enum SmartModeRingCue: Equatable, Sendable {

    /// Nothing changed that the hand should feel.
    case none

    /// The finger reached a new row it may release on: the picker's selection tick.
    case tick
}

/// What lifting the finger does.
public enum SmartModeRingRelease: Equatable, Sendable {

    /// Nothing: no mode change, no recording. The finger never left the mic, slid off the
    /// arc, or came back to the mode it started on.
    case cancel

    /// The finger lifted on a row that cannot be chosen right now. Nothing is written and
    /// nothing records; the caller says no with the refusal haptic.
    case refused

    /// Arm `entry` (Normal disarms) and start a dictation in it, the keyboard fan's
    /// release.
    case record(SmartModeFanEntry)

    /// The Dictus Pro row: nothing is written, the caller opens the paywall.
    case openPaywall
}

/// What the line under the ring says.
public enum SmartModeRingHint: Equatable, Sendable {

    /// The finger points at nothing it could release on yet.
    case slide

    /// The ring holds Normal alone: nothing is pinned.
    case nothingPinned

    /// The finger is on a row that cannot be chosen. The reason, or nil when the row is
    /// behind Dictus Pro (the non-subscriber's ring).
    case unavailable(SmartModeUnavailableReason?)

    /// Lifting now would do `entry`; coming back to `cancelOn` would not.
    case release(SmartModeFanEntry, cancelOn: SmartModeFanEntry)
}

/// How the mic is filled.
public enum SmartModeMicTint: Equatable, Sendable {

    /// The resting accent blue: Normal, and the Dictus Pro row.
    case accent

    /// The brand gradient's deep blue: a Smart Mode will run. Still the Dictus palette,
    /// never a colour of its own per mode — #79 refused a foreign colour on the mic twice.
    case deep

    public static func tint(for entry: SmartModeFanEntry) -> SmartModeMicTint {
        if case .mode = entry { return .deep }
        return .accent
    }
}

/// One long press on the home mic, from the moment the ring opens to the release.
///
/// A value: the view feeds it finger positions and reads back what to draw, what to feel
/// and, on release, what to do. Every rule lives here so it can be tested without a
/// touch screen.
public struct SmartModeRingSession: Equatable, Sendable {

    /// The rows, their gate and the store writes: the keyboard fan's model.
    public let picker: SmartModeHomePicker

    public let layout: SmartModeRingLayout

    /// The row the mic showed when the finger went down: what a dictation would run.
    /// Releasing on it changes nothing.
    public let startIndex: Int

    /// The row under the finger, selectable or not, or nil.
    public private(set) var targetIndex: Int?

    public init(picker: SmartModeHomePicker,
                innerRadius: CGFloat = SmartModeRingLayout.defaultInnerRadius,
                outerRadius: CGFloat = SmartModeRingLayout.defaultOuterRadius) {
        self.picker = picker
        self.layout = SmartModeRingLayout(
            entryCount: picker.entries.count, innerRadius: innerRadius, outerRadius: outerRadius
        )
        self.startIndex = picker.entries.firstIndex { $0.id == picker.effectiveIdentifier } ?? 0
        self.targetIndex = nil
    }

    public var entries: [SmartModeFanEntry] { picker.entries }

    public var startEntry: SmartModeFanEntry { entries[startIndex] }

    public var targetEntry: SmartModeFanEntry? {
        targetIndex.map { entries[$0] }
    }

    /// Whether row `index` may be released on.
    public func isSelectable(_ index: Int) -> Bool {
        entries.indices.contains(index) && picker.canChoose(entries[index])
    }

    /// The sector to light: the target, only when it may be chosen.
    public var highlightedIndex: Int? {
        guard let targetIndex, isSelectable(targetIndex) else { return nil }
        return targetIndex
    }

    /// What the mic shows while the ring is open: the lit row, else the starting one.
    public var micEntry: SmartModeFanEntry {
        highlightedIndex.map { entries[$0] } ?? startEntry
    }

    /// Track the finger at `point`, relative to the mic's centre.
    @discardableResult
    public mutating func move(to point: CGPoint) -> SmartModeRingCue {
        let next = layout.entryIndex(at: point)
        guard next != targetIndex else { return .none }
        targetIndex = next
        guard let next, isSelectable(next) else { return .none }
        return .tick
    }

    /// What lifting the finger now does.
    public var release: SmartModeRingRelease {
        guard let targetIndex, targetIndex != startIndex else { return .cancel }
        let entry = entries[targetIndex]
        guard picker.canChoose(entry) else { return .refused }
        if case .pro = entry { return .openPaywall }
        return .record(entry)
    }

    /// The line under the ring.
    public var hint: SmartModeRingHint {
        if picker.nothingPinned { return .nothingPinned }
        guard let targetIndex, targetIndex != startIndex else { return .slide }
        let entry = entries[targetIndex]
        guard picker.canChoose(entry) else { return .unavailable(picker.unavailableReason) }
        return .release(entry, cancelOn: startEntry)
    }

    /// Apply the release: write the store for a recording release, nothing otherwise.
    /// The caller starts the dictation, which reads the armed mode like any other.
    @discardableResult
    public func commit() -> SmartModeRingRelease {
        let outcome = release
        if case .record(let entry) = outcome {
            picker.choose(entry)
        }
        return outcome
    }
}
