// DictusCore/Tests/DictusCoreTests/KeyboardOnboardingGateTests.swift
// Tests for KeyboardOnboardingGate — what the keyboard may do before onboarding is
// finished (issue #827), and the typed phase reader it relies on.
import XCTest
@testable import DictusCore

final class KeyboardOnboardingGateTests: XCTestCase {

    /// A suite of its own: these tests write keys the app writes, and the shared App
    /// Group suite is live state on a developer machine.
    private let suiteName = "dictus.tests.keyboardOnboardingGate"
    private var defaults = UserDefaults.standard

    override func setUpWithError() throws {
        try super.setUpWithError()
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let hosts: [String?] = [nil, "com.apple.mobilenotes", KeyboardOnboardingGate.dictusHostId, ""]
    private let phases: [AppScenePhaseMarker] = [.active, .inactive, .background, .unknown]

    // MARK: - decide

    func testOnboardingCompleteAllowsEveryCombination() {
        for host in hosts {
            for phase in phases {
                XCTAssertEqual(
                    KeyboardOnboardingGate.decide(onboardingCompleted: true, hostId: host, appPhase: phase),
                    .onboardingComplete,
                    "An onboarded user sees no change: host=\(host ?? "nil") phase=\(phase)"
                )
            }
        }
    }

    func testDictusHostAllowsBeforeOnboardingWhateverThePhase() {
        for phase in phases {
            XCTAssertEqual(
                KeyboardOnboardingGate.decide(
                    onboardingCompleted: false,
                    hostId: KeyboardOnboardingGate.dictusHostId,
                    appPhase: phase
                ),
                .hostIsDictus
            )
        }
    }

    func testActiveAppAllowsBeforeOnboardingWhenTheHostIsNotDictus() {
        for host in hosts where host != KeyboardOnboardingGate.dictusHostId {
            XCTAssertEqual(
                KeyboardOnboardingGate.decide(onboardingCompleted: false, hostId: host, appPhase: .active),
                .appActive,
                "host=\(host ?? "nil")"
            )
        }
    }

    func testAnyOtherHostAndPhaseOpensOnboarding() {
        for host in hosts where host != KeyboardOnboardingGate.dictusHostId {
            for phase in phases where phase != .active {
                XCTAssertEqual(
                    KeyboardOnboardingGate.decide(onboardingCompleted: false, hostId: host, appPhase: phase),
                    .openOnboarding,
                    "host=\(host ?? "nil") phase=\(phase)"
                )
            }
        }
    }

    func testAKeyboardOrAppBundleIdIsNotTheDictusHost() {
        for host in ["com.pivi.dictus.keyboard", "com.example.com.pivi.dictus", "com.pivi.dictusx"] {
            XCTAssertEqual(
                KeyboardOnboardingGate.decide(onboardingCompleted: false, hostId: host, appPhase: .background),
                .openOnboarding,
                host
            )
        }
    }

    func testOnlyOpenOnboardingRefusesTheAction() {
        XCTAssertTrue(KeyboardOnboardingGate.Decision.onboardingComplete.allowsAction)
        XCTAssertTrue(KeyboardOnboardingGate.Decision.hostIsDictus.allowsAction)
        XCTAssertTrue(KeyboardOnboardingGate.Decision.appActive.allowsAction)
        XCTAssertFalse(KeyboardOnboardingGate.Decision.openOnboarding.allowsAction)
    }

    // MARK: - isOnboardingCompleted

    func testMissingOnboardingKeyReadsNotCompleted() {
        XCTAssertFalse(KeyboardOnboardingGate.isOnboardingCompleted(in: defaults))
    }

    func testStoredOnboardingFlagIsReadBack() {
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        XCTAssertTrue(KeyboardOnboardingGate.isOnboardingCompleted(in: defaults))

        defaults.set(false, forKey: SharedKeys.hasCompletedOnboarding)
        XCTAssertFalse(KeyboardOnboardingGate.isOnboardingCompleted(in: defaults))
    }

    func testOnboardingFlagOfAnotherTypeReadsNotCompleted() {
        defaults.set("yes", forKey: SharedKeys.hasCompletedOnboarding)
        XCTAssertFalse(KeyboardOnboardingGate.isOnboardingCompleted(in: defaults))
    }

    // MARK: - openIntent

    func testProBecomesSettingsOnlyBeforeOnboarding() {
        XCTAssertEqual(KeyboardOnboardingGate.openIntent(.pro, onboardingCompleted: false), .settings)
        XCTAssertEqual(KeyboardOnboardingGate.openIntent(.pro, onboardingCompleted: true), .pro)
    }

    func testOtherIntentsAreNeverRewritten() {
        for intent in KeyboardOpenIntent.allCases where intent != .pro {
            XCTAssertEqual(KeyboardOnboardingGate.openIntent(intent, onboardingCompleted: false), intent)
            XCTAssertEqual(KeyboardOnboardingGate.openIntent(intent, onboardingCompleted: true), intent)
        }
    }

    // MARK: - appMayStartKeyboardDictation

    func testAppRefusesADarwinStartOnlyBeforeOnboardingWhileNotActive() {
        XCTAssertTrue(KeyboardOnboardingGate.appMayStartKeyboardDictation(onboardingCompleted: true, appIsActive: true))
        XCTAssertTrue(KeyboardOnboardingGate.appMayStartKeyboardDictation(onboardingCompleted: true, appIsActive: false))
        XCTAssertTrue(KeyboardOnboardingGate.appMayStartKeyboardDictation(onboardingCompleted: false, appIsActive: true))
        XCTAssertFalse(KeyboardOnboardingGate.appMayStartKeyboardDictation(onboardingCompleted: false, appIsActive: false))
    }

    // MARK: - End to end through the App Group readers

    func testFreshInstallWithNoStoredStateOpensOnboarding() {
        let decision = KeyboardOnboardingGate.decide(
            onboardingCompleted: KeyboardOnboardingGate.isOnboardingCompleted(in: defaults),
            hostId: nil,
            appPhase: AppScenePhaseProbe.currentPhase(from: defaults)
        )
        XCTAssertEqual(decision, .openOnboarding)
    }

    func testOnboardedInstallWithNoPhaseStoredIsAllowed() {
        defaults.set(true, forKey: SharedKeys.hasCompletedOnboarding)
        let decision = KeyboardOnboardingGate.decide(
            onboardingCompleted: KeyboardOnboardingGate.isOnboardingCompleted(in: defaults),
            hostId: nil,
            appPhase: AppScenePhaseProbe.currentPhase(from: defaults)
        )
        XCTAssertEqual(decision, .onboardingComplete)
    }

    // MARK: - AppScenePhaseProbe.currentPhase

    func testCurrentPhaseIsUnknownWhenNothingIsStored() {
        XCTAssertEqual(AppScenePhaseProbe.currentPhase(from: defaults), .unknown)
    }

    func testCurrentPhaseReadsEveryRecordedMarker() {
        for marker in [AppScenePhaseMarker.active, .inactive, .background, .unknown] {
            AppScenePhaseProbe.record(marker, into: defaults)
            XCTAssertEqual(AppScenePhaseProbe.currentPhase(from: defaults), marker)
        }
    }

    func testCurrentPhaseIsUnknownForAnUnrecognisedValue() {
        defaults.set("suspended", forKey: SharedKeys.appScenePhase)
        XCTAssertEqual(AppScenePhaseProbe.currentPhase(from: defaults), .unknown)
    }
}
