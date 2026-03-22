// DictusKeyboard/TouchHandling/LetterKeyTouchView.swift
import SwiftUI
import UIKit

/// UIViewRepresentable wrapping a UIView with direct touch handling for letter keys.
///
/// WHY this exists:
/// SwiftUI DragGesture adds gesture resolution overhead (~5-10ms) due to
/// conflict resolution and minimum distance checks. UIKit touchesBegan fires
/// immediately on the UIResponder chain, eliminating that delay.
/// This is used ONLY for letter keys (.character type). Keys needing continuous
/// tracking (delete repeat, space trackpad, accent long-press drag) keep DragGesture.
///
/// TOUCH PIPELINE (per locked decision from CONTEXT.md):
/// touchDown: visual highlight -> audio -> haptic -> prepare() for next
/// touchUp: cancel long-press timer -> insertText -> update suggestions (async)
struct LetterKeyTouchView: UIViewRepresentable {
    /// Callbacks from UIKit touch events back to SwiftUI state.
    /// CGPoint provides the touch position within the UIView's bounds.
    let onTouchDown: (CGPoint) -> Void
    let onTouchUp: () -> Void
    let onLongPress: () -> Void
    /// Provides drag position for accent selection after long-press fires.
    let onDragPositionChanged: (CGPoint) -> Void
    let onTouchCancelled: () -> Void

    func makeUIView(context: Context) -> LetterKeyUIView {
        let view = LetterKeyUIView()
        view.onTouchDown = onTouchDown
        view.onTouchUp = onTouchUp
        view.onLongPress = onLongPress
        view.onDragPositionChanged = onDragPositionChanged
        view.onTouchCancelled = onTouchCancelled
        // Transparent background -- SwiftUI handles visual rendering.
        // The UIView only captures touch events.
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        return view
    }

    func updateUIView(_ uiView: LetterKeyUIView, context: Context) {
        // Update closures on every SwiftUI re-render to capture latest state
        uiView.onTouchDown = onTouchDown
        uiView.onTouchUp = onTouchUp
        uiView.onLongPress = onLongPress
        uiView.onDragPositionChanged = onDragPositionChanged
        uiView.onTouchCancelled = onTouchCancelled
    }
}

/// UIView subclass that captures raw touch events for zero-latency handling.
///
/// WHY a UIView subclass (not gesture recognizer):
/// UIGestureRecognizer still participates in gesture resolution.
/// Direct touchesBegan/Ended on UIView is the absolute lowest-latency path.
final class LetterKeyUIView: UIView {
    var onTouchDown: ((CGPoint) -> Void)?
    var onTouchUp: (() -> Void)?
    var onLongPress: (() -> Void)?
    var onDragPositionChanged: ((CGPoint) -> Void)?
    var onTouchCancelled: (() -> Void)?

    /// Task for 400ms long-press timer (accent popup).
    private var longPressTimer: Task<Void, Never>?
    /// Whether long-press has fired (accent mode active).
    private var longPressFired = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        longPressFired = false

        // Pass the touch position so KeyButton can record where the press started
        // (used for accent popup position calculation).
        if let touch = touches.first {
            let location = touch.location(in: self)
            onTouchDown?(location)
        }

        // Start 400ms long-press timer for accent popup
        longPressTimer?.cancel()
        longPressTimer = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            longPressFired = true
            onLongPress?()
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        // Only track drag position after long-press fires (accent selection).
        // Before long-press, small finger movements during a normal tap are ignored.
        guard longPressFired, let touch = touches.first else { return }
        let location = touch.location(in: self)
        onDragPositionChanged?(location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        longPressTimer?.cancel()
        longPressTimer = nil
        onTouchUp?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        longPressTimer?.cancel()
        longPressTimer = nil
        longPressFired = false
        onTouchCancelled?()
    }
}
