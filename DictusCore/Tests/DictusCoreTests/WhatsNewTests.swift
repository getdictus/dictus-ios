// DictusCore/Tests/DictusCoreTests/WhatsNewTests.swift
// Who sees What's new: once per version, never on a new install, never 2.0.0's replay (#685, #974).
import XCTest
@testable import DictusCore

final class WhatsNewTests: XCTestCase {

    /// A suite of its own, so the tests never read or write the App Group. Replaced in
    /// `setUpWithError` before any test reads it.
    private var defaults = UserDefaults.standard
    private let suiteName = "WhatsNewTests"

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private var lastVersionSeen: String? { defaults.string(forKey: SharedKeys.lastVersionSeen) }

    /// One launch of `version`: the launch's record, then whether What's new comes up.
    private func launch(_ version: String, hasNotes: Bool = true) -> Bool {
        WhatsNew.recordLaunch(hasNotes: hasNotes, currentVersion: version, defaults: defaults)
        return hasNotes && WhatsNew.isDue(currentVersion: version, defaults: defaults)
    }

    // MARK: - Once per version

    func testAnUpdateShowsTheNotesOnceThenNeverAgain() {
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        defaults.set("2.0.1", forKey: SharedKeys.lastVersionSeen)

        XCTAssertTrue(launch("2.0.2"))
        // A launch that could not show them (a dictation from the keyboard) leaves them due.
        XCTAssertTrue(launch("2.0.2"))
        XCTAssertEqual(lastVersionSeen, "2.0.1")

        // They appear.
        WhatsNew.recordSeen(currentVersion: "2.0.2", defaults: defaults)
        XCTAssertEqual(lastVersionSeen, "2.0.2")
        XCTAssertFalse(launch("2.0.2"))
        XCTAssertFalse(launch("2.0.2"))

        // The next version with notes is shown once in its turn.
        XCTAssertTrue(launch("2.1.0"))
    }

    // MARK: - Never on a new install

    func testANewInstallNeverSeesTheNotesOfTheVersionItInstalled() {
        // First launch, before onboarding: recorded at once.
        XCTAssertFalse(launch("2.0.2"))
        XCTAssertEqual(lastVersionSeen, "2.0.2")

        // Onboarding completes, then the next launches.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        XCTAssertFalse(launch("2.0.2"))
        XCTAssertFalse(launch("2.0.2"))

        // Its first update is an update like any other.
        XCTAssertTrue(launch("2.1.0"))
    }

    func testAnInstallStillInItsOnboardingIsNeverDue() {
        XCTAssertFalse(WhatsNew.isDue(lastVersionSeen: nil, onboardingCompleted: false, currentVersion: "2.0.2"))
        XCTAssertFalse(WhatsNew.isDue(lastVersionSeen: "1.9.0", onboardingCompleted: false, currentVersion: "2.0.2"))
    }

    // MARK: - No 2.0.0 replay

    func testAnInstallThatSawTheTwoPointZeroReplayIsNotShownItAgain() {
        // 2.0.0's What's new recorded "2.0.0" once its scenes were on screen.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        defaults.set("2.0.0", forKey: SharedKeys.lastVersionSeen)
        XCTAssertFalse(launch("2.0.0", hasNotes: false))
        XCTAssertEqual(lastVersionSeen, "2.0.0")

        // What it sees next is a later version's notes, not 2.0.0 again.
        XCTAssertTrue(launch("2.0.2"))
    }

    func testAVersionWithoutNotesShowsNothingAndIsRecordedAtLaunch() {
        // An install onboarded before the key existed, running a version without notes:
        // 2.0.0 has none, so its scenes can never come back.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        XCTAssertFalse(launch("2.0.0", hasNotes: false))
        XCTAssertEqual(lastVersionSeen, "2.0.0")
        XCTAssertFalse(WhatsNew.isDue(currentVersion: "2.0.0", defaults: defaults))
    }

    // MARK: - When it may take the screen

    func testWhatsNewOnlyAppearsOnAFreeScreenAndNeverOnAnActivationOpenedByAURL() {
        // An ordinary launch from the icon, nothing else on screen.
        XCTAssertTrue(WhatsNew.mayAppear(displayIsFree: true, activationOpenedByURL: false))
        // The voice note link, the keyboard's Pro entry, a dictation: the URL's screen wins,
        // and What's new waits for the next activation (CodeRabbit on PR #741).
        XCTAssertFalse(WhatsNew.mayAppear(displayIsFree: true, activationOpenedByURL: true))
        // A dictation, a preparation, a paywall, a voice note or a trial screen up.
        XCTAssertFalse(WhatsNew.mayAppear(displayIsFree: false, activationOpenedByURL: false))
    }

    // MARK: - Versions

    func testVersionsCompareByNumberNotByText() {
        XCTAssertTrue(WhatsNew.isOlder("1.9.0", than: "1.10.0"))
        XCTAssertFalse(WhatsNew.isOlder("1.10.0", than: "1.9.0"))
        XCTAssertTrue(WhatsNew.isOlder("2.0.1", than: "2.0.2"))
        XCTAssertFalse(WhatsNew.isOlder("2.0.2", than: "2.0.2"))
        XCTAssertTrue(WhatsNew.isOlder(nil, than: "0.0.1"))
    }

    func testTheRecordedVersionNeverGoesDown() {
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: nil, currentVersion: "2.0.2"), "2.0.2")
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: "2.0.0", currentVersion: "2.0.2"), "2.0.2")
        // A rollback to an older build keeps the later version.
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: "2.1.0", currentVersion: "2.0.2"), "2.1.0")
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: "2.0.10", currentVersion: "2.0.9"), "2.0.10")
    }
}
