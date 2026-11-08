// DictusCore/Tests/DictusCoreTests/WhatsNewTests.swift
// Who sees What's new, once, and which scenes it replays (#685).
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

    // MARK: - The rule

    func testTheEditionIsTwoPointZero() {
        XCTAssertEqual(WhatsNew.edition, "2.0.0")
        XCTAssertEqual(SharedKeys.lastVersionSeen, "dictus.lastVersionSeen")
    }

    func testAnOnboardedInstallWithoutTheKeyIsAnExistingUserAndSeesIt() {
        XCTAssertTrue(WhatsNew.isDue(lastVersionSeen: nil, onboardingCompleted: true))
    }

    func testAnInstallThatHasNotCompletedOnboardingNeverSeesIt() {
        XCTAssertFalse(WhatsNew.isDue(lastVersionSeen: nil, onboardingCompleted: false))
        XCTAssertFalse(WhatsNew.isDue(lastVersionSeen: "1.9.0", onboardingCompleted: false))
    }

    func testAnInstallBehindTheEditionSeesItAndOneAtOrPastItDoesNot() {
        XCTAssertTrue(WhatsNew.isDue(lastVersionSeen: "1.9.0", onboardingCompleted: true))
        XCTAssertFalse(WhatsNew.isDue(lastVersionSeen: "2.0.0", onboardingCompleted: true))
        XCTAssertFalse(WhatsNew.isDue(lastVersionSeen: "2.0.1", onboardingCompleted: true))
        XCTAssertFalse(WhatsNew.isDue(lastVersionSeen: "2.1.0", onboardingCompleted: true))
    }

    func testWhatsNewOnlyAppearsOnAFreeScreenAndNeverOnAnActivationOpenedByAURL() {
        // An ordinary launch from the icon, nothing else on screen.
        XCTAssertTrue(WhatsNew.mayAppear(displayIsFree: true, activationOpenedByURL: false))
        // The voice note link, the keyboard's Pro entry, a dictation: the URL's screen wins,
        // and What's new waits for the next activation (CodeRabbit on PR #741).
        XCTAssertFalse(WhatsNew.mayAppear(displayIsFree: true, activationOpenedByURL: true))
        // A dictation, a preparation, a paywall, a voice note or a trial screen up.
        XCTAssertFalse(WhatsNew.mayAppear(displayIsFree: false, activationOpenedByURL: false))
    }

    func testADeferredWhatsNewStaysDueUntilItIsOnScreen() {
        // A launch through a URL does not show it: nothing is recorded, so it is still due
        // at the next activation.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "2.0.0", defaults: defaults)
        XCTAssertFalse(WhatsNew.mayAppear(displayIsFree: true, activationOpenedByURL: true))
        XCTAssertTrue(WhatsNew.isDue(defaults: defaults))
    }

    func testVersionsCompareByNumberNotByText() {
        XCTAssertTrue(WhatsNew.isOlder("1.9.0", than: "1.10.0"))
        XCTAssertFalse(WhatsNew.isOlder("1.10.0", than: "1.9.0"))
        XCTAssertTrue(WhatsNew.isOlder("1.9.9", than: "2.0.0"))
        XCTAssertFalse(WhatsNew.isOlder("2.0.0", than: "2.0.0"))
        XCTAssertTrue(WhatsNew.isOlder(nil, than: "0.0.1"))
    }

    func testTheRecordedVersionIsTheLatestAndNeverLessThanTheEdition() {
        // A development build still numbered 1.9.0 records the edition, so 2.0.0 does not replay it.
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: nil, currentVersion: "1.9.0"), "2.0.0")
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: nil, currentVersion: "2.0.0"), "2.0.0")
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: "2.0.0", currentVersion: "2.1.0"), "2.1.0")
        // A rollback to an older build never lowers it.
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: "2.1.0", currentVersion: "2.0.0"), "2.1.0")
        XCTAssertEqual(WhatsNew.recordedVersion(lastVersionSeen: "2.0.0", currentVersion: "1.10.0"), "2.0.0")
    }

    // MARK: - The key, launch after launch

    func testANewInstallIsRecordedAtItsFirstLaunchSoItsOnboardingNeverLeadsToWhatsNew() {
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "2.0.0", defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.lastVersionSeen), "2.0.0")

        // Onboarding completes, then the next launch.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "2.0.0", defaults: defaults)
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))
    }

    func testANewInstallOnADevelopmentBuildNeverSeesItEither() {
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "1.9.0", defaults: defaults)
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "2.0.0", defaults: defaults)
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))
    }

    func testAnExistingUserIsShownItOnceThenNeverAgain() {
        // Onboarded on a version from before the key existed.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)

        // The first launch of 2.0.0 leaves the key alone: What's new is due.
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "2.0.0", defaults: defaults)
        XCTAssertNil(defaults.string(forKey: SharedKeys.lastVersionSeen))
        XCTAssertTrue(WhatsNew.isDue(defaults: defaults))

        // A launch that could not show it (a dictation from the keyboard) leaves it due.
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "2.0.0", defaults: defaults)
        XCTAssertTrue(WhatsNew.isDue(defaults: defaults))

        // It appears.
        WhatsNew.recordSeen(currentVersion: "2.0.0", defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.lastVersionSeen), "2.0.0")
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))

        // Later launches, and later versions, keep it seen.
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "2.0.0", defaults: defaults)
        WhatsNew.recordLaunch(deviceCanRunSmartModes: true, currentVersion: "2.0.1", defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.lastVersionSeen), "2.0.1")
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))
    }

    // MARK: - The steps

    func testACapableDeviceReplaysTheFourScenesAndNoSetupOrStopStep() {
        // How to stop Dictus left What's new on 2026-10-14: it is not new (Pierre, PR #741).
        let steps = WhatsNew.steps(deviceCanRunSmartModes: true)
        XCTAssertEqual(steps, [.smartModesScene, .voiceNotesScene, .vocabularyScene, .historyScene])
        XCTAssertFalse(steps.contains(.smartModePick))
        XCTAssertFalse(steps.contains(.stopStandby))
    }

    func testADeviceThatCanNeverRunSmartModesHasNothingToShowAndIsRecordedAtLaunch() {
        XCTAssertTrue(WhatsNew.steps(deviceCanRunSmartModes: false).isEmpty)

        // An existing user on such a device: due, but nothing to show, so the launch
        // records it and What's new never appears, not even as an empty screen.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        WhatsNew.recordLaunch(deviceCanRunSmartModes: false, currentVersion: "2.0.0", defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.lastVersionSeen), "2.0.0")
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))
    }

    func testNextWalksTheScenesAndEndsAfterHistory() {
        let steps = WhatsNew.steps(deviceCanRunSmartModes: true)
        XCTAssertEqual(WhatsNew.next(after: .smartModesScene, in: steps), .voiceNotesScene)
        XCTAssertEqual(WhatsNew.next(after: .vocabularyScene, in: steps), .historyScene)
        XCTAssertNil(WhatsNew.next(after: .historyScene, in: steps))
    }
}
