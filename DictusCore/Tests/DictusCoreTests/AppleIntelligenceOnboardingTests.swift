// DictusCore/Tests/DictusCoreTests/AppleIntelligenceOnboardingTests.swift
// When the onboarding shows its Apple Intelligence step (#683, #649 decision 7).
import XCTest
@testable import DictusCore

final class AppleIntelligenceOnboardingTests: XCTestCase {

    /// A capable iPhone where Apple Intelligence is not ready, whatever the reason Apple
    /// gives: off (or reported as not ready by the Apple bug), still downloading, or a
    /// reason this build does not know.
    func testShownOnACapableIPhoneWhereAppleIntelligenceIsNotReady() {
        let notReady: [PolishAvailabilityState] = [
            .appleIntelligenceNotEnabled, .modelNotReady, .other("aReasonAddedLater")
        ]
        for state in notReady {
            XCTAssertTrue(AppleIntelligenceOnboarding.isStepNeeded(engineState: state), "\(state)")
        }
    }

    func testHiddenWhenAppleIntelligenceIsReady() {
        XCTAssertFalse(AppleIntelligenceOnboarding.isStepNeeded(engineState: .available))
    }

    /// Nothing the user can turn on: no step, as for the rest of the Pro steps.
    func testHiddenOnADeviceThatCanNeverRunIt() {
        for state in [PolishAvailabilityState.deviceNotEligible, .osTooOld, .sdkMissing] {
            XCTAssertFalse(AppleIntelligenceOnboarding.isStepNeeded(engineState: state), "\(state)")
        }
    }

    /// The step reads the same capability table as the trial and the paywall, so the
    /// onboarding cannot ask an iPhone to turn on what those surfaces call impossible.
    func testAgreesWithTheCapabilityTheTrialReads() {
        let every: [PolishAvailabilityState] = [
            .available, .appleIntelligenceNotEnabled, .modelNotReady, .deviceNotEligible,
            .osTooOld, .sdkMissing, .other("x")
        ]
        for state in every where AppleIntelligenceOnboarding.isStepNeeded(engineState: state) {
            XCTAssertTrue(SmartModeAvailability.isCapable(engineState: state), "\(state)")
        }
    }
}
