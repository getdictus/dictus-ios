// DictusCore/Sources/DictusCore/VoiceNotes/VoiceNoteDiscovery.swift
// Whether the toolbar still teaches the long press on ☰ that opens the voice note reader (issue #639).
import Foundation

/// The voice note hint's policy: when "← Long press: your voice notes" is worth the
/// centre slot.
///
/// `SmartModeDiscovery`'s shape, for the other long press in the bar. The reader has
/// no visible entry point of its own once #637's chip is gone — the ☰ keeps its tap
/// for the panel, and the long press is invisible until somebody says it is there.
/// The ring on ☰ says *something* is waiting; this says *how to get to it*.
///
/// Two conditions, both needed:
///
/// - **A note is waiting.** Teaching a gesture whose outcome is the empty state is a
///   lesson with nothing to show for it, and the hint is tied to something that just
///   happened — which is why it outranks the Smart Mode hint when both apply.
/// - **The user has never long-pressed ☰.** Once is enough: it taught what it had to
///   teach, and a permanent instruction for a gesture performed daily is noise.
///   Nothing brings it back. The onboarding that teaches both long presses is #494's.
public enum VoiceNoteDiscovery {

    private static var defaults: UserDefaults { AppGroup.defaults }

    /// Whether the user has ever opened the reader with a long press on ☰.
    public static var hasUsedLongPress: Bool {
        defaults.bool(forKey: SharedKeys.voiceNoteLongPressUsed)
    }

    /// Record a long press on ☰. Idempotent, and never undone.
    public static func noteLongPressUsed() {
        guard !hasUsedLongPress else { return }
        defaults.set(true, forKey: SharedKeys.voiceNoteLongPressUsed)
        defaults.synchronize()
    }

    /// Whether the hint should be offered the centre slot.
    ///
    /// - Parameter notesWaiting: how many voice notes the keyboard may offer now.
    /// - Parameter longPressUsed: `hasUsedLongPress`, passed in so the caller can
    ///   cache it — the hint is evaluated on every toolbar body, and the flag only
    ///   ever moves once, from this process.
    public static func offersHint(notesWaiting: Int, longPressUsed: Bool) -> Bool {
        notesWaiting > 0 && !longPressUsed
    }
}
