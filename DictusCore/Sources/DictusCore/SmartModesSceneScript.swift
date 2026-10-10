// DictusCore/Sources/DictusCore/SmartModesSceneScript.swift
// What the onboarding's Smart Modes scene shows at each moment of its loop (#679).
import CoreGraphics
import Foundation

/// The script of the Smart Modes scene (#679, #649 decisions 9 and 14, mock-up
/// `05-scene-smart-modes`): the keyboard's long-press fan, performed by a drawn finger.
///
/// THE STORY, two passes of the same gesture so the loop closes on itself:
/// 1. A finger lands on the mic pill and holds. After the fan's real long-press delay the
///    rows replace the keys. The finger slides down to `→ EN` and lets go: the fan closes,
///    the mic pill wears the `EN` badge and the toolbar names the armed mode.
/// 2. The same gesture again, down to `Normal`: the badge goes, the keyboard is back where
///    the loop started.
///
/// The second pass is not filler. Releasing back on the mic aborts the gesture, so
/// `Normal` is the only way to clear a sticky mode (`SmartModeFanEntry.normal`), and a
/// user who learns only half of the gesture dictates in English forever.
///
/// WHY IN DICTUSCORE: the app target has no test bundle, and the one thing that makes this
/// a drawing of the real fan rather than of an imagined one is that the row under the
/// finger is the row the keyboard would highlight. That is `SmartModeFanLayout`'s
/// arithmetic, applied here to the finger's position and tested.
public enum SmartModesSceneScript {

    /// One pass: rest, press, hold, slide, release, rest.
    public static let passSeconds: Double = 6

    /// The whole loop: two passes, about 12 s (decision 14 asks for 10 to 20).
    public static let loopSeconds: Double = passSeconds * 2

    /// How long the finger holds before the fan opens: the `minimumDuration` of the
    /// keyboard's `LongPressGesture` (`ToolbarView.fanGesture`), so the scene teaches the
    /// real wait. Written here because the keyboard target cannot be imported.
    public static let longPressSeconds: Double = 0.35

    /// The moment shown with Reduce Motion on: the first pass, the finger resting on
    /// `→ EN`, the fan open and that row lit. It tells the whole gesture without moving,
    /// and it is the moment mock-up 05 draws.
    public static let stillSeconds: Double = Beat.release - 0.25

    /// The beats of one pass, in seconds from its start.
    enum Beat {
        static let fingerIn: Double = 0.6
        static let press: Double = 0.9
        static let fanOpens: Double = press + longPressSeconds
        static let slideStart: Double = 1.55
        static let slideEnd: Double = 3.05
        static let release: Double = 3.55
        static let fingerOut: Double = 3.85
        /// How long the finger takes to appear and to go.
        static let fade: Double = 0.3
    }

    /// The fan the scene draws: `Normal`, `Message`, `Liste`, `→ EN` (#679, mock-up 05).
    ///
    /// WHY NOT THE USER'S PINNED LIST: the user has not picked yet (the pick comes right
    /// after this scene), and the seed would show three modes that all transform the
    /// text the same way. These four show the two axes the catalogue moves text along,
    /// a register (Message), a structure (List), and a language.
    ///
    /// WHY THE TRANSLATION TARGET DEPENDS ON THE USER: `→ EN` to an English speaker is a
    /// mode they will never use, and the pick that follows does not even offer it. The
    /// scene takes the first target the pick offers (`SmartModePick.translateTargets`),
    /// which is `→ EN` for everyone but English speakers.
    ///
    /// - Parameter spokenLanguage: `SharedKeys.spokenLanguage`, as the pick reads it.
    public static func entries(spokenLanguage: String?) -> [SmartModeFanEntry] {
        let modes = [SmartModeCatalogue.messageIdentifier, SmartModeCatalogue.notesIdentifier]
            .compactMap { identifier in SmartModeCatalogue.builtIns.first { $0.id == identifier } }
        let target = SmartModePick.translateTargets(spokenLanguage: spokenLanguage).first ?? .english
        return [.normal]
            + modes.map(SmartModeFanEntry.mode)
            + [.mode(SmartModeCatalogue.translate(to: target))]
    }

    /// The drawn finger.
    public struct Finger: Equatable, Sendable {
        /// Vertical position in the fan's coordinates: 0 is the top of the first row,
        /// negative is up on the toolbar, where the mic is.
        public let y: CGFloat
        /// 0 on the mic, 1 on the row it is heading for. The view moves the finger
        /// sideways with it.
        public let travel: Double
        /// Whether it is touching the screen.
        public let isPressed: Bool
        /// 0 to 1, for its fade in and out.
        public let opacity: Double
    }

    /// Everything the scene draws at one moment.
    public struct Frame: Equatable, Sendable {
        /// Whether the rows have replaced the keys.
        public let isFanOpen: Bool
        /// The row under the finger, nil when the fan is closed or the finger is on none.
        public let highlightedIndex: Int?
        /// The row of the armed mode, nil for none (Normal).
        public let armedIndex: Int?
        /// The finger, nil while it is off screen.
        public let finger: Finger?
    }

    /// The frame at `time` seconds into the loop.
    ///
    /// - Parameters:
    ///   - entryCount: the fan's rows, Normal included. The first pass arms the last row,
    ///     the second goes back to the first (Normal).
    ///   - fanAreaHeight: the height the rows divide (`SmartModeFanLayout.rowHeight`).
    ///   - micY: the centre of the mic pill in the fan's coordinates, so negative.
    public static func frame(at time: Double,
                             entryCount: Int,
                             fanAreaHeight: CGFloat,
                             micY: CGFloat) -> Frame {
        let looped = loopSeconds > 0 ? time.truncatingRemainder(dividingBy: loopSeconds) : 0
        let wrapped = looped < 0 ? looped + loopSeconds : looped
        let isSecondPass = wrapped >= passSeconds
        let local = isSecondPass ? wrapped - passSeconds : wrapped

        let lastIndex = max(0, entryCount - 1)
        let target = isSecondPass ? 0 : lastIndex
        // What the pass starts with and what its release leaves armed. Normal is "nothing
        // armed", so it is nil, as `SmartModeFanEntry.smartMode` is for it.
        let armedBefore: Int? = isSecondPass ? lastIndex : nil
        let armedAfter: Int? = isSecondPass ? nil : lastIndex
        let armedIndex = local < Beat.release ? armedBefore : armedAfter

        let isFanOpen = local >= Beat.fanOpens && local < Beat.release

        let finger = finger(at: local, target: target, entryCount: entryCount,
                            fanAreaHeight: fanAreaHeight, micY: micY)

        var highlighted: Int?
        if isFanOpen, let finger {
            highlighted = SmartModeFanLayout.entryIndex(
                atY: finger.y,
                availableHeight: fanAreaHeight,
                entryCount: entryCount,
                showsReason: false
            )
        }

        return Frame(
            isFanOpen: isFanOpen,
            highlightedIndex: highlighted,
            armedIndex: entryCount > 0 ? armedIndex : nil,
            finger: finger
        )
    }

    // MARK: - Private

    private static func finger(at local: Double,
                               target: Int,
                               entryCount: Int,
                               fanAreaHeight: CGFloat,
                               micY: CGFloat) -> Finger? {
        guard local >= Beat.fingerIn, local < Beat.fingerOut else { return nil }

        let travel = smoothStep(from: Beat.slideStart, to: Beat.slideEnd, at: local)
        let rowHeight = SmartModeFanLayout.rowHeight(
            availableHeight: fanAreaHeight, entryCount: entryCount, showsReason: false
        )
        // The middle of the target row: where a thumb choosing it rests.
        let targetY = rowHeight * (CGFloat(target) + 0.5)
        let y = micY + (targetY - micY) * CGFloat(travel)

        let opacity: Double
        if local < Beat.fingerIn + Beat.fade {
            opacity = (local - Beat.fingerIn) / Beat.fade
        } else if local >= Beat.release {
            opacity = max(0, 1 - (local - Beat.release) / Beat.fade)
        } else {
            opacity = 1
        }

        return Finger(
            y: y,
            travel: travel,
            isPressed: local >= Beat.press && local < Beat.release,
            opacity: min(1, max(0, opacity))
        )
    }

    /// 0 before `start`, 1 after `end`, an ease in and out between: a thumb accelerates
    /// and settles, it does not slide at constant speed.
    private static func smoothStep(from start: Double, to end: Double, at time: Double) -> Double {
        guard end > start else { return time >= end ? 1 : 0 }
        let linear = min(1, max(0, (time - start) / (end - start)))
        return linear * linear * (3 - 2 * linear)
    }
}
