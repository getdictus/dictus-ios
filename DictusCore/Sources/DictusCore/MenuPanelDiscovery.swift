// DictusCore/Sources/DictusCore/MenuPanelDiscovery.swift
// Whether the toolbar still teaches the long press on ☰ that opens the keyboard panel (issue #639).
import Foundation

/// The panel hint's policy: when "← Long press: languages & settings" is worth the
/// centre slot.
///
/// #639 gave the ☰ two gestures, tap for the voice note reader and long press for
/// the panel (languages, layouts, Settings, Pro). The panel used to be the tap, so
/// the user who has to be told where it went is the one who has met the new tap.
/// `SmartModeDiscovery`'s shape, for the other long press in the bar.
///
/// Two conditions, both needed:
///
/// - **The user has opened the reader with a tap at least once.** Before that, the
///   ☰ has not surprised anybody, and the slot belongs to whatever else it holds.
/// - **The user has never long-pressed ☰.** Once is enough: it taught what it had to
///   teach. Nothing brings it back. The onboarding that teaches both long presses is
///   #494's.
public enum MenuPanelDiscovery {

    private static var defaults: UserDefaults { AppGroup.defaults }

    /// Whether the user has ever opened the voice note reader with a tap on ☰.
    public static var hasOpenedReaderByTap: Bool {
        defaults.bool(forKey: SharedKeys.voiceNoteReaderOpenedByTap)
    }

    /// Whether the user has ever opened the panel with a long press on ☰.
    public static var hasUsedLongPress: Bool {
        defaults.bool(forKey: SharedKeys.menuLongPressUsed)
    }

    /// Record a tap on ☰ that opened the reader. Idempotent, and never undone.
    public static func noteReaderOpenedByTap() {
        guard !hasOpenedReaderByTap else { return }
        defaults.set(true, forKey: SharedKeys.voiceNoteReaderOpenedByTap)
        defaults.synchronize()
    }

    /// Record a long press on ☰. Idempotent, and never undone.
    public static func noteLongPressUsed() {
        guard !hasUsedLongPress else { return }
        defaults.set(true, forKey: SharedKeys.menuLongPressUsed)
        defaults.synchronize()
    }

    /// Whether the hint should be offered the centre slot. Both facts are passed in so
    /// the caller can cache them: the hint is evaluated on every toolbar body, and
    /// each flag only ever moves once, from the keyboard process.
    public static func offersHint(readerOpenedByTap: Bool, longPressUsed: Bool) -> Bool {
        readerOpenedByTap && !longPressUsed
    }
}
