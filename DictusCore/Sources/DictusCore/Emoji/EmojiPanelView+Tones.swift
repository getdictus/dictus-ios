// Ported from Hex (github.com/anomalyco/hex, branch dev @ 492d8c2,
// ios/HEXShared/FullKeyboard/Emoji/EmojiPanelView.swift, "Skin tones"), MIT,
// Copyright (c) 2026 Christopher Langton.
// Dictus's change (#1027): a picker released where it opened stays open for a tap.
#if canImport(UIKit)
import UIKit

extension EmojiPanelView {
    /// How far a finger may drift on the held emoji and still count as not having moved.
    static let toneStillDistance: CGFloat = 10

    @objc func held(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            hideCallout()
            guard let indexPath = grid.indexPathForItem(at: gesture.location(in: grid)),
                  let frame = cellFrame(indexPath) else { return }
            let entry = sections[indexPath.section].entries[indexPath.item]
            guard library.entries[entry].hasTones else {
                // Without tones a hold is a slow tap: typed if the finger lifts over it.
                heldEntry = (entry, frame)
                return
            }
            toneStart = point
            showTones(for: entry, over: frame)
        case .changed:
            guard var menu = tonePicker.menu else { return }
            let moved = hypot(point.x - toneStart.x, point.y - toneStart.y) > Self.toneStillDistance
            guard moved else { return }
            let index = menu.index(for: point.x)
            if index != menu.selectedIndex {
                menu.selectedIndex = index
                tonePicker.show(menu)
            }
        case .ended:
            hideCallout()
            if let held = heldEntry {
                heldEntry = nil
                if held.frame.insetBy(dx: -4, dy: -4).contains(point) {
                    insert(display(for: held.entry), entry: held.entry)
                }
                return
            }
            guard let menu = tonePicker.menu, let entry = toneEntry else { return }
            // Released where it opened: the picker stays, as iOS's does, and a tap picks.
            if hypot(point.x - toneStart.x, point.y - toneStart.y) <= Self.toneStillDistance {
                toneAwaitsTap = true
                return
            }
            pickTone(menu.options[menu.index(for: point.x)], for: entry)
        default:
            hideCallout()
            heldEntry = nil
            closeTones()
        }
    }

    /// Opens the skin tone picker over a cell, the remembered tone selected.
    func showTones(for entry: Int, over frame: CGRect) {
        let item = library.entries[entry]
        // As the system keyboard's: emoji about its grid's size, the untoned one set apart.
        var menu = AccentMenu.build(for: frame, rawOptions: [item.emoji] + item.tones, in: bounds.width, cellWidth: 44)
        tonePicker.optionFontSize = 28
        tonePicker.separatedOption = item.emoji
        if let index = menu.options.firstIndex(of: display(for: entry)) { menu.selectedIndex = index }
        toneEntry = entry
        tonePicker.show(menu)
    }

    func pickTone(_ chosen: String, for entry: Int) {
        let item = library.entries[entry]
        let tone = item.tones.firstIndex(of: chosen).map { $0 + 1 } ?? 0
        usage.setTone(tone, for: item.emoji)
        closeTones()
        insert(chosen, entry: entry)
        // Every cell showing it takes the new tone.
        grid.reloadData()
        suggestionRow.setItems(suggestions.map { (display(for: $0), library.name(of: $0)) })
    }

    func closeTones() {
        tonePicker.show(nil)
        toneEntry = nil
        toneAwaitsTap = false
    }

    /// The tap an open picker waits for: on a tone picks it, anywhere else closes the picker.
    /// `hitTest` sends every touch here while it waits.
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard toneAwaitsTap, let touch = touches.first, let menu = tonePicker.menu, let entry = toneEntry else {
            super.touchesEnded(touches, with: event)
            return
        }
        let point = touch.location(in: self)
        if menu.bubbleFrame.insetBy(dx: -4, dy: -6).contains(point) {
            pickTone(menu.options[menu.index(for: point.x)], for: entry)
        } else {
            closeTones()
        }
    }

    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if toneAwaitsTap { closeTones() }
        super.touchesCancelled(touches, with: event)
    }
}
#endif
