// Ported from Hex (github.com/anomalyco/hex, branch dev @ 492d8c2,
// ios/HEXMobileTests/EmojiPanelLettersKeyTests.swift), MIT, Copyright (c) 2026 Christopher Langton.
// Dictus's changes (#1027): Hex's experiment that puts ABC under the emoji key, and its
// dictation bar's back key, are not carried over, so their tests are not either. What stays
// is the panel's ABC at the bar's leading end, and the reason the port exists: Dictus's old
// ABC and search keys answered only on their glyphs ("almost unusable"). UIKit only: these
// run under the iOS Simulator destination, not under `swift test` on the Mac.
#if canImport(UIKit)
import UIKit
import XCTest
@testable import DictusCore

@MainActor
final class EmojiPanelLettersKeyTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUp() async throws {
        suiteName = "EmojiPanelLettersKeyTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func panel(width: CGFloat = 402, height: CGFloat = 226) throws -> EmojiPanelView {
        let library = try XCTUnwrap(EmojiLibrary.load(language: "en"))
        let panel = EmojiPanelView(
            library: library,
            usage: EmojiUsageStore(defaults: defaults),
            strings: .english,
            letterRows: EmojiPanelView.letterRows(for: .azerty)
        )
        panel.frame = CGRect(x: 0, y: 0, width: width, height: height)
        panel.textBefore = { "pizza " }
        panel.fill()
        panel.layoutIfNeeded()
        return panel
    }

    /// ABC sits at the bar's leading end, as wide as the panel's bar keys, on every iPhone width.
    func testStandalonePanelKeepsTheLeadingEnd() throws {
        for width in [375, 402, 440] as [CGFloat] {
            let panel = try panel(width: width)
            let letters = try XCTUnwrap(panel.subviews.first { $0.accessibilityLabel == "Letters" })
            XCTAssertEqual(letters.frame.minX, panel.metrics.side, accuracy: 0.5)
            XCTAssertEqual(letters.frame.width, panel.metrics.barKeyWidth, accuracy: 0.5)
            let delete = try XCTUnwrap(panel.subviews.first { $0.accessibilityLabel == "Delete" })
            XCTAssertEqual(delete.frame.maxX, width - panel.metrics.side, accuracy: 0.5)
        }
    }

    /// The old ABC answered only on its glyph. Now a tap anywhere left of the categories, in
    /// the whole band under the grid, is ABC; and the old magnifier's role goes to a button the
    /// whole height of the top row.
    func testLettersAndSearchTakeTheirWholeBand() throws {
        let panel = try panel()
        let letters = try XCTUnwrap(panel.subviews.first { $0.accessibilityLabel == "Letters" })
        let grid = try XCTUnwrap(panel.subviews.compactMap { $0 as? UICollectionView }.first { !($0.superview is EmojiRowView) })
        for point in [
            CGPoint(x: 1, y: panel.bounds.maxY - 1),
            CGPoint(x: letters.frame.midX, y: grid.frame.maxY + 0.5),
            CGPoint(x: letters.frame.maxX + 1, y: letters.frame.midY),
        ] {
            XCTAssertTrue(panel.hitTest(point, with: nil) === letters, "\(point)")
        }
        let search = panel.searchButton
        for point in [CGPoint(x: 1, y: 1), CGPoint(x: search.frame.midX, y: panel.rowFrame.maxY - 1), CGPoint(x: search.frame.maxX + 1, y: 20)] {
            XCTAssertTrue(panel.hitTest(point, with: nil) === search, "\(point)")
        }
    }

    func testLettersKeyCallsBackAndClicks() throws {
        let panel = try panel()
        var letters = 0
        var clicks: [KeySoundCategory] = []
        panel.onLetters = { letters += 1 }
        panel.onKeyClick = { clicks.append($0) }
        fireActions(of: panel.lettersKey, for: .touchUpInside)
        XCTAssertEqual(letters, 1)
        XCTAssertEqual(clicks, [.modifier])
    }

    /// #503: `hitTest` gives ABC and the search button whole bands, but iOS hands a keyboard
    /// extension only the touches that land on something its layers draw, so on a clear panel
    /// the band around ABC's key and the search chip's corners never reached `hitTest` at all
    /// (simulator, before this: 0 of 5 taps in ABC's band, 8 of 13 on the magnifier's band
    /// missed). Every point of the panel, open and searching, is drawn on, if invisibly.
    /// Ported from Hex's `testEveryPointOfThePanelAndTheSearchResultsTakesTouches` (pull 2547).
    func testEveryPointOfThePanelTakesTouches() throws {
        let panel = try panel()
        assertDrawnEverywhere(panel, "the open panel")
        panel.beginSearch()
        panel.layoutIfNeeded()
        assertDrawnEverywhere(panel, "the panel in search")
    }

    /// Every point 4 pt apart in `view` lies on a layer that draws (a fill or contents), as iOS
    /// needs before it routes a touch there to the keyboard.
    private func assertDrawnEverywhere(_ view: UIView, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        func draws(_ layer: CALayer, at point: CGPoint) -> Bool {
            guard !layer.isHidden, layer.opacity > 0, layer.bounds.contains(point) else { return false }
            if (layer.backgroundColor?.alpha ?? 0) > 0 || layer.contents != nil { return true }
            return (layer.sublayers ?? []).contains { draws($0, at: $0.convert(point, from: layer)) }
        }
        var missed: [CGPoint] = []
        for x in stride(from: CGFloat(1), to: view.bounds.width, by: 4) {
            for y in stride(from: CGFloat(1), to: view.bounds.height, by: 4) where !draws(view.layer, at: CGPoint(x: x, y: y)) {
                missed.append(CGPoint(x: x, y: y))
            }
        }
        XCTAssertTrue(missed.isEmpty, "\(what): \(missed.count) points draw nothing, as \(missed.prefix(3))", file: file, line: line)
    }
}
#endif
