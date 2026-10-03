// DictusCore/Sources/DictusCore/ToolbarCentreSlot.swift
// What the keyboard toolbar's centre slot shows, by priority (issues #79, #241, #266).
import Foundation

/// The one occupant of the toolbar's centre slot.
///
/// ### Why this is a value and not a chain of `if`s in the view
///
/// Six things compete for the same strip of the same 52 pt bar, arriving from six
/// different lifecycles — a dictation failing in another process, an insertion that
/// just landed, a keystroke, a rate limit that lasts the whole process, a setting
/// made last week, and a first-run hint. #79 specifies them as a priority table, and
/// a priority table written as nested branches in a SwiftUI body is a table nobody
/// can check. The keyboard extension has no test bundle; DictusCore does, which is
/// the same argument `KeyboardAreaMode` makes.
///
/// ### The order, and what each place is buying
///
/// 0. **Choosing a mode** — the fan is open under the user's thumb *right now*. It
///    outranks the error and the undo because both of those describe something that
///    already finished, and the bar is the only place left to title a menu that has
///    taken the keys: the fan itself cannot carry a header without pushing its rows
///    down, and the row positions are the arithmetic the release depends on.
/// 1. **Error** — the dictation failed. Nothing below it is worth saying, and undo
///    in particular is meaningless because nothing was inserted.
/// 2. **Undo** (#266) — expires in seconds and on the first keystroke, and it is the
///    only alternative to holding backspace on a two-minute dictation.
/// 3. **Suggestions** — the keyboard's core job, and the reason the left slot yields
///    at all (`ToolbarView` needs the width for three legible slots).
/// 3b. **Voice notes waiting** (#637) — a transcript shared to Dictus is ready to be
///    inserted. Below the suggestions so a user mid-word keeps them: the chip yields
///    and comes back the moment the slot is free. Above everything that describes a
///    *setting* or a *process state*, because this is the only occupant below the
///    suggestions that carries something of the user's own, waiting to be used — and
///    it expires (24 h), where the notice and the armed mode do not.
/// 4. **Polish unavailable** (#315) — not in #79's table, which predates it. It sits
///    here rather than higher because it can last the whole process, and above the
///    suggestions it would suppress completions for that entire time. It sits above
///    the two Smart Mode entries because when polish will not run, the armed mode
///    will not run either: naming the mode there would be advertising something the
///    process has already stopped doing.
/// 5. **Armed mode name** (#79) — a sticky setting the user made once, possibly
///    weeks ago, on a surface they only see when idle. Two cases at this rung, and
///    which one shows is decided by whether a dictation starting now would actually
///    honour it (#423): `armedMode` when it runs, `armedModeInactive` when it does
///    not. Same rung because it is the same fact — this is what you armed — and
///    demoting the inactive one would hide the very thing the user needs to see to
///    understand why their dictations changed.
/// 6. **Discovery hint** (#79) — costs nothing, because it only renders when there
///    is nothing else at all to show.
public enum ToolbarCentreSlot: Equatable, Sendable {

    /// The Smart Mode fan is open: the bar titles it.
    case choosingMode

    /// A dictation or Smart Mode failure, in red.
    case error(String)

    /// The undo-insertion control (#266).
    case dictationUndo

    /// The autocorrect suggestion bar.
    case suggestions

    /// Shared voice note transcripts are waiting for the keyboard (#637). Tapping it
    /// opens the reader. `count` is at least 1.
    case voiceNotesWaiting(count: Int)

    /// The #315 notice: this process has stopped calling the polish engine.
    case polishUnavailable

    /// The armed Smart Mode's display name.
    case armedMode(String)

    /// The armed Smart Mode's display name, for a mode that **will not run** (#423).
    ///
    /// A separate case rather than a flag on `armedMode` because the two say opposite
    /// things and the view must not be able to draw one as the other. `armedMode` is
    /// a statement about what the next dictation does; this one is a statement about
    /// a setting that survived a condition it cannot run under — Smart Modes switched
    /// off, no subscription, Apple Intelligence off, the model still downloading.
    ///
    /// It keeps the slot rather than falling through to the hint, because the choice
    /// is still there and re-teaching the gesture to someone who has armed a mode
    /// would be absurd. What it must not do is read as active: that is #423, where
    /// the bar named the mode in accent blue while every dictation ran Normal.
    case armedModeInactive(String)

    /// "Long-press for Smart Modes".
    case discoveryHint

    /// Nothing to say. The hamburger sits alone opposite the mic, which is what the
    /// bar looked like before any of this existed.
    case empty

    // swiftlint:disable function_parameter_count
    // Nine parameters because there are eight competitors and one of them needs a
    // second fact to pick between its two shapes (#423). A table with eight rows
    // needs eight inputs. Wrapping them in a struct would move the seven names
    // one line up and add a type whose only job is to be unpacked here; the
    // alternative that would genuinely reduce the count — resolving some of them in
    // here — is worse, because it would put UserDefaults and Apple Intelligence reads
    // behind a pure function the tests drive by hand.

    /// What the slot resolves to.
    ///
    /// - Parameter isChoosingMode: whether the long-press fan is on screen.
    /// - Parameter armedModeName: the armed mode's display name, or nil for Normal.
    /// - Parameter armedModeIsEffective: whether a dictation starting now would
    ///   actually run that mode — `SmartModeAvailability.forDictation` (#423). No
    ///   default, for the reason `SmartModeAvailability.armability` gives about its
    ///   own entitlement parameter: a default here is exactly the trap, because the
    ///   safe-looking answer is the one that produced the bug.
    /// - Parameter offersDiscoveryHint: whether the hint is still worth showing —
    ///   the caller owns that policy, see `SmartModeDiscovery`.
    /// - Parameter voiceNotesWaiting: how many shared voice note transcripts the
    ///   keyboard may offer (#637). Zero for none.
    public static func resolve(isChoosingMode: Bool,
                               errorMessage: String?,
                               offersDictationUndo: Bool,
                               hasSuggestions: Bool,
                               voiceNotesWaiting: Int,
                               polishUnavailable: Bool,
                               armedModeName: String?,
                               armedModeIsEffective: Bool,
                               offersDiscoveryHint: Bool) -> ToolbarCentreSlot {
        if isChoosingMode { return .choosingMode }
        if let errorMessage { return .error(errorMessage) }
        if offersDictationUndo { return .dictationUndo }
        if hasSuggestions { return .suggestions }
        if voiceNotesWaiting > 0 { return .voiceNotesWaiting(count: voiceNotesWaiting) }
        if polishUnavailable { return .polishUnavailable }
        if let armedModeName {
            return armedModeIsEffective ? .armedMode(armedModeName) : .armedModeInactive(armedModeName)
        }
        if offersDiscoveryHint { return .discoveryHint }
        return .empty
    }
    // swiftlint:enable function_parameter_count

    /// Whether this occupant needs the full width, taking the left slot with it.
    ///
    /// The three that do are the three that arrive mid-task and are read at a
    /// glance. The rest share the bar with the hamburger, at the cost — accepted
    /// since #241 — that the keyboard language cannot be changed mid-word.
    ///
    /// The voice note chip shares it (#637) for the polish notice's reason (#315): it
    /// can last as long as a note waits, up to a day, and in the hamburger's place it
    /// would make the panel unreachable for all of that time.
    public var evictsHamburger: Bool {
        switch self {
        case .error, .dictationUndo, .suggestions: return true
        case .choosingMode, .voiceNotesWaiting, .polishUnavailable, .armedMode,
             .armedModeInactive, .discoveryHint, .empty:
            return false
        }
    }
}
