// DictusCore/Sources/DictusCore/StopStandbySceneScript.swift
// What the onboarding's "how to stop Dictus" scene shows at each moment of its loop (#681).
import Foundation

/// The script of the "how to stop Dictus" scene (#681, #649 decision 19, mock-ups
/// `11-arreter-dictus-dynamic-island` and `11b-arreter-dictus-ecran-verrouille`): the
/// standby Live Activity's power button (`StopStandbyIntent`), pressed by a drawn finger.
///
/// THE STORY, one per kind of iPhone:
/// - **Island.** The compact island (logo bars, *On*). The finger touches and holds it;
///   after iOS's long press the island expands to the standby layout (logo, *Dictus / On*,
///   power and mic). The finger lifts, slides to the power button and taps it: the
///   activity ends and the island shrinks back to the bare camera cut-out. A few seconds
///   later the standby comes back, as it does after the next dictation, and the loop
///   starts again from that picture.
/// - **Lock Screen**, on an iPhone without an island (`DeviceCapabilities.hasDynamicIsland`):
///   the standby banner under the clock, with the same power button. The finger taps it
///   and the banner goes. Nothing to long-press there: the Lock Screen view shows the
///   buttons as it is.
///
/// WHY IN DICTUSCORE: the app target has no test bundle. What the scene must not get wrong
/// is the order of the gesture (no tap on a button that is not on screen yet, no expansion
/// before the long press has lasted) and that the loop closes on itself; both are tested.
public enum StopStandbySceneScript {

    /// Which picture the step draws.
    public enum Variant: String, Equatable, Sendable {
        /// The Dynamic Island: compact, long press, expanded, power.
        case island
        /// The Lock Screen banner and its power button.
        case lockScreen

        public init(hasDynamicIsland: Bool) {
            self = hasDynamicIsland ? .island : .lockScreen
        }
    }

    /// One pass of either scene: 10 s, the low end of decision 14's 10 to 20 s. The
    /// gesture itself takes four; the rest shows the island gone, then back.
    public static let loopSeconds: Double = 10

    /// How long iOS wants a finger on the island before it expands. Not published by
    /// Apple; half a second is the system's usual long press, and what the scene teaches
    /// is "hold", not a number.
    public static let longPressSeconds: Double = 0.5

    /// The moment shown with Reduce Motion on: the finger resting on the power button,
    /// lit, with the island expanded (or the banner up). The one picture that carries the
    /// whole answer, and the one the mock-ups draw.
    public static func stillSeconds(_ variant: Variant) -> Double {
        switch variant {
        case .island: return IslandBeat.travelEnd + 0.1
        case .lockScreen: return LockScreenBeat.fingerSettled + 0.2
        }
    }

    /// The beats of the island scene, in seconds from the start of the loop.
    enum IslandBeat {
        /// The finger comes onto the compact island and presses.
        static let fingerIn: Double = 1.2
        static let press: Double = 1.6
        /// iOS expands the island once the press has lasted.
        static let expands: Double = press + longPressSeconds
        /// The finger lifts; the island stays expanded.
        static let lift: Double = 2.5
        /// It slides from the island's centre to the power button.
        static let travelStart: Double = 2.8
        static let travelEnd: Double = 3.4
        /// It taps the power button: the activity ends.
        static let tapPress: Double = 3.65
        static let tapRelease: Double = 3.9
        /// The standby comes back, as after the next dictation.
        static let returns: Double = 8.4
    }

    /// The beats of the Lock Screen scene, in seconds from the start of the loop.
    enum LockScreenBeat {
        /// The finger comes onto the power button.
        static let fingerIn: Double = 1.4
        static let fingerSettled: Double = fingerIn + fade
        /// It taps it: the banner goes.
        static let tapPress: Double = 2.3
        static let tapRelease: Double = 2.55
        /// The banner comes back, as after the next dictation.
        static let returns: Double = 7.6
    }

    /// How long the finger takes to appear and to go.
    static let fade: Double = 0.3

    /// What of the standby Live Activity is on screen.
    public enum Activity: Equatable, Sendable {
        /// Nothing: the activity has ended. On an island iPhone, the bare camera cut-out.
        case none
        /// The compact island: logo bars and *On*. Island only.
        case compact
        /// The layout with the power and mic buttons: the expanded island, or the Lock
        /// Screen banner, which always shows them.
        case expanded
    }

    /// The three steps the island scene names above the phone (mock-up 11).
    public enum Chip: Int, CaseIterable, Sendable {
        /// "Island": the compact island, before it is touched.
        case island = 1
        /// "Long press": from the press to the expansion and the lift.
        case longPress = 2
        /// "Stop": from the slide to the power button until the island comes back.
        case stop = 3
    }

    /// Where the finger is.
    public struct Finger: Equatable, Sendable {
        /// 0 on the island's centre, 1 on the power button, in between while it slides.
        /// Always 1 on the Lock Screen, where the finger goes straight to the button.
        public let travel: Double
        public let isPressed: Bool
        /// 0 to 1 while it appears or goes.
        public let opacity: Double
    }

    /// One moment of the scene.
    public struct Frame: Equatable, Sendable {
        public let activity: Activity
        /// nil when no finger is on screen.
        public let finger: Finger?
        /// Whether the power button is lit (the blue ring of the mock-ups): from the moment
        /// the finger heads for it until the tap.
        public let isPowerLit: Bool
        /// The step named above the phone; nil on the Lock Screen, which has none.
        public let chip: Chip?
    }

    /// The scene at `time` seconds into the loop. Times outside the loop wrap.
    public static func frame(at time: Double, variant: Variant) -> Frame {
        let time = wrapped(time)
        switch variant {
        case .island: return islandFrame(at: time)
        case .lockScreen: return lockScreenFrame(at: time)
        }
    }

    // MARK: - Island

    private static func islandFrame(at time: Double) -> Frame {
        typealias Beat = IslandBeat
        let activity: Activity
        if time < Beat.expands || time >= Beat.returns {
            activity = .compact
        } else if time < Beat.tapRelease {
            activity = .expanded
        } else {
            activity = .none
        }

        let chip: Chip
        if time < Beat.press || time >= Beat.returns {
            chip = .island
        } else if time < Beat.travelStart {
            chip = .longPress
        } else {
            chip = .stop
        }

        let isPowerLit = time >= Beat.travelStart && time < Beat.tapRelease

        var finger: Finger?
        if time >= Beat.fingerIn && time < Beat.tapRelease + fade {
            let opacity: Double
            if time < Beat.fingerIn + fade {
                opacity = (time - Beat.fingerIn) / fade
            } else if time >= Beat.tapRelease {
                opacity = 1 - (time - Beat.tapRelease) / fade
            } else {
                opacity = 1
            }
            let pressed = (time >= Beat.press && time < Beat.lift)
                || (time >= Beat.tapPress && time < Beat.tapRelease)
            finger = Finger(
                travel: progress(time, from: Beat.travelStart, to: Beat.travelEnd),
                isPressed: pressed,
                opacity: clamped(opacity)
            )
        }

        return Frame(activity: activity, finger: finger, isPowerLit: isPowerLit, chip: chip)
    }

    // MARK: - Lock Screen

    private static func lockScreenFrame(at time: Double) -> Frame {
        typealias Beat = LockScreenBeat
        let isShown = time < Beat.tapRelease || time >= Beat.returns
        let isPowerLit = time >= Beat.fingerIn && time < Beat.tapRelease

        var finger: Finger?
        if time >= Beat.fingerIn && time < Beat.tapRelease + fade {
            let opacity: Double
            if time < Beat.fingerIn + fade {
                opacity = (time - Beat.fingerIn) / fade
            } else if time >= Beat.tapRelease {
                opacity = 1 - (time - Beat.tapRelease) / fade
            } else {
                opacity = 1
            }
            finger = Finger(
                travel: 1,
                isPressed: time >= Beat.tapPress && time < Beat.tapRelease,
                opacity: clamped(opacity)
            )
        }

        return Frame(activity: isShown ? .expanded : .none, finger: finger, isPowerLit: isPowerLit, chip: nil)
    }

    // MARK: - Helpers

    private static func wrapped(_ time: Double) -> Double {
        let remainder = time.truncatingRemainder(dividingBy: loopSeconds)
        return remainder < 0 ? remainder + loopSeconds : remainder
    }

    /// 0 before `start`, 1 after `end`, eased in and out in between.
    private static func progress(_ time: Double, from start: Double, to end: Double) -> Double {
        guard end > start else { return time >= end ? 1 : 0 }
        let linear = clamped((time - start) / (end - start))
        return linear * linear * (3 - 2 * linear)
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
