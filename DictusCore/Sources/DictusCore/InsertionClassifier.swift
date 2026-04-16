// DictusCore/Sources/DictusCore/InsertionClassifier.swift
// Pure-logic classifier for post-insertion verification.
// No UIKit dependency — testable on macOS via swift test.
//
// WHY extracted: The delta-interpretation rules are policy that must survive
// Apple's opaque documentContextBeforeInput windowing behavior. Isolating the
// logic in DictusCore lets us unit-test every branch without a real proxy.
//
// Phase 34.1 rewrite (2026-04-16): rule ordering is now success-first.
// Real-device logs showed the previous proxy-dead-first ordering produced
// false-positive failures (empty field with nil before-context, window
// truncation with negative delta) that triggered retries → duplicate text
// insertion. The new ordering trusts the `hasText` transition and defaults
// ambiguous cases to `.windowedSuccess`, eliminating false-positive retries.

import Foundation

/// Outcome of a single insertion attempt, as inferred from UITextDocumentProxy
/// before/after counts and hasText flags.
public enum InsertionOutcome: Equatable, Sendable {
    /// Delta equals transcription.utf16.count — definitive success.
    case success
    /// Delta > 0 but < transcription.utf16.count — documentContextBeforeInput
    /// windowing cap likely clipped the reading. Treat as provisional success,
    /// do not retry.
    case windowedSuccess
    /// before == 0, hasTextBefore == false, hasTextAfter == true — empty-field
    /// case where delta is unreadable but hasText transition proves insertion.
    case emptyFieldSuccess
    /// before == after, both non-empty, hasText unchanged — true silent drop.
    /// Retry candidate.
    case silentDrop
    /// Delta exists but is inconsistent with transcription length (e.g. negative,
    /// or implausibly large). Retry candidate.
    ///
    /// NOTE (Phase 34.1): no longer emitted by `classify`. The enum case is
    /// retained for source-compatibility with existing callers that pattern-
    /// match on it; new code should not rely on this outcome.
    case deltaMismatch
    /// One or both counts are -1 (documentContextBeforeInput was nil) — proxy
    /// disconnected or secure field. Retry candidate; will escalate if persists.
    ///
    /// NOTE (Phase 34.1): no longer emitted by `classify`. The enum case is
    /// retained for source-compatibility with existing callers that pattern-
    /// match on it; new code should not rely on this outcome.
    case proxyDead
}

public enum InsertionClassifier {
    /// Classify the result of a single insertText attempt.
    ///
    /// Rule ordering is success-first: hasText transition is authoritative over
    /// nil-context readings because iOS returns nil `documentContextBeforeInput`
    /// in several legitimate success cases (empty fields, truncated long fields,
    /// secure fields).
    ///
    /// Ambiguous cases default to `.windowedSuccess` (benefit of the doubt) rather
    /// than `.deltaMismatch` because retries cause duplicate insertions — never
    /// penalize the user for iOS oddness when hasText evidence doesn't clearly
    /// indicate failure.
    ///
    /// - Parameters:
    ///   - beforeCount: documentContextBeforeInput.utf16.count immediately before
    ///     insertText, or -1 if documentContextBeforeInput was nil.
    ///   - afterCount: documentContextBeforeInput.utf16.count immediately after
    ///     insertText, or -1 if documentContextBeforeInput was nil.
    ///   - transcriptionUtf16Count: transcription.utf16.count — the amount we
    ///     asked the proxy to insert.
    ///   - hasTextBefore: UIInputViewController.hasText immediately before.
    ///   - hasTextAfter: UIInputViewController.hasText immediately after.
    public static func classify(
        beforeCount: Int,
        afterCount: Int,
        transcriptionUtf16Count: Int,
        hasTextBefore: Bool,
        hasTextAfter: Bool
    ) -> InsertionOutcome {
        // Rule 1: hasText transition is authoritative for empty-field success.
        // The proxy may return nil `documentContextBeforeInput` for an empty field
        // even when insertion succeeds — the hasText flip is the ground truth.
        if hasTextBefore == false && hasTextAfter == true {
            return .emptyFieldSuccess
        }

        // Rules 2-4 require both context counts to be readable.
        if beforeCount >= 0 && afterCount >= 0 {
            let delta = afterCount - beforeCount

            // Rule 2: exact match — definitive success.
            if delta == transcriptionUtf16Count {
                return .success
            }

            // Rule 3: partial positive delta — window clipped the reading but
            // insertion happened. Do not retry.
            if delta > 0 && delta < transcriptionUtf16Count {
                return .windowedSuccess
            }

            // Rule 4: negative delta with hasTextAfter — iOS truncated its
            // documentContextBeforeInput window after insertion (long fields).
            // Insertion succeeded; the window we can see just shrunk.
            if delta < 0 && hasTextAfter == true {
                return .windowedSuccess
            }

            // Rule 6: narrow true silent drop. Field was non-empty and below the
            // known iOS truncation cap (~500-1000 chars), no growth, no hasText
            // transition. This is the only outcome that triggers App Group
            // preservation for HomeView recovery.
            if delta == 0 && beforeCount > 0 && beforeCount < 400 && hasTextBefore == hasTextAfter {
                return .silentDrop
            }
        }

        // Rule 5: post-context readable, hasTextAfter true, but pre-context was nil.
        // Benefit of the doubt — treat as windowed success rather than retry.
        if afterCount >= 0 && hasTextAfter == true && beforeCount < 0 {
            return .windowedSuccess
        }

        // Rule 7: default. Ambiguous or unreadable context without a clear failure
        // signature — benefit of the doubt. Do not retry, do not escalate. The
        // insertion might have succeeded and iOS is just being opaque.
        return .windowedSuccess
    }
}
