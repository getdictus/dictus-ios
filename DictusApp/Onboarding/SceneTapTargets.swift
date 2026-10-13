// DictusApp/Onboarding/SceneTapTargets.swift
// Puts a scene's drawn finger on the view it taps (#680).
import SwiftUI
import DictusCore

// WHY ANCHORS AND NOT COORDINATES: the Smart Modes scene (#679) computes its finger's
// position from the keyboard's metrics, because the finger slides along the fan. The voice
// notes, vocabulary and history scenes only tap buttons, and their buttons move: a sheet
// comes up, a row changes section, the search bar gains a button. Each button marks itself
// as a target, and the finger is laid over whichever one the script names, so a change to
// a layout can never leave the finger tapping empty space.

/// Where each tap target of a scene is drawn.
struct SceneTapTargetsKey<Target: Hashable>: PreferenceKey {
    static var defaultValue: [Target: Anchor<CGRect>] { [:] }

    static func reduce(value: inout [Target: Anchor<CGRect>], nextValue: () -> [Target: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, newer in newer }
    }
}

extension View {
    /// Marks this view as what the finger taps when the script names `target`.
    func sceneTapTarget<Target: Hashable>(_ target: Target) -> some View {
        anchorPreference(key: SceneTapTargetsKey<Target>.self, value: .bounds) { [target: $0] }
    }

    /// Draws `finger` over the centre of the view marked with its target, if it is on screen.
    func sceneFinger<Target: Hashable & Sendable>(_ finger: SceneTapFinger<Target>?) -> some View {
        overlayPreferenceValue(SceneTapTargetsKey<Target>.self) { anchors in
            GeometryReader { proxy in
                if let finger, let anchor = anchors[finger.target] {
                    let rect = proxy[anchor]
                    SceneFinger(isPressed: finger.isPressed)
                        .opacity(finger.opacity)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }
}
