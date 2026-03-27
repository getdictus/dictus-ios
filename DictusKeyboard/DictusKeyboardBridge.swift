// DictusKeyboard/DictusKeyboardBridge.swift
// Delegate bridge from giellakbd-ios GiellaKeyboardView key events to Dictus text actions.
// Created for Phase 18 Plan 02 -- wires the vendored UICollectionView keyboard
// to textDocumentProxy operations with haptic feedback and 3-category key sounds.

import UIKit
import AudioToolbox
import DictusCore

/// Adapts GiellaKeyboardView delegate callbacks into Dictus keyboard actions.
///
/// WHY a separate bridge class (not making KeyboardViewController the delegate):
/// 1. Single Responsibility: The bridge handles ONLY key event translation.
///    KeyboardViewController handles view lifecycle, height, and hosting.
/// 2. Testability: The bridge can be tested in isolation with a mock proxy.
/// 3. Decoupling: If the vendored delegate protocol changes, only this file changes.
///
/// The bridge receives key events from the UICollectionView keyboard and:
/// - Inserts/deletes text via textDocumentProxy
/// - Plays haptic feedback via DictusCore's HapticFeedback
/// - Plays 3-category key sounds via AudioServicesPlaySystemSound
/// - Manages shift/capslock page state on the keyboard view
/// - Handles auto-full-stop (double-space -> period)
final class DictusKeyboardBridge: NSObject,
    GiellaKeyboardViewDelegate,
    GiellaKeyboardViewKeyboardKeyDelegate
{
    // MARK: - Dependencies

    /// Weak reference to the input view controller for textDocumentProxy access.
    /// WHY weak: The controller owns the bridge (strong ref). If the bridge held
    /// a strong ref back, it would create a retain cycle.
    weak var controller: UIInputViewController?

    /// Reference to the keyboard view for page state management (shift/symbols).
    /// WHY weak: The keyboard view is owned by the controller's view hierarchy.
    weak var keyboardView: GiellaKeyboardView?

    // MARK: - Shift double-tap detection

    /// Timestamp of the last shift tap, used to detect double-tap for caps lock.
    /// If two shift taps occur within 300ms, we activate caps lock.
    private var lastShiftTapTime: TimeInterval = 0

    /// Threshold for double-tap detection (300ms matches iOS native behavior).
    private static let doubleTapThreshold: TimeInterval = 0.3

    // MARK: - GiellaKeyboardViewDelegate

    func didTriggerKey(_ key: KeyDefinition) {
        switch key.type {
        case .input(let character, _):
            handleInputKey(character)

        case .backspace:
            handleBackspace()

        case .spacebar:
            handleSpace()

        case .returnkey:
            handleReturn()

        case .shift:
            handleShift()

        case .symbols:
            handleSymbolsToggle()

        case .shiftSymbols:
            handleShiftSymbolsToggle()

        case .comma:
            handleInputKey(",")

        case .fullStop:
            handleInputKey(".")

        case .tab:
            handleInputKey("\t")

        case .keyboard:
            // Globe/next keyboard button -- advance to next input method
            HapticFeedback.keyTapped()
            AudioServicesPlaySystemSound(KeySound.modifier)
            controller?.advanceToNextInputMode()

        case .keyboardMode, .splitKeyboard, .normalKeyboard,
             .sideKeyboardLeft, .sideKeyboardRight:
            // iPad keyboard mode keys -- not supported on iPhone, no-op
            HapticFeedback.keyTapped()
            AudioServicesPlaySystemSound(KeySound.modifier)

        case .spacer, .caps:
            // Spacer is a layout element, caps is handled by double-tap shift
            break
        }
    }

    func didTriggerDoubleTap(forKey key: KeyDefinition) {
        switch key.type {
        case .shift:
            // Double-tap shift activates caps lock
            HapticFeedback.keyTapped()
            AudioServicesPlaySystemSound(KeySound.modifier)
            keyboardView?.page = .capslock
            lastShiftTapTime = 0 // Reset to prevent triple-tap confusion

        default:
            // Other keys don't have double-tap behavior in our layout
            break
        }
    }

    func didSwipeKey(_ key: KeyDefinition) {
        // Swipe key inserts the alternate character (e.g., swipe down on "e" for accent)
        // For now, treat same as regular trigger -- Phase 19 will add accent handling
        didTriggerKey(key)
    }

    func didTriggerHoldKey(_ key: KeyDefinition) {
        // Long-press hold triggers are handled by the GiellaKeyboardView's
        // longpress overlay system. No additional action needed here.
    }

    func didMoveCursor(_ movement: Int) {
        // Spacebar trackpad cursor movement
        controller?.textDocumentProxy.adjustTextPosition(byCharacterOffset: movement)
        HapticFeedback.cursorMoved()
    }

    // MARK: - GiellaKeyboardViewKeyboardKeyDelegate

    @objc func didTriggerKeyboardButton(sender: UIView, forEvent event: UIEvent) {
        // This is the accessibility/globe button callback from GiellaKeyboardView.
        // It creates an invisible UIButton over the keyboard/globe key for VoiceOver.
        controller?.advanceToNextInputMode()
    }

    // MARK: - Key Action Handlers

    /// Handle character input (letters, numbers, punctuation).
    /// Inserts the character, plays letter sound + haptic, auto-unshifts after one letter.
    private func handleInputKey(_ character: String) {
        HapticFeedback.keyTapped()
        AudioServicesPlaySystemSound(KeySound.letter)

        // Insert the character. When on shifted/capslock page, the key definition
        // already contains the uppercase character, so we insert as-is.
        controller?.textDocumentProxy.insertText(character)

        // Auto-unshift after one character (unless caps locked).
        // This matches iOS native behavior: shift is "one-shot" unless locked.
        if let page = keyboardView?.page, page == .shifted {
            keyboardView?.page = .normal
        }

        postTextDidChange()
    }

    /// Handle backspace/delete key.
    private func handleBackspace() {
        HapticFeedback.keyTapped()
        AudioServicesPlaySystemSound(KeySound.delete)
        controller?.textDocumentProxy.deleteBackward()
        postTextDidChange()
    }

    /// Handle spacebar press with auto-full-stop detection.
    private func handleSpace() {
        HapticFeedback.keyTapped()
        AudioServicesPlaySystemSound(KeySound.modifier)

        // Check for double-space -> period BEFORE inserting the space.
        // This must happen first so we can replace the trailing space.
        handleAutoFullStop()

        controller?.textDocumentProxy.insertText(" ")
        postTextDidChange()
    }

    /// Handle return/newline key.
    private func handleReturn() {
        HapticFeedback.keyTapped()
        AudioServicesPlaySystemSound(KeySound.modifier)
        controller?.textDocumentProxy.insertText("\n")
        postTextDidChange()
    }

    /// Handle single shift tap: cycle through normal -> shifted -> normal.
    /// Double-tap for caps lock is handled by didTriggerDoubleTap.
    private func handleShift() {
        HapticFeedback.keyTapped()
        AudioServicesPlaySystemSound(KeySound.modifier)

        guard let kbView = keyboardView else { return }

        let now = Date.timeIntervalSinceReferenceDate

        // Check if this is a double-tap (within 300ms of last shift tap)
        if (now - lastShiftTapTime) < Self.doubleTapThreshold {
            // Double-tap -> caps lock
            kbView.page = .capslock
            lastShiftTapTime = 0
            return
        }

        lastShiftTapTime = now

        // Single tap: toggle between normal and shifted
        switch kbView.page {
        case .normal:
            kbView.page = .shifted
        case .shifted:
            kbView.page = .normal
        case .capslock:
            kbView.page = .normal
        default:
            // On symbols pages, shift doesn't do anything
            break
        }
    }

    /// Handle 123/ABC layer switch.
    /// Toggles between letter pages (normal/shifted/capslock) and symbols1.
    private func handleSymbolsToggle() {
        HapticFeedback.keyTapped()
        AudioServicesPlaySystemSound(KeySound.modifier)

        guard let kbView = keyboardView else { return }

        switch kbView.page {
        case .normal, .shifted, .capslock:
            kbView.page = .symbols1
        case .symbols1, .symbols2:
            kbView.page = .normal
        }
    }

    /// Handle #+=/123 toggle on symbols pages.
    /// Toggles between symbols1 and symbols2.
    private func handleShiftSymbolsToggle() {
        HapticFeedback.keyTapped()
        AudioServicesPlaySystemSound(KeySound.modifier)

        guard let kbView = keyboardView else { return }

        switch kbView.page {
        case .symbols1:
            kbView.page = .symbols2
        case .symbols2:
            kbView.page = .symbols1
        default:
            break
        }
    }

    // MARK: - Auto-full-stop

    /// Replaces double-space with ". " (period + space).
    /// This is the standard iOS auto-punctuation behavior:
    /// If the user types two spaces in a row after a word character,
    /// replace "  " with ". " to end the sentence.
    ///
    /// WHY called BEFORE inserting the space: We need to check what's already
    /// in the text buffer. After inserting, the buffer would have the new space
    /// and the check would need to account for that.
    private func handleAutoFullStop() {
        guard let proxy = controller?.textDocumentProxy,
              let text = proxy.documentContextBeforeInput?.suffix(3),
              text.count == 3,
              text.suffix(2) == "  " else { return }

        let first = text.prefix(1)
        // Only replace if the character before the two spaces is a word character
        // (not a period or another space -- that would create ".. " or " . ")
        if first != "." && first != " " {
            proxy.deleteBackward() // delete first space
            proxy.deleteBackward() // delete second space
            proxy.insertText(". ")
        }
    }

    // MARK: - Notifications

    /// Post text-did-change notification for autocapitalization checks.
    private func postTextDidChange() {
        NotificationCenter.default.post(name: .dictusTextDidChange, object: nil)
    }
}
