// DictusCore/Tests/DictusCoreTests/KeyPlaneGeometryTests.swift
// Apple's key plane per iPhone size and orientation, and the grid Dictus lays out from it.
// Modelled on Hex's KeyboardLayoutTests (https://github.com/anomalyco/hex, MIT): the
// measured numbers are pinned, and every layout must tile the grid with touch targets
// that leave no dead zone and never overlap, keycaps inside them.
import CoreGraphics
import XCTest
@testable import DictusCore

final class KeyPlaneGeometryTests: XCTestCase {

    private let accuracy: CGFloat = 0.001

    // MARK: - Fixtures

    /// The AZERTY letter page: two rows of ten, shift and delete at 1.5 around seven letters,
    /// then globe, 123, emoji, space, return (`KeyboardLayouts`).
    private let azerty: [[CGFloat]] = [
        Array(repeating: 1, count: 10),
        Array(repeating: 1, count: 10),
        [1.5] + Array(repeating: 1, count: 7) + [1.5],
        [1, 1.25, 1.25, 4, 2]
    ]
    /// QWERTY: row 2 is nine letters between two half-unit spacers.
    private let qwerty: [[CGFloat]] = [
        Array(repeating: 1, count: 10),
        [0.5] + Array(repeating: 1, count: 9) + [0.5],
        [1.5] + Array(repeating: 1, count: 7) + [1.5],
        [1.25, 1.25, 5.5, 2]
    ]

    /// The grids Dictus lays its keys in (`KeyboardHeightProvider`, unchanged by this table),
    /// with the width the keyboard view gets on each simulator measured for the study.
    private let grids: [(KeyPlaneSizeClass, KeyPlaneOrientation, CGSize)] = [
        (.small, .portrait, CGSize(width: 375, height: 216)),
        (.standard, .portrait, CGSize(width: 402, height: 216)),
        (.large, .portrait, CGSize(width: 440, height: 224)),
        (.small, .landscape, CGSize(width: 667, height: 175)),
        (.standard, .landscape, CGSize(width: 874 - 2 * 75.33, height: 175)),
        (.large, .landscape, CGSize(width: 956 - 2 * 117.33, height: 175))
    ]

    private func layout(_ rows: [[CGFloat]], _ grid: (KeyPlaneSizeClass, KeyPlaneOrientation, CGSize)) -> [[KeyPlaneSlot]] {
        guard let slots = KeyPlaneGeometry.apple(grid.0, grid.1).layout(rows: rows, width: grid.2.width, height: grid.2.height) else {
            XCTFail("no layout for \(grid)")
            return []
        }
        return slots
    }

    // MARK: - Size classes

    func testSizeClassFollowsTheScreensLongerSide() {
        XCTAssertEqual(KeyPlaneSizeClass.forScreen(CGSize(width: 375, height: 667)), .small)
        XCTAssertEqual(KeyPlaneSizeClass.forScreen(CGSize(width: 667, height: 375)), .small)
        XCTAssertEqual(KeyPlaneSizeClass.forScreen(CGSize(width: 390, height: 844)), .standard)
        XCTAssertEqual(KeyPlaneSizeClass.forScreen(CGSize(width: 402, height: 874)), .standard)
        XCTAssertEqual(KeyPlaneSizeClass.forScreen(CGSize(width: 874, height: 402)), .standard)
        XCTAssertEqual(KeyPlaneSizeClass.forScreen(CGSize(width: 420, height: 912)), .large)
        XCTAssertEqual(KeyPlaneSizeClass.forScreen(CGSize(width: 440, height: 956)), .large)
    }

    // MARK: - Apple's numbers (iOS 26.5 simulators, 2026-11-22)

    /// Upright, on the screen: SE rows from 459 pt (grid top 451), 17 from 591 (583),
    /// Pro Max from 663 (657); keycaps 6.5 pt in from each side.
    func testPortraitRowsSitOnApplesRows() {
        let se = layout(azerty, grids[0])
        XCTAssertEqual(451 + se[0][0].cap.minY, 459, accuracy: accuracy)
        XCTAssertEqual(se[0][0].cap.height, 42, accuracy: accuracy)
        XCTAssertEqual(se[1][0].cap.minY - se[0][0].cap.minY, 54, accuracy: accuracy)
        XCTAssertEqual(451 + se[3][0].cap.maxY, 663, accuracy: accuracy)
        XCTAssertEqual(se[0][0].cap.minX, 6.5, accuracy: accuracy)
        XCTAssertEqual(se[0][9].cap.maxX, 375 - 6.5, accuracy: accuracy)
        // 10 keycaps and 9 gaps of 6 pt in 375 − 13 pt.
        XCTAssertEqual(se[0][0].cap.width, (375 - 13 - 54) / 10, accuracy: accuracy)

        let iPhone17 = layout(azerty, grids[1])
        XCTAssertEqual(583 + iPhone17[0][0].cap.minY, 591, accuracy: accuracy)
        XCTAssertEqual(iPhone17[0][0].cap.height, 43, accuracy: accuracy)
        XCTAssertEqual(583 + iPhone17[3][0].cap.minY, 753, accuracy: accuracy)
        XCTAssertEqual(iPhone17[0][0].cap.minX, 6.5, accuracy: accuracy)

        let proMax = layout(azerty, grids[2])
        // Already Apple's before this table (#117): 5.5 pt under row 4, 45 pt on 56 pt.
        XCTAssertEqual(657 + proMax[0][0].cap.minY, 662.5, accuracy: accuracy)
        XCTAssertEqual(proMax[0][0].cap.height, 45, accuracy: accuracy)
        XCTAssertEqual(proMax[1][0].cap.minY - proMax[0][0].cap.minY, 56, accuracy: accuracy)
        XCTAssertEqual(proMax[0][0].cap.minX, 6.5, accuracy: accuracy)
    }

    /// Turned: the SE's keys 72 pt in from each side, 32 pt on 40 pt from 219 pt (grid top
    /// 200); the 17's 27.3 pt on 35.3 pt from 244 pt (grid top 206), 4 pt in from the grid.
    func testLandscapeRowsSitOnApplesRows() {
        let se = layout(azerty, grids[3])
        XCTAssertEqual(200 + se[0][0].cap.minY, 219, accuracy: accuracy)
        XCTAssertEqual(se[0][0].cap.height, 32, accuracy: accuracy)
        XCTAssertEqual(se[1][0].cap.minY - se[0][0].cap.minY, 40, accuracy: accuracy)
        XCTAssertEqual(se[0][0].cap.minX, 72, accuracy: accuracy)
        XCTAssertEqual(se[0][9].cap.maxX, 667 - 72, accuracy: accuracy)
        XCTAssertEqual(se[0][0].cap.width, 46.9, accuracy: 0.01)

        let iPhone17 = layout(azerty, grids[4])
        XCTAssertEqual(206 + iPhone17[0][0].cap.minY, 244, accuracy: 0.34)
        XCTAssertEqual(iPhone17[0][0].cap.height, 27.33, accuracy: 0.01)
        XCTAssertEqual(206 + iPhone17[3][0].cap.maxY, 377, accuracy: accuracy)
        XCTAssertEqual(75.33 + iPhone17[0][0].cap.minX, 79.33, accuracy: accuracy)
    }

    // MARK: - Invariants, every size and orientation

    func testTargetsTileTheGridWithNoDeadZoneAndNoOverlap() {
        var generator = SystemRandomNumberGenerator()
        for grid in grids {
            for page in [azerty, qwerty] {
                let slots = layout(page, grid)
                let size = grid.2
                var rowTop: CGFloat = 0
                for row in slots {
                    XCTAssertEqual(row.first?.hit.minX ?? -1, 0, accuracy: accuracy, "\(grid)")
                    XCTAssertEqual(row.last?.hit.maxX ?? -1, size.width, accuracy: accuracy, "\(grid)")
                    for (a, b) in zip(row, row.dropFirst()) {
                        XCTAssertEqual(a.hit.maxX, b.hit.minX, accuracy: accuracy, "\(grid)")
                    }
                    for slot in row {
                        XCTAssertEqual(slot.hit.minY, rowTop, accuracy: accuracy, "\(grid)")
                    }
                    rowTop = row[0].hit.maxY
                }
                XCTAssertEqual(rowTop, size.height, accuracy: accuracy, "\(grid)")

                let all = slots.flatMap { $0 }
                for _ in 0..<500 {
                    let point = CGPoint(x: CGFloat.random(in: 0..<size.width, using: &generator),
                                        y: CGFloat.random(in: 0..<size.height, using: &generator))
                    XCTAssertEqual(all.filter { $0.hit.contains(point) }.count, 1, "\(grid) at \(point)")
                }
            }
        }
    }

    func testKeycapsSitInsideTheirTargetsAndNeverTouch() {
        for grid in grids {
            for page in [azerty, qwerty] {
                let all = layout(page, grid).flatMap { $0 }
                for slot in all {
                    XCTAssertTrue(slot.hit.insetBy(dx: -accuracy, dy: -accuracy).contains(slot.cap), "\(grid)")
                }
                // Every key of a whole unit or more is wide enough to hit (QWERTY's half-unit
                // spacers draw no keycap).
                for (row, units) in zip(layout(page, grid), page) {
                    for (slot, unit) in zip(row, units) where unit >= 1 {
                        XCTAssertGreaterThan(slot.cap.width, 25, "\(grid)")
                    }
                }
                for (i, a) in all.enumerated() {
                    for b in all[(i + 1)...] {
                        XCTAssertFalse(a.cap.intersects(b.cap), "\(grid) \(a.cap) × \(b.cap)")
                    }
                }
            }
        }
    }

    /// Keycap edges line up between rows of whole-unit keys, so a column reads straight.
    func testGapsAndPitchAreUniform() {
        for grid in grids {
            let geometry = KeyPlaneGeometry.apple(grid.0, grid.1)
            let slots = layout(azerty, grid)
            for row in slots {
                for (a, b) in zip(row, row.dropFirst()) {
                    XCTAssertEqual(b.cap.minX - a.cap.maxX, geometry.keyGap, accuracy: accuracy, "\(grid)")
                }
            }
            for (upper, lower) in zip(slots, slots.dropFirst()) {
                XCTAssertEqual(lower[0].cap.minY - upper[0].cap.minY, geometry.rowPitch, accuracy: accuracy, "\(grid)")
            }
            XCTAssertEqual(grid.2.height - slots[3][0].cap.maxY, geometry.bottomInset, accuracy: accuracy, "\(grid)")
        }
    }

    // MARK: - Where the table does not apply

    func testOtherRowCountsAndShortGridsKeepTheEvenGrid() {
        let geometry = KeyPlaneGeometry.apple(.standard, .portrait)
        let fiveRows = [Array(repeating: CGFloat(1), count: 10)] + azerty
        XCTAssertNil(geometry.layout(rows: fiveRows, width: 402, height: 270))
        XCTAssertNil(geometry.layout(rows: azerty, width: 402, height: geometry.requiredHeight - 1))
        XCTAssertNotNil(geometry.layout(rows: azerty, width: 402, height: geometry.requiredHeight))
        XCTAssertNil(geometry.layout(rows: azerty, width: 10, height: 216))
    }
}
