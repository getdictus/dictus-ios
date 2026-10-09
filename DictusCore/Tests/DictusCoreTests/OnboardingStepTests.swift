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
            .welcome, .language, .keyboardSetup, .appleIntelligence, .modelPreparation, .microphone,
            .firstDictation, .completion
        ])
        XCTAssertEqual(OnboardingStep.microphone.next, .firstDictation)
        XCTAssertFalse(OnboardingStep.allCases.map(\.rawValue).contains { $0.lowercased().contains("polish") })
    }

    func testNextWalksTheFlowAndEndsAfterTheCompletion() {
        XCTAssertEqual(OnboardingStep.welcome.next, .language)
        XCTAssertEqual(OnboardingStep.language.next, .keyboardSetup)
        XCTAssertEqual(OnboardingStep.keyboardSetup.next, .appleIntelligence)
        XCTAssertEqual(OnboardingStep.appleIntelligence.next, .modelPreparation)
        XCTAssertEqual(OnboardingStep.modelPreparation.next, .microphone)
        XCTAssertEqual(OnboardingStep.firstDictation.next, .completion)
        XCTAssertNil(OnboardingStep.completion.next)
    }

    // MARK: - Skips

    func testAReadyModelSkipsThePreparation() {
        XCTAssertEqual(OnboardingStep.appleIntelligence.next(skipping: [.modelPreparation]), .microphone)
    }

    /// #683, #649 decision 1.4: Apple Intelligence comes right after the keyboard, and
    /// only when it has something to ask.
    func testAppleIntelligenceComesRightAfterTheKeyboardWhenNeeded() {
        XCTAssertEqual(OnboardingStep.keyboardSetup.next(skipping: []), .appleIntelligence)
        XCTAssertEqual(OnboardingStep.keyboardSetup.next(skipping: [.appleIntelligence]), .modelPreparation)
        XCTAssertEqual(
            OnboardingStep.keyboardSetup.next(skipping: [.appleIntelligence, .modelPreparation]),
            .microphone
        )
    }

    func testTheAppleIntelligenceStepIsPersistedUnderItsOwnName() {
        OnboardingStep.save(.appleIntelligence)
        XCTAssertEqual(defaults.string(forKey: SharedKeys.onboardingStep), "appleIntelligence")
        XCTAssertEqual(OnboardingStep.current(), .appleIntelligence)
    }

    func testAGrantedMicrophoneSkipsItsStep() {
        XCTAssertEqual(OnboardingStep.modelPreparation.next(skipping: [.microphone]), .firstDictation)
    }

    func testBothSkipsChain() {
        XCTAssertEqual(
            OnboardingStep.keyboardSetup.next(skipping: [.appleIntelligence, .modelPreparation, .microphone]),
            .firstDictation
        )
    }

    func testOnlyAppleIntelligenceTheWaitAndTheMicrophoneCanBeSkipped() {
        XCTAssertEqual(
            OnboardingStep.allCases.filter(\.isSkippedWhenSatisfied),
            [.appleIntelligence, .modelPreparation, .microphone]
        )
        // A step outside that list is shown even when the caller calls it satisfied.
        XCTAssertEqual(OnboardingStep.language.next(skipping: [.keyboardSetup]), .keyboardSetup)
        XCTAssertEqual(OnboardingStep.microphone.next(skipping: [.firstDictation]), .firstDictation)
    }

    // MARK: - Shell

    func testProgressBarCoversEveryStepBetweenTheIntroAndTheCompletion() {
        XCTAssertEqual(OnboardingStep.progressSteps, [
            .language, .keyboardSetup, .appleIntelligence, .modelPreparation, .microphone, .firstDictation
        ])
        XCTAssertNil(OnboardingStep.welcome.progressIndex)
        XCTAssertNil(OnboardingStep.completion.progressIndex)
        XCTAssertEqual(OnboardingStep.language.progressIndex, 0)
        XCTAssertEqual(OnboardingStep.appleIntelligence.progressIndex, 2)
        XCTAssertEqual(OnboardingStep.microphone.progressIndex, 4)
        XCTAssertEqual(OnboardingStep.firstDictation.progressIndex, 5)
    }

    func testOnlyTheFirstDictationOffersSkip() {
        XCTAssertEqual(OnboardingStep.allCases.filter(\.isSkippable), [.firstDictation])
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
