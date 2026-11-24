// DictusKeyboard/Views/EmojiPickerView.swift
import AudioToolbox
import DictusCore
import SwiftUI
import UIKit

/// The emoji picker under the toolbar: Hex's emoji panel (DictusCore/Emoji, ported from
/// github.com/anomalyco/hex, MIT; #1027), hosted in SwiftUI.
///
/// WHY a thin wrapper with the old initializer: `KeyboardRootView` builds this view with the
/// same five arguments it always passed, so replacing the picker leaves that file — and the
/// view controller's geometry for `.emoji` — exactly as they were.
///
/// WHAT THE PANEL FIXES over the picker it replaces: ABC and search answer in their whole band
/// (they answered only on their glyphs); emoji are drawn into a bounded bitmap cache instead
/// of as text, whose glyphs iOS never released (110 MB after scrolling every category on the
/// simulator, still held after closing); skin tones; every category in one grid; recents that
/// do not move under the finger; and a search index in French, English, Spanish and German.
struct EmojiPickerView: View {
    let onEmojiInsert: (String) -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    /// The measured area. WHY parameters: in a keyboard extension the hosting controller may
    /// not give SwiftUI the full width, so the parent measures it and the panel takes exactly that.
    let availableWidth: CGFloat
    let availableHeight: CGFloat

    var body: some View {
        EmojiPanelHost(onEmojiInsert: onEmojiInsert, onDelete: onDelete, onDismiss: onDismiss)
            .frame(width: availableWidth, height: availableHeight)
            .clipped()
    }
}

/// `UIViewRepresentable` is SwiftUI's door to a UIKit view: SwiftUI calls `makeUIView` once,
/// `updateUIView` on every redraw (here only to refresh the closures), and `dismantleUIView`
/// when the picker goes, which is where the panel lets go of its bitmaps and timers.
private struct EmojiPanelHost: UIViewRepresentable {
    let onEmojiInsert: (String) -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    final class Coordinator {
        var host: EmojiPanelHost

        init(host: EmojiPanelHost) {
            self.host = host
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(host: self)
    }

    func makeUIView(context: Context) -> UIView {
        let coordinator = context.coordinator
        // One index per process (EmojiLibrary.bundled), not one per presentation: Hex #2352.
        guard let library = EmojiLibrary.bundled(language: SupportedLanguage.active.rawValue) else {
            return Self.unavailableView(onDismiss: { coordinator.host.onDismiss() })
        }
        let panel = EmojiPanelView(
            library: library,
            usage: EmojiUsageStore(),
            strings: Self.strings,
            letterRows: EmojiPanelView.letterRows(for: LayoutType.active)
        )
        panel.onInsert = { coordinator.host.onEmojiInsert($0) }
        panel.onDelete = { coordinator.host.onDelete() }
        panel.onLetters = { coordinator.host.onDismiss() }
        panel.onKeyClick = { category in
            // Inserting and deleting already give their haptic in `KeyboardRootView`'s
            // closures; the panel's other keys (categories, search, ABC, search letters)
            // give theirs here, with the click the main keys make (`KeySoundCategory`).
            if category != .delete { HapticFeedback.keyTapped() }
            AudioServicesPlaySystemSound(category.systemSoundID)
        }
        panel.textBefore = { KeyboardState.shared.controller?.textDocumentProxy.documentContextBeforeInput }
        panel.fill()
        return panel
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.host = self
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        (uiView as? EmojiPanelView)?.tearDown()
    }

    /// The keyboard's own words for the panel: the keys its old picker already had.
    private static var strings: EmojiPanelStrings {
        EmojiPanelStrings(
            recents: String(localized: "Recents", comment: "Emoji picker section header for recently used emoji (issue #418)."),
            categories: [
                .smileys: String(localized: "Smileys", comment: "Emoji picker section header, shown uppercased above the grid."),
                .people: String(localized: "People", comment: "Emoji picker section header, shown uppercased above the grid."),
                .animalsNature: String(localized: "Animals & Nature", comment: "Emoji picker section header, shown uppercased above the grid."),
                .foodDrink: String(localized: "Food & Drink", comment: "Emoji picker section header, shown uppercased above the grid."),
                .activity: String(localized: "Activities", comment: "Emoji picker section header, shown uppercased above the grid."),
                .travelPlaces: String(localized: "Travel", comment: "Emoji picker section header, shown uppercased above the grid."),
                .objects: String(localized: "Objects", comment: "Emoji picker section header, shown uppercased above the grid."),
                .symbols: String(localized: "Symbols", comment: "Emoji picker section header, shown uppercased above the grid."),
                .flags: String(localized: "Flags", comment: "Emoji picker section header, shown uppercased above the grid.")
            ],
            searchPlaceholder: String(localized: "Search Emoji"),
            noResults: String(localized: "No results"),
            lettersTitle: String(localized: "ABC", comment: "The text for the \"ABC\" button in the emoji category bar."),
            lettersLabel: NSLocalizedString("accessibility.moreLetters", comment: ""),
            delete: NSLocalizedString("accessibility.backspace", comment: ""),
            space: String(localized: "space"),
            closeSearch: String(localized: "Close", comment: "Accessibility label of the keyboard voice note reader's close button (#637).")
        )
    }

    /// The index could not be read (it ships in DictusCore's bundle, so this means a broken
    /// build): an ABC key back to the letters rather than an empty keyboard.
    private static func unavailableView(onDismiss: @escaping () -> Void) -> UIView {
        let button = UIButton(type: .system, primaryAction: UIAction { _ in onDismiss() })
        button.setTitle(String(localized: "ABC", comment: "The text for the \"ABC\" button in the emoji category bar."), for: .normal)
        return button
    }
}
