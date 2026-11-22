// DictusCore/Sources/DictusCore/KeyPlaneGeometry.swift
// Where Apple's keyboard draws its keys, per iPhone size and orientation, and the key
// grid Dictus lays out from it.
//
// The approach — a table of Apple's measured key plane per phone size, keycaps laid out
// from the bottom of the height the keyboard has, and touch targets that tile the whole
// view so the outer keys reach the screen edges — is the one Hex uses
// (https://github.com/anomalyco/hex, `ios/HEXShared/FullKeyboard/KeyboardLayout.swift`
// and `ios/HEXMobileTests/KeyboardLayoutTests.swift`, MIT, Copyright (c) 2026
// Christopher Langton). No Hex code is copied; the numbers are Dictus's own, measured on
// iOS 26.5 (Hex measured iOS 27.2, whose key plane differs).
import CoreGraphics

/// The three iPhone sizes Apple's key plane differs on, from the screen's longer side.
///
/// WHY the longer side and not the model: a keyboard extension only sees its screen, and
/// the three key planes Apple draws follow it (iOS 26.5 simulators, 2026-11-22): a
/// Home-button iPhone (667 pt, SE), the 844 to 874 pt iPhones (16e to 17 Pro), and the
/// 900 pt and taller ones (Air, Plus, Pro Max).
public enum KeyPlaneSizeClass: String, CaseIterable, Sendable {
    /// Home-button iPhones (the SE, 667 pt).
    case small
    /// 700 to 899 pt (16e, 16, 17, 17 Pro).
    case standard
    /// 900 pt and taller (Air, Plus, Pro Max).
    case large

    public static func forScreen(_ size: CGSize) -> KeyPlaneSizeClass {
        let tall = max(size.width, size.height)
        if tall < 700 { return .small }
        return tall < 900 ? .standard : .large
    }
}

public enum KeyPlaneOrientation: String, CaseIterable, Sendable {
    case portrait
    case landscape
}

/// Apple's letter keys as they sit inside Dictus's key grid: the grid is the view under the
/// toolbar whose height `KeyboardHeightProvider` declares, and that height is not this type's
/// business (#166). Everything here is measured from the grid's own edges.
///
/// Measured on the iOS 26.5 simulator, Apple's keyboard and Dictus's (develop 4ebcf0d4) in
/// the same `UITextField`, the same screen position: see
/// `docs/study-captures/disposition-apple-etude.md` on `study/disposition-apple-captures`.
public struct KeyPlaneGeometry: Equatable, Sendable {
    /// Height of a keycap.
    public let keyHeight: CGFloat
    /// From the top of one row's keycaps to the top of the next row's.
    public let rowPitch: CGFloat
    /// From the last row's keycaps down to the grid's bottom edge.
    public let bottomInset: CGFloat
    /// From the grid's side edge to the outer edge of the first (and last) keycap.
    public let sideInset: CGFloat
    /// Between two keycaps of a row.
    public let keyGap: CGFloat

    public init(keyHeight: CGFloat, rowPitch: CGFloat, bottomInset: CGFloat, sideInset: CGFloat, keyGap: CGFloat) {
        self.keyHeight = keyHeight
        self.rowPitch = rowPitch
        self.bottomInset = bottomInset
        self.sideInset = sideInset
        self.keyGap = keyGap
    }

    /// The rows this table describes. A page with another count (the digit row, #331) keeps
    /// the even grid it always had: Apple has no five-row iPhone keyboard to copy.
    public static let rowCount = 4

    /// Apple's key plane for a size and orientation (iOS 26.5).
    ///
    /// - Upright, every iPhone puts its keycaps 6.5 pt in from each side with 6 pt between
    ///   them, where Dictus's sat 3 pt in. The SE and the 17 draw them on a 54 pt pitch, 42 and
    ///   43 pt tall, and both sat 2 pt below Dictus's rows: Apple's last row ends 4 pt (SE) and
    ///   3 pt (17) above the bottom of the grid Dictus has, where Dictus left 5.5. The Pro Max
    ///   (45 pt on 56 pt, 5.5 pt under) already matched since #117 and keeps its values.
    /// - Turned, the SE's keys are 32 pt on a 40 pt pitch, 72 pt in from each side; the 17's and
    ///   the Pro Max's are 27.3 pt on a 35.3 pt pitch, 4 pt in from the grid's sides (the
    ///   grid already starts at the safe area). Every turned keyboard leaves 4 pt under its last
    ///   row. Dictus drew 36.7 pt keys on a 43.8 pt pitch there.
    public static func apple(_ sizeClass: KeyPlaneSizeClass, _ orientation: KeyPlaneOrientation) -> KeyPlaneGeometry {
        switch (sizeClass, orientation) {
        case (.small, .portrait):
            return KeyPlaneGeometry(keyHeight: 42, rowPitch: 54, bottomInset: 4, sideInset: 6.5, keyGap: 6)
        case (.standard, .portrait):
            return KeyPlaneGeometry(keyHeight: 43, rowPitch: 54, bottomInset: 3, sideInset: 6.5, keyGap: 6)
        case (.large, .portrait):
            return KeyPlaneGeometry(keyHeight: 45, rowPitch: 56, bottomInset: 5.5, sideInset: 6.5, keyGap: 6)
        case (.small, .landscape):
            return KeyPlaneGeometry(keyHeight: 32, rowPitch: 40, bottomInset: 4, sideInset: 72, keyGap: 6)
        case (.standard, .landscape), (.large, .landscape):
            // 82 and 106 device pixels at 3x: 27.33 pt keycaps on a 35.33 pt pitch.
            return KeyPlaneGeometry(keyHeight: 82.0 / 3, rowPitch: 106.0 / 3, bottomInset: 4, sideInset: 4, keyGap: 6)
        }
    }

    /// The height four rows need: keycaps, the gaps between them, and the inset under them.
    public var requiredHeight: CGFloat {
        CGFloat(Self.rowCount - 1) * rowPitch + keyHeight + bottomInset
    }
}

/// One key of the grid: where a touch types it, and where its keycap is drawn.
public struct KeyPlaneSlot: Equatable, Sendable {
    /// The touch target. The targets of a page tile the grid with no gap and no overlap.
    public let hit: CGRect
    /// The keycap, always inside `hit`.
    public let cap: CGRect

    public init(hit: CGRect, cap: CGRect) {
        self.hit = hit
        self.cap = cap
    }
}

public extension KeyPlaneGeometry {
    /// Lays out a page of keys in a grid `width` × `height`, or nil when this table does not
    /// apply (not four rows, or a grid too short for Apple's rows) and the caller keeps its
    /// even grid.
    ///
    /// `rows` holds each key's width in key units, row by row, as `KeyDefinition.size.width`
    /// gives it (a spacer is a key here).
    ///
    /// - Keycaps: the last row ends `bottomInset` above the grid's bottom, each row above it
    ///   `rowPitch` higher. Across a row, the keys share the width between the two side insets
    ///   in proportion to their units, `keyGap` apart.
    /// - Touch targets: each keycap's slot, half a gap on each side. Row boundaries are midway
    ///   between two rows of keycaps; the first row reaches up to the grid's top and the last
    ///   down to its bottom, and the first and last key of a row reach the grid's sides, so a
    ///   tap anywhere in the grid types a key (Apple's outer keys reach the edges the same way).
    func layout(rows: [[CGFloat]], width: CGFloat, height: CGFloat) -> [[KeyPlaneSlot]]? {
        guard rows.count == Self.rowCount, height >= requiredHeight, width > 2 * sideInset else { return nil }
        let rowGap = rowPitch - keyHeight
        let last = rows.count - 1
        var result: [[KeyPlaneSlot]] = []
        for (r, units) in rows.enumerated() {
            let capBottom = height - bottomInset - CGFloat(last - r) * rowPitch
            let capTop = capBottom - keyHeight
            let hitTop = r == 0 ? 0 : capTop - rowGap / 2
            let hitBottom = r == last ? height : capBottom + rowGap / 2

            let totalUnits = units.reduce(0, +)
            guard totalUnits > 0 else { return nil }
            // The slots span from half a gap outside the first keycap to half a gap outside
            // the last, so every keycap is its slot less half a gap on each side.
            let slotsStart = sideInset - keyGap / 2
            let unitWidth = (width - 2 * slotsStart) / totalUnits
            var x = slotsStart
            var row: [KeyPlaneSlot] = []
            for (i, unit) in units.enumerated() {
                let slotWidth = unit * unitWidth
                let cap = CGRect(x: x + keyGap / 2, y: capTop, width: slotWidth - keyGap, height: keyHeight)
                let hitLeft = i == 0 ? 0 : x
                let hitRight = i == units.count - 1 ? width : x + slotWidth
                let hit = CGRect(x: hitLeft, y: hitTop, width: hitRight - hitLeft, height: hitBottom - hitTop)
                row.append(KeyPlaneSlot(hit: hit, cap: cap))
                x += slotWidth
            }
            result.append(row)
        }
        return result
    }
}
