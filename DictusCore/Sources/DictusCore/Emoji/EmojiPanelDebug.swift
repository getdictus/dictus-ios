// DEBUG-only probes for the emoji panel (#1027), in the spirit of Hex's `debugScroll`.
//
// WHY: on the simulator, `axe` taps reach the keyboard extension but its drags never do (tried
// swipe, finer samples, a held swipe and contact-token moves, 2026-11-22), so nothing outside
// the keyboard can scroll the grid. A Darwin notification posted inside the simulator can:
//
//     xcrun simctl spawn <udid> notifyutil -p dictus.debug.emojiScrollAll
//
// scrolls every open panel's grid from start to end, a screen at a time, which is what the
// memory measurement "after scrolling every category" needs. The panels also log when they are
// made and freed, which is how a leaked panel (Hex #2352) would show. Release builds have none
// of this.
#if DEBUG && canImport(UIKit)
import UIKit

@MainActor
enum EmojiPanelDebug {
    static let scrollAllName = "dictus.debug.emojiScrollAll"
    private static let panels = NSHashTable<EmojiPanelView>.weakObjects()
    private static var observing = false

    static func register(_ panel: EmojiPanelView) {
        panels.add(panel)
        NSLog("EMOJI_DEBUG panel created, live panels: %d", panels.allObjects.count)
        guard !observing else { return }
        observing = true
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { EmojiPanelDebug.scrollAll() }
                }
            },
            scrollAllName as CFString,
            nil,
            .deliverImmediately
        )
    }

    static func scrollAll() {
        for panel in panels.allObjects where panel.window != nil {
            panel.debugScrollThroughEverything()
        }
    }
}

extension EmojiPanelView {
    /// Scrolls the grid from its start to its end, most of a screen every 60 ms, so every
    /// emoji is drawn once.
    func debugScrollThroughEverything() {
        grid.layoutIfNeeded()
        grid.setContentOffset(.zero, animated: false)
        step()
    }

    private func step() {
        let maxX = max(0, grid.contentSize.width - grid.bounds.width)
        guard grid.contentOffset.x < maxX else {
            NSLog("EMOJI_DEBUG scrolled to the end: %.0f pt, %d bitmaps cached (%d bytes), %d drawn",
                  maxX, glyphs.cachedCount, glyphs.cachedBytes, glyphs.renders)
            return
        }
        grid.setContentOffset(CGPoint(x: min(maxX, grid.contentOffset.x + grid.bounds.width * 0.8), y: 0), animated: false)
        grid.layoutIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in self?.step() }
    }
}
#endif
