// DictusCore/Sources/DictusCore/KeyboardAreaMode.swift
// Single value describing what the keyboard extension's keyboard area presents.
import Foundation

/// What the keyboard area — the region below the 52 pt toolbar — is presenting.
///
/// Before #271 this was three independent flags spread over two layers: a SwiftUI
/// `@State` for the emoji picker in `KeyboardRootView`, a separate `Bool` for the
/// same picker in `KeyboardViewController` (kept in step through
/// `NotificationCenter`), and the recording overlay derived from `DictationStatus`.
/// Nothing in the type system stopped two of them being true at once, and the
/// layout code that reacted to them was a chain of negated guards that any new
/// full-area state had to be added to by hand — a state that was forgotten
/// collapsed to toolbar height while still being rendered.
///
/// With one value, mutual exclusion is a consequence of the type. Both layers
/// switch on it: SwiftUI to pick the branch it renders, the view controller to set
/// the hosting height, the hosting bottom anchor and the key grid's visibility.
///
/// Lives in DictusCore rather than DictusKeyboard so the transition rule below is
/// unit-testable — the keyboard extension target has no test bundle. Same
/// reasoning as `DefaultKeyboardLayer` and `LayoutType`.
public enum KeyboardAreaMode: String, Equatable, CaseIterable, Sendable {
    /// The UIKit key grid. Toolbar sits above it at 52 pt.
    case keys
    /// The emoji picker fills the area; the toolbar stays visible above it.
    case emoji
    /// Reserved for the hamburger panel (#241). No view is attached yet — the
    /// layout contract exists so #241 adds a view rather than reopening #271.
    case panel
    /// The long-press Smart Mode fan fills the area; the toolbar stays visible above
    /// it, because the gesture that opened it is still live on the mic (#79).
    ///
    /// WHY it is a mode rather than a SwiftUI overlay on the toolbar: in `.keys` the
    /// hosting view is 52 pt tall and SwiftUI cannot draw outside it. The fan deploys
    /// *downward* over the keys, so it needs the area — the same contract the emoji
    /// picker and the panel already have, reached the same way, touching nothing
    /// else.
    case smartModeFan
    /// The recording overlay fills the whole area, toolbar included.
    case recording
    /// The voice note reader fills the whole area, toolbar included (#637): the
    /// transcripts of voice notes shared to Dictus, one page each, with an explicit
    /// `Insert`.
    ///
    /// WHY the whole area and not the area below the bar, like the pickers: the
    /// reader's header takes the toolbar's 52 pt band, so the keyboard *becomes* the
    /// transcript for a moment rather than hosting a panel. That is `.recording`'s
    /// geometry exactly, and it is reached the same way — no new height, no new
    /// anchor, and the keyboard's declared height untouched (#166).
    ///
    /// Opened only by the keyboard itself: from a tap on ☰ (#639), or on an
    /// appearance (`VoiceNoteKeyboardPresentation`). A dictation takes the area from it like from
    /// any other mode, and leaving the dictation returns to the keys.
    case voiceNoteResult

    /// Whether only the controller that owns the keyboard area and is visible may
    /// present this mode; any other instance falls back to `.keys`.
    ///
    /// `KeyboardRootView.presentedMode` and `KeyboardViewController.applyAreaMode`
    /// both ask this, so the two layers cannot disagree about which modes are gated.
    /// `.recording` is pushed from another process and can arrive while no controller
    /// owns the keyboard (#260). `.voiceNoteResult` can open from a keyboard
    /// appearance, where iOS keeps several cached controllers alive (#128), and it
    /// carries an `Insert` that writes into a text field — the last thing a stale
    /// instance may be allowed to draw. The pickers are opened by a key the user just
    /// touched on the visible keyboard, and are not gated (see `presentedMode`).
    ///
    /// An exhaustive switch so a new mode has to answer.
    public var requiresVisibleOwner: Bool {
        switch self {
        case .recording, .voiceNoteResult:
            return true
        case .keys, .emoji, .panel, .smartModeFan:
            return false
        }
    }

    /// The mode after a dictation status change.
    ///
    /// A dictation owns the entire keyboard area while it is in flight, so
    /// entering an owning status is the explicit transition that dismisses the
    /// emoji picker (or, later, the #241 panel). Leaving it returns to the key
    /// grid: a picker the user had open before dictating is not restored, which
    /// is what the pre-#271 code did by clearing its emoji flag on overlay show.
    ///
    /// The voice note reader (#637) follows the same rule. Its notes are not lost —
    /// nothing is consumed by a dictation — and the keyboard rereads them when the
    /// dictation leaves, so the ☰ halo is back with the keys (#639).
    public static func resolving(
        status: DictationStatus,
        current: KeyboardAreaMode
    ) -> KeyboardAreaMode {
        if status.ownsKeyboardArea {
            return .recording
        }
        return current == .recording ? .keys : current
    }
}

public extension DictationStatus {
    /// Whether a dictation round-trip currently owns the keyboard area, i.e.
    /// whether the recording overlay should be filling it.
    ///
    /// WHY an exhaustive switch and not a `Set` membership test: adding a case to
    /// `DictationStatus` must not silently fall through to "does not own the area".
    /// The compiler stops on this function instead, which is how `processing`
    /// (#267) got here.
    ///
    /// `processing` owning the area is what keeps the overlay on screen through the
    /// LLM stage: it resolves to the same `.recording` mode every other in-flight
    /// status does, so the view controller sees no new mode and no new height.
    var ownsKeyboardArea: Bool {
        switch self {
        case .requested, .recording, .transcribing, .processing:
            return true
        case .idle, .ready, .failed:
            return false
        }
    }
}
