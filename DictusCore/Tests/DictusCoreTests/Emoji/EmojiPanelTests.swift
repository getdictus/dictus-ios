// The panel's UIKit tests. The drawing, tone, band and scrub tests are ported from Hex
// (github.com/anomalyco/hex, branch dev @ 492d8c2, ios/HEXMobileTests/EmojiSuggesterTests.swift),
// MIT, Copyright (c) 2026 Christopher Langton; the search, recents and French ones are Dictus's
// (#1027). UIKit only: they run under the iOS Simulator destination, not `swift test` on the Mac.
#if canImport(UIKit)
import UIKit
import XCTest
@testable import DictusCore

/// `UIControl.sendActions(for:)` goes through `UIApplication`, which a package's test bundle
/// (no host app) does not have: the actions never arrive. This calls the targets directly.
@MainActor
func fireActions(of control: UIControl, for event: UIControl.Event) {
    for target in control.allTargets {
        for action in control.actions(forTarget: target, forControlEvent: event) ?? [] {
            _ = (target as NSObject).perform(Selector(action), with: control)
        }
    }
}

@MainActor
final class EmojiPanelTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUp() async throws {
        suiteName = "EmojiPanelTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makePanel(language: String = "en", usage: EmojiUsageStore? = nil) throws -> EmojiPanelView {
        let library = try XCTUnwrap(EmojiLibrary.load(language: language))
        let panel = EmojiPanelView(
            library: library,
            usage: usage ?? EmojiUsageStore(defaults: defaults),
            strings: .english,
            letterRows: EmojiPanelView.letterRows(for: .azerty)
        )
        panel.frame = CGRect(x: 0, y: 0, width: 402, height: 226)
        return panel
    }

    private func grid(of panel: EmojiPanelView) throws -> UICollectionView {
        try XCTUnwrap(panel.subviews.compactMap { $0 as? UICollectionView }.first { !($0.superview is EmojiRowView) })
    }

    // MARK: - Drawing (Hex)

    /// The box, in points, that `draw`'s opaque pixels cover in a 3x bitmap of `size`.
    private func inkBounds(_ size: CGSize, _ draw: (CGContext) -> Void) throws -> CGRect {
        let width = Int(size.width * 3)
        let height = Int(size.height * 3)
        let context = try XCTUnwrap(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 3, y: -3)
        draw(context)
        let pixels = try XCTUnwrap(context.data).bindMemory(to: UInt8.self, capacity: width * height * 4)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] > 24 {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        XCTAssertGreaterThanOrEqual(maxX, 0, "nothing drawn")
        return CGRect(x: CGFloat(minX) / 3, y: CGFloat(minY) / 3, width: CGFloat(maxX - minX + 1) / 3, height: CGFloat(maxY - minY + 1) / 3)
    }

    /// The grid's cells draw their own bitmaps (iOS keeps every emoji a label draws), so
    /// they must land where the label put them.
    func testAnEmojiCellDrawsItsEmojiWhereALabelDid() throws {
        let renderer = EmojiGlyphRenderer()
        XCTAssertTrue(renderer.hasPrivateFont)
        let size = CGSize(width: 46, height: 40)
        for emoji in ["😀", "👍🏽", "🇫🇷", "❤️", "#️⃣", "🧑‍🧑‍🧒", "©️"] {
            for fontSize: CGFloat in [32, 28] {
                let label = UILabel(frame: CGRect(origin: .zero, size: size))
                label.textAlignment = .center
                label.font = .systemFont(ofSize: fontSize)
                label.text = emoji
                let expected = try inkBounds(size) { context in
                    UIGraphicsPushContext(context)
                    label.drawText(in: label.bounds)
                    UIGraphicsPopContext()
                }
                let cell = EmojiCell(frame: CGRect(origin: .zero, size: size))
                cell.configure(emoji: emoji, name: emoji, fontSize: fontSize, palette: EmojiPanelPalette(isDark: false), renderer: renderer, scale: 3)
                cell.layoutIfNeeded()
                let drawn = try inkBounds(size) { cell.contentView.layer.render(in: $0) }
                for (a, b, edge) in [(drawn.minX, expected.minX, "left"), (drawn.maxX, expected.maxX, "right"),
                                     (drawn.minY, expected.minY, "top"), (drawn.maxY, expected.maxY, "bottom")] {
                    XCTAssertEqual(a, b, accuracy: 0.7, "\(emoji) at \(fontSize) pt: \(edge) edge \(drawn) vs \(expected)")
                }
            }
        }
    }

    /// Paging past every emoji keeps a bounded set of bitmaps and leaves the process about
    /// where it started (drawn as text, Hex measured about 90 MB; Dictus's old picker, 110 MB
    /// on the simulator).
    func testDrawingEveryEmojiStaysWithinTheRenderersLimit() throws {
        let library = try XCTUnwrap(EmojiLibrary.load(language: "en"))
        let renderer = EmojiGlyphRenderer(byteLimit: 1 << 20, rendersPerFont: 32)
        let before = Self.footprint()
        for (index, entry) in library.entries.enumerated() {
            XCTAssertNotNil(renderer.glyph(for: entry.emoji, size: 29, scale: 3), entry.emoji)
            XCTAssertLessThanOrEqual(renderer.cachedBytes, 1 << 20)
            if index % 40 == 39 { RunLoop.current.run(until: Date()) }
        }
        let grown = Self.footprint() - before
        XCTAssertLessThan(grown, 12, "drawing every emoji grew the process by \(grown) MB")
        let last = try XCTUnwrap(library.entries.last?.emoji)
        let renders = renderer.renders
        let first = renderer.glyph(for: last, size: 29, scale: 3)
        XCTAssertTrue(first === renderer.glyph(for: last, size: 29, scale: 3))
        XCTAssertEqual(renderer.renders, renders, "a cached emoji was drawn again")
        renderer.purge()
        XCTAssertEqual(renderer.cachedBytes, 0)
        XCTAssertEqual(renderer.cachedCount, 0)
    }

    private static func footprint() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    // MARK: - Skin tones (Hex, and Dictus's old picker had none)

    func testTheGridShowsTheSkinToneYouPicked() throws {
        let usage = EmojiUsageStore(defaults: defaults)
        usage.setTone(3, for: "👍")
        let panel = try makePanel(usage: usage)
        let thumbs = try XCTUnwrap(panel.library.entryByEmoji["👍"])
        panel.show(suggestions: [thumbs], frequent: [thumbs])
        panel.layoutIfNeeded()
        let grid = try grid(of: panel)
        grid.layoutIfNeeded()
        let first = grid.cellForItem(at: IndexPath(item: 0, section: 0)) as? EmojiCell
        XCTAssertEqual(first?.emoji, panel.library.entries[thumbs].tones[2])
        XCTAssertGreaterThan(grid.visibleCells.count, 20)
    }

    func testPickingAToneInsertsItAndRemembersIt() throws {
        let panel = try makePanel()
        panel.fill()
        panel.layoutIfNeeded()
        var inserted: [String] = []
        panel.onInsert = { inserted.append($0) }
        let thumbs = try XCTUnwrap(panel.library.entryByEmoji["👍"])
        panel.showTones(for: thumbs, over: CGRect(x: 100, y: 120, width: 46, height: 40))
        let menu = try XCTUnwrap(panel.tonePicker.menu)
        XCTAssertEqual(menu.options.count, 6, "the untoned emoji and five tones")
        let dark = panel.library.entries[thumbs].tones[4]
        panel.pickTone(dark, for: thumbs)
        XCTAssertEqual(inserted, [dark])
        XCTAssertNil(panel.tonePicker.menu)
        XCTAssertEqual(panel.usage.tone(for: "👍"), 5)
        XCTAssertEqual(panel.display(for: thumbs), dark)
    }

    // MARK: - The bar (Hex)

    /// A tap a little under or over the bar's icons, or beside ABC and delete, still lands
    /// on them: the whole band under the grid, each category across the full width of its slot.
    func testTheBarsKeysTakeTheWholeBandUnderTheGrid() throws {
        let panel = try makePanel()
        panel.show(suggestions: [], frequent: [])
        panel.layoutIfNeeded()
        let bar = panel.categoryBar
        let buttons = bar.subviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, EmojiCategory.allCases.count + 1)
        let grid = try grid(of: panel)
        for (index, button) in buttons.enumerated() {
            let frame = button.convert(button.bounds, to: panel)
            for y in [grid.frame.maxY + 1, frame.minY - 1, frame.midY, frame.maxY + 1, panel.bounds.maxY - 1] where y < panel.bounds.maxY {
                for x in [frame.minX + 0.5, frame.midX, frame.maxX - 0.5] {
                    let point = CGPoint(x: x, y: y)
                    XCTAssertTrue(panel.hitTest(point, with: nil) === bar, "\(button.accessibilityLabel ?? "") at \(point)")
                    XCTAssertEqual(bar.slot(atX: panel.convert(point, to: bar).x).index, index)
                }
            }
        }
        let below = panel.bounds.maxY - 1
        XCTAssertEqual(panel.hitTest(CGPoint(x: 20, y: below), with: nil)?.accessibilityLabel, "Letters")
        XCTAssertEqual(panel.hitTest(CGPoint(x: 390, y: below), with: nil)?.accessibilityLabel, "Delete")
        XCTAssertTrue(panel.hitTest(CGPoint(x: 200, y: grid.frame.midY), with: nil)?.isDescendant(of: grid) ?? false)
    }

    /// Every category is in one grid: a tap on a category jumps there, a slide along the bar
    /// scrubs through every emoji, and the bar follows the grid (Dictus's old picker showed
    /// one category at a time).
    func testSlidingAlongTheBarScrubsTheGrid() throws {
        let panel = try makePanel()
        panel.show(suggestions: [], frequent: [])
        panel.layoutIfNeeded()
        var clicks = 0
        panel.onKeyClick = { _ in clicks += 1 }
        let bar = panel.categoryBar
        let grid = try grid(of: panel)
        grid.layoutIfNeeded()
        let count = EmojiCategory.allCases.count + 1
        let slot = bar.bounds.width / CGFloat(count)
        let food = 1 + EmojiCategory.foodDrink.rawValue
        let foodX = slot * (CGFloat(food) + 0.5)

        bar.touchBegan(atX: foodX)
        bar.touchMoved(toX: foodX + 4)
        XCTAssertEqual(grid.contentOffset.x, 0, "a finger that hardly moves is a tap")
        bar.touchEnded(atX: foodX + 4)
        XCTAssertEqual(bar.selected, food, "a tap picks its category as it lifts")
        let foodStart = grid.contentOffset.x
        XCTAssertGreaterThan(foodStart, 0)
        XCTAssertEqual(clicks, 1)

        var x = slot * 1.1
        bar.touchBegan(atX: x)
        var offsets: [CGFloat] = []
        var seen: [Int] = []
        while x < bar.bounds.width + 20 {
            x += 3
            bar.touchMoved(toX: x)
            guard bar.isScrubbing else { continue }
            offsets.append(grid.contentOffset.x)
            if seen.last != bar.selected { seen.append(bar.selected) }
        }
        XCTAssertEqual(seen, Array(1..<count), "the chip follows the finger through every category")
        XCTAssertEqual(offsets, offsets.sorted(), "the grid only moves on as the finger does")
        let maxX = grid.contentSize.width - grid.bounds.width
        XCTAssertEqual(offsets.last ?? 0, maxX, accuracy: 1, "the end of the bar is the end of the grid")
        bar.touchEnded(atX: x)
        XCTAssertEqual(clicks, 1, "a slide types no key click")

        grid.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        XCTAssertEqual(bar.selected, 0)
        grid.setContentOffset(CGPoint(x: foodStart, y: 0), animated: false)
        XCTAssertEqual(bar.selected, food)
    }

    // MARK: - Recents (Dictus)

    /// The old picker re-sorted its recents on every tap, so the emoji moved under the finger.
    /// Recents are read when the panel fills, and only then.
    func testRecentsDoNotMoveWhileThePanelIsOpen() throws {
        let usage = EmojiUsageStore(defaults: defaults)
        for emoji in ["😂", "❤️", "👍"] { usage.record(emoji) }
        let panel = try makePanel(usage: usage)
        panel.fill()
        panel.layoutIfNeeded()
        let before = panel.sections[0].entries
        let fire = try XCTUnwrap(panel.library.entryByEmoji["🔥"])
        for _ in 0..<5 { panel.insert("🔥", entry: fire) }
        XCTAssertEqual(panel.sections[0].entries, before, "the open grid keeps its order")
        panel.fill()
        XCTAssertEqual(panel.sections[0].entries.first, fire, "the next fill puts it first")
    }

    // MARK: - Search (Dictus)

    func testSearchInFrenchFindsTheHeartAndInsertsIt() throws {
        let panel = try makePanel(language: "fr")
        panel.fill()
        panel.layoutIfNeeded()
        var inserted: [String] = []
        panel.onInsert = { inserted.append($0) }
        panel.beginSearch()
        XCTAssertTrue(panel.grid.isHidden)
        XCTAssertFalse(panel.searchKeys.isHidden)
        for query in ["coeur", "cœur"] {
            panel.query = ""
            panel.debugType(query)
            let first3 = panel.searchEntries.prefix(3).map { panel.library.entries[$0].emoji }
            XCTAssertTrue(first3.contains("❤️"), "\(query): \(first3)")
        }
        panel.searchResults.onPick?(0)
        XCTAssertEqual(inserted.count, 1)
        panel.endSearch()
        XCTAssertFalse(panel.grid.isHidden)
        XCTAssertTrue(panel.searchKeys.isHidden)
        XCTAssertNil(panel.query)
    }

    func testTheSearchKeysTypeIntoTheQuery() throws {
        let panel = try makePanel()
        panel.layoutIfNeeded()
        panel.beginSearch()
        panel.layoutIfNeeded()
        let keys = panel.searchKeys.subviews.compactMap { $0 as? PanelKeyButton }
        for letter in ["p", "i", "z"] {
            let key = try XCTUnwrap(keys.first { $0.title == letter })
            fireActions(of: key, for: .touchUpInside)
        }
        XCTAssertEqual(panel.query, "piz")
        XCTAssertEqual(panel.searchEntries.first.map { panel.library.entries[$0].emoji }, "🍕")
        let delete = try XCTUnwrap(keys.first { $0.symbol == "delete.left" })
        fireActions(of: delete, for: .touchDown)
        fireActions(of: delete, for: .touchUpInside)
        XCTAssertEqual(panel.query, "pi")
    }

    /// With the toolbar folded away in emoji mode, the panel has the whole keyboard area
    /// (about 278 pt on an iPhone 17): four rows, as Hex's, and Recents fills all four even
    /// though the host fills the panel before its first layout.
    func testTheWholeKeyboardAreaGivesFourFullRows() throws {
        let panel = try makePanel()
        panel.fill()
        panel.frame = CGRect(x: 0, y: 0, width: 402, height: 278)
        panel.layoutIfNeeded()
        XCTAssertEqual(panel.gridRows, 4)
        XCTAssertEqual(panel.sections[0].entries.count, 32, "Recents: four rows of eight")
        let narrow = try makePanel()
        narrow.fill()
        narrow.frame = CGRect(x: 0, y: 0, width: 402, height: 226)
        narrow.layoutIfNeeded()
        XCTAssertEqual(narrow.gridRows, 3, "under a 52 pt bar there is room for three")
        XCTAssertEqual(narrow.sections[0].entries.count, 24)
    }

    func testTheGridFitsTheKeyboardArea() throws {
        let panel = try makePanel()
        panel.fill()
        panel.layoutIfNeeded()
        let grid = try grid(of: panel)
        XCTAssertGreaterThanOrEqual(panel.gridRows, 3)
        XCTAssertLessThanOrEqual(grid.frame.maxY, panel.categoryBar.frame.minY)
        XCTAssertEqual(panel.categoryBar.frame.maxY, panel.bounds.maxY - panel.metrics.bottomInset, accuracy: 0.5)
        XCTAssertGreaterThan(panel.categoryBar.frame.width / CGFloat(EmojiCategory.allCases.count + 1), 21, "every category icon has a full-size slot")
    }
}
#endif
