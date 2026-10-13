// DictusCore/Tests/DictusCoreTests/WhatsNewTests.swift
// Who sees What's new, once, and which scenes it replays (#685).
import XCTest
@testable import DictusCore

final class WhatsNewTests: XCTestCase {

    /// A suite of its own, so the tests never read or write the App Group.
    private var defaults: UserDefaults!
    private let suiteName = "WhatsNewTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func device(_ identifier: String) -> DeviceCapabilities {
        DeviceCapabilities(physicalMemoryGB: 8, availableMemoryMB: 0, deviceModelIdentifier: identifier,
                           thermalState: .nominal)
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
        WhatsNew.recordLaunch(currentVersion: "2.0.0", defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.lastVersionSeen), "2.0.0")

        // Onboarding completes, then the next launch.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        WhatsNew.recordLaunch(currentVersion: "2.0.0", defaults: defaults)
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))
    }

    func testANewInstallOnADevelopmentBuildNeverSeesItEither() {
        WhatsNew.recordLaunch(currentVersion: "1.9.0", defaults: defaults)
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        WhatsNew.recordLaunch(currentVersion: "2.0.0", defaults: defaults)
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))
    }

    func testAnExistingUserIsShownItOnceThenNeverAgain() {
        // Onboarded on a version from before the key existed.
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)

        // The first launch of 2.0.0 leaves the key alone: What's new is due.
        WhatsNew.recordLaunch(currentVersion: "2.0.0", defaults: defaults)
        XCTAssertNil(defaults.string(forKey: SharedKeys.lastVersionSeen))
        XCTAssertTrue(WhatsNew.isDue(defaults: defaults))

        // A launch that could not show it (a dictation from the keyboard) leaves it due.
        WhatsNew.recordLaunch(currentVersion: "2.0.0", defaults: defaults)
        XCTAssertTrue(WhatsNew.isDue(defaults: defaults))

        // It appears.
        WhatsNew.recordSeen(currentVersion: "2.0.0", defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.lastVersionSeen), "2.0.0")
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))

        // Later launches, and later versions, keep it seen.
        WhatsNew.recordLaunch(currentVersion: "2.0.0", defaults: defaults)
        WhatsNew.recordLaunch(currentVersion: "2.0.1", defaults: defaults)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.lastVersionSeen), "2.0.1")
        XCTAssertFalse(WhatsNew.isDue(defaults: defaults))
    }

    // MARK: - The steps

    func testACapableIPhoneReplaysTheFourScenesThenTheStopTutorialAndNoSetupStep() {
        let steps = WhatsNew.steps(deviceCanRunSmartModes: true, device: device("iPhone16,2"))
        XCTAssertEqual(steps, [.smartModesScene, .voiceNotesScene, .vocabularyScene, .historyScene, .stopStandby])
        XCTAssertFalse(steps.contains(.smartModePick))
    }

    func testAnIPhoneWithoutAnIslandStillGetsTheStopTutorial() {
        // The Lock Screen variant: the page picks it, What's new keeps the step.
        let steps = WhatsNew.steps(deviceCanRunSmartModes: true, device: device("iPhone14,7"))
        XCTAssertEqual(steps.last, .stopStandby)
    }

    func testADeviceThatCanNeverRunSmartModesGetsOnlyTheStopTutorial() {
        XCTAssertEqual(WhatsNew.steps(deviceCanRunSmartModes: false, device: device("iPhone13,2")), [.stopStandby])
    }

    func testAnIPadGetsTheScenesWithoutTheStopTutorial() {
        XCTAssertEqual(WhatsNew.steps(deviceCanRunSmartModes: true, device: device("iPad13,4")),
                       [.smartModesScene, .voiceNotesScene, .vocabularyScene, .historyScene])
        XCTAssertTrue(WhatsNew.steps(deviceCanRunSmartModes: false, device: device("iPad13,4")).isEmpty)
    }

    func testNextWalksTheStepsAndEndsAfterTheLast() {
        let steps = WhatsNew.steps(deviceCanRunSmartModes: true, device: device("iPhone16,2"))
        XCTAssertEqual(WhatsNew.next(after: .smartModesScene, in: steps), .voiceNotesScene)
        XCTAssertEqual(WhatsNew.next(after: .historyScene, in: steps), .stopStandby)
        XCTAssertNil(WhatsNew.next(after: .stopStandby, in: steps))
    }

    func testSkipFromAnySceneLandsOnTheStopTutorialOrEnds() {
        let iPhone = WhatsNew.steps(deviceCanRunSmartModes: true, device: device("iPhone16,2"))
        for scene in [OnboardingStep.smartModesScene, .voiceNotesScene, .vocabularyScene, .historyScene] {
            XCTAssertEqual(WhatsNew.stepAfterScenes(from: scene, in: iPhone), .stopStandby, scene.rawValue)
        }
        let iPad = WhatsNew.steps(deviceCanRunSmartModes: true, device: device("iPad13,4"))
        XCTAssertNil(WhatsNew.stepAfterScenes(from: .smartModesScene, in: iPad))
    }
}
