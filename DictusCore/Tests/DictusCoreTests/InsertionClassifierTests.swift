// DictusCore/Tests/DictusCoreTests/InsertionClassifierTests.swift
// Unit tests for InsertionClassifier — every outcome branch covered.
//
// Phase 34.1 rewrite: rule ordering is success-first. `hasText` transition is
// authoritative over nil-context heuristics. Ambiguous cases default to
// `.windowedSuccess` rather than `.deltaMismatch` — the classifier never emits
// `.proxyDead` or `.deltaMismatch` anymore.
import XCTest
@testable import DictusCore

final class InsertionClassifierTests: XCTestCase {

    // MARK: - success (exact delta match, both counts readable)

    func test_exactDeltaMatch_returnsSuccess() {
        let outcome = InsertionClassifier.classify(
            beforeCount: 10,
            afterCount: 20,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .success)
    }

    func test_exactDeltaMatch_emptyField_returnsEmptyFieldSuccess() {
        // Rule 1 fires first because hasTextBefore=false && hasTextAfter=true.
        // The hasText transition is authoritative, so even when delta matches
        // exactly we report emptyFieldSuccess rather than .success.
        let outcome = InsertionClassifier.classify(
            beforeCount: 0,
            afterCount: 5,
            transcriptionUtf16Count: 5,
            hasTextBefore: false,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .emptyFieldSuccess)
    }

    // MARK: - emptyFieldSuccess (hasText transition proves insertion)

    func test_emptyField_hasTextFlips_zeroDelta_returnsEmptyFieldSuccess() {
        let outcome = InsertionClassifier.classify(
            beforeCount: 0,
            afterCount: 0,
            transcriptionUtf16Count: 10,
            hasTextBefore: false,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .emptyFieldSuccess)
    }

    // MARK: - silentDrop (narrow true-failure window)

    func test_nonEmptyField_noChange_belowCap_returnsSilentDrop() {
        // beforeCount=42 < 400 truncation cap, delta=0, hasText unchanged.
        // Only case that returns .silentDrop under the new rules.
        let outcome = InsertionClassifier.classify(
            beforeCount: 42,
            afterCount: 42,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .silentDrop)
    }

    // MARK: - windowedSuccess (partial delta or ambiguous context)

    func test_partialDelta_lessThanRequested_returnsWindowedSuccess() {
        let outcome = InsertionClassifier.classify(
            beforeCount: 990,
            afterCount: 1000,
            transcriptionUtf16Count: 50,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .windowedSuccess)
    }

    // MARK: - unicode / emoji edge case

    func test_utf16CountForMultibyteTranscription_classifiesByUtf16() {
        // "café" is 4 Characters but 4 UTF-16 code units in NFC.
        // Caller is responsible for passing transcription.utf16.count — classifier trusts it.
        // hasTextBefore=false && hasTextAfter=true → rule 1 → emptyFieldSuccess.
        let outcome = InsertionClassifier.classify(
            beforeCount: 0,
            afterCount: 4,
            transcriptionUtf16Count: 4,
            hasTextBefore: false,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .emptyFieldSuccess)
    }

    // MARK: - Phase 34.1 regression tests (real-device false-positive categories)

    func test_empty_field_with_nil_before_returns_emptyFieldSuccess() {
        // Regression: real-device probe at 08:15:38 — hasText flipped false→true,
        // afterCount equals transcriptionCount, but beforeCount=-1 because field was empty.
        // Old classifier returned .proxyDead → retry → duplicate insertion.
        let outcome = InsertionClassifier.classify(
            beforeCount: -1,
            afterCount: 407,
            transcriptionUtf16Count: 407,
            hasTextBefore: false,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .emptyFieldSuccess)
    }

    func test_negative_delta_with_hasTextAfter_is_windowedSuccess() {
        // Regression: real-device probe at 08:15:54 — field had 816 chars of visible
        // context, insertion added 315, but iOS truncated documentContextBeforeInput
        // to 500. Delta is -316. Old classifier returned .deltaMismatch → retry → duplicate.
        let outcome = InsertionClassifier.classify(
            beforeCount: 816,
            afterCount: 500,
            transcriptionUtf16Count: 315,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .windowedSuccess)
    }

    func test_nil_before_with_hasTextAfter_is_windowedSuccess() {
        // Similar to empty-field case but proxy gave nil pre-context despite field
        // likely having content (hasTextBefore was also true in some real probes).
        // If hasTextAfter is true and afterCount ≥ 0, treat as windowedSuccess.
        let outcome = InsertionClassifier.classify(
            beforeCount: -1,
            afterCount: 985,
            transcriptionUtf16Count: 985,
            hasTextBefore: false,
            hasTextAfter: true
        )
        // hasTextBefore=false → takes rule 1 path, emptyFieldSuccess
        XCTAssertEqual(outcome, .emptyFieldSuccess)
    }

    func test_narrow_silentDrop_only_fires_below_truncation_cap() {
        // Only this narrow case should return silentDrop: small field, no growth,
        // no hasText transition. This is the only case that will preserve App Group.
        let outcome = InsertionClassifier.classify(
            beforeCount: 50,
            afterCount: 50,
            transcriptionUtf16Count: 20,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .silentDrop)
    }

    func test_delta_zero_above_truncation_cap_is_windowedSuccess() {
        // Regression: real-device probe at 08:16:34 attempt=1 — beforeCount=500,
        // afterCount=500 (stuck at truncation cap). Old classifier returned silentDrop
        // → cascade of retries → eventual failure banner. New: must be windowedSuccess.
        let outcome = InsertionClassifier.classify(
            beforeCount: 500,
            afterCount: 500,
            transcriptionUtf16Count: 647,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .windowedSuccess)
    }

    func test_exact_delta_match_is_success() {
        // Happy path regression — do not break this case.
        let outcome = InsertionClassifier.classify(
            beforeCount: 51,
            afterCount: 96,
            transcriptionUtf16Count: 45,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .success)
    }

    // MARK: - Retargeted tests (formerly asserted .proxyDead / .deltaMismatch)

    func test_negativeDelta_withHasTextAfter_returnsWindowedSuccess() {
        // Previously asserted .deltaMismatch. Under new rule 4, negative delta
        // with hasTextAfter=true is a windowed success (iOS truncated its view).
        let outcome = InsertionClassifier.classify(
            beforeCount: 100,
            afterCount: 80,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .windowedSuccess)
    }

    func test_oversizedDelta_returnsWindowedSuccess() {
        // Previously asserted .deltaMismatch. Under new rules this falls through
        // to rule 7 (default benefit-of-doubt) → .windowedSuccess. Retries on
        // oversized deltas caused duplicate insertions in real-device logs.
        let outcome = InsertionClassifier.classify(
            beforeCount: 10,
            afterCount: 500,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .windowedSuccess)
    }

    func test_beforeCountNegativeOne_hasTextFlips_returnsEmptyFieldSuccess() {
        // Previously asserted .proxyDead. Under new rule 1, hasTextBefore=false
        // && hasTextAfter=true → .emptyFieldSuccess regardless of nil context.
        let outcome = InsertionClassifier.classify(
            beforeCount: -1,
            afterCount: 10,
            transcriptionUtf16Count: 10,
            hasTextBefore: false,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .emptyFieldSuccess)
    }

    func test_afterCountNegativeOne_nonEmptyField_returnsWindowedSuccess() {
        // Previously asserted .proxyDead. Under new rules, afterCount=-1 means
        // rules 2-4 and rule 6 cannot fire (all require afterCount ≥ 0). Rule 5
        // requires afterCount ≥ 0 too. Falls through to rule 7 default.
        let outcome = InsertionClassifier.classify(
            beforeCount: 10,
            afterCount: -1,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .windowedSuccess)
    }

    func test_bothCountsNegativeOne_noHasTextTransition_returnsWindowedSuccess() {
        // Previously asserted .proxyDead. Under new rules, without a hasText
        // transition and with unreadable context, benefit of the doubt says
        // windowedSuccess (rule 7 default). We never retry on opaque proxy state
        // because retries caused duplicate insertions in real-device logs.
        let outcome = InsertionClassifier.classify(
            beforeCount: -1,
            afterCount: -1,
            transcriptionUtf16Count: 10,
            hasTextBefore: false,
            hasTextAfter: false
        )
        XCTAssertEqual(outcome, .windowedSuccess)
    }
}
