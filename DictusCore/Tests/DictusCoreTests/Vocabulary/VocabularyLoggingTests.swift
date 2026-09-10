// DictusCore/Tests/DictusCoreTests/Vocabulary/VocabularyLoggingTests.swift
// The one line the pass writes down, and the count behind it (#80).
import XCTest
@testable import DictusCore

/// #80's device test produced 5532 lines of persistent log and no occurrence of
/// "vocab", so establishing whether the pass had run took three round trips and an
/// inspection of the App Group container. These tests pin what an agent greps for.
final class VocabularyLoggingTests: XCTestCase {

    /// The line an agent greps for. Spelled out because that is the contract: #80's
    /// device test cost three round trips precisely because there was nothing to
    /// grep, and a renamed key would silently break the next diagnosis.
    func testTheLogLineNamesTheCountsAndCarriesNoText() {
        let event = LogEvent.vocabularyApplied(
            enabled: true, entries: 3, replacements: 1, chars: 58
        )
        XCTAssertEqual(event.name, "vocabularyApplied")
        XCTAssertEqual(event.message, "enabled=yes entries=3 replacements=1 chars=58")

        let off = LogEvent.vocabularyApplied(enabled: false, entries: 0, replacements: 0, chars: 12)
        XCTAssertEqual(off.message, "enabled=no entries=0 replacements=0 chars=12",
                       "switched off must read differently from on-but-empty")
    }

    func testTheReplacementCountIsWhatTheLogReports() {
        guard let entry = VocabularyEntry(term: "Kubernetes", variants: ["cubernetes"]) else {
            return XCTFail("entry should be constructible")
        }
        XCTAssertEqual(
            VocabularyReplacer.outcome("cubernetes puis cubernetes", entries: [entry]).replacements, 2
        )
        XCTAssertEqual(VocabularyReplacer.outcome("rien à voir", entries: [entry]).replacements, 0)
        XCTAssertEqual(VocabularyReplacer.outcome("cubernetes", entries: []).replacements, 0)
    }
}
