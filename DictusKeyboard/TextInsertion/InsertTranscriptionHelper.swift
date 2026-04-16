// DictusKeyboard/TextInsertion/InsertTranscriptionHelper.swift
// Phase 34 STAB-01: single point of truth for transcription insertion.
//
// Pattern: validate -> insert -> verify -> retry -> escalate.
// Wraps the SOLE insertText(transcription) call site in the keyboard
// (KeyboardState.handleTranscriptionReady lines 341 + 370). Cold start
// Audio Bridge re-enters this same helper via the Darwin notification
// that triggers handleTranscriptionReady — no second physical call site
// exists in the codebase (confirmed by research in 34-RESEARCH.md).
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
    case noFullAccess       // hasFullAccess == false (terminal — skip retries)
    case contextUnavailable // documentContextBeforeInput is nil AND keyboard not visible
    case silentDrop         // classifier returned .silentDrop
    case deltaMismatch      // classifier returned .deltaMismatch
    case proxyDead          // classifier returned .proxyDead after insert
}

public enum InsertTranscriptionResult {
    case success(attempts: Int, outcome: InsertionOutcome)
    case failed(lastReason: InsertionFailureReason, attempts: Int)
}

public struct InsertTranscriptionHelper {

    /// Call sites: KeyboardState.handleTranscriptionReady primary path and 100ms retry path.
    ///
    /// Runs the first attempt synchronously. If it fails, schedules retries on the main queue
    /// at +50ms, +150ms, +350ms (cumulative) via DispatchQueue.main.asyncAfter. Total worst
    /// case: ~350 ms. Calls onComplete once on first success OR after all retries exhausted.
    ///
    /// - Parameters:
    ///   - transcription: the text to insert (read once by caller from App Group)
    ///   - controller: weak reference from KeyboardState (may become nil mid-retry)
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
        let backoffs: [TimeInterval] = [0.050, 0.100, 0.200]  // locked by CONTEXT.md
        let transcriptionUtf16 = transcription.utf16.count

        func attempt(_ index: Int) {
            let elapsedMs = Int(Date().timeIntervalSince(darwinNotificationTimestamp) * 1000)

            // --- Validate controller ---
            guard let ctrl = controller else {
                PersistentLog.log(.keyboardInsertRetry(
                    path: path.rawValue,
                    sessionID: sessionID,
                    attempt: index,
                    reason: InsertionFailureReason.proxyNil.rawValue
                ))
                scheduleNextOrFail(.proxyNil, attemptIndex: index)
                return
            }

            // --- Validate Full Access (terminal — skip retries) ---
            if !ctrl.hasFullAccess {
                PersistentLog.log(.keyboardInsertFailed(
                    path: path.rawValue,
                    sessionID: sessionID,
                    totalAttempts: index + 1,
                    finalReason: InsertionFailureReason.noFullAccess.rawValue
                ))
                onComplete(.failed(lastReason: .noFullAccess, attempts: index + 1))
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
                PersistentLog.log(.keyboardInsertRetry(
                    path: path.rawValue,
                    sessionID: sessionID,
                    attempt: index,
                    reason: InsertionFailureReason.contextUnavailable.rawValue
                ))
                scheduleNextOrFail(.contextUnavailable, attemptIndex: index)
                return
            }

            // --- Insert ---
            proxy.insertText(transcription)

            // --- Snapshot after ---
            let afterText = proxy.documentContextBeforeInput
            let afterCount = afterText?.utf16.count ?? -1
            let hasTextAfter = proxy.hasText

            // --- Probe (privacy-safe: counts/bools/timing only) ---
            PersistentLog.log(.keyboardInsertProbe(
                path: path.rawValue,
                sessionID: sessionID,
                attempt: index,
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
                onComplete(.success(attempts: index + 1, outcome: outcome))
            case .silentDrop:
                PersistentLog.log(.keyboardInsertRetry(
                    path: path.rawValue, sessionID: sessionID,
                    attempt: index, reason: InsertionFailureReason.silentDrop.rawValue
                ))
                scheduleNextOrFail(.silentDrop, attemptIndex: index)
            case .deltaMismatch:
                PersistentLog.log(.keyboardInsertRetry(
                    path: path.rawValue, sessionID: sessionID,
                    attempt: index, reason: InsertionFailureReason.deltaMismatch.rawValue
                ))
                scheduleNextOrFail(.deltaMismatch, attemptIndex: index)
            case .proxyDead:
                PersistentLog.log(.keyboardInsertRetry(
                    path: path.rawValue, sessionID: sessionID,
                    attempt: index, reason: InsertionFailureReason.proxyDead.rawValue
                ))
                scheduleNextOrFail(.proxyDead, attemptIndex: index)
            }
        }

        func scheduleNextOrFail(_ reason: InsertionFailureReason, attemptIndex: Int) {
            let nextIndex = attemptIndex + 1
            if nextIndex <= backoffs.count {
                let delay = backoffs[nextIndex - 1]
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    attempt(nextIndex)
                }
            } else {
                PersistentLog.log(.keyboardInsertFailed(
                    path: path.rawValue,
                    sessionID: sessionID,
                    totalAttempts: nextIndex,
                    finalReason: reason.rawValue
                ))
                onComplete(.failed(lastReason: reason, attempts: nextIndex))
            }
        }

        attempt(0)
    }
}
