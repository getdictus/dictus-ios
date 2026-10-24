// DictusCore/Sources/DictusCore/Polish/SmartModeRing.swift
// The home mic's Smart Mode dial: sector geometry and the hold-slide-release rules (issue #489).
import CoreGraphics
import Foundation

/// Where each row of the home picker sits on the half-ring around the mic, and which row
/// a finger is on.
///
/// ### Normal on top, the modes alternating outward
///
/// The finger that long-pressed the mic is on the mic's centre. Normal goes straight
/// above it, the shortest move, and the pinned modes take the next sectors in the fan's
/// order, alternating left then right so the first pinned mode is as close as the second.
/// That is the keyboard fan's rule — the nearest row is the cheapest — bent round an arc.
///
/// ### Always an odd number of slots
///
/// The ring spans the upper half-circle and is cut into equal slots. With an even number
/// of rows Normal could not be centred, so the slot count is rounded up to the next odd
/// number and the outermost right slot stays empty: the dial is symmetric whatever the
/// user pinned, and Normal is always directly above the finger.
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

    /// The ring's inner and outer radii as drawn. The inner edge hugs the halo with a
    /// small gap; the outer edge leaves room for an icon and a short name.
    public static let innerRadius: CGFloat = 52

    public static let outerRadius: CGFloat = 120

    /// The number of rows on the ring.
    public let entryCount: Int

    public init(entryCount: Int) {
        self.entryCount = max(0, entryCount)
    }

    /// The slots the half-ring is cut into: `entryCount`, rounded up to an odd number.
    public var slotCount: Int {
        entryCount % 2 == 1 ? entryCount : entryCount + 1
    }

    /// The angular width of one slot.
    public var slotWidth: Double {
        Self.sweep / Double(max(1, slotCount))
    }

    /// The signed slot offset of row `index` from the top: 0 for Normal, positive to the
    /// left, negative to the right.
    static func slotOffset(ofEntry index: Int) -> Int {
        guard index > 0 else { return 0 }
        return index % 2 == 1 ? (index + 1) / 2 : -(index / 2)
    }

    /// The row a signed slot offset holds, or nil for an empty slot.
    func entryIndex(atSlotOffset offset: Int) -> Int? {
        let index: Int
        if offset == 0 {
            index = 0
        } else if offset > 0 {
            index = 2 * offset - 1
        } else {
            index = -2 * offset
        }
        return index < entryCount ? index : nil
    }

    /// The angle at the centre of row `index`'s sector.
    public func centerAngle(ofEntry index: Int) -> Double {
        90 + Double(Self.slotOffset(ofEntry: index)) * slotWidth
    }

    /// The angles bounding row `index`'s sector, lower first.
    public func angleRange(ofEntry index: Int) -> ClosedRange<Double> {
        let center = centerAngle(ofEntry: index)
        return (center - slotWidth / 2)...(center + slotWidth / 2)
    }

    /// The row under a finger at `point`, relative to the mic's centre, or nil when the
    /// finger is still on the mic, below the arc, or on an empty slot.
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

        let raw = (angle - 90) / slotWidth
        // An end of the arc sits exactly on a slot's outer edge; keep it in that slot.
        let half = Double(slotCount / 2)
        let offset = Int(min(half, max(-half, raw.rounded())))
        return entryIndex(atSlotOffset: offset)
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
