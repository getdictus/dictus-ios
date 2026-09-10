// DictusCore/Sources/DictusCore/MirrorSync.swift
// Detects that UITextDocumentProxy's mirror has stopped reflecting the keyboard's
// own edits, and holds the resulting suppression (issue #530).
//
// THE BUG THIS PREVENTS:
// Deleting a selected word leaves `documentContextBeforeInput` reporting characters
// the document does not hold. Every keyboard decision that counts characters off it
// then over-counts: autocorrect deletes one too many, eats the space before the word
// and merges it with the previous one ("Ok je vais" -> "Ok jevais"), and the
// auto-period writes ". " over a space that is not there. The user's untouched text
// is destroyed, and each repair attempt arms the next one.
//
// WHY A KEYBOARD CAN DETECT THIS AT ALL:
// It cannot observe the document — that is the premise of #530, and two fix designs
// died on hoping otherwise. But it does not need to. It knows what IT just did, so
// it can check that the mirror moved by exactly that much. The 2026-09-10 capture
// caught the divergence on precisely that signal: the keyboard pressed backspace,
// its own prediction went 54 -> 53, and the mirror stayed at 49.
//
// WHY LENGTHS AND NOT TEXT:
// The trigger is arithmetic, so this needs no shadow copy of the document. Two
// integer reads bracket one edit, and both happen inside a single synchronous
// run-loop turn — no host callback can land between them, so nothing but the
// keyboard's own edit can move the mirror. That is what makes a discrepancy
// attributable rather than merely suspicious.
//
// READING A LOG: `off=0` FROM MirrorProbe IS NOT PROOF OF A TRUTHFUL MIRROR.
// The diagnostic instrument compares the mirror to a prediction, never to the
// document. When it re-baselines on a lying mirror it absorbs the lie and reports
// agreement afterwards — that is exactly what happened at seq=42 of the capture,
// and why the destructive apply four seconds later logged `off=0`. Only the screen
// recording showed the mirror was still wrong.

import Foundation

/// The arithmetic half: did the mirror move by what one keyboard edit implies?
public enum MirrorSync {

    /// What one edit's before/after pair says about the mirror.
    public enum Verdict: Equatable {
        /// The mirror moved by exactly the edit. Nothing to do.
        case consistent
        /// The mirror holds `by` characters the edit does not account for. This is
        /// the destructive direction: a later count taken off the mirror will
        /// over-delete and cross a word boundary. Arm.
        case mirrorAhead(by: Int)
        /// The mirror moved by more than the edit, or grew less. The document holds
        /// characters the mirror lacks, so a later count UNDER-deletes and leaves a
        /// stray character — a typo one backspace clears, not destroyed text.
        /// Deliberately not armed on: it is also the shape of two harmless things,
        /// a combining mark merging into the previous grapheme and a windowed
        /// mirror that has stopped growing (#266).
        case mirrorBehind(by: Int)
    }

    /// Compares one keyboard edit against the mirror's movement.
    ///
    /// - Parameters:
    ///   - before: `documentContextBeforeInput.count` read immediately BEFORE the edit.
    ///   - after: the same value read immediately AFTER it, same run-loop turn.
    ///   - deleted: deleteBackward() calls the edit issued.
    ///   - inserted: graphemes the edit inserted.
    public static func verdict(before: Int, after: Int, deleted: Int, inserted: Int) -> Verdict {
        // A delete can never consume more than the mirror is showing. Without this,
        // backspace on an empty field expects -1, observes 0, and looks exactly like
        // the bug — the most common keystroke in the app arming the suppression.
        let expected = inserted - min(deleted, before)
        let observed = after - before
        if observed == expected { return .consistent }
        return observed > expected
            ? .mirrorAhead(by: observed - expected)
            : .mirrorBehind(by: expected - observed)
    }
}

/// The gate the automatic replacement site asks before counting characters.
public enum MirrorGatedReplacement {

    /// The reason slug a refusal carries into the DEBUG log and, more importantly,
    /// into `handleSpace`'s existing `.failed` fall-through.
    public static let armedReason = "mirror-desync"

    /// Validates a pending replacement, refusing outright while the mirror is armed.
    ///
    /// Expressed as an `AutocorrectReplacement.CheckResult` on purpose: the caller
    /// already has a `.failed` path that inserts a plain space, keeps the user's word
    /// and blocks dictionary learning. Reusing it means the armed case cannot drift
    /// away from the desync case it belongs to — there is one skip path, not two.
    ///
    /// The armed case never produces a delete count, which is what "makes no
    /// deleteBackward() call" means at this seam: the caller can only delete from a
    /// count this returns.
    public static func check(
        mirrorArmed: Bool,
        context: String?,
        word: String
    ) -> AutocorrectReplacement.CheckResult {
        guard !mirrorArmed else { return .failed(reason: armedReason) }
        return AutocorrectReplacement.check(context: context, word: word)
    }
}

/// Holds whether the mirror is currently untrustworthy, and the counters that say
/// what that cost the user.
///
/// Owned per keyboard instance rather than shared: only the visible keyboard edits a
/// document, and per-instance state cannot be polluted by the other ~9 instances that
/// live in the same process.
public final class MirrorSyncState {

    /// True once the mirror has been caught holding characters the keyboard's own
    /// edits do not account for. Automatic character-counting sites must refuse to
    /// act while this is set.
    public private(set) var isArmed = false

    /// When the current armed period began, for the DEBUG cost report.
    private var armedAt: Date?
    /// Spacebar presses that happened while armed — the exposure, in the unit the
    /// user feels it: one skipped correction each.
    private(set) var spacesWhileArmed = 0
    /// Corrections and auto-periods refused while armed.
    private(set) var suppressedCorrections = 0
    private(set) var suppressedFullStops = 0

    public init() {}

    /// Reports one keyboard edit. Arms the suppression if the mirror kept characters
    /// the edit does not explain. Never disarms: no release condition was observed in
    /// the 2026-09-10 capture (zero reconvergences), and the two that were proposed
    /// are falsified — see `release(reason:)`.
    @discardableResult
    public func observe(before: Int, after: Int, deleted: Int, inserted: Int) -> MirrorSync.Verdict {
        let verdict = MirrorSync.verdict(
            before: before, after: after, deleted: deleted, inserted: inserted
        )
        if case .mirrorAhead(let by) = verdict, !isArmed {
            isArmed = true
            armedAt = Date()
            #if DEBUG
            AutocorrectDebugLog.mirrorArmed(surplus: by, before: before, after: after)
            #endif
        }
        return verdict
    }

    /// Counts a spacebar press that happened under suppression.
    public func noteSpaceWhileArmed() {
        guard isArmed else { return }
        spacesWhileArmed += 1
    }

    /// Counts one refused autocorrect replacement.
    public func noteSuppressedCorrection() {
        suppressedCorrections += 1
    }

    /// Counts one refused auto-period.
    public func noteSuppressedFullStop() {
        suppressedFullStops += 1
    }

    /// Clears the suppression. The ONLY release that ships, and it is the keyboard's
    /// own teardown — a new input context, where iOS builds the mirror afresh.
    ///
    /// Two cheaper releases were proposed and both are falsified by the capture, so
    /// neither is implemented and neither should be re-proposed without new evidence:
    ///
    /// - "release on the next word boundary": the damage landed at 20:03:55, four
    ///   seconds and several keystrokes past the divergence at 20:03:51, well beyond
    ///   the next boundary.
    /// - "release once the mirror tracks our edits again": from seq=43 every probe
    ///   read off=0 while the mirror was still lying in absolute terms — it reported
    ///   "vaiss" for a document holding "vais". Tracking again is not being truthful,
    ///   and releasing there would have re-enabled autocorrect immediately before the
    ///   destructive apply.
    ///
    /// The cost of this default is bounded and sayable: after a selection delete,
    /// autocorrect and the auto-period stay off until the user leaves the field and
    /// comes back. The suggestion bar still corrects on tap, so a correction remains
    /// one tap away.
    public func release(reason: String) {
        #if DEBUG
        if isArmed {
            AutocorrectDebugLog.mirrorReleased(
                reason: reason,
                durationMs: armedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0,
                spaces: spacesWhileArmed,
                suppressed: (corrections: suppressedCorrections, fullStops: suppressedFullStops)
            )
        }
        #endif
        isArmed = false
        armedAt = nil
        spacesWhileArmed = 0
        suppressedCorrections = 0
        suppressedFullStops = 0
    }
}

#if DEBUG
/// Measures what the #530 arming check costs per read (criterion 6).
///
/// The check brackets each keyboard edit with a `documentContextBeforeInput` read,
/// and that call is an IPC round trip to the host — the one cost this fix adds to
/// every keystroke. It is not assumed to be free; this reports it from the only
/// place the real number exists, which is a device.
///
/// DEBUG only, and silent until the autocorrect debug log is switched on.
public enum MirrorReadCost {

    private static var samples = 0
    private static var totalNanos: UInt64 = 0
    private static var maxNanos: UInt64 = 0

    /// How many reads to average before writing a line. Large enough that the log
    /// stays readable during a normal typing session, small enough that one
    /// reproduction produces at least one line.
    private static let reportEvery = 100

    public static func sample(nanos: UInt64) {
        samples += 1
        totalNanos += nanos
        maxNanos = max(maxNanos, nanos)
        guard samples >= reportEvery else { return }
        AutocorrectDebugLog.mirrorReadCost(
            samples: samples,
            meanMicros: Double(totalNanos) / Double(samples) / 1000.0,
            maxMicros: Double(maxNanos) / 1000.0
        )
        samples = 0
        totalNanos = 0
        maxNanos = 0
    }
}
#endif
