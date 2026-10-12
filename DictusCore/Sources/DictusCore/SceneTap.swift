// DictusCore/Sources/DictusCore/SceneTap.swift
// The taps a drawn finger performs in an onboarding scene, and the text it types (#680).
import Foundation

/// One tap of a scene's drawn finger (#680, #649 decision 14): it fades in over its
/// target, presses, lifts, and fades out.
///
/// WHY A VALUE AND NOT A TIMELINE PER SCENE: the voice notes, vocabulary and history
/// scenes are sequences of taps on buttons, and each needs the same finger: on screen a
/// beat before the press, gone a beat after the release. The Smart Modes scene (#679)
/// slides its finger along the fan and keeps its own script; these three only tap.
///
/// What the tap *does* starts at `release`, as a real button acts on touch-up.
public struct SceneTap<Target: Hashable & Sendable>: Equatable, Sendable {
    public let target: Target
    /// When the finger touches the screen.
    public let press: Double
    /// When it lifts. A long press is a tap whose release comes late.
    public let release: Double

    /// How long the finger takes to appear before the press and to go after the release.
    public static var fade: Double { 0.3 }

    public init(_ target: Target, press: Double, release: Double) {
        self.target = target
        self.press = press
        self.release = release
    }

    /// When the finger starts to appear.
    public var fingerIn: Double { press - Self.fade }
    /// When it is gone.
    public var fingerOut: Double { release + Self.fade }

    /// The finger at `time`, or nil when this tap does not show it.
    public func finger(at time: Double) -> SceneTapFinger<Target>? {
        guard time >= fingerIn, time < fingerOut else { return nil }
        let opacity: Double
        if time < press {
            opacity = (time - fingerIn) / Self.fade
        } else if time >= release {
            opacity = 1 - (time - release) / Self.fade
        } else {
            opacity = 1
        }
        return SceneTapFinger(
            target: target,
            isPressed: time >= press && time < release,
            opacity: min(max(opacity, 0), 1)
        )
    }
}

/// The drawn finger at one moment: over which target, touching or not, how visible.
public struct SceneTapFinger<Target: Hashable & Sendable>: Equatable, Sendable {
    public let target: Target
    public let isPressed: Bool
    /// 0 to 1, for its fade in and out.
    public let opacity: Double

    public init(target: Target, isPressed: Bool, opacity: Double) {
        self.target = target
        self.isPressed = isPressed
        self.opacity = opacity
    }
}

public extension Array {
    /// The finger of whichever tap shows it at `time`. The taps of a scene never
    /// overlap, which the scenes' tests check, so at most one does.
    func finger<Target>(at time: Double) -> SceneTapFinger<Target>? where Element == SceneTap<Target> {
        lazy.compactMap { $0.finger(at: time) }.first
    }
}

/// Text typed into a drawn field, one character at a time (#680).
public enum SceneTyping {
    /// The part of `text` typed at `time`, when typing runs from `start` to `end` at an
    /// even pace: nothing before `start`, all of it from `end`.
    ///
    /// WHY A FIXED WINDOW AND NOT A FIXED PACE PER CHARACTER: the text is localized, and
    /// the scene's beats must not move with the language. A longer word is typed a
    /// little faster.
    public static func typed(_ text: String, from start: Double, to end: Double, at time: Double) -> String {
        guard time >= start else { return "" }
        guard time < end, end > start else { return text }
        let count = Int(Double(text.count) * (time - start) / (end - start))
        return String(text.prefix(count))
    }
}
