// DictusKeyboard/InputView.swift
import UIKit

/// Custom UIInputView that enables the system keyboard click sound and provides
/// explicit touch routing between the SwiftUI toolbar and the UIKit keyboard.
///
/// UIInputViewAudioFeedback protocol must be adopted by a UIView subclass,
/// not by a SwiftUI view. We set this as the inputView of
/// UIInputViewController to enable UIDevice.current.playInputClick().
///
/// UIInputView (not UIView) is required because UIInputViewController.inputView
/// is typed as UIInputView?. Using .keyboard style tells iOS this view behaves
/// like a keyboard, which is necessary for playInputClick() to work.
class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    /// Return true to enable keyboard click sounds via playInputClick().
    var enableInputClicksWhenVisible: Bool { true }

    /// Reference to the GiellaKeyboardView for explicit touch routing.
    weak var keyboardView: UIView?

    /// Reference to the UIHostingController's view (toolbar + recording overlay).
    weak var hostingView: UIView?

    /// Height of the toolbar area where touches should go to the hosting view.
    var toolbarHeight: CGFloat = 52

    /// Convenience initializer using .keyboard input view style.
    convenience init() {
        self.init(frame: .zero, inputViewStyle: .keyboard)
    }

    /// Explicit touch routing to prevent UIHostingController from intercepting
    /// edge touches meant for the keyboard.
    ///
    /// WHY this is needed:
    /// UIHostingController's _UIHostingView can intercept touches at the keyboard
    /// edges even when its visible content is only 52pt tall. The original
    /// giellakbd-ios keyboard doesn't have this problem because it's pure UIKit
    /// with no sibling hosting view. By overriding hitTest, we ensure:
    /// - Touches in the toolbar area (y < toolbarHeight) → hosting view
    /// - Touches in the keyboard area (y >= toolbarHeight) → keyboard view
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01 else { return nil }

        // If recording overlay is active (hosting view expanded to full height),
        // let the hosting view handle all touches for the overlay controls.
        if let hosting = hostingView, hosting.frame.height > toolbarHeight + 10 {
            return super.hitTest(point, with: event)
        }

        // Toolbar area: route to hosting view for mic button, settings, etc.
        if point.y < toolbarHeight, let hosting = hostingView {
            let hostingPoint = convert(point, to: hosting)
            if let hit = hosting.hitTest(hostingPoint, with: event) {
                return hit
            }
        }

        // Keyboard area: ALWAYS route to keyboard view.
        // This bypasses UIHostingController's hit-test which can intercept
        // edge touches and prevent touchesBegan from reaching GiellaKeyboardView.
        if let keyboard = keyboardView {
            let kbPoint = convert(point, to: keyboard)
            if let hit = keyboard.hitTest(kbPoint, with: event) {
                return hit
            }
        }

        return super.hitTest(point, with: event)
    }
}
