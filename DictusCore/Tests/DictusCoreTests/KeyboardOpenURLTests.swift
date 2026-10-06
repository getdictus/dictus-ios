// DictusCore/Tests/DictusCoreTests/KeyboardOpenURLTests.swift
// The keyboard-to-app screen request, both ends of it (issues #241, #404).
import XCTest
@testable import DictusCore

final class KeyboardOpenURLTests: XCTestCase {

    /// The point of the type: the keyboard builds and the app parses, and this target
    /// is the only place both halves exist at once. #404 is the bill for them being two
    /// strings — the keyboard sent `intent=pro` faithfully and the app had no `open`
    /// route at all, so the one row in the fan that leads anywhere led nowhere useful.
    func testEveryIntentSurvivesTheRoundTrip() throws {
        for intent in KeyboardOpenIntent.allCases {
            let url = try XCTUnwrap(KeyboardOpenURL.url(intent: intent), intent.rawValue)
            XCTAssertEqual(KeyboardOpenURL.intent(from: url), intent)
        }
    }

    func testTheProIntentIsTheOneThePaywallRoutesOn() throws {
        let url = try XCTUnwrap(KeyboardOpenURL.url(intent: .pro))
        XCTAssertEqual(url.absoluteString, "dictus://open?source=keyboard&intent=pro")
    }

    /// The scheme is public, so a screen request is only ours when we sent it — the
    /// same rule `KeyboardDictationURL` applies for the same reason.
    func testAUrlWithoutTheKeyboardSourceIsNotOurs() throws {
        let url = try XCTUnwrap(URL(string: "dictus://open?intent=pro"))
        XCTAssertNil(KeyboardOpenURL.intent(from: url))
    }

    /// And a dictation URL is not a screen request. Keeping the two vocabularies apart
    /// is what stops a paywall reaching `ColdStartLaunch`, whose job is deciding the
    /// first frame of a dictation.
    func testDictationURLsAreNotScreenRequests() throws {
        for raw in [
            "dictus://dictate?source=keyboard",
            "dictus://dictate?source=keyboard&intent=prepare",
            "dictus://stop"
        ] {
            let url = try XCTUnwrap(URL(string: raw))
            XCTAssertNil(KeyboardOpenURL.intent(from: url), raw)
        }
    }

    func testScreenRequestsAreNotDictations() throws {
        for intent in KeyboardOpenIntent.allCases {
            let url = try XCTUnwrap(KeyboardOpenURL.url(intent: intent))
            XCTAssertNil(KeyboardDictationURL.intent(from: url), intent.rawValue)
        }
    }

    /// The reader's `Open in Dictus` (#637) targets the voice note link the app already
    /// routes, on the note the user is reading.
    func testTheVoiceNoteIntentTargetsTheVoiceNoteLink() throws {
        let id = try XCTUnwrap(UUID(uuidString: "6F1C8E2A-1B3D-4E5F-8A9B-0C1D2E3F4A5B"))
        let url = try XCTUnwrap(KeyboardOpenURL.url(intent: .voiceNote, voiceNoteID: id))
        XCTAssertEqual(url.scheme, "dictus")
        XCTAssertEqual(url.host, VoiceNoteURL.host)
        // The app's existing router reads the same note out of it.
        XCTAssertEqual(VoiceNoteURL.target(of: url), .some(id))
        XCTAssertEqual(KeyboardOpenURL.intent(from: url), .voiceNote)
    }

    /// The island's and the share extension's links carry no `source=keyboard`, so
    /// they are not keyboard screen requests — their routing is untouched.
    func testTheIslandsVoiceNoteLinkIsNotAKeyboardRequest() throws {
        let island = try XCTUnwrap(VoiceNoteURL.url(for: nil))
        XCTAssertNil(KeyboardOpenURL.intent(from: island))
    }

    /// `voiceNote` lives on its own host; an `open` URL naming it was not built here.
    func testTheVoiceNoteIntentIsNotAcceptedOnTheOpenHost() throws {
        let url = try XCTUnwrap(URL(string: "dictus://open?source=keyboard&intent=voiceNote"))
        XCTAssertNil(KeyboardOpenURL.intent(from: url))
    }

    /// An intent a future build sends and this one has never heard of reads as nil,
    /// which routes nowhere rather than routing wrongly.
    func testAnUnknownIntentIsRefusedRatherThanGuessed() throws {
        let url = try XCTUnwrap(URL(string: "dictus://open?source=keyboard&intent=history"))
        XCTAssertNil(KeyboardOpenURL.intent(from: url))
    }
}
