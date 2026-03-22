// DictusKeyboard/TouchHandling/KeyboardTouchInterceptor.swift
import SwiftUI
import UIKit
import AudioToolbox
import DictusCore

// MARK: - Preference Key for collecting key frames

/// Information about a key's frame in the keyboard coordinate space.
struct KeyFrameInfo: Equatable {
    let frame: CGRect
    let isLetter: Bool
}

/// Collects key frames from all keys in the keyboard via SwiftUI preference system.
/// Each key reports its frame in the "keyboardArea" coordinate space.
struct KeyFramePreferenceKey: PreferenceKey {
    static var defaultValue: [String: KeyFrameInfo] = [:]
    static func reduce(value: inout [String: KeyFrameInfo], nextValue: () -> [String: KeyFrameInfo]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Frame Reporter

/// ViewModifier that reports a key's frame in the keyboard coordinate space.
/// Applied to each key in KeyRow.keyView(for:) so every key is registered
/// with the dead zone interceptor.
struct KeyFrameReporter: ViewModifier {
    let keyId: String
    let isLetter: Bool

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: KeyFramePreferenceKey.self,
                            value: [keyId: KeyFrameInfo(
                                frame: geo.frame(in: .named("keyboardArea")),
                                isLetter: isLetter
                            )]
                        )
                }
            )
    }
}

extension View {
    /// Report this key's frame to the dead zone interceptor.
    func reportKeyFrame(id: String, isLetter: Bool) -> some View {
        self.modifier(KeyFrameReporter(keyId: id, isLetter: isLetter))
    }
}

// MARK: - Touch Interceptor

/// UIViewRepresentable that catches touches in dead zones (gaps between keys).
///
/// WHY this exists:
/// The keyboard has 5-6pt horizontal gaps and 10-11pt vertical gaps between keys.
/// When a user taps in these gaps, no key receives the touch. Apple's native keyboard
/// eliminates dead zones by routing every touch to the nearest key. This interceptor
/// does the same: it sits behind all keys in a ZStack, only intercepts touches that
/// miss every key frame, and routes them to the nearest key.
///
/// HOW it works:
/// 1. Each key reports its frame via KeyFramePreferenceKey
/// 2. This UIView covers the entire keyboard area (ZStack background)
/// 3. hitTest() returns nil for touches on keys (passthrough to normal handling)
/// 4. hitTest() returns self for dead zone touches
/// 5. touchesBegan finds nearest key, plays audio+haptic
/// 6. touchesEnded calls onDeadZoneTap with the nearest key's ID
struct KeyboardTouchInterceptorView: UIViewRepresentable {
    let keyFrames: [String: KeyFrameInfo]
    let onDeadZoneTap: (String) -> Void

    func makeUIView(context: Context) -> KeyboardInterceptorUIView {
        let view = KeyboardInterceptorUIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        return view
    }

    func updateUIView(_ uiView: KeyboardInterceptorUIView, context: Context) {
        uiView.keyFrames = keyFrames
        uiView.onDeadZoneTap = onDeadZoneTap
    }
}

/// UIView that intercepts dead zone touches and routes to nearest key.
final class KeyboardInterceptorUIView: UIView {
    var keyFrames: [String: KeyFrameInfo] = [:]
    var onDeadZoneTap: ((String) -> Void)?

    /// The key ID that received the touchDown (used to pair touchUp)
    private var activeKeyId: String?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // No key frames registered (e.g., emoji mode) → don't intercept
        guard !keyFrames.isEmpty, bounds.contains(point) else { return nil }

        // If point is within any key's visual frame → passthrough to normal handling
        for (_, info) in keyFrames {
            if info.frame.contains(point) {
                return nil
            }
        }

        // Dead zone: intercept this touch
        return self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)

        // Find nearest key by distance to center
        var nearestId: String?
        var nearestDist: CGFloat = .infinity

        for (id, info) in keyFrames {
            let center = CGPoint(x: info.frame.midX, y: info.frame.midY)
            let dist = hypot(point.x - center.x, point.y - center.y)
            if dist < nearestDist {
                nearestDist = dist
                nearestId = id
            }
        }

        activeKeyId = nearestId

        // Play audio + haptic on touchDown (matches Apple: feedback on press)
        if let id = nearestId, let info = keyFrames[id] {
            AudioServicesPlaySystemSound(info.isLetter ? KeySound.letter : KeySound.modifier)
            HapticFeedback.keyTapped()
            HapticFeedback.prepareForNextTap()
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let id = activeKeyId {
            onDeadZoneTap?(id)
        }
        activeKeyId = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeKeyId = nil
    }
}
