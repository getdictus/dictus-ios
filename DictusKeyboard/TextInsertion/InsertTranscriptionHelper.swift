// DictusKeyboard/TextInsertion/InsertTranscriptionHelper.swift
// Phase 34.1 simplified: single-shot insert + classify + log + preserve-or-clear.
//
// Rationale (.planning/phases/34.1-simplify-insertion-detection/34.1-CONTEXT.md):
// Plan 34-03's retry loop caused 3x-4x duplicate insertions on iOS context-window
// truncation false-positives. At a measured real-failure base rate of ~1-in-hundreds,
// retries are net negative UX. The classifier now errs toward success (success-first
// priority, benefit-of-doubt default) so this helper can trust the first classification.
//
// Probe emits privacy-safe structured LogEvents on every attempt. No raw
// transcription text or document context strings are logged.

import UIKit
import DictusCore

public enum InsertionPath: String {
    case warmDarwin
    case coldStartBridge
}

public enum InsertionFailureReason: String {
    case proxyNil           // controller is nil (deallocated mid-transcription)
    case noFullAccess       // hasFullAccess == false
    case contextUnavailable // documentContextBeforeInput nil AND keyboard not visible
    case silentDrop         // classifier returned .silentDrop (narrow true failure)
}

public enum InsertTranscriptionResult {
    case success(outcome: InsertionOutcome)
    case failed(lastReason: InsertionFailureReason)
}

public struct InsertTranscriptionHelper {

    /// Single-shot insert + classify + log + preserve-or-clear App Group.
    /// No retries. Calls `onComplete` exactly once on the same run-loop tick
    /// as the underlying insertText call (or immediately on validation
    /// failure before insertText is attempted).
    ///
    /// - Parameters:
    ///   - transcription: the text to insert (read once by caller from App Group)
    ///   - controller: weak reference from KeyboardState (may be nil)
    ///   - isKeyboardVisible: current KeyboardState.isKeyboardVisible
    ///   - sessionID: KeyboardState.activeSessionID for log correlation ("" acceptable)
    ///   - darwinNotificationTimestamp: Date when handleTranscriptionReady was entered
    ///     (used to compute darwinToInsertMs for probe)
    ///   - path: .warmDarwin or .coldStartBridge (caller reads SharedKeys.coldStartActive)
    ///   - onComplete: called on main queue exactly once with terminal result
    public static func insertTranscription(
        _ transcription: String,
        controller: UIInputViewController?,
        isKeyboardVisible: Bool,
        sessionID: String,
        darwinNotificationTimestamp: Date,
        path: InsertionPath,
        onComplete: @escaping (InsertTranscriptionResult) -> Void
    ) {
        let transcriptionUtf16 = transcription.utf16.count
        let elapsedMs = Int(Date().timeIntervalSince(darwinNotificationTimestamp) * 1000)

        // --- Validate controller ---
        guard let ctrl = controller else {
            PersistentLog.log(.keyboardInsertFailed(
                path: path.rawValue,
                sessionID: sessionID,
                totalAttempts: 1,
                finalReason: InsertionFailureReason.proxyNil.rawValue
            ))
            onComplete(.failed(lastReason: .proxyNil))
            return
        }

        // --- Validate Full Access ---
        if !ctrl.hasFullAccess {
            PersistentLog.log(.keyboardInsertFailed(
                path: path.rawValue,
                sessionID: sessionID,
                totalAttempts: 1,
                finalReason: InsertionFailureReason.noFullAccess.rawValue
            ))
            onComplete(.failed(lastReason: .noFullAccess))
            return
        }

        let proxy = ctrl.textDocumentProxy
        // UITextDocumentProxy conforms to UIKeyInput — hasText reflects whether
        // the host field currently contains any text (not just context window).
        let hasTextBefore = proxy.hasText

        // --- Snapshot before ---
        let beforeText = proxy.documentContextBeforeInput
        let beforeCount = beforeText?.utf16.count ?? -1

        // If proxy context is nil and keyboard isn't visible, we have no active session.
        if beforeCount < 0 && !isKeyboardVisible {
            PersistentLog.log(.keyboardInsertFailed(
                path: path.rawValue,
                sessionID: sessionID,
                totalAttempts: 1,
                finalReason: InsertionFailureReason.contextUnavailable.rawValue
            ))
            onComplete(.failed(lastReason: .contextUnavailable))
            return
        }

        // --- Insert ---
        proxy.insertText(transcription)

        // --- Snapshot after ---
        let afterText = proxy.documentContextBeforeInput
        let afterCount = afterText?.utf16.count ?? -1
        let hasTextAfter = proxy.hasText

        // --- Probe (privacy-safe: counts/bools/timing only) ---
        // attempt is hardcoded to 0 (only one attempt per invocation); the field
        // is retained in the LogEvent for telemetry compatibility with existing
        // log parsers and future re-introduction of retries if production data
        // justifies it.
        PersistentLog.log(.keyboardInsertProbe(
            path: path.rawValue,
            sessionID: sessionID,
            attempt: 0,
            transcriptionCount: transcriptionUtf16,
            hasFullAccess: ctrl.hasFullAccess,
            hasTextBefore: hasTextBefore,
            hasTextAfter: hasTextAfter,
            beforeCount: beforeCount,
            afterCount: afterCount,
            keyboardVisible: isKeyboardVisible,
            darwinToInsertMs: elapsedMs
        ))

        // --- Classify ---
        let outcome = InsertionClassifier.classify(
            beforeCount: beforeCount,
            afterCount: afterCount,
            transcriptionUtf16Count: transcriptionUtf16,
            hasTextBefore: hasTextBefore,
            hasTextAfter: hasTextAfter
        )

        switch outcome {
        case .success, .windowedSuccess, .emptyFieldSuccess:
            // App Group clearing is performed by the caller (KeyboardState) —
            // keep this helper pure with respect to shared state beyond logging.
            onComplete(.success(outcome: outcome))

        case .silentDrop:
            // Narrow true-failure case. Log for telemetry. Caller preserves
            // App Group key so HomeView recoverableTranscription can surface
            // the lost text.
            PersistentLog.log(.keyboardInsertFailed(
                path: path.rawValue,
                sessionID: sessionID,
                totalAttempts: 1,
                finalReason: InsertionFailureReason.silentDrop.rawValue
            ))
            onComplete(.failed(lastReason: .silentDrop))

        case .deltaMismatch, .proxyDead:
            // The new classifier (Plan 34.1-01) never returns these. Defensive
            // fallback: treat as success (benefit of doubt) rather than failing.
            onComplete(.success(outcome: outcome))
        }
    }
}
