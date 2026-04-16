// DictusCore/Sources/DictusCore/InsertionClassifier.swift
// Pure-logic classifier for post-insertion verification.
// No UIKit dependency — testable on macOS via swift test.
//
// WHY extracted: The delta-interpretation rules are policy that must survive
// Apple's opaque documentContextBeforeInput windowing behavior. Isolating the
// logic in DictusCore lets us unit-test every branch without a real proxy.

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
    case deltaMismatch
    /// One or both counts are -1 (documentContextBeforeInput was nil) — proxy
    /// disconnected or secure field. Retry candidate; will escalate if persists.
    case proxyDead
}

public enum InsertionClassifier {
    /// Classify the result of a single insertText attempt.
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
        // Proxy dead: nil context on either side signals disconnected proxy.
        if beforeCount < 0 || afterCount < 0 {
            return .proxyDead
        }

        let delta = afterCount - beforeCount

        // Exact-match success.
        if delta == transcriptionUtf16Count {
            return .success
        }

        // Empty-field success: before context was empty and hasText flipped
        // false -> true. Delta could be 0 (proxy clipped the reading) or
        // anything else — the hasText transition is authoritative.
        if beforeCount == 0 && hasTextBefore == false && hasTextAfter == true {
            return .emptyFieldSuccess
        }

        // Silent drop: no change at all, non-empty field.
        if delta == 0 && beforeCount > 0 && hasTextBefore == hasTextAfter {
            return .silentDrop
        }

        // Windowed success: partial delta in the "more than zero but less than
        // requested" range. Apple's documentContextBeforeInput window is
        // bounded (~1000 chars in practice); a long pre-cursor field can
        // legitimately show this.
        if delta > 0 && delta < transcriptionUtf16Count {
            return .windowedSuccess
        }

        // Anything else (negative delta, delta much larger than requested,
        // partial with inconsistent hasText) is deltaMismatch.
        return .deltaMismatch
    }
}
