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

/// The gate the automatic counting sites ask before counting characters.
public enum MirrorGatedReplacement {

    /// The slug a refusal carries into `handleSpace`'s existing `.failed`
    /// fall-through: keep the user's word, insert a plain space, learn nothing.
    public static let suspectReason = "mirror-desync"

    /// Validates a pending replacement, refusing outright while the mirror is suspect.
    ///
    /// DECIDED 2026-09-12, after three rounds spent trying to correct the count rather
    /// than abandon it. The magnitude of the mirror's error is NOT COMPUTABLE from
    /// anything a keyboard extension can observe — two documents measured on device
    /// produce an identical observable trace and need different delete counts, so no
    /// rule can serve both. See `MirrorSurplusUnknowabilityTests`; it is a proof, not
    /// a caveat, and it is why there is no arithmetic here any more.
    ///
    /// What IS answerable is "might the mirror be lying right now?", and the detector
    /// answers it reliably: it never fires on healthy typing, device-confirmed twice.
    /// So this refuses on suspicion and counts normally otherwise. The cost is a
    /// correction skipped for about a word; the alternative damaged the text three
    /// times out of three.
    public static func check(
        mirrorSuspect: Bool,
        context: String?,
        word: String
    ) -> AutocorrectReplacement.CheckResult {
        guard !mirrorSuspect else { return .failed(reason: suspectReason) }
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

    /// Characters the mirror is holding that this keyboard's own edits do not account
    /// for.
    ///
    /// DIAGNOSTIC ONLY. It decides WHETHER the mirror is suspect and it is reported in
    /// the log; it is never subtracted from a delete count. Three rounds were spent
    /// trying to use its magnitude and it cannot be used — see
    /// `MirrorGatedReplacement.check` and `MirrorSurplusUnknowabilityTests`.
    private var surplus = 0

    /// A surplus that a boundary put behind the cursor, and the mirror length at that
    /// boundary. Dormant rather than discarded: the cursor can come back.
    private var dormantSurplus = 0
    private var settledAtLength: Int?

    /// True while the mirror has been caught holding characters this keyboard's own
    /// edits do not account for. Every automatic counting site refuses while it is set.
    public var isSuspect: Bool { surplus > 0 }

    /// When the current suspect period began. The DEBUG report of how long suspicion
    /// lasts is what makes refusal acceptable rather than the session-long blackout of
    /// the first attempt — the captures measure it at 0.4 to 2.9 seconds.
    private var suspectSince: Date?
    private(set) var spacesWhileSuspect = 0
    private(set) var suppressedCorrections = 0
    private(set) var suppressedFullStops = 0

    public init() {}

    /// Reports one keyboard edit.
    ///
    /// `.mirrorAhead` adds to the surplus: the mirror kept characters this edit should
    /// have removed. `.mirrorBehind` subtracts: the mirror gave up more than it was
    /// asked for, which pays the surplus back down. The floor at zero keeps the
    /// suspicion from being negative, which would mean nothing.
    @discardableResult
    public func observe(before: Int, after: Int, deleted: Int, inserted: Int) -> MirrorSync.Verdict {
        let verdict = MirrorSync.verdict(
            before: before, after: after, deleted: deleted, inserted: inserted
        )

        // A settle only holds while the cursor stays at or beyond the boundary that
        // produced it. Backspacing past it puts the phantom back inside reach, and
        // capture 3 does exactly that: a space at seq=42 settled the suspicion, then
        // two backspaces at seq=43/44 took the mirror from 50 to 48 and the next
        // correction merged two words anyway.
        if let boundary = settledAtLength, after < boundary {
            surplus = dormantSurplus
            dormantSurplus = 0
            settledAtLength = nil
            if surplus > 0 {
                suspectSince = suspectSince ?? Date()
                #if DEBUG
                AutocorrectDebugLog.mirrorUnsettled(boundary: boundary, length: after, surplus: surplus)
                #endif
            }
        }

        let wasSuspect = isSuspect
        switch verdict {
        case .consistent:
            break
        case .mirrorAhead(let by):
            surplus += by
        case .mirrorBehind(let by):
            surplus = max(0, surplus - by)
        }

        // Host-side edits are deliberately not tracked: the keyboard cannot tell its
        // own textDidChange from the host's — the capture measured ONE selection
        // delete arriving as TWO of them — so counting them would misattribute far
        // more often than it would catch anything. Nothing is invented by missing one:
        // a suspicion not raised costs a correction made exactly as develop makes it.
        if !wasSuspect, isSuspect {
            suspectSince = Date()
            #if DEBUG
            AutocorrectDebugLog.mirrorSuspect(surplus: surplus, before: before, after: after)
            #endif
        }
        return verdict
    }

    /// The keyboard has inserted a word boundary — a space, a newline, ". ", or a
    /// correction's trailing space. Suspicion ends here.
    ///
    /// WHY A BOUNDARY ENDS IT: a counting site only ever asks about the CURRENT word,
    /// and the current word begins after the last boundary. Once the keyboard has
    /// written one, whatever the mirror is over-reporting lies behind it and cannot be
    /// inside anything that will be counted. Not a claim that the mirror resynced — it
    /// almost certainly has not, the diagnostic capture recorded zero reconvergences.
    ///
    /// The surplus goes dormant rather than being discarded, with the mirror length at
    /// this boundary, because the cursor can come back past it.
    public func noteBoundaryInserted(reason: String, atLength: Int) {
        guard isSuspect else { return }
        dormantSurplus = surplus
        settledAtLength = atLength
        #if DEBUG
        AutocorrectDebugLog.mirrorSettled(
            reason: reason,
            durationMs: suspectSince.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
        )
        #endif
        surplus = 0
        suspectSince = nil
    }

    /// Counts a spacebar press that happened while the mirror was suspect.
    public func noteSpaceWhileSuspect() {
        guard isSuspect else { return }
        spacesWhileSuspect += 1
    }

    /// Counts one refused autocorrect replacement.
    public func noteSuppressedCorrection() { suppressedCorrections += 1 }

    /// Counts one refused auto-period.
    public func noteSuppressedFullStop() { suppressedFullStops += 1 }

    /// Clears everything. The keyboard's own teardown, where iOS builds the mirror
    /// afresh.
    ///
    /// This was once the ONLY release, and that is why the first attempt failed on
    /// device: the keyboard lives as long as the user types in one field, so
    /// suspicion lasted a session and autocorrect went dark. The boundary rule above
    /// is what bounds it now; this is just the reset.
    public func release(reason: String) {
        #if DEBUG
        if isSuspect {
            AutocorrectDebugLog.mirrorReleased(
                reason: reason,
                durationMs: suspectSince.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0,
                spaces: spacesWhileSuspect,
                suppressed: (corrections: suppressedCorrections, fullStops: suppressedFullStops)
            )
        }
        #endif
        surplus = 0
        dormantSurplus = 0
        settledAtLength = nil
        suspectSince = nil
        spacesWhileSuspect = 0
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
