// DictusKeyboard/Views/KeyboardView.swift
import SwiftUI
import UIKit
import DictusCore

/// The main keyboard view composing all rows and managing layer/shift state.
struct KeyboardView: View {
    let controller: UIInputViewController
    let hasFullAccess: Bool

    @State private var currentLayer: KeyboardLayerType = .letters
    @State private var shiftState: ShiftState = .off
    /// Tracks the last typed character for the adaptive accent key.
    /// After typing a vowel (e, a, u, i, o), the adaptive key shows the most
    /// common accent for that vowel. Reset on space, delete, return, or layer switch.
    @State private var lastTypedChar: String? = nil

    private var isShifted: Bool {
        shiftState == .shifted || shiftState == .capsLocked
    }

    private var currentRows: [[KeyDefinition]] {
        switch currentLayer {
        case .letters:
            // Use dynamic layout (AZERTY or QWERTY) based on App Group preference.
            // Filter out .mic keys from every row -- the mic button now lives in the
            // toolbar above the keyboard (Plan 03-02). Filtering all rows (not just row 4)
            // is a safety measure in case layouts are restructured in the future.
            return KeyboardLayout.currentLettersRows().map { row in
                row.filter { $0.type != .mic }
            }
        case .numbers: return KeyboardLayout.numbersRows
        case .symbols: return KeyboardLayout.symbolsRows
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: KeyMetrics.rowSpacing) {
                ForEach(Array(currentRows.enumerated()), id: \.offset) { _, row in
                    KeyRow(
                        keys: row,
                        rowWidth: geometry.size.width,
                        isShifted: isShifted,
                        shiftState: $shiftState,
                        onCharacter: { char in
                            insertCharacter(char)
                        },
                        onDelete: {
                            HapticFeedback.keyTapped()
                            if hasFullAccess {
                                UIDevice.current.playInputClick()
                            }
                            controller.textDocumentProxy.deleteBackward()
                            lastTypedChar = nil
                        },
                        onGlobe: {
                            HapticFeedback.keyTapped()
                            controller.advanceToNextInputMode()
                        },
                        onLayerSwitch: {
                            HapticFeedback.keyTapped()
                            toggleLettersNumbers()
                        },
                        onSymbolToggle: {
                            HapticFeedback.keyTapped()
                            toggleNumbersSymbols()
                        },
                        onSpace: {
                            HapticFeedback.keyTapped()
                            if hasFullAccess {
                                UIDevice.current.playInputClick()
                            }
                            controller.textDocumentProxy.insertText(" ")
                            lastTypedChar = nil
                        },
                        onReturn: {
                            HapticFeedback.keyTapped()
                            if hasFullAccess {
                                UIDevice.current.playInputClick()
                            }
                            controller.textDocumentProxy.insertText("\n")
                            lastTypedChar = nil
                        },
                        onAccentAdaptive: { char in
                            HapticFeedback.keyTapped()
                            insertCharacter(char)
                        },
                        lastTypedChar: lastTypedChar,
                        hasFullAccess: hasFullAccess
                    )
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: keyboardHeight)
    }

    private var keyboardHeight: CGFloat {
        let rows = CGFloat(currentRows.count)
        return (rows * KeyMetrics.keyHeight)
            + ((rows - 1) * KeyMetrics.rowSpacing)
            + 8  // vertical padding
    }

    private func insertCharacter(_ char: String) {
        // Play system keyboard click sound when Full Access is enabled.
        // Requires KeyboardInputView (UIInputViewAudioFeedback) to be in view hierarchy.
        if hasFullAccess {
            UIDevice.current.playInputClick()
        }

        // Track last typed character for the adaptive accent key.
        // The accent key uses this to decide whether to show apostrophe or an accent.
        lastTypedChar = char

        controller.textDocumentProxy.insertText(char)

        // Auto-unshift after one character (unless caps locked)
        if shiftState == .shifted {
            shiftState = .off
        }
    }

    private func toggleLettersNumbers() {
        if currentLayer == .letters {
            currentLayer = .numbers
        } else {
            currentLayer = .letters
            shiftState = .off
        }
    }

    private func toggleNumbersSymbols() {
        if currentLayer == .numbers {
            currentLayer = .symbols
        } else {
            currentLayer = .numbers
        }
    }
}
