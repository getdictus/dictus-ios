// DictusCore/Tests/DictusCoreTests/OnboardingStepTests.swift
// The onboarding order and where an install mid-onboarding resumes (#649).
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

    func testOrderPutsLanguageBeforeMicrophoneAndHasNoPolishStep() {
        XCTAssertEqual(OnboardingStep.allCases, [
            .welcome, .language, .microphone, .keyboardSetup, .modelPreparation, .firstDictation
        ])
        XCTAssertFalse(OnboardingStep.allCases.map(\.rawValue).contains { $0.lowercased().contains("polish") })
    }

    func testNextWalksTheFlowAndEndsAfterTheFirstDictation() {
        XCTAssertEqual(OnboardingStep.welcome.next, .language)
        XCTAssertEqual(OnboardingStep.keyboardSetup.next, .modelPreparation)
        XCTAssertNil(OnboardingStep.firstDictation.next)
    }

    func testFreshInstallStartsAtWelcome() {
        XCTAssertEqual(OnboardingStep.current(), .welcome)
    }

    func testSavedStepIsRestored() {
        OnboardingStep.save(.keyboardSetup)
        XCTAssertEqual(OnboardingStep.current(), .keyboardSetup)
    }

    func testUnknownSavedStepStartsOver() {
        defaults.set("someFutureStep", forKey: SharedKeys.onboardingStep)
        XCTAssertEqual(OnboardingStep.current(), .welcome)
    }

    // MARK: - The old page index

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
