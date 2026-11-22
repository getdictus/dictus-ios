// DictusKeyboard/Vendored/Controllers/LongPressController.swift
// Vendored from giellakbd-ios Keyboard/Controllers/LongPressController.swift
// Stripped: Bundle.top reference replaced with Bundle.main for image loading

import UIKit
import DictusCore

protocol LongPressOverlayDelegate: AnyObject {
    func longpress(didCreateOverlayContentView contentView: UIView)
    func longpressDidCancel()
    func longpress(didSelectKey key: KeyDefinition)

    func longpressFrameOfReference() -> CGRect
    func longpressKeySize() -> CGSize
}

protocol LongPressCursorMovementDelegate: AnyObject {
    /// Move the host's cursor `movedCursor` UTF-16 units, as `adjustTextPosition` counts.
    func longpress(movedCursor: Int)
    func longpressDidCancel()
    /// The text the host shares around its cursor, read now (it lags the moves).
    func longpressTextContext() -> (before: String, after: String)
}

protocol LongPressBehaviorProvider {
    func touchesBegan(_ point: CGPoint)
    func touchesMoved(_ point: CGPoint)
    func touchesEnded(_ point: CGPoint)
}

/// The space-bar trackpad (#950): held, the space bar moves the cursor through the text in
/// two dimensions, at the text's own scale, faster the faster the finger, as Apple's does.
///
/// The approach is Hex's (https://github.com/anomalyco/hex, PRs #2219 and #2233, MIT
/// License, Copyright (c) 2026 Christopher Langton): the text the host shares is laid out the
/// way a field most likely shows it, and the finger drags a point through that layout. The
/// math lives in DictusCore (`TrackpadCursor`), where it is unit-tested; this class only feeds
/// it the finger and moves the host's cursor by what it answers.
///
/// What changed from the giellakbd controller this replaces: 12 pt per character whatever
/// the text, an acceleration that never engaged (its baseline reset after every move, so
/// the ×3 it promised stayed near ×1.2), horizontal only, a 60 Hz cap that dropped moves, an
/// 8 pt dead zone after the hold, and a selection tick per move.
final class LongPressCursorMovementController: NSObject, LongPressBehaviorProvider {
    public weak var delegate: LongPressCursorMovementDelegate?

    /// The finger that held the space bar. Other fingers on the keys are ignored while the
    /// trackpad is on: they type nothing (Apple's starts a selection there, which a keyboard
    /// cannot make), and lifting one does not end the trackpad.
    private weak var touch: UITouch?

    private let wrapWidth: CGFloat
    private var gesture: TrackpadCursor.Gesture?

    /// The keycaps without their labels, over the keys while the trackpad is on.
    private var blankKeys: UIView?

    /// The look a moment after each move, for what the host shows by then (see `refresh`).
    private var refreshes: [DispatchWorkItem] = []

    /// - Parameters:
    ///   - touch: the finger holding the space bar, when the view knows it.
    ///   - keyboardWidth: the keyboard's width, which the host's lines are guessed from.
    init(touch: UITouch?, keyboardWidth: CGFloat) {
        self.touch = touch
        wrapWidth = TrackpadCursor.wrapWidth(forWidth: keyboardWidth)
    }

    /// The trackpad starts where the finger is: travel before the hold doesn't count. Called
    /// again for every other finger that lands while it is on, which it ignores.
    public func touchesBegan(_ point: CGPoint) {
        guard gesture == nil, let delegate else { return }
        let context = delegate.longpressTextContext()
        let font = Self.font()
        let state = TrackpadCursor.State(
            before: context.before,
            after: context.after,
            wrapWidth: wrapWidth,
            lineHeight: font.lineHeight,
            width: Self.width
        )
        gesture = TrackpadCursor.Gesture(state: state, at: point, time: touch?.timestamp ?? CACurrentMediaTime())
    }

    /// Fallback for a caller that has only a point: the time is now.
    public func touchesMoved(_ point: CGPoint) {
        move(to: point, at: CACurrentMediaTime())
    }

    /// The trackpad finger's moves among `touches`, each coalesced sample at its own time,
    /// so the speed reads the finger as the screen sampled it (120 Hz on ProMotion).
    func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) {
        guard let own = ownTouch(in: touches) else { return }
        let samples = event?.coalescedTouches(for: own) ?? [own]
        for sample in samples {
            move(to: sample.location(in: view), at: sample.timestamp)
        }
    }

    /// Whether the trackpad's own finger is among `touches`. A view that never told the
    /// trackpad which finger it is gets the first one, as before.
    func owns(_ touches: Set<UITouch>) -> Bool {
        ownTouch(in: touches) != nil
    }

    /// The finger lifts: the cursor goes where the point is, among the rows known.
    public func touchesEnded(_ point: CGPoint) {
        if var gesture {
            let offset = gesture.lift(at: CACurrentMediaTime())
            self.gesture = gesture
            if offset != 0 { delegate?.longpress(movedCursor: offset) }
        }
        finish()
    }

    /// The system took the touch away (a system gesture, a call): stop where the cursor is.
    func cancel() {
        finish()
    }

    /// Lays blank keycaps over `collectionView`'s keys: Apple's keys lose their labels while
    /// the trackpad is on, and each keycap sits 60% of the way to the backdrop (Hex, from
    /// Apple's 242,242,247 on 226,227,232 in light and 54 on 32 in dark). The view hides the
    /// keys themselves; these stand in for them until the trackpad ends.
    func showBlankKeys(over collectionView: UICollectionView) {
        guard blankKeys == nil, let container = collectionView.superview else { return }
        let overlay = UIView(frame: collectionView.frame)
        overlay.isUserInteractionEnabled = false
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        for cell in collectionView.visibleCells {
            guard let cap = Self.keycap(in: cell),
                  let color = cap.backgroundColor,
                  color.cgColor.alpha > 0 else { continue }
            let blank = UIView(frame: cap.convert(cap.bounds, to: collectionView))
            blank.backgroundColor = color.withAlphaComponent(color.cgColor.alpha * 0.4)
            blank.layer.cornerRadius = cap.layer.cornerRadius
            blank.layer.cornerCurve = cap.layer.cornerCurve
            overlay.addSubview(blank)
        }
        container.insertSubview(overlay, aboveSubview: collectionView)
        blankKeys = overlay
    }

    // MARK: - Private

    private func ownTouch(in touches: Set<UITouch>) -> UITouch? {
        guard let touch else { return touches.first }
        return touches.contains(touch) ? touch : nil
    }

    private func move(to point: CGPoint, at time: TimeInterval) {
        guard var gesture, let delegate else { return }
        let offset = gesture.move(to: point, at: time, context: delegate.longpressTextContext, width: Self.width)
        self.gesture = gesture
        if offset != 0 { delegate.longpress(movedCursor: offset) }
        scheduleRefresh()
    }

    /// Hex settles the cursor again on the host's text and selection callbacks, which tell it
    /// the host has caught up with a move. Those callbacks reach Dictus in the view
    /// controller; looking again a moment after each move gets the same answers without
    /// another hook there. Two looks: one for a host that has caught up (about 10 ms in the
    /// simulator's UITextView), one just after `edgeTimeout`, which is when a step past the
    /// known text that went unanswered is taken as the text's start or end.
    private func scheduleRefresh() {
        refreshes.forEach { $0.cancel() }
        refreshes = [0.03, TrackpadCursor.edgeTimeout + 0.02].map { delay in
            let work = DispatchWorkItem { [weak self] in self?.refresh() }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            return work
        }
    }

    private func refresh() {
        guard var gesture, let delegate else { return }
        let offset = gesture.refresh(at: CACurrentMediaTime(), context: delegate.longpressTextContext, width: Self.width)
        self.gesture = gesture
        if offset != 0 { delegate.longpress(movedCursor: offset) }
    }

    private func finish() {
        refreshes.forEach { $0.cancel() }
        refreshes = []
        gesture = nil
        blankKeys?.removeFromSuperview()
        blankKeys = nil
        delegate?.longpressDidCancel()
    }

    /// The keycap of a key cell: its `KeyView`'s background view.
    private static func keycap(in cell: UICollectionViewCell) -> UIView? {
        var stack: [UIView] = [cell]
        while let view = stack.popLast() {
            if let key = view as? KeyView { return key.contentView }
            stack.append(contentsOf: view.subviews)
        }
        return nil
    }

    // MARK: Character widths

    private static var widths: (font: UIFont, widths: [Character: CGFloat]) = (.systemFont(ofSize: 17), [:])

    /// Body text, as most fields show it (17 pt, larger with Dynamic Type): the font the
    /// trackpad measures characters in (Hex's choice).
    private static func font() -> UIFont {
        let font = UIFont.preferredFont(forTextStyle: .body)
        if font != widths.font { widths = (font, [:]) }
        return font
    }

    /// A character's width in `font()`, measured once.
    private static func width(_ character: Character) -> CGFloat {
        if let width = widths.widths[character] { return width }
        let width = character.isNewline ? 0 : (String(character) as NSString).size(withAttributes: [.font: widths.font]).width
        widths.widths[character] = width
        return width
    }
}

class LongPressOverlayController: NSObject,
    LongPressBehaviorProvider,
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout
{
    class LongpressCollectionView: UICollectionView {}

    private let deadZone: CGFloat = 20.0

    private let key: KeyDefinition
    private let theme: Theme
    let longpressValues: [KeyDefinition]

    private var baselinePoint: CGPoint?
    private var collectionView: UICollectionView?

    private let reuseIdentifier = "longpressCell"

    private var selectedKey: KeyDefinition? {
        didSet {
            if selectedKey?.type != oldValue?.type {
                collectionView?.reloadData()
            }
        }
    }

    weak var delegate: LongPressOverlayDelegate?
    private let labelFont: UIFont

    init(key: KeyDefinition, page: KeyboardPage, theme: Theme, longpressValues: [KeyDefinition]) {
        self.key = key
        self.theme = theme
        self.longpressValues = longpressValues
        switch page {
        case .normal:
            labelFont = theme.popupLongpressLowerKeyFont
        default:
            labelFont = theme.popupLongpressCapitalKeyFont
        }
    }

    private func setup() {
        collectionView = LongpressCollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        collectionView?.register(LongpressKeyCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        collectionView?.translatesAutoresizingMaskIntoConstraints = false
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.backgroundColor = .clear
        // The popup never scrolls, and iOS 27 blurs its letters with the scroll edge effect (#884).
        if #available(iOS 26.0, *) {
            collectionView?.topEdgeEffect.isHidden = true
            collectionView?.bottomEdgeEffect.isHidden = true
            collectionView?.leftEdgeEffect.isHidden = true
            collectionView?.rightEdgeEffect.isHidden = true
        }

        if let delegate = self.delegate {
            delegate.longpress(didCreateOverlayContentView: collectionView!)
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func touchesBegan(_ point: CGPoint) {
        if baselinePoint == nil {
            baselinePoint = point
            setup()
        }
        pointUpdated(point)
    }

    public func touchesMoved(_ point: CGPoint) {
        if baselinePoint == nil {
            baselinePoint = point
            setup()
        }
        pointUpdated(point)
    }

    public func touchesEnded(_ point: CGPoint) {
        pointUpdated(point)

        if let selectedKey = self.selectedKey {
            delegate?.longpress(didSelectKey: selectedKey)
        } else {
            delegate?.longpressDidCancel()
        }
    }

    private func longPressTouchPoint(at point: CGPoint,
                                     cellSize: CGSize,
                                     view collectionView: UICollectionView,
                                     parentView: UIView) -> CGPoint {
        func pointInCollectionView(with point: CGPoint) -> CGPoint {
            let bounds = collectionView.bounds
            let halfWidth = cellSize.width / 2.0
            let halfHeight = cellSize.height / 2.0
            let heightOffset: CGFloat = collectionView.shouldUseiPadLayout ? 0 : -halfHeight

            var x = point.x
            let minX = bounds.minX
            let maxX = bounds.maxX

            if x <= minX {
                x = minX + halfWidth
            } else if x >= maxX {
                x = maxX - halfWidth
            }

            var y = point.y + heightOffset
            let minY = collectionView.bounds.minY
            let maxY = collectionView.bounds.maxY

            if y <= minY {
                y = minY + halfHeight
            } else if y >= maxY {
                y = maxY - halfHeight
            }

            return CGPoint(x: x, y: y)
        }

        let selectionBox: CGRect = collectionView.frame.insetBy(dx: -cellSize.width, dy: -cellSize.height)

        let convertedPoint = parentView.convert(point, to: collectionView)
        if selectionBox.contains(convertedPoint) {
            return pointInCollectionView(with: convertedPoint)
        }

        return point
    }

    private func pointUpdated(_ point: CGPoint) {
        let cellSize = delegate?.longpressKeySize() ?? CGSize(width: 20, height: 30.0)
        let bigFrame = delegate!.longpressFrameOfReference()
        var superView: UIView? = collectionView

        repeat {
            superView = superView?.superview
        } while superView?.bounds != bigFrame && superView != nil

        guard let wholeView = superView else { return }
        guard let collectionView = self.collectionView else { return }

        let point = longPressTouchPoint(at: point, cellSize: cellSize, view: collectionView, parentView: wholeView)

        if let indexPath = collectionView.indexPathForItem(at: point) {
            selectedKey = longpressValues[indexPath.row + Int(ceil(Double(longpressValues.count) / 2.0)) * indexPath.section]
        } else {
            selectedKey = nil
        }
    }

    func numberOfSections(in _: UICollectionView) -> Int {
        return longpressValues.count > theme.popupLongpressKeysPerRow ? 2 : 1
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if longpressValues.count > theme.popupLongpressKeysPerRow {
            return section == 0 ? Int(ceil(Double(longpressValues.count) / 2.0)) : Int(floor(Double(longpressValues.count) / 2.0))
        }
        return longpressValues.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
                                                            for: indexPath) as? LongpressKeyCell else {
            fatalError("Unable to cast to LongpressKeyCell")
        }
        cell.configure(theme: theme)
        let key = longpressValues[indexPath.row + Int(ceil(Double(longpressValues.count) / 2.0)) * indexPath.section]

        // Font scaled to match the reduced longpressKeySize height (#69).
        cell.label.font = labelFont.withSize(labelFont.pointSize * 0.8)

        func setupKeyboardModeCell(imageName: String) {
            // Use Bundle.main instead of Bundle.top (Divvun-specific)
            cell.imageView.image = UIImage(named: imageName, in: Bundle.main, compatibleWith: collectionView.traitCollection)
        }

        if case let .input(string, _) = key.type {
            cell.label.text = string
            cell.imageView.image = nil
        } else if case .normalKeyboard = key.type {
            setupKeyboardModeCell(imageName: "keyboard-mode-normal")
        } else if case .splitKeyboard = key.type {
            setupKeyboardModeCell(imageName: "keyboard-mode-split")
        } else if case .sideKeyboardLeft = key.type {
            setupKeyboardModeCell(imageName: "keyboard-mode-left")
        } else if case .sideKeyboardRight = key.type {
            setupKeyboardModeCell(imageName: "keyboard-mode-right")
        }

        if key.type == selectedKey?.type {
            cell.select(theme: theme)
        } else {
            cell.deselect(theme: theme)
        }

        return cell
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt _: IndexPath) -> CGSize {
        return delegate?.longpressKeySize() ?? CGSize(width: 20, height: 30.0)
    }

    func collectionView(_: UICollectionView,
                        layout _: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt _: Int) -> CGFloat {
        return 0
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, minimumLineSpacingForSectionAt _: Int) -> CGFloat {
        return 0
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout _: UICollectionViewLayout,
                        insetForSectionAt _: Int) -> UIEdgeInsets {
        let cellSize = delegate?.longpressKeySize() ?? CGSize(width: 20.0, height: 30.0)
        let cellWidth = cellSize.width
        let numberOfCells = CGFloat(longpressValues.count)

        guard numberOfCells <= 1 else { return .zero }

        let edgeInsets = (collectionView.frame.size.width - (numberOfCells * cellWidth)) / (numberOfCells + 1)
        return UIEdgeInsets(top: 0, left: edgeInsets, bottom: 0, right: edgeInsets)
    }

    class LongpressKeyCell: UICollectionViewCell {
        let label: UILabel
        let imageView: UIImageView

        private(set) var isSelectedKey: Bool = false

        func select(theme: Theme) {
            label.textColor = theme.activeTextColor
            label.backgroundColor = theme.longPressActiveColor
            imageView.tintColor = theme.activeTextColor
            isSelectedKey = true
        }

        func deselect(theme: Theme) {
            label.textColor = theme.textColor
            label.backgroundColor = theme.popupColor
            imageView.tintColor = theme.textColor
            isSelectedKey = false
        }

        override init(frame: CGRect) {
            label = UILabel(frame: frame)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textAlignment = .center
            label.clipsToBounds = true

            imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit

            super.init(frame: frame)

            addSubview(label)
            addSubview(imageView)
            imageView.fill(superview: self)
            label.fill(superview: self)
        }

        func configure(theme: Theme) {
            label.layer.cornerRadius = theme.keyCornerRadius
            imageView.tintColor = theme.textColor
        }

        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
