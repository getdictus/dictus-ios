// DictusKeyboard/InputView.swift
import UIKit

/// Custom UIView that enables the system keyboard click sound.
/// UIInputViewAudioFeedback protocol must be adopted by a UIView subclass,
/// not by a SwiftUI view. We set this as the inputView of
/// UIInputViewController to enable UIDevice.current.playInputClick().
class KeyboardInputView: UIView, UIInputViewAudioFeedback {
    /// Return true to enable keyboard click sounds via playInputClick().
    var enableInputClicksWhenVisible: Bool { true }
}
