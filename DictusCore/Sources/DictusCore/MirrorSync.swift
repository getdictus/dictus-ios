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

    /// What a counting site must actually delete.
    public enum CountAdjustment: Equatable {
        /// The mirror is trustworthy: spend the count as given.
        case exact(deleteCount: Int)
        /// The mirror over-reports by `surplus`, so delete that much less.
        case corrected(deleteCount: Int, surplus: Int)
        /// The count cannot be corrected. Refuse rather than guess.
        case refuse(reason: String)
    }

    /// Corrects a delete count for what the mirror is known to be over-reporting.
    ///
    /// THE SAFETY PROPERTY, and it is the whole argument for doing this rather than
    /// refusing: the returned count is NEVER larger than the one handed in. `surplus`
    /// is non-negative by construction, so this can only ever delete fewer characters
    /// than today's code does. It therefore cannot destroy text that `develop` would
    /// have kept — the worst it can do is stop short and leave a stray character,
    /// which one backspace clears.
    ///
    /// WHY IT CAN CORRECT A COUNT BUT NOT A CHARACTER:
    /// The surplus is a LENGTH, not a position. The phantom is not necessarily at the
    /// tail — a document "to" whose mirror kept "tox" and then took an insert of "y"
    /// reads "toxy" for a document holding "toy", and dropping the last character
    /// gives "tox", which is wrong. The length is still right, which is all a delete
    /// count needs. Decisions that ask what a specific character IS — the auto-period
    /// asking whether the tail is a space — cannot be repaired this way and must
    /// still refuse. See `AutoFullStop`.
    public static func adjust(deleteCount: Int, trust: MirrorTrust) -> CountAdjustment {
        switch trust {
        case .trusted:
            return .exact(deleteCount: deleteCount)
        case .unknown:
            return .refuse(reason: MirrorGatedReplacement.unknownReason)
        case .surplus(let surplus):
            let corrected = deleteCount - surplus
            // The surplus claims the whole word, or more, is phantom. Deleting
            // nothing and inserting the correction would duplicate the word
            // ("ton" -> "tonton"), so this is the accounting saying it has lost track.
            guard corrected > 0 else {
                return .refuse(reason: MirrorGatedReplacement.surplusExceedsWordReason)
            }
            return .corrected(deleteCount: corrected, surplus: surplus)
        }
    }
}

/// How much the mirror can be trusted to count characters against.
public enum MirrorTrust: Equatable {
    /// The mirror has reflected every edit the keyboard made. Counts are exact.
    case trusted
    /// The mirror holds this many characters the document does not. A delete count
    /// taken off it is too large by exactly this much.
    case surplus(Int)
    /// The accounting is no longer usable. The count cannot be corrected, so the
    /// site must refuse instead of guessing.
    case unknown
}

/// The gate the automatic replacement site asks before counting characters.
public enum MirrorGatedReplacement {

    /// Slugs a refusal carries into `handleSpace`'s existing `.failed` fall-through.
    public static let unknownReason = "mirror-desync-unknown"
    public static let surplusExceedsWordReason = "mirror-surplus-exceeds-word"

    /// Validates a pending replacement and corrects its delete count.
    ///
    /// REVISED 2026-09-11. The first version refused outright while the mirror was
    /// suspect, and the device test killed it: armed once, released never, ten
    /// suppressions in 25 seconds, seven of them real misspellings. Autocorrect went
    /// dark for the rest of the session.
    ///
    /// The surplus is already known — it is what arming is computed from — so the
    /// count can be corrected rather than abandoned. Both field captures land exactly:
    /// `tonn`(4) with surplus 1 deletes 3 and gives `Une fois ton `; `vaiss`(5) with
    /// surplus 1 deletes 4 and gives `Ok je vais `.
    ///
    /// The result is still an `AutocorrectReplacement.CheckResult` so the caller keeps
    /// one skip path rather than two.
    public static func check(
        trust: MirrorTrust,
        context: String?,
        word: String
    ) -> AutocorrectReplacement.CheckResult {
        switch AutocorrectReplacement.check(context: context, word: word) {
        case .failed(let reason):
            return .failed(reason: reason)
        case .ok(let deleteCount):
            switch MirrorSync.adjust(deleteCount: deleteCount, trust: trust) {
            case .exact(let count), .corrected(let count, _):
                return .ok(deleteCount: count)
            case .refuse(let reason):
                return .failed(reason: reason)
            }
        }
    }
}

/// Holds whether the mirror is currently untrustworthy, and the counters that say
/// what that cost the user.
///
/// Owned per keyboard instance rather than shared: only the visible keyboard edits a
/// document, and per-instance state cannot be polluted by the other ~9 instances that
/// live in the same process.
public final class MirrorSyncState {

    /// The largest surplus the accounting will carry before declaring itself lost.
    /// One phantom character is what both field captures produced; a run of them
    /// means the bookkeeping has drifted and a corrected count would be a guess.
    private static let surplusCeiling = 8

    /// How much the mirror can currently be trusted to count characters against.
    public private(set) var trust: MirrorTrust = .trusted

    /// Characters the mirror is holding that the keyboard's own edits do not account
    /// for. Accumulates across successive desyncs and never goes below zero.
    private var surplus = 0

    /// True while counts taken off the mirror cannot be spent as given. Kept for the
    /// sites that can only refuse, and for the counters.
    public var isSuspect: Bool { trust != .trusted }

    /// When the current suspect period began, for the DEBUG cost report.
    private var suspectSince: Date?
    private(set) var spacesWhileSuspect = 0
    private(set) var suppressedCorrections = 0
    private(set) var suppressedFullStops = 0
    /// Replacements that went ahead on a corrected count — the ones the revised
    /// reaction saves, and the number that says whether it was worth it.
    private(set) var correctedReplacements = 0

    public init() {}

    /// Reports one keyboard edit and updates the surplus.
    ///
    /// `.mirrorAhead` adds to the surplus: the mirror kept characters this edit
    /// should have removed. `.mirrorBehind` subtracts: the mirror gave up more than
    /// it was asked for, which pays the surplus back down. The floor at zero is
    /// load-bearing — a negative surplus would mean adding deletions, and adding
    /// deletions is exactly the thing that destroys text.
    ///
    /// Once `.unknown`, it stays there until `release`: a lost accounting cannot be
    /// re-derived from later edits.
    @discardableResult
    public func observe(before: Int, after: Int, deleted: Int, inserted: Int) -> MirrorSync.Verdict {
        let verdict = MirrorSync.verdict(
            before: before, after: after, deleted: deleted, inserted: inserted
        )
        guard trust != .unknown else { return verdict }

        let wasSuspect = isSuspect
        switch verdict {
        case .consistent:
            break
        case .mirrorAhead(let by):
            surplus += by
        case .mirrorBehind(let by):
            surplus = max(0, surplus - by)
        }

        guard surplus <= Self.surplusCeiling else {
            // The only way into `.unknown` that ships. A host-side edit could also
            // invalidate the accounting in principle, but the keyboard cannot tell
            // its own textDidChange from the host's — the capture measured ONE
            // selection delete arriving as TWO of them — so counting them would
            // misattribute far more often than it would catch anything. Not tracking
            // them is safe for a different reason: the corrected count is never
            // larger than the uncorrected one, so an unseen host change can only make
            // this delete less than develop already does, never more.
            markUnknown(reason: "surplus-ceiling")
            return verdict
        }
        trust = surplus > 0 ? .surplus(surplus) : .trusted

        if !wasSuspect, isSuspect {
            suspectSince = Date()
            #if DEBUG
            AutocorrectDebugLog.mirrorSuspect(surplus: surplus, before: before, after: after)
            #endif
        }
        return verdict
    }

    /// Declares the accounting lost. The counting sites then refuse, which is the
    /// fallback and not the behaviour: it is what happens when the surplus is not
    /// known, never what happens when it is.
    public func markUnknown(reason: String) {
        guard trust != .unknown else { return }
        let wasSuspect = isSuspect
        trust = .unknown
        if !wasSuspect { suspectSince = Date() }
        #if DEBUG
        AutocorrectDebugLog.mirrorUnknown(reason: reason, surplus: surplus)
        #endif
    }

    /// The keyboard has inserted a word boundary — a space, a newline, ". ", or a
    /// correction's trailing space. Any outstanding surplus is cleared.
    ///
    /// WHY A BOUNDARY SETTLES IT, and this is the fix for the "pproblème" round:
    /// a surplus is POSITIONAL, not just a magnitude. Every delete count a counting
    /// site computes is the length of the CURRENT word, and the current word begins
    /// after the last boundary. Once the keyboard has written one, the phantom lies
    /// behind it, so every character of every later word was typed and observed after
    /// the divergence — the word's length in the mirror equals its length in the
    /// document, and subtracting anything from it deletes one character too few.
    ///
    /// That is exactly what shipped and failed: capture 5 armed on a key-delete and
    /// the very next event was a space, yet the surplus stayed latched and eight
    /// consecutive corrections came out one character short ("pproblème"). The
    /// magnitude was never re-derived because `observe` only ever sees deltas. This
    /// re-derives RELEVANCE instead, which needs no absolute reading of anything.
    ///
    /// `.unknown` clears too: it means the accounting lost track of a magnitude, and
    /// a magnitude behind a boundary is no longer being asked about.
    ///
    /// NOT a claim that the mirror has resynced. It almost certainly has not — the
    /// diagnostic capture recorded zero reconvergences. The phantom stays in the
    /// mirror; it simply stops being inside anything this keyboard counts.
    public func noteBoundaryInserted(reason: String) {
        guard isSuspect else { return }
        #if DEBUG
        AutocorrectDebugLog.mirrorSettled(
            reason: reason,
            durationMs: suspectSince.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0,
            corrected: correctedReplacements
        )
        #endif
        trust = .trusted
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

    /// Counts one replacement that went ahead on a corrected count.
    public func noteCorrectedReplacement() { correctedReplacements += 1 }

    /// Clears the accounting. The keyboard's own teardown, where iOS builds the
    /// mirror afresh.
    ///
    /// This is no longer the thing that makes the fix usable — correcting the count
    /// is — but it stays as the reset, and the two cheaper releases stay closed:
    ///
    /// - "release on the next word boundary": the damage landed at 20:03:55, four
    ///   seconds and several keystrokes past the divergence at 20:03:51.
    /// - "release once the mirror tracks our edits again": from seq=43 every probe
    ///   read off=0 while the mirror still reported "vaiss" for a document holding
    ///   "vais". Tracking again is not being truthful.
    public func release(reason: String) {
        #if DEBUG
        if isSuspect {
            AutocorrectDebugLog.mirrorReleased(
                reason: reason,
                durationMs: suspectSince.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0,
                spaces: spacesWhileSuspect,
                suppressed: (corrections: suppressedCorrections, fullStops: suppressedFullStops),
                corrected: correctedReplacements
            )
        }
        #endif
        trust = .trusted
        surplus = 0
        suspectSince = nil
        spacesWhileSuspect = 0
        suppressedCorrections = 0
        suppressedFullStops = 0
        correctedReplacements = 0
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
