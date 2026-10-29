// DictusCore/Tests/DictusCoreTests/StopStandbySceneScriptTests.swift
// The onboarding's "how to stop Dictus" scene: the order of its gesture and its loop (#681, #858).
import XCTest
@testable import DictusCore

final class StopStandbySceneScriptTests: XCTestCase {

    private typealias Script = StopStandbySceneScript
    private typealias IslandBeat = StopStandbySceneScript.IslandBeat
    private typealias LockBeat = StopStandbySceneScript.LockScreenBeat

    /// Every frame of the loop, 10 ms apart.
    private func everyFrame(_ variant: Script.Variant) -> [(time: Double, frame: Script.Frame)] {
        stride(from: 0.0, to: Script.loopSeconds, by: 0.01).map { ($0, Script.frame(at: $0, variant: variant)) }
    }

    /// The activity states in the order they appear, consecutive repeats collapsed.
    private func activitySequence(_ variant: Script.Variant) -> [Script.Activity] {
        everyFrame(variant).map(\.frame.activity).reduce(into: []) { sequence, activity in
            if sequence.last != activity { sequence.append(activity) }
        }
    }

    // MARK: - Variant

    func testTheVariantFollowsTheIsland() {
        XCTAssertEqual(Script.Variant(hasDynamicIsland: true), .island)
        XCTAssertEqual(Script.Variant(hasDynamicIsland: false), .lockScreen)
    }

    // MARK: - Loop

    /// A 3 s pass (#858): the gesture, then a second of empty island, nothing more.
    func testTheLoopLastsThreeSeconds() {
        XCTAssertEqual(Script.loopSeconds, 3)
    }

    /// The seam is the standby coming back, as after the next dictation: the pass ends on
    /// the activity gone and starts on it up, with no finger on either side.
    func testTheSeamBringsTheStandbyBack() {
        let expectations: [(Script.Variant, Script.Activity)] = [(.island, .compact), (.lockScreen, .expanded)]
        for (variant, start) in expectations {
            let first = Script.frame(at: 0, variant: variant)
            let last = Script.frame(at: Script.loopSeconds - 0.001, variant: variant)
            XCTAssertEqual(first.activity, start, "\(variant)")
            XCTAssertEqual(last.activity, .none, "\(variant)")
            XCTAssertNil(first.finger, "\(variant): no finger at the seam")
            XCTAssertNil(last.finger, "\(variant): no finger at the seam")
        }
    }

    /// The last second of either pass shows the activity gone (#858: 2.0 to 3.0 s).
    func testTheLastSecondShowsTheActivityGone() {
        for variant in [Script.Variant.island, .lockScreen] {
            for (time, frame) in everyFrame(variant) where time >= 2.0 {
                XCTAssertEqual(frame.activity, .none, "\(variant), t=\(time)")
            }
            XCTAssertNotEqual(Script.frame(at: 1.99, variant: variant).activity, .none, "\(variant)")
        }
    }

    func testTimesOutsideTheLoopWrap() {
        for variant in [Script.Variant.island, .lockScreen] {
            for time in [0.5, 0.9, 1.7, 2.5] {
                XCTAssertEqual(
                    Script.frame(at: time + Script.loopSeconds * 3, variant: variant),
                    Script.frame(at: time, variant: variant)
                )
                XCTAssertEqual(
                    Script.frame(at: time - Script.loopSeconds, variant: variant),
                    Script.frame(at: time, variant: variant)
                )
            }
        }
    }

    // MARK: - Island

    /// compact → long press → expanded → tap → gone: the story of decision 19, the return
    /// being the next pass.
    func testTheIslandGoesCompactExpandedGone() {
        XCTAssertEqual(activitySequence(.island), [.compact, .expanded, .none])
    }

    /// #858's beats: press at 0.3 s, expanded at 0.8 s, slide 1.1 to 1.6 s, tap 1.8 to 2.0 s.
    func testTheIslandBeatsFitTheShortLoop() {
        let frames = everyFrame(.island)
        func firstTime(_ condition: (Script.Frame) -> Bool) -> Double? {
            frames.first { condition($0.frame) }?.time
        }
        XCTAssertEqual(firstTime { $0.finger?.isPressed == true } ?? -1, 0.3, accuracy: 0.011)
        XCTAssertEqual(firstTime { $0.activity == .expanded } ?? -1, 0.8, accuracy: 0.011)
        XCTAssertEqual(firstTime { ($0.finger?.travel ?? 0) > 0 } ?? -1, 1.1, accuracy: 0.011)
        XCTAssertEqual(firstTime { $0.finger?.travel == 1 } ?? -1, 1.6, accuracy: 0.011)
        XCTAssertEqual(firstTime { $0.finger?.isPressed == true && $0.finger?.travel == 1 } ?? -1, 1.8, accuracy: 0.011)
        XCTAssertEqual(firstTime { $0.activity == .none } ?? -1, 2.0, accuracy: 0.011)
    }

    /// The island expands only once the finger has held it for the long press.
    func testTheIslandExpandsOnlyAfterTheLongPress() {
        let frames = everyFrame(.island)
        guard let pressAt = frames.first(where: { $0.frame.finger?.isPressed == true })?.time,
              let expandAt = frames.first(where: { $0.frame.activity == .expanded })?.time else {
            return XCTFail("the scene must press and expand")
        }
        XCTAssertGreaterThanOrEqual(expandAt - pressAt, Script.longPressSeconds - 0.011)
        for (time, frame) in frames where time >= pressAt && time < expandAt {
            XCTAssertEqual(frame.finger?.isPressed, true, "the finger holds until it expands, t=\(time)")
            XCTAssertEqual(frame.finger?.travel, 0, "it holds on the island, t=\(time)")
        }
    }

    /// The finger taps the power button only where there is one.
    func testThePowerButtonIsPressedOnlyWhileItIsOnScreen() {
        for (time, frame) in everyFrame(.island) {
            guard let finger = frame.finger, finger.isPressed, finger.travel > 0 else { continue }
            XCTAssertEqual(finger.travel, 1, "pressed only once it has arrived, t=\(time)")
            XCTAssertEqual(frame.activity, .expanded, "t=\(time)")
            XCTAssertTrue(frame.isPowerLit, "t=\(time)")
        }
    }

    /// The tap is what ends the activity: the frame after it has no island.
    func testTheTapEndsTheActivity() {
        XCTAssertEqual(Script.frame(at: IslandBeat.tapRelease - 0.01, variant: .island).activity, .expanded)
        XCTAssertEqual(Script.frame(at: IslandBeat.tapRelease, variant: .island).activity, .none)
        XCTAssertEqual(Script.frame(at: IslandBeat.tapRelease - 0.01, variant: .island).finger?.isPressed, true)
    }

    /// The finger lifts between the long press and the tap: two gestures, not one drag.
    func testTheFingerLiftsBeforeSliding() {
        for (time, frame) in everyFrame(.island) where time >= IslandBeat.travelStart && time < IslandBeat.tapPress {
            XCTAssertEqual(frame.finger?.isPressed, false, "t=\(time)")
        }
        XCTAssertEqual(Script.frame(at: IslandBeat.lift, variant: .island).activity, .expanded,
                       "the island stays expanded once the finger lifts")
    }

    func testNoFingerWhileTheIslandIsGone() {
        for (time, frame) in everyFrame(.island) where frame.activity == .none {
            if let finger = frame.finger {
                XCTAssertFalse(finger.isPressed, "t=\(time)")
                // Only the fade out after the tap, starting from the tap's own frame.
                XCTAssertLessThan(time, IslandBeat.tapRelease + Script.fade, "t=\(time)")
                if time > IslandBeat.tapRelease + 0.005 {
                    XCTAssertLessThan(finger.opacity, 1, "fading out, t=\(time)")
                }
            }
        }
    }

    /// The chips light 1, 2, 3 in order; 1 again is the next pass.
    func testTheChipsFollowTheGesture() {
        let sequence = everyFrame(.island).compactMap(\.frame.chip).reduce(into: [Script.Chip]()) { result, chip in
            if result.last != chip { result.append(chip) }
        }
        XCTAssertEqual(sequence, [.island, .longPress, .stop])
        XCTAssertEqual(Script.frame(at: IslandBeat.expands, variant: .island).chip, .longPress)
        XCTAssertEqual(Script.frame(at: IslandBeat.tapPress, variant: .island).chip, .stop)
    }

    func testTheFingerFadesInAndOut() {
        XCTAssertNil(Script.frame(at: IslandBeat.fingerIn - 0.01, variant: .island).finger)
        XCTAssertEqual(Script.frame(at: IslandBeat.fingerIn, variant: .island).finger?.opacity, 0)
        XCTAssertEqual(Script.frame(at: IslandBeat.press, variant: .island).finger?.opacity, 1)
        XCTAssertNil(Script.frame(at: IslandBeat.tapRelease + Script.fade, variant: .island).finger)
    }

    /// Reduce Motion: the one picture that says it all, the finger on the lit power button
    /// of the expanded island, between the slide and the tap.
    func testTheIslandStillFrameShowsThePowerButton() {
        let stillSeconds = Script.stillSeconds(.island)
        XCTAssertGreaterThan(stillSeconds, 1.6)
        XCTAssertLessThan(stillSeconds, 1.8)
        let still = Script.frame(at: stillSeconds, variant: .island)
        XCTAssertEqual(still.activity, .expanded)
        XCTAssertTrue(still.isPowerLit)
        XCTAssertEqual(still.finger?.travel, 1)
        XCTAssertEqual(still.finger?.opacity, 1)
        XCTAssertEqual(still.finger?.isPressed, false)
        XCTAssertEqual(still.chip, .stop)
    }

    // MARK: - Lock Screen

    /// The banner shows its buttons as it is: never compact, and no chips.
    func testTheLockScreenBannerGoes() {
        XCTAssertEqual(activitySequence(.lockScreen), [.expanded, .none])
        for (_, frame) in everyFrame(.lockScreen) {
            XCTAssertNil(frame.chip)
            XCTAssertNotEqual(frame.activity, .compact)
            if let finger = frame.finger {
                XCTAssertEqual(finger.travel, 1, "straight to the power button")
            }
        }
    }

    /// The same tap as the island's, 1.8 to 2.0 s, after the finger has rested on the button.
    func testTheLockScreenTapEndsTheBanner() {
        let firstPress = everyFrame(.lockScreen).first { $0.frame.finger?.isPressed == true }?.time ?? -1
        XCTAssertEqual(firstPress, 1.8, accuracy: 0.011)
        XCTAssertEqual(Script.frame(at: LockBeat.tapRelease - 0.01, variant: .lockScreen).finger?.isPressed, true)
        XCTAssertEqual(Script.frame(at: LockBeat.tapRelease - 0.01, variant: .lockScreen).activity, .expanded)
        XCTAssertEqual(Script.frame(at: LockBeat.tapRelease, variant: .lockScreen).activity, .none)
        for (time, frame) in everyFrame(.lockScreen) where frame.finger?.isPressed == true {
            XCTAssertEqual(frame.activity, .expanded, "t=\(time)")
            XCTAssertTrue(frame.isPowerLit, "t=\(time)")
        }
    }

    func testTheLockScreenStillFrameShowsThePowerButton() {
        let still = Script.frame(at: Script.stillSeconds(.lockScreen), variant: .lockScreen)
        XCTAssertEqual(still.activity, .expanded)
        XCTAssertTrue(still.isPowerLit)
        XCTAssertEqual(still.finger?.opacity, 1)
        XCTAssertEqual(still.finger?.isPressed, false)
    }
}
