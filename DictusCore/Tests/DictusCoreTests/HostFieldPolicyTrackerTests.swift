// DictusCore/Tests/DictusCoreTests/HostFieldPolicyTrackerTests.swift
// Tests for #1004: WhatsApp turns its field to autocorrectionType.no after an
// @ mention, and Dictus must keep the policy the field had before the mention.

import XCTest
@testable import DictusCore

final class HostFieldPolicyTrackerTests: XCTestCase {

    private let prose = HostFieldTraits()
    private let noAutocorrect = HostFieldTraits(autocorrectionDisabled: true)
    /// What WhatsApp holds right after a mention is picked (device log, build b85eeb31).
    private let mentionText = "@\u{2068}Kevin LAGE\u{2069} "
    private let document = "doc-1"

    // MARK: - The issue's target

    func testMentionThenAutocorrectionNoKeepsAutocorrectOn() {
        var tracker = HostFieldPolicyTracker()
        XCTAssertTrue(tracker.policy(for: prose, document: document, text: "").autocorrectAllowed)
        _ = tracker.policy(for: prose, document: document, text: mentionText)

        let policy = tracker.policy(for: noAutocorrect, document: document, text: mentionText)

        XCTAssertTrue(policy.autocorrectAllowed)
        XCTAssertTrue(policy.suggestionsAllowed)
    }

    func testHoldSurvivesWhenTheMentionLeavesTheContextWindow() {
        var tracker = HostFieldPolicyTracker()
        _ = tracker.policy(for: prose, document: document, text: "")
        _ = tracker.policy(for: noAutocorrect, document: document, text: mentionText)

        let later = tracker.policy(for: noAutocorrect, document: document, text: "plus loin dans le message ")

        XCTAssertTrue(later.autocorrectAllowed)
    }

    func testSpellCheckingSwitchedOffWithTheMentionIsIgnoredToo() {
        var tracker = HostFieldPolicyTracker()
        _ = tracker.policy(for: prose, document: document, text: "")
        let both = HostFieldTraits(autocorrectionDisabled: true, spellCheckingDisabled: true)

        XCTAssertTrue(tracker.policy(for: both, document: document, text: mentionText).autocorrectAllowed)
    }

    func testMessageSentReleasesTheHold() {
        var tracker = HostFieldPolicyTracker()
        _ = tracker.policy(for: prose, document: document, text: "")
        _ = tracker.policy(for: noAutocorrect, document: document, text: mentionText)
        // WhatsApp empties the field on send and turns autocorrection back on.
        XCTAssertTrue(tracker.policy(for: prose, document: document, text: "").autocorrectAllowed)

        // A later `.no` with no mention in sight is the host's word again.
        XCTAssertFalse(tracker.policy(for: noAutocorrect, document: document, text: "abc").autocorrectAllowed)
    }

    // MARK: - What stays off

    func testFieldThatIsNoFromTheStartStaysOff() {
        var tracker = HostFieldPolicyTracker()
        XCTAssertFalse(tracker.policy(for: noAutocorrect, document: document, text: "").autocorrectAllowed)

        let policy = tracker.policy(for: noAutocorrect, document: document, text: mentionText)

        XCTAssertFalse(policy.autocorrectAllowed)
        XCTAssertFalse(policy.suggestionsAllowed)
    }

    func testMidFieldNoWithoutAMentionIsHonoured() {
        var tracker = HostFieldPolicyTracker()
        _ = tracker.policy(for: prose, document: document, text: "")

        XCTAssertFalse(tracker.policy(for: noAutocorrect, document: document, text: "bonjour ").autocorrectAllowed)
    }

    func testSecureFieldNeverGetsAutocorrect() {
        let secureCases = [
            HostFieldTraits(autocorrectionDisabled: true, isSecureEntry: true),
            HostFieldTraits(content: .password, autocorrectionDisabled: true),
            HostFieldTraits(content: .oneTimeCode, autocorrectionDisabled: true),
            HostFieldTraits(isSecureEntry: true)
        ]
        for secure in secureCases {
            var tracker = HostFieldPolicyTracker()
            _ = tracker.policy(for: prose, document: document, text: "")
            _ = tracker.policy(for: noAutocorrect, document: document, text: mentionText)

            let policy = tracker.policy(for: secure, document: document, text: mentionText)

            XCTAssertFalse(policy.autocorrectAllowed, "\(secure)")
            XCTAssertFalse(policy.suggestionsAllowed, "\(secure)")
        }
    }

    func testSecureFromTheStartStaysOff() {
        var tracker = HostFieldPolicyTracker()
        let secure = HostFieldTraits(isSecureEntry: true)

        XCTAssertFalse(tracker.policy(for: secure, document: document, text: mentionText).autocorrectAllowed)
    }

    func testNewDocumentDropsTheHold() {
        var tracker = HostFieldPolicyTracker()
        _ = tracker.policy(for: prose, document: document, text: "")
        _ = tracker.policy(for: noAutocorrect, document: document, text: mentionText)

        // A search field in another app, reached while the hold was on.
        XCTAssertFalse(tracker.policy(for: noAutocorrect, document: "doc-2", text: "").autocorrectAllowed)
    }

    func testKeyboardReappearingReadsTheFieldAfresh() {
        var tracker = HostFieldPolicyTracker()
        _ = tracker.policy(for: prose, document: nil, text: "")
        _ = tracker.policy(for: noAutocorrect, document: nil, text: mentionText)

        tracker.fieldFocused()

        XCTAssertFalse(tracker.policy(for: noAutocorrect, document: nil, text: "").autocorrectAllowed)
    }

    func testFocusPolicyWithSpellCheckingOffIsWhatTheHoldKeeps() {
        var tracker = HostFieldPolicyTracker()
        let noSpellCheck = HostFieldTraits(spellCheckingDisabled: true)
        _ = tracker.policy(for: noSpellCheck, document: document, text: "")

        let policy = tracker.policy(for: noAutocorrect, document: document, text: mentionText)

        XCTAssertFalse(policy.autocorrectAllowed)
        XCTAssertTrue(policy.suggestionsAllowed)
    }

    // MARK: - Mention detection

    func testMentionDetection() {
        XCTAssertTrue(HostMention.isPresent(in: "salut @\u{2068}Kevin\u{2069} ça va"))
        XCTAssertTrue(HostMention.isPresent(in: "\u{2068}@Kevin\u{2069}"))
        XCTAssertFalse(HostMention.isPresent(in: "écris à kevin@example.com"))
        XCTAssertFalse(HostMention.isPresent(in: "@Kevin"))
        XCTAssertFalse(HostMention.isPresent(in: "\u{2068}Kevin\u{2069}"))
        XCTAssertFalse(HostMention.isPresent(in: "@\u{2068}\u{2069}"))
        XCTAssertFalse(HostMention.isPresent(in: "@\u{2068}Kevin"))
    }
}
