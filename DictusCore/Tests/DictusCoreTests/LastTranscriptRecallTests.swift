// DictusCore/Tests/DictusCoreTests/LastTranscriptRecallTests.swift
// Unit tests for the #531 last-transcript store and its preview derivation.

import XCTest
@testable import DictusCore

final class LastTranscriptRecallTests: XCTestCase {

    /// A private suite, so these never touch the real App Group.
    private var defaults: UserDefaults!
    private let suiteName = "dictus.tests.lastTranscriptRecall"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Recording

    func testNothingRecordedYieldsNoPreview() {
        XCTAssertNil(LastTranscriptRecall.fullText(from: defaults))
        XCTAssertNil(LastTranscriptRecall.preview(from: defaults))
    }

    func testRecordKeepsTheWholeText() {
        let long = String(repeating: "a", count: 500)
        LastTranscriptRecall.record(long, in: defaults)
        XCTAssertEqual(LastTranscriptRecall.fullText(from: defaults), long)
    }

    func testTheNextDictationReplacesThePrevious() {
        LastTranscriptRecall.record("first", in: defaults)
        LastTranscriptRecall.record("second", in: defaults)
        XCTAssertEqual(LastTranscriptRecall.fullText(from: defaults), "second")
    }

    /// Decision 2: only the next dictation replaces it. A dictation that produced nothing
    /// has not replaced anything, and must not blank the island's bottom region.
    func testBlankInputLeavesThePreviousTranscriptInPlace() {
        LastTranscriptRecall.record("kept", in: defaults)
        LastTranscriptRecall.record(nil, in: defaults)
        LastTranscriptRecall.record("", in: defaults)
        LastTranscriptRecall.record("   \n  ", in: defaults)
        XCTAssertEqual(LastTranscriptRecall.fullText(from: defaults), "kept")
    }

    func testClearRemovesIt() {
        LastTranscriptRecall.record("gone", in: defaults)
        LastTranscriptRecall.clear(in: defaults)
        XCTAssertNil(LastTranscriptRecall.fullText(from: defaults))
    }

    // MARK: - Preview derivation

    func testShortTextIsItsOwnPreview() {
        XCTAssertEqual(LastTranscriptRecall.preview(of: "Alors ouais."), "Alors ouais.")
    }

    func testLongTextIsCutAtTheLimitAndMarked() {
        let long = String(repeating: "x", count: 250)
        let preview = LastTranscriptRecall.preview(of: long)
        XCTAssertEqual(preview.count, LastTranscriptRecall.previewLimit + 1)
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertEqual(preview.dropLast(), String(long.prefix(LastTranscriptRecall.previewLimit))[...])
    }

    func testTextExactlyAtTheLimitIsNotMarked() {
        let exact = String(repeating: "x", count: LastTranscriptRecall.previewLimit)
        XCTAssertEqual(LastTranscriptRecall.preview(of: exact), exact)
    }

    func testParagraphBreaksCollapseIntoSpaces() {
        XCTAssertEqual(
            LastTranscriptRecall.preview(of: "Première ligne.\n\nSeconde ligne."),
            "Première ligne. Seconde ligne."
        )
    }

    func testLeadingAndTrailingWhitespaceIsDropped() {
        XCTAssertEqual(LastTranscriptRecall.preview(of: "\n  Bonjour  \n"), "Bonjour")
    }

    /// The preview a stored transcript produces is the same one the pure function gives,
    /// and it is never the text the copy button hands over.
    func testStoredPreviewIsShorterThanTheStoredText() {
        let long = String(repeating: "mot ", count: 100)
        LastTranscriptRecall.record(long, in: defaults)
        let preview = LastTranscriptRecall.preview(from: defaults)
        XCTAssertEqual(preview, LastTranscriptRecall.preview(of: long))
        XCTAssertEqual(LastTranscriptRecall.fullText(from: defaults), long)
        XCTAssertNotEqual(preview, LastTranscriptRecall.fullText(from: defaults))
    }
}
