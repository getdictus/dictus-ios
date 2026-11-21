// DictusCore/Tests/DictusCoreTests/InKeyboardDictationPoliciesTests.swift
// Tests for the rules around in-keyboard dictation (#992): permission refused, Full
// Access off, interruptions, the one-time explanation, the default setting.
import XCTest
@testable import DictusCore

final class InKeyboardDictationPoliciesTests: XCTestCase {

    private let suiteName = "dictus.tests.inKeyboardPolicies"
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

    private func route(fullAccess: Bool = true,
                       microphone: InKeyboardDictationRoute.MicrophonePermission = .granted,
                       appAnswered: Bool = false) -> InKeyboardDictationRoute {
        InKeyboardDictationRoute.decide(settingEnabled: true, appAnswered: appAnswered, systemMajorVersion: 26,
                                        localeInstalled: true, hasFullAccess: fullAccess, microphone: microphone)
    }

    // MARK: - Permission refused, Full Access off

    func testMicrophoneRefusedSaysSoAndOpensNothing() {
        XCTAssertEqual(route(microphone: .denied), .microphoneDenied)
    }

    func testMicrophoneNeverAskedGoesToTheAppWhichCanAsk() {
        XCTAssertEqual(route(microphone: .undetermined), .openAppURL)
    }

    func testFullAccessOffKeepsTodaysPath() {
        XCTAssertEqual(route(fullAccess: false), .openAppURL)
        XCTAssertEqual(route(fullAccess: false, microphone: .denied), .openAppURL)
    }

    func testAWarmAppIsNeverRefusedHere() {
        XCTAssertEqual(route(microphone: .denied, appAnswered: true), .appIsRecording)
    }

    func testGrantedWithFullAccessDictatesInTheKeyboard() {
        XCTAssertEqual(route(), .inKeyboard)
    }

    func testVoiceNotesNeverReachTheMicrophoneRule() {
        XCTAssertEqual(VoiceNoteRoute.decide(appTookIt: false, settingEnabled: true, systemMajorVersion: 26,
                                             localeInstalled: true), .shareExtension)
    }

    // MARK: - Interruptions

    func testCallOrSiriKeepsTheTextSoFar() {
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .interruptionBegan, recordedSeconds: 4), .finishKeepingText)
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .captureEnded, recordedSeconds: 2), .finishKeepingText)
    }

    func testAnInterruptionRightAfterTheTapEndsQuietly() {
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .interruptionBegan, recordedSeconds: 0.2), .discard)
    }

    func testAirPodsTakenOutDoNotStopTheDictation() {
        XCTAssertEqual(InKeyboardInterruptionPolicy.action(for: .inputDeviceLost, recordedSeconds: 5), .continue)
    }

    // MARK: - First use

    func testFirstUseExplanationIsShownOnce() {
        XCTAssertTrue(InKeyboardFirstUse.shouldShow(in: defaults))
        InKeyboardFirstUse.markShown(in: defaults)
        XCTAssertFalse(InKeyboardFirstUse.shouldShow(in: defaults))
    }

    // MARK: - Default setting

    func testOnForEveryoneTouchesNothing() {
        let resolution = InKeyboardDictationDefault.resolveAtLaunch(policy: .onForEveryone, storedValue: nil,
                                                                    onboardingCompleted: true, promptPending: false)
        XCTAssertEqual(resolution, .init(write: nil, prompt: false))
    }

    func testNewInstallsOnlyTurnsItOnForANewInstall() {
        let resolution = InKeyboardDictationDefault.resolveAtLaunch(policy: .newInstallsOnly, storedValue: nil,
                                                                    onboardingCompleted: false, promptPending: false)
        XCTAssertEqual(resolution, .init(write: true, prompt: false))
    }

    func testNewInstallsOnlyAsksAnExistingUserOnce() {
        let first = InKeyboardDictationDefault.resolveAtLaunch(policy: .newInstallsOnly, storedValue: nil,
                                                               onboardingCompleted: true, promptPending: false)
        XCTAssertEqual(first, .init(write: false, prompt: true))
        // Next launch, prompt still unanswered: ask again, write nothing.
        let unanswered = InKeyboardDictationDefault.resolveAtLaunch(policy: .newInstallsOnly, storedValue: false,
                                                                    onboardingCompleted: true, promptPending: true)
        XCTAssertEqual(unanswered, .init(write: nil, prompt: true))
        // Answered: never again.
        let answered = InKeyboardDictationDefault.resolveAtLaunch(policy: .newInstallsOnly, storedValue: true,
                                                                  onboardingCompleted: true, promptPending: false)
        XCTAssertEqual(answered, .init(write: nil, prompt: false))
    }

    func testAChoiceTheUserMadeIsNeverOverwritten() {
        for policy in [InKeyboardDictationDefault.Policy.onForEveryone, .newInstallsOnly] {
            for stored in [true, false] {
                let resolution = InKeyboardDictationDefault.resolveAtLaunch(policy: policy, storedValue: stored,
                                                                            onboardingCompleted: true, promptPending: false)
                XCTAssertNil(resolution.write)
            }
        }
    }
}
