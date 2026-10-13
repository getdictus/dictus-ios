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
            .welcome, .language, .keyboardSetup, .appleIntelligence, .smartModesScene, .smartModePick,
            .modelPreparation,
            .microphone, .firstDictation, .stopStandby, .completion
        ])
        XCTAssertEqual(OnboardingStep.microphone.next, .firstDictation)
        XCTAssertFalse(OnboardingStep.allCases.map(\.rawValue).contains { $0.lowercased().contains("polish") })
    }

    func testNextWalksTheFlowAndEndsAfterTheCompletion() {
        XCTAssertEqual(OnboardingStep.welcome.next, .language)
        XCTAssertEqual(OnboardingStep.language.next, .keyboardSetup)
        XCTAssertEqual(OnboardingStep.keyboardSetup.next, .appleIntelligence)
        XCTAssertEqual(OnboardingStep.appleIntelligence.next, .smartModesScene)
        XCTAssertEqual(OnboardingStep.smartModesScene.next, .smartModePick)
        XCTAssertEqual(OnboardingStep.smartModePick.next, .modelPreparation)
        XCTAssertEqual(OnboardingStep.modelPreparation.next, .microphone)
        XCTAssertEqual(OnboardingStep.firstDictation.next, .stopStandby)
        XCTAssertEqual(OnboardingStep.stopStandby.next, .completion)
        XCTAssertNil(OnboardingStep.completion.next)
    }

    // MARK: - How to stop Dictus (#681)

    /// #649 decision 19: right after the first dictation, which is what puts the standby
    /// island up for real.
    func testTheStopStepFollowsTheFirstDictationOnEveryDevice() {
        for capable in [true, false] {
            XCTAssertEqual(
                OnboardingStep.firstDictation.next(skipping: [], deviceCanRunSmartModes: capable), .stopStandby
            )
            XCTAssertEqual(
                OnboardingStep.stopStandby.next(skipping: [], deviceCanRunSmartModes: capable), .completion
            )
            XCTAssertTrue(OnboardingStep.stopStandby.isShown(deviceCanRunSmartModes: capable))
        }
    }

    private func device(_ identifier: String) -> DeviceCapabilities {
        DeviceCapabilities(physicalMemoryGB: 8, availableMemoryMB: 0, deviceModelIdentifier: identifier,
                           thermalState: .nominal)
    }

    /// Every iPhone sees it, with an island (`iPhone16,2`, 15 Pro Max) or without one
    /// (`iPhone14,7`, 14), and an iPhone this build does not know yet.
    func testEveryIPhoneIsShownTheStopStep() {
        for identifier in ["iPhone16,2", "iPhone14,7", "iPhone17,5", "iPhone99,1"] {
            let passedOver = OnboardingStep.passedOver(on: device(identifier))
            XCTAssertTrue(passedOver.isEmpty, identifier)
            for capable in [true, false] {
                XCTAssertEqual(
                    OnboardingStep.firstDictation.next(skipping: passedOver, deviceCanRunSmartModes: capable),
                    .stopStandby, identifier
                )
            }
        }
    }

    /// iPadOS shows no Live Activity: neither picture is true there, so the first dictation
    /// goes straight to the completion screen, its Skip included (both call `next`).
    func testAnIPadPassesOverTheStopStep() {
        for identifier in ["iPad8,1", "iPad13,4", "iPad16,3"] {
            let passedOver = OnboardingStep.passedOver(on: device(identifier))
            XCTAssertEqual(passedOver, [.stopStandby], identifier)
            for capable in [true, false] {
                XCTAssertEqual(
                    OnboardingStep.firstDictation.next(skipping: passedOver, deviceCanRunSmartModes: capable),
                    .completion, identifier
                )
            }
        }
    }

    /// The iPad rule adds to what the app reports, it does not replace it.
    func testTheIPadRuleCombinesWithTheOtherSkips() {
        let satisfied = OnboardingStep.passedOver(on: device("iPad13,4")).union([.microphone])
        XCTAssertEqual(OnboardingStep.modelPreparation.next(skipping: satisfied, deviceCanRunSmartModes: true),
                       .firstDictation)
        XCTAssertEqual(OnboardingStep.firstDictation.next(skipping: satisfied, deviceCanRunSmartModes: true),
                       .completion)
    }

    func testTheStopStepIsNeitherProNorAScene() {
        XCTAssertFalse(OnboardingStep.stopStandby.isProStep)
        XCTAssertFalse(OnboardingStep.stopStandby.isInSceneSequence)
        XCTAssertFalse(OnboardingStep.stopStandby.isSkippable, "its own button moves on (mock-up 11)")
    }

    /// A new name: no build before #681 wrote it, and it survives the Full Access kill
    /// like every other step.
    func testTheStopStepPersistsUnderItsOwnName() {
        OnboardingStep.save(.stopStandby)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.onboardingStep), "stopStandby")
        XCTAssertEqual(OnboardingStep.current(), .stopStandby)
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

    func testOnlyAppleIntelligenceTheWaitTheMicrophoneAndTheStopStepCanBeSkipped() {
        XCTAssertEqual(
            OnboardingStep.allCases.filter(\.isSkippedWhenSatisfied),
            [.appleIntelligence, .modelPreparation, .microphone, .stopStandby]
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
            OnboardingStep.appleIntelligence.next(skipping: [.smartModesScene], deviceCanRunSmartModes: true),
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
            OnboardingStep.keyboardSetup.next(skipping: [.appleIntelligence], deviceCanRunSmartModes: true),
            .smartModesScene
        )
    }

    func testThePickComesRightAfterTheSmartModesScene() {
        // #679, #649 decision 16 as moved on 2026-10-07.
        XCTAssertEqual(
            OnboardingStep.smartModesScene.next(skipping: [], deviceCanRunSmartModes: true), .smartModePick
        )
        XCTAssertEqual(OnboardingStep.smartModePick.position, OnboardingStep.smartModesScene.position + 1)
    }

    /// #683, #649 decision 1.4: Apple Intelligence comes right after the keyboard, and
    /// only when it has something to ask; the Smart Modes scene follows it (#679).
    func testAppleIntelligenceComesRightAfterTheKeyboardWhenNeeded() {
        XCTAssertEqual(
            OnboardingStep.keyboardSetup.next(skipping: [], deviceCanRunSmartModes: true), .appleIntelligence
        )
        XCTAssertEqual(
            OnboardingStep.appleIntelligence.next(skipping: [], deviceCanRunSmartModes: true), .smartModesScene
        )
    }

    func testTheAppleIntelligenceStepIsHiddenWhereSmartModesCanNeverRun() {
        XCTAssertFalse(OnboardingStep.appleIntelligence.isShown(deviceCanRunSmartModes: false))
        XCTAssertNil(OnboardingStep.appleIntelligence.progressIndex(deviceCanRunSmartModes: false))
    }

    func testAKillOnTheAppleIntelligenceStepResumesThere() {
        OnboardingStep.save(.appleIntelligence)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.onboardingStep), "appleIntelligence")
        XCTAssertEqual(OnboardingStep.current(), .appleIntelligence)
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
        XCTAssertEqual(
            OnboardingStep.allCases.filter(\.isProStep), [.appleIntelligence, .smartModesScene, .smartModePick]
        )
        for step in OnboardingStep.allCases where !step.isProStep {
            XCTAssertTrue(step.isShown(deviceCanRunSmartModes: false), "\(step)")
        }
    }

    // MARK: - Shell

    func testProgressBarCoversEveryStepBetweenTheIntroAndTheCompletion() {
        XCTAssertEqual(OnboardingStep.progressSteps(deviceCanRunSmartModes: true), [
            .language, .keyboardSetup, .appleIntelligence, .smartModesScene, .smartModePick, .modelPreparation,
            .microphone,
            .firstDictation, .stopStandby
        ])
        XCTAssertNil(OnboardingStep.welcome.progressIndex(deviceCanRunSmartModes: true))
        XCTAssertNil(OnboardingStep.completion.progressIndex(deviceCanRunSmartModes: true))
        XCTAssertEqual(OnboardingStep.language.progressIndex(deviceCanRunSmartModes: true), 0)
        XCTAssertEqual(OnboardingStep.appleIntelligence.progressIndex(deviceCanRunSmartModes: true), 2)
        XCTAssertEqual(OnboardingStep.smartModesScene.progressIndex(deviceCanRunSmartModes: true), 3)
        XCTAssertEqual(OnboardingStep.smartModePick.progressIndex(deviceCanRunSmartModes: true), 4)
        XCTAssertEqual(OnboardingStep.microphone.progressIndex(deviceCanRunSmartModes: true), 6)
        XCTAssertEqual(OnboardingStep.firstDictation.progressIndex(deviceCanRunSmartModes: true), 7)
        XCTAssertEqual(OnboardingStep.stopStandby.progressIndex(deviceCanRunSmartModes: true), 8)
    }

    func testAHiddenProStepHasNoSegment() {
        XCTAssertEqual(OnboardingStep.progressSteps(deviceCanRunSmartModes: false), [
            .language, .keyboardSetup, .modelPreparation, .microphone, .firstDictation, .stopStandby
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
            .appleIntelligence
        )
        XCTAssertEqual(
            OnboardingStep.appleIntelligence.stepAfterSceneSequence(skipping: [], deviceCanRunSmartModes: true),
            .smartModesScene
        )
    }

    func testTheAppleIntelligenceStepIsNotPartOfTheSceneSequence() {
        // Skipping the scenes never sends the user back, and the Apple Intelligence step
        // keeps its own *Later* (#683).
        XCTAssertFalse(OnboardingStep.appleIntelligence.isInSceneSequence)
        XCTAssertLessThan(OnboardingStep.appleIntelligence.position, OnboardingStep.smartModesScene.position)
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

    func testTheRemovedFullAccessExplainerStepResumesAtTheKeyboard() {
        // #704: a step on test builds only, now a sheet on the keyboard step.
        defaults.set(OnboardingStep.legacyFullAccessExplainerRawValue, forKey: SharedKeys.onboardingStep)
        XCTAssertEqual(OnboardingStep.current(), .keyboardSetup)
        XCTAssertEqual(
            defaults.string(forKey: SharedKeys.onboardingStep), "keyboardSetup",
            "the old name is rewritten, so the migration does not run again"
        )
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
