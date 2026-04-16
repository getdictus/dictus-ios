// DictusCore/Tests/DictusCoreTests/InsertionClassifierTests.swift
// Unit tests for InsertionClassifier — every outcome branch covered.
import XCTest
@testable import DictusCore

final class InsertionClassifierTests: XCTestCase {

    // MARK: - success (exact delta match)

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

    func test_exactDeltaMatch_emptyField_returnsSuccess() {
        let outcome = InsertionClassifier.classify(
            beforeCount: 0,
            afterCount: 5,
            transcriptionUtf16Count: 5,
            hasTextBefore: false,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .success)
    }

    // MARK: - emptyFieldSuccess (delta unreadable, hasText transition proves insertion)

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

    // MARK: - silentDrop (no change, non-empty field)

    func test_nonEmptyField_noChange_returnsSilentDrop() {
        let outcome = InsertionClassifier.classify(
            beforeCount: 42,
            afterCount: 42,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .silentDrop)
    }

    // MARK: - windowedSuccess (partial delta within bounds)

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

    // MARK: - deltaMismatch (negative or oversized delta)

    func test_negativeDelta_returnsDeltaMismatch() {
        let outcome = InsertionClassifier.classify(
            beforeCount: 100,
            afterCount: 80,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .deltaMismatch)
    }

    func test_oversizedDelta_returnsDeltaMismatch() {
        let outcome = InsertionClassifier.classify(
            beforeCount: 10,
            afterCount: 500,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .deltaMismatch)
    }

    // MARK: - proxyDead (nil context sentinel)

    func test_beforeCountNegativeOne_returnsProxyDead() {
        let outcome = InsertionClassifier.classify(
            beforeCount: -1,
            afterCount: 10,
            transcriptionUtf16Count: 10,
            hasTextBefore: false,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .proxyDead)
    }

    func test_afterCountNegativeOne_returnsProxyDead() {
        let outcome = InsertionClassifier.classify(
            beforeCount: 10,
            afterCount: -1,
            transcriptionUtf16Count: 10,
            hasTextBefore: true,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .proxyDead)
    }

    func test_bothCountsNegativeOne_returnsProxyDead() {
        let outcome = InsertionClassifier.classify(
            beforeCount: -1,
            afterCount: -1,
            transcriptionUtf16Count: 10,
            hasTextBefore: false,
            hasTextAfter: false
        )
        XCTAssertEqual(outcome, .proxyDead)
    }

    // MARK: - unicode / emoji edge case

    func test_utf16CountForMultibyteTranscription_classifiesByUtf16() {
        // "café" is 4 Characters but 4 UTF-16 code units in NFC.
        // Caller is responsible for passing transcription.utf16.count — classifier trusts it.
        let outcome = InsertionClassifier.classify(
            beforeCount: 0,
            afterCount: 4,
            transcriptionUtf16Count: 4,
            hasTextBefore: false,
            hasTextAfter: true
        )
        XCTAssertEqual(outcome, .success)
    }
}
