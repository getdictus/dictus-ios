// What Hex's emoji panel takes from the rest of Hex's keyboard, cut down to what the panel uses.
// Ported from Hex (github.com/anomalyco/hex, branch dev @ 492d8c2), MIT,
// Copyright (c) 2026 Christopher Langton:
// - EmojiPanelPalette: FullKeyboardPalette.swift, the colours the panel reads (no themes).
// - PanelKeyButton: HexKeyViews.swift.
// - KeyBalloon, KeyCalloutView: KeyboardKeyPlaneView.swift, the pop-up over a pressed key.
// - AccentMenu, AccentCalloutView: AccentPicker.swift, only the skin-tone picker's layout
//   (`buildFixed`) and drawing (`drawFixed`).
// - EmojiPanelStrings and EmojiPanelMetrics are Dictus's (#1027): the strings come from the
//   keyboard's own catalogue, and the metrics fit the panel under Dictus's toolbar.
#if canImport(UIKit)
import UIKit

/// The panel's words. DictusCore has no string catalogue of its own, so the keyboard passes
/// its own localized strings in (the keys its old picker already had, French and English).
public struct EmojiPanelStrings: Equatable, Sendable {
    public var recents: String
    public var categories: [EmojiCategory: String]
    public var searchPlaceholder: String
    public var noResults: String
    /// The letters key's title ("ABC") and its VoiceOver label.
    public var lettersTitle: String
    public var lettersLabel: String
    public var delete: String
    public var space: String
    public var closeSearch: String

    public init(
        recents: String,
        categories: [EmojiCategory: String],
        searchPlaceholder: String,
        noResults: String,
        lettersTitle: String,
        lettersLabel: String,
        delete: String,
        space: String,
        closeSearch: String
    ) {
        self.recents = recents
        self.categories = categories
        self.searchPlaceholder = searchPlaceholder
        self.noResults = noResults
        self.lettersTitle = lettersTitle
        self.lettersLabel = lettersLabel
        self.delete = delete
        self.space = space
        self.closeSearch = closeSearch
    }

    /// English, for tests and previews.
    public static let english = EmojiPanelStrings(
        recents: "Recents",
        categories: [
            .smileys: "Smileys", .people: "People", .animalsNature: "Animals & Nature",
            .foodDrink: "Food & Drink", .activity: "Activities", .travelPlaces: "Travel",
            .objects: "Objects", .symbols: "Symbols", .flags: "Flags"
        ],
        searchPlaceholder: "Search Emoji",
        noResults: "No results",
        lettersTitle: "ABC",
        lettersLabel: "Letters",
        delete: "Delete",
        space: "space",
        closeSearch: "Close"
    )

    func title(of category: EmojiCategory) -> String {
        categories[category] ?? ""
    }
}

/// The panel's colours, light and dark, calibrated by Hex against Apple's iOS 26 Liquid Glass
/// keyboard. Dark follows the panel's trait collection, which iOS sets from the field's
/// keyboard appearance and the host's style.
struct EmojiPanelPalette: Equatable {
    let isDark: Bool

    private static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    var textBase: UIColor { isDark ? .white : .black }
    var textMuted: UIColor { isDark ? UIColor(white: 1, alpha: 0.56) : Self.rgb(0x525763) }
    var keyFill: UIColor { isDark ? UIColor(white: 1, alpha: 0.16) : .white }
    var keyPressedFill: UIColor { isDark ? UIColor(white: 1, alpha: 0.28) : Self.rgb(0xD8DCE4) }
    var functionFill: UIColor { isDark ? UIColor(white: 1, alpha: 0.09) : UIColor(white: 0, alpha: 0.065) }
    var popupFill: UIColor { isDark ? Self.rgb(0x4E5056) : .white }
    var bubbleFill: UIColor { isDark ? Self.rgb(0x3F3F41) : .white }
    var bubbleShadow: UIColor { UIColor(white: 0, alpha: isDark ? 0.3 : 0.1) }
    var popupBorder: UIColor { isDark ? UIColor(white: 1, alpha: 0.14) : UIColor(white: 0, alpha: 0.08) }
    var popupShadow: UIColor { UIColor(white: 0, alpha: isDark ? 0.42 : 0.18) }
    var chipFill: UIColor { isDark ? UIColor(white: 1, alpha: 0.11) : UIColor(white: 0, alpha: 0.065) }
    var separator: UIColor { isDark ? UIColor(white: 1, alpha: 0.12) : UIColor(white: 0, alpha: 0.10) }
    /// Apple's keyboard action blue (`#007AFF`): the search caret and the chosen skin tone.
    var actionFill: UIColor { Self.rgb(0x007AFF) }

    static let cornerRadius: CGFloat = 8.5
}

/// Where the panel's rows go. Hex's panel replaces its strip and its keys; Dictus's sits under
/// the toolbar, which stays, so it has the keys' height only (about 220 pt on an iPhone).
struct EmojiPanelMetrics: Equatable {
    /// The suggestion row (search button and emoji for what you typed) at the top.
    var rowHeight: CGFloat = 40
    /// ABC, the categories and delete at the bottom.
    var barHeight: CGFloat = 36
    var bottomInset: CGFloat = 2
    /// The bar's and the row's distance from the panel's sides.
    var side: CGFloat = 4
    var cornerRadius: CGFloat = EmojiPanelPalette.cornerRadius
    /// ABC's and delete's width; the categories share the rest.
    var barKeyWidth: CGFloat = 44
}

extension CGContext {
    /// A continuous-corner iOS 26 keycap, without the old under-shadow.
    func fillKeycap(_ rect: CGRect, fill: UIColor, radius: CGFloat = EmojiPanelPalette.cornerRadius) {
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
        saveGState()
        addPath(path)
        setFillColor(fill.cgColor)
        fillPath()
        restoreGState()
    }
}

/// A keycap-styled button: the panel's ABC and delete, and the search's letter keys.
@MainActor
final class PanelKeyButton: UIControl {
    var palette = EmojiPanelPalette(isDark: false) { didSet { setNeedsDisplay() } }
    var title: String? { didSet { setNeedsDisplay() } }
    var symbol: String? { didSet { setNeedsDisplay() } }
    var isPrimary = false { didSet { setNeedsDisplay() } }
    var cornerRadius: CGFloat = EmojiPanelPalette.cornerRadius { didSet { setNeedsDisplay() } }
    /// Only the title or symbol, with a keycap only while pressed (the panel's ABC and
    /// delete, which the system emoji keyboard draws without keys).
    var isPlain = false { didSet { setNeedsDisplay() } }
    /// The title's size; nil draws it as the system keyboard's 123 key.
    var titleSize: CGFloat? { didSet { setNeedsDisplay() } }
    /// How far past its edges a touch still counts as on the key (the panel's bar).
    var hitOutsets: UIEdgeInsets = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityTraits = .button
        addTarget(self, action: #selector(redraw), for: [.touchDown, .touchDragEnter, .touchDragExit, .touchCancel, .touchUpInside, .touchUpOutside])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isHighlighted: Bool { didSet { setNeedsDisplay() } }
    @objc private func redraw() { setNeedsDisplay() }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(top: -hitOutsets.top, left: -hitOutsets.left, bottom: -hitOutsets.bottom, right: -hitOutsets.right)).contains(point)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        if isHighlighted {
            context.fillKeycap(bounds, fill: palette.keyPressedFill, radius: cornerRadius)
        } else if !isPlain {
            context.fillKeycap(bounds, fill: isPrimary ? palette.keyFill : palette.functionFill, radius: cornerRadius)
        }
        let ink = isEnabled ? palette.textBase : palette.textMuted
        if let symbol {
            let config = UIImage.SymbolConfiguration(pointSize: bounds.height < 34 ? 16 : 18, weight: .regular)
            if let image = UIImage(systemName: symbol, withConfiguration: config)?
                .withTintColor(ink, renderingMode: .alwaysOriginal) {
                image.draw(at: CGPoint(x: bounds.midX - image.size.width / 2, y: bounds.midY - image.size.height / 2))
            }
        } else if let title {
            let font = UIFont.systemFont(ofSize: titleSize ?? (bounds.height < 34 ? 14.5 : 15.5))
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
            let size = (title as NSString).size(withAttributes: attributes)
            (title as NSString).draw(
                at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
                withAttributes: attributes
            )
        }
    }
}

/// The pop-up over a pressed emoji: its bubble, and the cell under it.
struct KeyBalloon: Equatable {
    static let extraWidth: CGFloat = 14
    static let neck: CGFloat = 4
    static let bubbleHeight: CGFloat = 52

    let keyFrame: CGRect
    let bubble: CGRect
}

/// The pop-up balloon over a pressed emoji: a rounded rectangle floating over it (iOS 26/27),
/// with the emoji larger inside.
@MainActor
final class KeyCalloutView: UIView {
    var palette = EmojiPanelPalette(isDark: false)
    private var balloon: KeyBalloon?
    private var label = ""
    private static let font = UIFont.systemFont(ofSize: 36)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show(_ balloon: KeyBalloon?, label: String) {
        guard balloon != self.balloon || label != self.label else { return }
        self.balloon = balloon
        self.label = label
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let balloon, let context = UIGraphicsGetCurrentContext() else { return }
        let path = UIBezierPath(roundedRect: balloon.bubble, cornerRadius: 12).cgPath
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1), blur: 6, color: palette.bubbleShadow.cgColor)
        context.addPath(path)
        context.setFillColor(palette.bubbleFill.cgColor)
        context.fillPath()
        context.restoreGState()
        let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: palette.textBase]
        let size = (label as NSString).size(withAttributes: attributes)
        (label as NSString).draw(
            at: CGPoint(x: balloon.bubble.midX - size.width / 2, y: balloon.bubble.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}

/// The skin-tone picker's geometry: a row of cells over the held emoji, the untoned one at
/// the end nearest the thumb, opening toward the middle of the keyboard.
struct AccentMenu: Equatable {
    static let cellHeight: CGFloat = 44
    static let padding: CGFloat = 4
    static let gap: CGFloat = 6

    let keyFrame: CGRect
    let bubbleFrame: CGRect
    /// Every option, left to right.
    let options: [String]
    let cellFrames: [CGRect]
    var selectedIndex: Int

    var selectedOption: String { options[selectedIndex] }

    static func build(
        for keyFrame: CGRect,
        rawOptions: [String],
        in layoutWidth: CGFloat,
        horizontalInset: CGFloat = 0,
        cellWidth: CGFloat
    ) -> AccentMenu {
        let minX = max(2, horizontalInset + 4)
        let maxX = max(minX + 60, layoutWidth - horizontalInset - 4)
        // Right-half emoji reverse the list so the untoned one sits under the thumb on the
        // right and the tones fan inward.
        let opensLeft = keyFrame.midX > layoutWidth * 0.52
        let ordered = opensLeft ? Array(rawOptions.reversed()) : rawOptions
        let defaultIndex = opensLeft ? max(0, ordered.count - 1) : 0

        let count = CGFloat(max(1, ordered.count))
        let cellW = min(cellWidth, (maxX - minX - 2 * padding) / count)
        let bubbleW = count * cellW + 2 * padding
        let bubbleH = cellHeight + 2 * padding
        var bubbleX = keyFrame.midX - (padding + (CGFloat(defaultIndex) + 0.5) * cellW)
        bubbleX = max(minX, min(maxX - bubbleW, bubbleX))
        let bubbleY = max(1, keyFrame.minY - gap - bubbleH)
        let bubbleFrame = CGRect(x: bubbleX, y: bubbleY, width: bubbleW, height: bubbleH)
        let cells = (0..<ordered.count).map { index in
            CGRect(x: bubbleX + padding + CGFloat(index) * cellW, y: bubbleY + padding, width: cellW, height: cellHeight)
        }
        return AccentMenu(keyFrame: keyFrame, bubbleFrame: bubbleFrame, options: ordered, cellFrames: cells, selectedIndex: defaultIndex)
    }

    /// The nearest cell along the row for `x`.
    func index(for x: CGFloat) -> Int {
        guard let first = cellFrames.first else { return 0 }
        if x <= first.minX { return 0 }
        return cellFrames.firstIndex { x <= $0.maxX } ?? cellFrames.count - 1
    }
}

/// Draws an open `AccentMenu`: the skin-tone picker.
@MainActor
final class AccentCalloutView: UIView {
    var palette = EmojiPanelPalette(isDark: false) { didSet { if palette != oldValue { setNeedsDisplay() } } }
    private(set) var menu: AccentMenu?
    var optionFontSize: CGFloat = 28 { didSet { setNeedsDisplay() } }
    /// An option set apart from the rest by a hairline (the emoji's untoned form).
    var separatedOption: String? { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show(_ menu: AccentMenu?) {
        guard menu != self.menu else { return }
        self.menu = menu
        isHidden = menu == nil
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let menu, let context = UIGraphicsGetCurrentContext() else { return }
        let pill = UIBezierPath(roundedRect: menu.bubbleFrame, cornerRadius: 12)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 3), blur: 10, color: palette.popupShadow.cgColor)
        context.addPath(pill.cgPath)
        context.setFillColor(palette.popupFill.cgColor)
        context.fillPath()
        context.restoreGState()

        let scale = max(1, traitCollection.displayScale)
        context.saveGState()
        context.addPath(pill.cgPath)
        context.setLineWidth(1 / scale)
        context.setStrokeColor(palette.popupBorder.cgColor)
        context.strokePath()
        context.restoreGState()

        if let separatedOption, let index = menu.options.firstIndex(of: separatedOption), menu.options.count > 1 {
            let cell = menu.cellFrames[index]
            let x = index == 0 ? cell.maxX : cell.minX
            context.saveGState()
            context.setFillColor(palette.separator.cgColor)
            context.fill(CGRect(x: x - 0.5 / scale, y: cell.minY + 9, width: 1 / scale, height: cell.height - 18))
            context.restoreGState()
        }
        for (index, option) in menu.options.enumerated() {
            let cell = menu.cellFrames[index]
            let isSelected = index == menu.selectedIndex
            if isSelected {
                context.saveGState()
                context.addPath(UIBezierPath(roundedRect: cell.insetBy(dx: 1.5, dy: 2), cornerRadius: 8).cgPath)
                context.setFillColor(palette.actionFill.cgColor)
                context.fillPath()
                context.restoreGState()
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: optionFontSize, weight: isSelected ? .medium : .regular),
                .foregroundColor: isSelected ? UIColor.white : palette.textBase
            ]
            let size = (option as NSString).size(withAttributes: attributes)
            (option as NSString).draw(
                at: CGPoint(x: cell.midX - size.width / 2, y: cell.midY - size.height / 2),
                withAttributes: attributes
            )
        }
    }
}
#endif
