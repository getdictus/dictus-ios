// DictusKeyboard/Views/KeyboardView.swift
import SwiftUI
import DictusCore

/// The main keyboard view composing all rows and managing layer/shift state.
struct KeyboardView: View {
    let controller: UIInputViewController
    let hasFullAccess: Bool

    @State private var currentLayer: KeyboardLayerType = .letters
    @State private var shiftState: ShiftState = .off

    private var isShifted: Bool {
        shiftState == .shifted || shiftState == .capsLocked
    }

    private var currentRows: [[KeyDefinition]] {
        switch currentLayer {
        case .letters: return KeyboardLayout.lettersRows
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
                            controller.textDocumentProxy.deleteBackward()
                        },
                        onGlobe: {
                            controller.advanceToNextInputMode()
                        },
                        onLayerSwitch: {
                            toggleLettersNumbers()
                        },
                        onSymbolToggle: {
                            toggleNumbersSymbols()
                        },
                        onSpace: {
                            controller.textDocumentProxy.insertText(" ")
                        },
                        onReturn: {
                            controller.textDocumentProxy.insertText("\n")
                        },
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

/// Mic key — shows Link when Full Access is on, disabled button otherwise.
struct MicKey: View {
    let width: CGFloat
    let hasFullAccess: Bool

    var body: some View {
        if hasFullAccess {
            // Link destination requires non-nil URL — safe to force-unwrap
            // a compile-time literal that is always a valid URL
            Link(destination: URL(string: "dictus://dictate")!) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: width)
                    .frame(height: KeyMetrics.keyHeight)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.blue)
                    )
            }
        } else {
            Image(systemName: "mic.fill")
                .font(.system(size: 18, weight: .medium))
                .frame(width: width)
                .frame(height: KeyMetrics.keyHeight)
                .foregroundColor(Color(.systemGray2))
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.systemGray4))
                )
        }
    }
}
