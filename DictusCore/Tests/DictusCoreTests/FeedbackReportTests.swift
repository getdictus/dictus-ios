// DictusCore/Tests/DictusCoreTests/FeedbackReportTests.swift
// The feedback form's draft rules and JSON body, against the website contract (#565).
import XCTest
@testable import DictusCore

final class FeedbackReportTests: XCTestCase {

    private let device = FeedbackDeviceInfo(appVersion: "2.0.1", build: "41", gitRevision: "d76d48ed",
                                            iosVersion: "26.5", deviceModel: "iPhone16,1", locale: "fr_FR")

    private func draft(_ kind: FeedbackKind = .bug, name: String = "Pierre", email: String = "",
                       message: String = "The mic stays grey.") -> FeedbackDraft {
        var draft = FeedbackDraft()
        draft.kind = kind
        draft.name = name
        draft.email = email
        draft.message = message
        draft.attachesLog = true
        return draft
    }

    private func json(_ payload: FeedbackPayload?) throws -> [String: Any] {
        let body = try XCTUnwrap(payload).body()
        return try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    func testTheLogIsOffByDefaultForEveryKindAndTheChoiceSurvivesAKindChange() {
        var draft = FeedbackDraft()
        XCTAssertFalse(draft.attachesLog)
        for kind in FeedbackKind.allCases {
            draft.kind = kind
            XCTAssertFalse(draft.attachesLog, "\(kind)")
        }
        draft.attachesLog = true
        draft.kind = .idea
        XCTAssertTrue(draft.attachesLog)
    }

    func testAFreshDraftSendsNoLog() throws {
        var fresh = FeedbackDraft()
        fresh.name = "Pierre"
        fresh.message = "Hello"
        XCTAssertNil(try json(FeedbackPayload(draft: fresh, device: device, log: "line\n"))["log"])
    }

    func testTheBodyCarriesExactlyTheContractFields() throws {
        let object = try json(FeedbackPayload(draft: draft(email: " pierre@example.com "), device: device, log: "line\n"))
        XCTAssertEqual(Set(object.keys), ["type", "name", "email", "message", "appVersion", "build", "gitRevision",
                                          "iosVersion", "deviceModel", "locale", "log"])
        XCTAssertEqual(object["type"] as? String, "bug")
        XCTAssertEqual(object["email"] as? String, "pierre@example.com")
        XCTAssertEqual(object["deviceModel"] as? String, "iPhone16,1")
        XCTAssertEqual(object["log"] as? String, "line\n")
    }

    func testAbsentEmailAndDetachedLogAreLeftOut() throws {
        var idea = draft(.idea)
        idea.attachesLog = false
        let object = try json(FeedbackPayload(draft: idea, device: device, log: "line\n"))
        XCTAssertNil(object["email"])
        XCTAssertNil(object["log"])
        idea.attachesLog = true
        XCTAssertNil(try json(FeedbackPayload(draft: idea, device: device, log: ""))["log"])
    }

    func testSlashesAreNotEscaped() throws {
        let body = try XCTUnwrap(FeedbackPayload(draft: draft(message: "a/b"), device: device, log: nil)).body()
        XCTAssertTrue(try XCTUnwrap(String(bytes: body, encoding: .utf8)).contains("a/b"))
    }

    func testNameAndMessageAreRequired() {
        XCTAssertEqual(draft(name: "  \n ").problems, [.nameMissing])
        XCTAssertEqual(draft(message: " \n\t ").problems, [.messageMissing])
        XCTAssertNil(FeedbackPayload(draft: draft(name: ""), device: device, log: nil))
    }

    func testCapsCountUnicodeScalarsLikeTheServer() {
        // "é" written as e + combining accent is one grapheme and two scalars.
        let decomposed = "e\u{301}"
        XCTAssertEqual(draft(name: String(repeating: "a", count: 100)).problems, [])
        XCTAssertEqual(draft(name: String(repeating: decomposed, count: 51)).problems, [.nameTooLong])
        XCTAssertEqual(draft(message: String(repeating: "a", count: 4000)).problems, [])
        let long = draft(message: String(repeating: decomposed, count: 2001))
        XCTAssertEqual(long.problems, [.messageTooLong])
        XCTAssertEqual(long.messageOverflow, 2)
    }

    func testEmailFollowsTheServerShape() {
        XCTAssertEqual(draft(email: "a@b.c").problems, [])
        XCTAssertEqual(draft(email: "   ").problems, [])
        XCTAssertEqual(draft(email: "pierre").problems, [.emailInvalid])
        XCTAssertEqual(draft(email: "a b@c.d").problems, [.emailInvalid])
        XCTAssertEqual(draft(email: "a@b").problems, [.emailInvalid])
        let tooLong = String(repeating: "a", count: 250) + "@b.cd"
        XCTAssertEqual(draft(email: tooLong).problems, [.emailTooLong])
    }

    func testControlCharactersTheServerRefusesAreDropped() throws {
        let dirty = draft(name: "Pi\u{7}erre\u{85}", message: "line\u{0}1\n\tline 2\r\n")
        let object = try json(FeedbackPayload(draft: dirty, device: device, log: nil))
        XCTAssertEqual(object["name"] as? String, "Pierre")
        XCTAssertEqual(object["message"] as? String, "line1\n\tline 2")
    }

    func testDeviceValuesAreCutToTheServerCharacterSets() {
        let info = FeedbackDeviceInfo(appVersion: "2.0.1 beta", build: "41/a", gitRevision: "d76d48ed@feature/565-x",
                                      iosVersion: "26.5 (23F79)", deviceModel: "iPhone16,1", locale: "en_FR@rg=frzzzz")
        XCTAssertEqual(info.appVersion, "2.0.1beta")
        XCTAssertEqual(info.build, "41a")
        XCTAssertEqual(info.gitRevision, "d76d48ed")
        XCTAssertEqual(info.iosVersion, "26.5 (23F79)")
        XCTAssertEqual(info.locale, "en_FR@rg=frzzzz")
        let odd = FeedbackDeviceInfo(appVersion: "", build: "", gitRevision: "unknown", iosVersion: "26",
                                     deviceModel: "iPhone", locale: "x")
        XCTAssertEqual(odd.appVersion, "unknown")
        XCTAssertEqual(odd.locale, "und")
        XCTAssertEqual(FeedbackDeviceInfo(appVersion: "1", build: "1", gitRevision: "a", iosVersion: "1",
                                          deviceModel: "a", locale: "zh-Hans_CN").locale, "zh-Hans_CN")
    }

    func testAnOversizedLogKeepsItsNewestWholeLines() throws {
        let line = String(repeating: "x", count: 99) + "\n"
        let log = "HEADER\n" + String(repeating: line, count: 20_000)  // 2,000,007 bytes
        let object = try json(FeedbackPayload(draft: draft(), device: device, log: log))
        let sent = try XCTUnwrap(object["log"] as? String)
        XCTAssertLessThanOrEqual(sent.utf8.count, FeedbackLimits.logBytes)
        XCTAssertGreaterThan(sent.utf8.count, FeedbackLimits.logBytes - 100)
        XCTAssertTrue(sent.hasPrefix(line), "starts on a whole line")
        XCTAssertTrue(log.hasSuffix(sent))
    }

    func testTheCutNeverSplitsAMultibyteCharacter() {
        let text = String(repeating: "é", count: 10)  // 20 bytes, no line break
        let tail = FeedbackPayload.newestLines(of: text, maxBytes: 7)
        XCTAssertEqual(tail, "ééé")
    }

    func testABodyThatEscapingPushesOverTheWireCapDropsOldLogLines() throws {
        // Quotes double when JSON-escaped: 1.5 MB of them is 3 MB on the wire.
        let line = String(repeating: "\"", count: 99) + "\n"
        let log = String(repeating: line, count: 15_000)
        let body = try XCTUnwrap(FeedbackPayload(draft: draft(), device: device, log: log)).body()
        XCTAssertLessThanOrEqual(body.count, FeedbackLimits.bodyBytes)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertTrue(log.hasSuffix(try XCTUnwrap(object["log"] as? String)))
    }

    func testTheShareTextHoldsEverythingButTheLog() throws {
        let payload = try XCTUnwrap(FeedbackPayload(draft: draft(email: "a@b.c"), device: device, log: "secret-log"))
        XCTAssertEqual(payload.shareText, """
            Dictus feedback: bug
            Name: Pierre
            Email: a@b.c
            Dictus 2.0.1 (41) rev d76d48ed | iOS 26.5 | iPhone16,1 | fr_FR

            The mic stays grey.
            """)
    }
}
