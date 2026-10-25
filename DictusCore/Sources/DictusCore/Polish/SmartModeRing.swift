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
/// ### Normal nearest the top, the modes alternating outward
///
/// The finger that long-pressed the mic is on the mic's centre. Normal takes the sector
/// nearest straight up, the shortest move, and the pinned modes take the next nearest in
/// the fan's order. A tie goes to the left, so with an odd count Normal is centred and the
/// modes alternate left then right; with an even count Normal sits just left of the top
/// and the first mode just right of it. That is the keyboard fan's rule — the nearest row
/// is the cheapest — bent round an arc.
///
/// ### One function for touching and for drawing
///
/// `angleRange(ofEntry:)` is the sector a finger selects, and `beanArc(ofEntry:…)` is
/// the bean the view draws inside that same sector. The view adds no geometry of its
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

    /// The radius inside which the finger is still on the mic, and points at nothing.
    /// The mic's halo (`DictusHalo`, 92 pt across).
    public static let micRadius: CGFloat = 46

    /// The ring's inner and outer radii as drawn. The inner edge clears the halo of the
    /// mic grown for the dial (`HomeSmartModeRingStyle.openMicScale`); the outer edge
    /// leaves room for an icon and a short name.
    public static let innerRadius: CGFloat = 62

    public static let outerRadius: CGFloat = 120

    /// The radius a bean's centre line runs along, and the bean's thickness: a bean is
    /// this arc stroked `beanThickness` wide with round caps.
    public static var beanRadius: CGFloat { (innerRadius + outerRadius) / 2 }

    public static var beanThickness: CGFloat { outerRadius - innerRadius }

    /// The number of rows on the ring.
    public let entryCount: Int

    public init(entryCount: Int) {
        self.entryCount = max(0, entryCount)
    }

    /// The angular width of one row's sector: the half-circle split evenly.
    public var slotWidth: Double {
        Self.sweep / Double(max(1, entryCount))
    }

    /// Sectors numbered from the left end of the arc (0) to the right end.
    private func slotCenter(_ slot: Int) -> Double {
        Self.sweep - (Double(slot) + 0.5) * slotWidth
    }

    /// The sector each row takes, row order in, slot out. See the type's comment.
    private var slotOfEntry: [Int] {
        (0..<entryCount).sorted { lhs, rhs in
            let left = abs(slotCenter(lhs) - 90)
            let right = abs(slotCenter(rhs) - 90)
            if abs(left - right) > 1e-9 { return left < right }
            return lhs < rhs
        }
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
    /// finger is still on the mic or well below the arc.
    ///
    /// There is no outer limit: a finger that slid past the ring still points along its
    /// sector, the way a dial keeps turning when the hand drifts off it.
    public func entryIndex(at point: CGPoint) -> Int? {
        guard entryCount > 0 else { return nil }
        let distance = (point.x * point.x + point.y * point.y).squareRoot()
        guard distance > Self.micRadius else { return nil }

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

    /// Where a row's icon and name are centred: the middle of its sector, on the bean's
    /// centre line. Relative to the mic's centre, y down.
    public func labelCenter(ofEntry index: Int) -> CGPoint {
        Self.point(angle: centerAngle(ofEntry: index), radius: Self.beanRadius)
    }

    /// The width a row's label may take: the chord of its drawn bean on the centre line,
    /// never more than `maximum`.
    public func labelWidth(gapDegrees: Double, maximum: CGFloat) -> CGFloat {
        let chord = 2 * Self.beanRadius * CGFloat(sin((slotWidth - gapDegrees) * .pi / 360))
        return max(0, min(maximum, chord))
    }

    /// The centre line row `index` is drawn along, relative to the mic's centre, y down.
    ///
    /// The drawn row is a "bean": this arc stroked `beanThickness` wide with **round
    /// caps**. A round cap is a half-disc of radius `beanThickness / 2` past the line's
    /// end, so the line stops `asin(cap / beanRadius)` short of each end of the sector,
    /// less `gapDegrees / 2`: the cap then just meets that limit and two neighbours never
    /// touch. Rows too narrow for a line draw as a single point, which strokes as a disc.
    ///
    /// - Parameters:
    ///   - gapDegrees: the empty angle drawn between two neighbouring beans.
    ///   - stepDegrees: the sampling of the arc; one degree is smooth at these radii.
    public func beanArc(ofEntry index: Int,
                        gapDegrees: Double,
                        stepDegrees: Double = 1) -> [CGPoint] {
        let range = angleRange(ofEntry: index)
        let cap = asin(min(1, Double(Self.beanThickness / 2 / Self.beanRadius))) * 180 / .pi
        var from = range.lowerBound + gapDegrees / 2 + cap
        var to = range.upperBound - gapDegrees / 2 - cap
        if from > to { from = (from + to) / 2; to = from }
        let steps = max(1, Int(((to - from) / stepDegrees).rounded(.up)))
        return (0...steps).map { step in
            Self.point(angle: from + (to - from) * Double(step) / Double(steps), radius: Self.beanRadius)
        }
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

    public init(picker: SmartModeHomePicker) {
        self.picker = picker
        self.layout = SmartModeRingLayout(entryCount: picker.entries.count)
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
