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

    // MARK: - Shift state tracking

    /// Timestamp of the last shift tap, used to detect double-tap for caps lock.
    /// If two shift taps occur within 300ms, we activate caps lock.
    private var lastShiftTapTime: TimeInterval = 0

    /// Threshold for double-tap detection (300ms matches iOS native behavior).
    private static let doubleTapThreshold: TimeInterval = 0.3

    /// Tracks whether shift was activated by the user tapping shift (true)
    /// or by autocapitalization (false). This distinction matters because:
    /// - Manual shift: returns to .normal after ONE character typed (one-shot shift)
    /// - Autocap shift: also returns to .normal after one character, but updateCapitalization
    ///   may re-apply shift if conditions still hold (e.g., still at start of sentence)
    private var isManualShift = false

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
            AudioServicesPlaySystemSound(KeySound.modifier)
            controller?.advanceToNextInputMode()

        case .keyboardMode, .splitKeyboard, .normalKeyboard,
             .sideKeyboardLeft, .sideKeyboardRight:
            // iPad keyboard mode keys -- not supported on iPhone, no-op
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
            // Haptic already fired in touchesBegan
            AudioServicesPlaySystemSound(KeySound.modifier)
            keyboardView?.page = .capslock
            lastShiftTapTime = 0 // Reset to prevent triple-tap confusion
            isManualShift = false // Caps lock is its own mode, not "manual shift"

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
    /// Inserts the character, plays letter sound, auto-unshifts after one letter,
    /// then rechecks autocapitalization (e.g., typing "." may prepare shift for next char).
    /// NOTE: Haptic fires in GiellaKeyboardView.touchesBegan() for ALL keys on touchDown.
    private func handleInputKey(_ character: String) {
        AudioServicesPlaySystemSound(KeySound.letter)

        // Insert the character. When on shifted/capslock page, the key definition
        // already contains the uppercase character, so we insert as-is.
        controller?.textDocumentProxy.insertText(character)

        // Auto-unshift after one character (unless caps locked).
        // This matches iOS native behavior: shift is "one-shot" unless locked.
        if let page = keyboardView?.page, page == .shifted {
            keyboardView?.page = .normal
            isManualShift = false
        }

        // Recheck autocapitalization after the character was inserted.
        // Example: typing "." won't trigger autocap yet (need space after),
        // but typing after "Hello. " should capitalize.
        updateCapitalization()
    }

    /// Handle backspace/delete key.
    /// After deleting, recheck autocapitalization -- deleting back to the start
    /// of a text field or to after a sentence-ending punctuation should re-shift.
    private func handleBackspace() {
        AudioServicesPlaySystemSound(KeySound.delete)
        controller?.textDocumentProxy.deleteBackward()
        updateCapitalization()
    }

    /// Handle spacebar press with auto-full-stop detection.
    /// If double-space is detected, replaces the trailing space with ". " (period+space).
    /// Otherwise inserts a normal space. Then rechecks autocapitalization.
    private func handleSpace() {
        AudioServicesPlaySystemSound(KeySound.modifier)

        // Check for double-space -> period BEFORE inserting the space.
        // handleAutoFullStop returns true if it performed the ". " substitution,
        // in which case we must NOT insert an additional space.
        if !handleAutoFullStop() {
            controller?.textDocumentProxy.insertText(" ")
        }

        // After space (or period+space), recheck autocap.
        // "Hello. " should trigger shift for the next character.
        updateCapitalization()
    }

    /// Handle return/newline key.
    /// After inserting newline, recheck autocapitalization -- many apps use
    /// .sentences autocap which should capitalize after a newline.
    private func handleReturn() {
        AudioServicesPlaySystemSound(KeySound.modifier)
        controller?.textDocumentProxy.insertText("\n")
        updateCapitalization()
    }

    /// Handle single shift tap: cycle through normal -> shifted -> normal.
    /// Double-tap within 300ms activates caps lock.
    ///
    /// WHY we handle double-tap here AND in didTriggerDoubleTap:
    /// The GiellaKeyboardView fires didTriggerDoubleTap for keys with supportsDoubleTap,
    /// but we also detect it here as a fallback because the timing can differ between
    /// the gesture recognizer and our manual tracking. Both paths lead to .capslock.
    private func handleShift() {
        AudioServicesPlaySystemSound(KeySound.modifier)

        guard let kbView = keyboardView else { return }

        let now = Date.timeIntervalSinceReferenceDate

        // Check if this is a double-tap (within 300ms of last shift tap)
        if (now - lastShiftTapTime) < Self.doubleTapThreshold {
            // Double-tap -> caps lock
            kbView.page = .capslock
            lastShiftTapTime = 0
            isManualShift = false
            return
        }

        lastShiftTapTime = now

        // Single tap: toggle between normal and shifted
        switch kbView.page {
        case .normal:
            kbView.page = .shifted
            isManualShift = true
        case .shifted:
            kbView.page = .normal
            isManualShift = false
        case .capslock:
            kbView.page = .normal
            isManualShift = false
        default:
            // On symbols pages, shift doesn't do anything
            break
        }
    }

    /// Handle 123/ABC layer switch.
    /// Toggles between letter pages (normal/shifted/capslock) and symbols1.
    private func handleSymbolsToggle() {
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
    /// Returns `true` if the substitution was performed (". " was inserted),
    /// `false` if no substitution happened (caller should insert a normal space).
    ///
    /// WHY called BEFORE inserting the space: We need to check what's already
    /// in the text buffer. The caller checks the return value to decide whether
    /// to insert an additional space.
    @discardableResult
    private func handleAutoFullStop() -> Bool {
        guard let proxy = controller?.textDocumentProxy,
              let text = proxy.documentContextBeforeInput?.suffix(3),
              text.count == 3,
              text.suffix(2) == "  " else { return false }

        let first = text.prefix(1)
        // Only replace if the character before the two spaces is a word character
        // (not a period or another space -- that would create ".. " or " . ")
        if first != "." && first != " " {
            proxy.deleteBackward() // delete first space
            proxy.deleteBackward() // delete second space
            proxy.insertText(". ")
            return true
        }
        return false
    }

    // MARK: - Autocapitalization

    /// Checks the textDocumentProxy's autocapitalization type and sets the keyboard
    /// page to .shifted when appropriate.
    ///
    /// This implements the standard iOS autocapitalization behavior:
    /// - `.sentences`: Capitalize at start of text field and after sentence-ending
    ///   punctuation (.!?) followed by a space or newline.
    /// - `.words`: Capitalize at start of text field and after each space.
    /// - `.allCharacters`: Always caps lock.
    /// - `.none`: Never autocapitalize.
    ///
    /// WHY guard against capslock: If the user has manually activated caps lock
    /// (via double-tap shift), autocapitalization must not interfere. The user
    /// explicitly wants ALL CAPS and tapping shift will deactivate it.
    func updateCapitalization() {
        guard let proxy = controller?.textDocumentProxy else { return }
        guard let kbView = keyboardView else { return }

        // Don't override user's caps lock
        guard kbView.page != .capslock else { return }
        // Only autocap on letter pages (not symbols)
        guard kbView.page == .normal || kbView.page == .shifted else { return }

        let autocapType = proxy.autocapitalizationType ?? .sentences

        switch autocapType {
        case .sentences:
            let beforeInput = proxy.documentContextBeforeInput ?? ""
            if beforeInput.isEmpty {
                // Beginning of text field -- capitalize first letter
                kbView.page = .shifted
                isManualShift = false
            } else {
                let trimmed = beforeInput.trimmingCharacters(in: .whitespaces)
                let lastChar = trimmed.last
                let endsWithSentencePunctuation = lastChar != nil && ".!?".contains(lastChar!)
                let lastInputChar = beforeInput.last

                if endsWithSentencePunctuation && (lastInputChar == " " || lastInputChar == "\n") {
                    // After sentence-ending punctuation + space/newline -> capitalize
                    kbView.page = .shifted
                    isManualShift = false
                } else if lastInputChar == "\n" {
                    // After a newline (return key) -> capitalize for new paragraph
                    kbView.page = .shifted
                    isManualShift = false
                } else if kbView.page == .shifted && !isManualShift {
                    // Was shifted from autocap, now typing regular text -> return to normal
                    kbView.page = .normal
                }
            }

        case .words:
            let beforeInput = proxy.documentContextBeforeInput ?? ""
            if beforeInput.isEmpty || beforeInput.last == " " || beforeInput.last == "\n" {
                kbView.page = .shifted
                isManualShift = false
            } else if kbView.page == .shifted && !isManualShift {
                kbView.page = .normal
            }

        case .allCharacters:
            kbView.page = .capslock

        default: // .none
            break
        }
    }
}
