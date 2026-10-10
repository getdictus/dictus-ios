// DictusCore/Tests/DictusCoreTests/OnboardingStepTests.swift
// The onboarding order and where an install mid-onboarding resumes (#649, #675).
import XCTest
@testable import DictusCore

final class OnboardingStepTests: XCTestCase {

    private var defaults: UserDefaults { AppGroup.defaults }

    override func setUp() {
        super.setUp()
        clear()
    }

    override func tearDown() {
        clear()
        super.tearDown()
    }

    private func clear() {
        defaults.removeObject(forKey: SharedKeys.onboardingStep)
        defaults.removeObject(forKey: SharedKeys.onboardingCurrentPage)
    }

    // MARK: - The order (#675)

    func testOrderPutsTheMicrophoneRightBeforeTheFirstDictation() {
        XCTAssertEqual(OnboardingStep.allCases, [
            .welcome, .language, .keyboardSetup, .smartModesScene, .smartModePick, .modelPreparation,
            .microphone, .firstDictation, .completion
        ])
        XCTAssertEqual(OnboardingStep.microphone.next, .firstDictation)
        XCTAssertFalse(OnboardingStep.allCases.map(\.rawValue).contains { $0.lowercased().contains("polish") })
    }

    func testNextWalksTheFlowAndEndsAfterTheCompletion() {
        XCTAssertEqual(OnboardingStep.welcome.next, .language)
        XCTAssertEqual(OnboardingStep.language.next, .keyboardSetup)
        XCTAssertEqual(OnboardingStep.keyboardSetup.next, .smartModesScene)
        XCTAssertEqual(OnboardingStep.smartModesScene.next, .smartModePick)
        XCTAssertEqual(OnboardingStep.smartModePick.next, .modelPreparation)
        XCTAssertEqual(OnboardingStep.modelPreparation.next, .microphone)
        XCTAssertEqual(OnboardingStep.firstDictation.next, .completion)
        XCTAssertNil(OnboardingStep.completion.next)
    }

    // MARK: - Skips

    func testAReadyModelSkipsThePreparation() {
        XCTAssertEqual(
            OnboardingStep.smartModePick.next(skipping: [.modelPreparation], deviceCanRunSmartModes: true),
            .microphone
        )
    }

    func testAGrantedMicrophoneSkipsItsStep() {
        XCTAssertEqual(
            OnboardingStep.modelPreparation.next(skipping: [.microphone], deviceCanRunSmartModes: true),
            .firstDictation
        )
    }

    func testBothSkipsChain() {
        XCTAssertEqual(
            OnboardingStep.smartModePick.next(skipping: [.modelPreparation, .microphone], deviceCanRunSmartModes: true),
            .firstDictation
        )
    }

    func testOnlyTheWaitAndTheMicrophoneCanBeSkipped() {
        XCTAssertEqual(
            OnboardingStep.allCases.filter(\.isSkippedWhenSatisfied),
            [.modelPreparation, .microphone]
        )
        // A step outside that list is shown even when the caller calls it satisfied.
        XCTAssertEqual(
            OnboardingStep.language.next(skipping: [.keyboardSetup], deviceCanRunSmartModes: true), .keyboardSetup
        )
        XCTAssertEqual(
            OnboardingStep.microphone.next(skipping: [.firstDictation], deviceCanRunSmartModes: true), .firstDictation
        )
        // Calling the scene or the pick "satisfied" does not hide them: only the device
        // decides that.
        XCTAssertEqual(
            OnboardingStep.keyboardSetup.next(skipping: [.smartModesScene], deviceCanRunSmartModes: true),
            .smartModesScene
        )
        XCTAssertEqual(
            OnboardingStep.smartModesScene.next(skipping: [.smartModePick], deviceCanRunSmartModes: true),
            .smartModePick
        )
    }

    // MARK: - Pro steps (#677)

    func testTheSmartModesSceneComesRightAfterTheKeyboardOnACapableDevice() {
        XCTAssertEqual(
            OnboardingStep.keyboardSetup.next(skipping: [], deviceCanRunSmartModes: true), .smartModesScene
        )
    }

    func testThePickComesRightAfterTheSmartModesScene() {
        // #679, #649 decision 16 as moved on 2026-10-07.
        XCTAssertEqual(
            OnboardingStep.smartModesScene.next(skipping: [], deviceCanRunSmartModes: true), .smartModePick
        )
        XCTAssertEqual(OnboardingStep.smartModePick.position, OnboardingStep.smartModesScene.position + 1)
    }

    func testTheSmartModePickIsHiddenWhereSmartModesCanNeverRun() {
        XCTAssertEqual(
            OnboardingStep.keyboardSetup.next(skipping: [], deviceCanRunSmartModes: false), .modelPreparation
        )
        // And the skips that follow it still apply.
        XCTAssertEqual(
            OnboardingStep.keyboardSetup.next(skipping: [.modelPreparation, .microphone], deviceCanRunSmartModes: false),
            .firstDictation
        )
        XCTAssertFalse(OnboardingStep.smartModePick.isShown(deviceCanRunSmartModes: false))
        XCTAssertFalse(OnboardingStep.smartModesScene.isShown(deviceCanRunSmartModes: false))
    }

    func testOnlyProStepsDependOnTheDevice() {
        XCTAssertEqual(OnboardingStep.allCases.filter(\.isProStep), [.smartModesScene, .smartModePick])
        for step in OnboardingStep.allCases where !step.isProStep {
            XCTAssertTrue(step.isShown(deviceCanRunSmartModes: false), "\(step)")
        }
    }

    // MARK: - Shell

    func testProgressBarCoversEveryStepBetweenTheIntroAndTheCompletion() {
        XCTAssertEqual(OnboardingStep.progressSteps(deviceCanRunSmartModes: true), [
            .language, .keyboardSetup, .smartModesScene, .smartModePick, .modelPreparation, .microphone,
            .firstDictation
        ])
        XCTAssertNil(OnboardingStep.welcome.progressIndex(deviceCanRunSmartModes: true))
        XCTAssertNil(OnboardingStep.completion.progressIndex(deviceCanRunSmartModes: true))
        XCTAssertEqual(OnboardingStep.language.progressIndex(deviceCanRunSmartModes: true), 0)
        XCTAssertEqual(OnboardingStep.smartModesScene.progressIndex(deviceCanRunSmartModes: true), 2)
        XCTAssertEqual(OnboardingStep.smartModePick.progressIndex(deviceCanRunSmartModes: true), 3)
        XCTAssertEqual(OnboardingStep.microphone.progressIndex(deviceCanRunSmartModes: true), 5)
        XCTAssertEqual(OnboardingStep.firstDictation.progressIndex(deviceCanRunSmartModes: true), 6)
    }

    func testAHiddenProStepHasNoSegment() {
        XCTAssertEqual(OnboardingStep.progressSteps(deviceCanRunSmartModes: false), [
            .language, .keyboardSetup, .modelPreparation, .microphone, .firstDictation
        ])
        XCTAssertNil(OnboardingStep.smartModePick.progressIndex(deviceCanRunSmartModes: false))
        XCTAssertNil(OnboardingStep.smartModesScene.progressIndex(deviceCanRunSmartModes: false))
        XCTAssertEqual(OnboardingStep.firstDictation.progressIndex(deviceCanRunSmartModes: false), 4)
    }

    func testTheScenePickAndFirstDictationOfferSkip() {
        XCTAssertEqual(
            OnboardingStep.allCases.filter(\.isSkippable), [.smartModesScene, .smartModePick, .firstDictation]
        )
    }

    // MARK: - The scene sequence (#679)

    func testTheSceneSequenceIsTheSceneAndThePick() {
        XCTAssertEqual(OnboardingStep.allCases.filter(\.isInSceneSequence), [.smartModesScene, .smartModePick])
    }

    func testSkippingTheScenesJumpsTheWholeSequence() {
        XCTAssertEqual(
            OnboardingStep.smartModesScene.stepAfterSceneSequence(skipping: [], deviceCanRunSmartModes: true),
            .modelPreparation
        )
        // The usual skips still apply after the jump.
        XCTAssertEqual(
            OnboardingStep.smartModesScene.stepAfterSceneSequence(
                skipping: [.modelPreparation, .microphone], deviceCanRunSmartModes: true
            ),
            .firstDictation
        )
    }

    func testSkippingFromOutsideTheSequenceIsAPlainNext() {
        XCTAssertEqual(
            OnboardingStep.keyboardSetup.stepAfterSceneSequence(skipping: [], deviceCanRunSmartModes: true),
            .smartModesScene
        )
    }

    func testAKillOnTheSmartModesSceneResumesThere() {
        OnboardingStep.save(.smartModesScene)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.onboardingStep), "smartModesScene")
        XCTAssertEqual(OnboardingStep.current(), .smartModesScene)
    }

    func testAKillOnTheSmartModePickResumesThere() {
        OnboardingStep.save(.smartModePick)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.onboardingStep), "smartModePick")
        XCTAssertEqual(OnboardingStep.current(), .smartModePick)
    }

    // MARK: - Persistence

    func testFreshInstallStartsAtWelcome() {
        XCTAssertEqual(OnboardingStep.current(), .welcome)
    }

    func testEveryStepSurvivesAKill() {
        // What `OnboardingView` does on every step change, then what a relaunch reads.
        for step in OnboardingStep.allCases {
            OnboardingStep.save(step)
            XCTAssertEqual(OnboardingStep.current(), step, "\(step)")
        }
    }

    func testFullAccessKillOnTheKeyboardStepResumesThere() {
        OnboardingStep.save(.keyboardSetup)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.onboardingStep), "keyboardSetup")
        XCTAssertEqual(OnboardingStep.current(), .keyboardSetup)
    }

    func testUnknownSavedStepStartsOver() {
        defaults.set("someFutureStep", forKey: SharedKeys.onboardingStep)
        XCTAssertEqual(OnboardingStep.current(), .welcome)
    }

    // MARK: - The #649 order (before #675)

    func testRawValuesWrittenBeforeTheReorderKeepTheirStep() {
        // The five names the #649 build wrote that still exist mean the same step.
        for raw in ["welcome", "language", "keyboardSetup", "modelPreparation", "firstDictation"] {
            defaults.set(raw, forKey: SharedKeys.onboardingStep)
            XCTAssertEqual(OnboardingStep.current().rawValue, raw, raw)
        }
    }

    func testTheOldMicrophoneStepResumesAtTheKeyboard() {
        // Before #675 the microphone came right after the language screen, so a user
        // stored there had not added the keyboard yet.
        defaults.set(OnboardingStep.legacyMicrophoneRawValue, forKey: SharedKeys.onboardingStep)
        XCTAssertEqual(OnboardingStep.current(), .keyboardSetup)
        XCTAssertEqual(
            defaults.string(forKey: SharedKeys.onboardingStep), "keyboardSetup",
            "the old name is rewritten, so the migration does not run again"
        )
    }

    func testTheNewMicrophoneStepIsNotMistakenForTheOldOne() {
        OnboardingStep.save(.microphone)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.onboardingStep), "microphonePrompt")
        XCTAssertEqual(OnboardingStep.current(), .microphone)
    }

    func testResumedFromStoredRawValue() {
        XCTAssertEqual(OnboardingStep.resumed(fromStoredRawValue: "microphone"), .keyboardSetup)
        XCTAssertEqual(OnboardingStep.resumed(fromStoredRawValue: "microphonePrompt"), .microphone)
        XCTAssertEqual(OnboardingStep.resumed(fromStoredRawValue: "completion"), .completion)
        XCTAssertNil(OnboardingStep.resumed(fromStoredRawValue: "polish"))
    }

    // MARK: - The old page index (before #649)

    func testLegacyIndexMapping() {
        XCTAssertEqual(OnboardingStep.migrated(fromLegacyPageIndex: 0), .welcome)
        for index in 1...4 {
            XCTAssertEqual(OnboardingStep.migrated(fromLegacyPageIndex: index), .language, "\(index)")
        }
        XCTAssertEqual(OnboardingStep.migrated(fromLegacyPageIndex: 5), .firstDictation)
        XCTAssertEqual(OnboardingStep.migrated(fromLegacyPageIndex: 9), .welcome)
        XCTAssertEqual(OnboardingStep.migrated(fromLegacyPageIndex: -1), .welcome)
    }

    func testLegacyIndexIsMigratedOnceAndRemoved() {
        defaults.set(2, forKey: SharedKeys.onboardingCurrentPage)
        XCTAssertEqual(OnboardingStep.current(), .language)
        XCTAssertNil(defaults.object(forKey: SharedKeys.onboardingCurrentPage))
        XCTAssertEqual(defaults.string(forKey: SharedKeys.onboardingStep), "language")

        OnboardingStep.save(.microphone)
        XCTAssertEqual(OnboardingStep.current(), .microphone, "the migration does not run a second time")
    }

    func testNewKeyWinsOverALeftoverLegacyIndex() {
        defaults.set(5, forKey: SharedKeys.onboardingCurrentPage)
        OnboardingStep.save(.microphone)
        XCTAssertEqual(OnboardingStep.current(), .microphone)
    }
}
