// DictusKeyboard/Models/KeyboardLayout.swift
import Foundation

/// Defines the complete AZERTY keyboard layout matching iOS native French keyboard.
enum KeyboardLayout {

    // MARK: - Letters layer (lowercase shown; shift applies uppercasing)

    static let lettersRows: [[KeyDefinition]] = [
        // Row 1: top letter row
        ["A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"].map {
            KeyDefinition($0, output: $0.lowercased())
        },
        // Row 2: home row
        ["Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"].map {
            KeyDefinition($0, output: $0.lowercased())
        },
        // Row 3: bottom letter row with shift and delete
        [
            KeyDefinition("shift", type: .shift, width: 1.5),
            KeyDefinition("W", output: "w"),
            KeyDefinition("X", output: "x"),
            KeyDefinition("C", output: "c"),
            KeyDefinition("V", output: "v"),
            KeyDefinition("B", output: "b"),
            KeyDefinition("N", output: "n"),
            KeyDefinition("delete", type: .delete, width: 1.5),
        ],
        // Row 4: bottom function row
        [
            KeyDefinition("globe", type: .globe, width: 1.2),
            KeyDefinition("123", type: .layerSwitch, width: 1.2),
            KeyDefinition("mic", type: .mic, width: 1.0),
            KeyDefinition("space", output: " ", type: .space, width: 3.5),
            KeyDefinition("return", type: .returnKey, width: 1.8),
        ],
    ]

    // MARK: - Numbers layer
    // Note: Mic key is intentionally absent from numbers/symbols layers,
    // matching native iOS behavior where the mic is letters-layer only.

    static let numbersRows: [[KeyDefinition]] = [
        // Row 1: numbers
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"].map {
            KeyDefinition($0)
        },
        // Row 2: common symbols
        ["-", "/", ":", ";", "(", ")", "€", "&", "@", "\""].map {
            KeyDefinition($0)
        },
        // Row 3: more symbols + toggle + delete
        [
            KeyDefinition("#+=", type: .symbolToggle, width: 1.5),
            KeyDefinition(".", output: "."),
            KeyDefinition(",", output: ","),
            KeyDefinition("?", output: "?"),
            KeyDefinition("!", output: "!"),
            KeyDefinition("'", output: "'"),
            KeyDefinition("delete", type: .delete, width: 1.5),
        ],
        // Row 4: back to letters + space + return (no mic — letters only)
        [
            KeyDefinition("ABC", type: .layerSwitch, width: 1.2),
            KeyDefinition("globe", type: .globe, width: 1.2),
            KeyDefinition("space", output: " ", type: .space, width: 4.7),
            KeyDefinition("return", type: .returnKey, width: 1.8),
        ],
    ]

    // MARK: - Symbols layer (accessed via #+= on numbers layer)

    static let symbolsRows: [[KeyDefinition]] = [
        // Row 1: brackets and math
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="].map {
            KeyDefinition($0)
        },
        // Row 2: special characters
        ["_", "\\", "|", "~", "<", ">", "$", "£", "¥", "·"].map {
            KeyDefinition($0)
        },
        // Row 3: toggle back + more + delete
        [
            KeyDefinition("123", type: .symbolToggle, width: 1.5),
            KeyDefinition(".", output: "."),
            KeyDefinition(",", output: ","),
            KeyDefinition("?", output: "?"),
            KeyDefinition("!", output: "!"),
            KeyDefinition("'", output: "'"),
            KeyDefinition("delete", type: .delete, width: 1.5),
        ],
        // Row 4: same as numbers
        [
            KeyDefinition("ABC", type: .layerSwitch, width: 1.2),
            KeyDefinition("globe", type: .globe, width: 1.2),
            KeyDefinition("space", output: " ", type: .space, width: 4.7),
            KeyDefinition("return", type: .returnKey, width: 1.8),
        ],
    ]
}
