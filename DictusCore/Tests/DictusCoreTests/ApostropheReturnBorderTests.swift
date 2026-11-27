import CoreGraphics
import XCTest
@testable import DictusCore

/// #1080: the apostrophe/Return border on the French AZERTY page, laid out as the keyboard
/// lays it out (`KeyPlaneGeometry`, iPhone 17 upright, 402 x 216 pt grid).
final class ApostropheReturnBorderTests: XCTestCase {
    /// The AZERTY letter page's key widths in key units (`KeyboardLayouts.azertyNormal`):
    /// row 3 is shift, w x c v b n, the apostrophe key, backspace; row 4 is 123, emoji, space, Return.
    private static let azerty: [[CGFloat]] = [
        Array(repeating: 1, count: 10),
        Array(repeating: 1, count: 10),
        [1.5, 1, 1, 1, 1, 1, 1, 1, 1.5],
        [1.25, 1.25, 5.5, 2]
    ]
    private static let geometry = KeyPlaneGeometry.apple(.standard, .portrait)
    private static let slots = geometry.layout(rows: azerty, width: 402, height: 216)

    private struct Grid {
        let apostrophe: KeyPlaneSlot
        let returnKey: KeyPlaneSlot
        let unitWidth: CGFloat
        let rowPitch: CGFloat

        /// A `TJ TAP` offset from Return's keycap centre, in key units (one-unit key widths
        /// across, row pitches down), as the journal records it.
        func onReturn(dx: CGFloat, dy: CGFloat) -> CGPoint {
            CGPoint(x: returnKey.cap.midX + dx * unitWidth, y: returnKey.cap.midY + dy * rowPitch)
        }

        /// Which key the keyboard types at `point` after `text`.
        func key(at point: CGPoint, after text: String) -> String {
            if apostrophe.hit.contains(point) { return "apostrophe" }
            guard returnKey.hit.contains(point) else { return "other" }
            let moved = ApostropheReturnBorder.takesApostrophe(
                point, apostrophe: apostrophe.hit, returnKey: returnKey.hit, rowPitch: rowPitch,
                textBeforeCursor: { text }
            )
            return moved ? "apostrophe" : "return"
        }
    }

    private func grid() throws -> Grid {
        let slots = try XCTUnwrap(Self.slots)
        let returnKey = slots[3][3]
        // The journal's unit: a keycap and its gap over the key's width in units.
        return Grid(apostrophe: slots[2][7], returnKey: returnKey,
                    unitWidth: (returnKey.cap.width + Self.geometry.keyGap) / 2, rowPitch: Self.geometry.rowPitch)
    }

    /// Pierre's taps, device session of 2026-11-26 (build 2.1.0 (45), cab230d0), `TJ TAP` #69
    /// and #74: aimed at the apostrophe after « c », resolved to Return.
    private static let pierreTaps: [(dx: CGFloat, dy: CGFloat)] = [(-0.97, -0.42), (-0.70, -0.46)]

    func testPierresTapsLandOnReturnWithoutTheRule() throws {
        let grid = try grid()
        for tap in Self.pierreTaps {
            let point = grid.onReturn(dx: tap.dx, dy: tap.dy)
            XCTAssertTrue(grid.returnKey.hit.contains(point), "\(tap) is Return's for the plain hit test")
            // Under the apostrophe's column, in the gap above Return's keycap.
            XCTAssertTrue(point.x >= grid.apostrophe.hit.minX && point.x < grid.apostrophe.hit.maxX)
            XCTAssertLessThan(point.y, grid.returnKey.cap.minY)
        }
    }

    func testPierresTapsTypeTheApostropheAfterC() throws {
        let grid = try grid()
        for tap in Self.pierreTaps {
            let point = grid.onReturn(dx: tap.dx, dy: tap.dy)
            XCTAssertEqual(grid.key(at: point, after: "c"), "apostrophe", "\(tap)")
            // Auto-capitalised, as on Pierre's device, and mid-sentence.
            XCTAssertEqual(grid.key(at: point, after: "C"), "apostrophe", "\(tap)")
            XCTAssertEqual(grid.key(at: point, after: "Oui, c"), "apostrophe", "\(tap)")
        }
    }

    func testPierresTapsStayReturnWithoutAnElision() throws {
        let grid = try grid()
        for tap in Self.pierreTaps {
            let point = grid.onReturn(dx: tap.dx, dy: tap.dy)
            XCTAssertEqual(grid.key(at: point, after: "bonjour"), "return", "\(tap)")
            XCTAssertEqual(grid.key(at: point, after: "Bonjour"), "return", "\(tap)")
            XCTAssertEqual(grid.key(at: point, after: ""), "return", "\(tap)")
            XCTAssertEqual(grid.key(at: point, after: "c "), "return", "\(tap)")
            XCTAssertEqual(grid.key(at: point, after: "c'"), "return", "\(tap)")
            XCTAssertEqual(grid.key(at: point, after: "x"), "return", "\(tap)")
        }
    }

    func testTheCentreOfReturnStaysReturn() throws {
        let grid = try grid()
        XCTAssertEqual(grid.key(at: grid.onReturn(dx: 0, dy: 0), after: "c"), "return")
        // The left end of Return's keycap, halfway down: well inside Return.
        XCTAssertEqual(grid.key(at: grid.onReturn(dx: -0.8, dy: 0), after: "c"), "return")
        // Just below the band.
        let below = CGPoint(x: grid.onReturn(dx: -0.8, dy: 0).x,
                            y: grid.returnKey.hit.minY + ApostropheReturnBorder.reach * grid.rowPitch + 0.5)
        XCTAssertEqual(grid.key(at: below, after: "c"), "return")
    }

    func testTheCentreOfTheApostropheStaysTheApostrophe() throws {
        let grid = try grid()
        let centre = CGPoint(x: grid.apostrophe.cap.midX, y: grid.apostrophe.cap.midY)
        XCTAssertEqual(grid.key(at: centre, after: "c"), "apostrophe")
        XCTAssertEqual(grid.key(at: centre, after: "bonjour"), "apostrophe")
    }

    func testTheBandStopsAtTheApostrophesColumn() throws {
        let grid = try grid()
        // High on Return, under backspace: stays Return.
        let underBackspace = grid.onReturn(dx: 0.3, dy: -0.45)
        XCTAssertGreaterThanOrEqual(underBackspace.x, grid.apostrophe.hit.maxX)
        XCTAssertEqual(grid.key(at: underBackspace, after: "c"), "return")
    }

    func testTheWordsFrenchElides() {
        for text in ["c", "d", "j", "l", "m", "n", "s", "t", "qu", "C", "L", "QU", "Qu", "jusqu", "lorsqu",
                     "puisqu", "il dit qu", "(l", "«\u{00A0}j", "ligne\nc"] {
            XCTAssertTrue(ApostropheReturnBorder.expectsApostrophe(after: text), text)
        }
        for text in ["", "c ", "c'", "c\n", "bonjour", "ce", "x", "b", "le", "1", "the"] {
            XCTAssertFalse(ApostropheReturnBorder.expectsApostrophe(after: text), text)
        }
    }

    func testTheTextIsReadOnlyInTheBand() throws {
        let grid = try grid()
        var reads = 0
        _ = ApostropheReturnBorder.takesApostrophe(
            grid.onReturn(dx: 0, dy: 0), apostrophe: grid.apostrophe.hit, returnKey: grid.returnKey.hit,
            rowPitch: grid.rowPitch, textBeforeCursor: { reads += 1; return "c" }
        )
        XCTAssertEqual(reads, 0)
    }
}
