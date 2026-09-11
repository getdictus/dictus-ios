// DictusCore/Tests/DictusCoreTests/KnownAppSchemesTests.swift
// The catalogue that turns a host app's bundle ID into a way back into it (#23).
import XCTest
@testable import DictusCore

final class KnownAppSchemesTests: XCTestCase {

    // MARK: - Shape

    func testCatalogueIsNotEmpty() {
        XCTAssertFalse(KnownAppSchemes.schemesByBundleId.isEmpty)
    }

    /// Every value has to survive `URL(string:)`, because a value that does not is a
    /// silent no-return: `returnURL` hands back nil and the user gets the overlay with
    /// nothing in the log to say the entry was malformed rather than absent.
    func testEverySchemeParsesAsAURL() {
        for (bundleId, scheme) in KnownAppSchemes.schemesByBundleId {
            XCTAssertNotNil(URL(string: scheme), "\(bundleId) has an unparseable scheme: \(scheme)")
        }
    }

    func testEverySchemeIsOpenable() {
        for (bundleId, scheme) in KnownAppSchemes.schemesByBundleId {
            XCTAssertTrue(
                scheme.contains("://"),
                "\(bundleId) maps to \(scheme), which is not a full URL — bare schemes were the "
                    + "shape canOpenURL needed, and canOpenURL is gone"
            )
        }
    }

    /// A bundle ID in both places would be a contradiction: the catalogue says there is a
    /// way back and the no-scheme set says there is not.
    func testNoBundleIdIsBothMappedAndKnownDead() {
        for bundleId in KnownAppSchemes.knownNoSchemeHosts {
            XCTAssertNil(
                KnownAppSchemes.schemesByBundleId[bundleId],
                "\(bundleId) is listed as having no way back and also has a scheme"
            )
        }
    }

    // MARK: - The traps, each one carried over deliberately

    /// `whatsapp://` belongs to the SMB build. Getting this pair the wrong way round
    /// sends a WhatsApp user to WhatsApp Business or nowhere.
    func testWhatsAppConsumerAndBusinessAreNotSwapped() {
        XCTAssertEqual(KnownAppSchemes.schemesByBundleId["net.whatsapp.WhatsApp"], "whatsapp-consumer://")
        XCTAssertEqual(KnownAppSchemes.schemesByBundleId["net.whatsapp.WhatsAppSMB"], "whatsapp://")
    }

    /// `x-apple-reminder://` is unregistered; the working one carries `kit`.
    func testRemindersUsesTheRegisteredScheme() {
        XCTAssertEqual(KnownAppSchemes.schemesByBundleId["com.apple.reminders"], "x-apple-reminderkit://")
    }

    /// Swiftgram must not claim `tg://` — it is shared with official Telegram, and iOS
    /// picks between them.
    func testSwiftgramDoesNotShareTelegramsScheme() {
        XCTAssertEqual(KnownAppSchemes.schemesByBundleId["app.swiftgram.ios"], "sg://")
        XCTAssertNotEqual(KnownAppSchemes.schemesByBundleId["app.swiftgram.ios"], "tg://")
    }

    /// Two bundle identifiers that look like nothing in particular and are in fact Slack
    /// and Simplenote. Both are easy to "tidy away" in a later edit.
    func testTheTwoUnrecognisableBundleIdsAreKept() {
        XCTAssertEqual(KnownAppSchemes.schemesByBundleId["com.tinyspeck.chatlyio"], "slack://open")
        XCTAssertEqual(KnownAppSchemes.schemesByBundleId["com.codality.NotationalFlow"], "simplenote://")
    }

    /// Measured on iOS 26.5: `sms://`, `messages://`, `imessage://` and `im://` all open
    /// the compose sheet. Only `ichat://` resumes the conversation. The upstream
    /// catalogue this was ported from still has `sms://`, so the obvious-looking "fix"
    /// is a regression waiting to happen.
    func testMessagesUsesTheSchemeThatResumesRatherThanComposes() {
        XCTAssertEqual(KnownAppSchemes.schemesByBundleId["com.apple.MobileSMS"], "ichat://")
        for composing in ["sms://", "messages://", "imessage://", "im://"] {
            XCTAssertNotEqual(KnownAppSchemes.schemesByBundleId["com.apple.MobileSMS"], composing)
        }
    }

    /// Safari has schemes that open it and none that resume it — `x-web-search://` opens
    /// an empty search, `x-safari-https://` a blank tab, both discarding the page. The
    /// overlay leaves the page alone, so it is the better floor.
    func testSafariHasNoWayBackRatherThanABadOne() {
        XCTAssertNil(KnownAppSchemes.returnURL(forHostId: "com.apple.mobilesafari"))
        XCTAssertFalse(KnownAppSchemes.isWorthReporting("com.apple.mobilesafari"))
    }

    // MARK: - The three hosts the acceptance criteria name

    func testTheAcceptanceHostsAreAllMapped() {
        for bundleId in ["com.apple.mobilenotes", "com.apple.MobileSMS", "net.whatsapp.WhatsApp"] {
            XCTAssertNotNil(
                KnownAppSchemes.returnURL(forHostId: bundleId),
                "\(bundleId) is named in #23's acceptance criteria and must have a way back"
            )
        }
    }

    // MARK: - Reporting

    /// Spotlight was observed as a real host in a device capture. It is a dead end, not a
    /// gap, and reporting it would cost a triage pass every time.
    func testObservedSystemPseudoHostsAreNotReported() {
        for bundleId in ["com.apple.Spotlight", "com.apple.SafariViewService", "com.apple.mobilesms.compose"] {
            XCTAssertFalse(KnownAppSchemes.isWorthReporting(bundleId), "\(bundleId) should be silent")
        }
    }

    /// Dictus hosting its own keyboard is not a return target.
    func testDictusIsNotItsOwnReturnTarget() {
        XCTAssertNil(KnownAppSchemes.returnURL(forHostId: "com.pivi.dictus"))
        XCTAssertFalse(KnownAppSchemes.isWorthReporting("com.pivi.dictus"))
    }

    /// An unmapped host nobody has classified is exactly what the log line is for.
    func testAnUnknownHostIsWorthReporting() {
        XCTAssertTrue(KnownAppSchemes.isWorthReporting("com.example.nobody.has.seen.this"))
        XCTAssertNil(KnownAppSchemes.returnURL(forHostId: "com.example.nobody.has.seen.this"))
    }
}
