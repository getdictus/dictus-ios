// DictusKeyboard/FrenchKeyboardLayouts.swift
// French AZERTY and QWERTY layout definitions in giellakbd-ios KeyboardDefinition format.
// Created for Phase 18 Plan 01 -- matches iOS stock French keyboard key positions.
// Long-press accents will be added in Phase 19.

import UIKit
import DictusCore

/// Constructs KeyboardDefinition objects for French AZERTY and QWERTY layouts.
///
/// These layouts are built programmatically (not from JSON) using the same KeyDefinition
/// types as the vendored giellakbd-ios codebase. Each layout includes 5 pages:
/// normal, shifted, capslock (same visual as shifted), symbols1 (numbers), symbols2 (symbols).
///
/// Bottom row on letter pages: [123] [emoji] [space] [return] -- emoji key added in Phase 20.
/// Globe key is provided by iOS below third-party keyboards -- not part of our layout.
enum FrenchKeyboardLayouts {

    // MARK: - Public API

    /// French AZERTY layout matching iOS stock keyboard.
    static func azerty() -> KeyboardDefinition {
        return KeyboardDefinition(
            name: "Fran\u{00E7}ais",
            locale: "fr",
            spaceName: "espace",
            returnName: "retour",
            longPress: frenchLongPress,
            layout: KeyboardDefinition.Layout(
                normal: azertyNormal,
                shifted: azertyShifted,
                symbols1: numbersPage,
                symbols2: symbolsPage
            )
        )
    }

    /// French QWERTY layout for users who prefer QWERTY.
    static func qwerty() -> KeyboardDefinition {
        return KeyboardDefinition(
            name: "Fran\u{00E7}ais (QWERTY)",
            locale: "fr",
            spaceName: "espace",
            returnName: "retour",
            longPress: frenchLongPress,
            layout: KeyboardDefinition.Layout(
                normal: qwertyNormal,
                shifted: qwertyShifted,
                symbols1: numbersPage,
                symbols2: symbolsPage
            )
        )
    }

    /// Returns the layout matching the user's App Group preference.
    static func current() -> KeyboardDefinition {
        switch LayoutType.active {
        case .azerty: return azerty()
        case .qwerty: return qwerty()
        }
    }

    // MARK: - AZERTY Letter Pages

    private static let azertyNormal: [[KeyDefinition]] = [
        // Row 1: 10 keys
        inputRow("a", "z", "e", "r", "t", "y", "u", "i", "o", "p"),
        // Row 2: 10 keys
        inputRow("q", "s", "d", "f", "g", "h", "j", "k", "l", "m"),
        // Row 3: shift + 6 letters + accent key + delete = 9 items (10 units)
        [
            KeyDefinition(type: .shift, size: CGSize(width: 1.5, height: 1)),
            key("w"), key("x"), key("c"), key("v"), key("b"), key("n"),
            KeyDefinition(type: .input(key: "'", alternate: "accent")),
            KeyDefinition(type: .backspace, size: CGSize(width: 1.5, height: 1)),
        ],
        // Row 4: 123 + emoji + space + return
        lettersBottomRow,
    ]

    private static let azertyShifted: [[KeyDefinition]] = [
        // Row 1: uppercase
        inputRow("A", "Z", "E", "R", "T", "Y", "U", "I", "O", "P"),
        // Row 2: uppercase
        inputRow("Q", "S", "D", "F", "G", "H", "J", "K", "L", "M"),
        // Row 3: shift (filled state handled by KeyView) + uppercase letters + accent key + delete
        [
            KeyDefinition(type: .shift, size: CGSize(width: 1.5, height: 1)),
            key("W"), key("X"), key("C"), key("V"), key("B"), key("N"),
            KeyDefinition(type: .input(key: "'", alternate: "accent")),
            KeyDefinition(type: .backspace, size: CGSize(width: 1.5, height: 1)),
        ],
        // Row 4: same as normal
        lettersBottomRow,
    ]

    // MARK: - QWERTY Letter Pages

    private static let qwertyNormal: [[KeyDefinition]] = [
        // Row 1: 10 keys = 10 units
        inputRow("q", "w", "e", "r", "t", "y", "u", "i", "o", "p"),
        // Row 2: 9 keys with side spacers = 10 units (matches Apple QWERTY centering)
        [
            KeyDefinition(type: .spacer, size: CGSize(width: 0.5, height: 1)),
            key("a"), key("s"), key("d"), key("f"), key("g"), key("h"), key("j"), key("k"), key("l"),
            KeyDefinition(type: .spacer, size: CGSize(width: 0.5, height: 1)),
        ],
        // Row 3: shift + 7 letters + delete = 10 units
        [
            KeyDefinition(type: .shift, size: CGSize(width: 1.5, height: 1)),
            key("z"), key("x"), key("c"), key("v"), key("b"), key("n"), key("m"),
            KeyDefinition(type: .backspace, size: CGSize(width: 1.5, height: 1)),
        ],
        // Row 4: 123 + space + return
        lettersBottomRow,
    ]

    private static let qwertyShifted: [[KeyDefinition]] = [
        inputRow("Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"),
        [
            KeyDefinition(type: .spacer, size: CGSize(width: 0.5, height: 1)),
            key("A"), key("S"), key("D"), key("F"), key("G"), key("H"), key("J"), key("K"), key("L"),
            KeyDefinition(type: .spacer, size: CGSize(width: 0.5, height: 1)),
        ],
        [
            KeyDefinition(type: .shift, size: CGSize(width: 1.5, height: 1)),
            key("Z"), key("X"), key("C"), key("V"), key("B"), key("N"), key("M"),
            KeyDefinition(type: .backspace, size: CGSize(width: 1.5, height: 1)),
        ],
        lettersBottomRow,
    ]

    // MARK: - Numbers Page (symbols1)

    private static let numbersPage: [[KeyDefinition]] = [
        // Row 1: digits
        inputRow("1", "2", "3", "4", "5", "6", "7", "8", "9", "0"),
        // Row 2: common punctuation and symbols
        inputRow("-", "/", ":", ";", "(", ")", "\u{20AC}", "&", "@", "\""),
        // Row 3: #+= toggle + punctuation + delete
        [
            KeyDefinition(type: .shiftSymbols, size: CGSize(width: 1.5, height: 1)),
            key("."), key(","), key("?"), key("!"), key("'"),
            KeyDefinition(type: .backspace, size: CGSize(width: 1.5, height: 1)),
        ],
        // Row 4: ABC + space + return
        symbolsBottomRow,
    ]

    // MARK: - Symbols Page (symbols2)

    private static let symbolsPage: [[KeyDefinition]] = [
        // Row 1: brackets and math
        inputRow("[", "]", "{", "}", "#", "%", "^", "*", "+", "="),
        // Row 2: special characters
        inputRow("_", "\\", "|", "~", "<", ">", "$", "\u{00A3}", "\u{00A5}", "\u{00B7}"),
        // Row 3: 123 toggle + punctuation + delete
        [
            KeyDefinition(type: .shiftSymbols, size: CGSize(width: 1.5, height: 1)),
            key("."), key(","), key("?"), key("!"), key("'"),
            KeyDefinition(type: .backspace, size: CGSize(width: 1.5, height: 1)),
        ],
        // Row 4: ABC + space + return
        symbolsBottomRow,
    ]

    // MARK: - Bottom Rows

    /// Letters page bottom row: [123 2.0w] [emoji 1.5w] [space 4.5w] [return 2.0w]
    /// Note: symbols key uses .symbols type which shows "123" on letter pages and "ABC" on symbol pages.
    private static let lettersBottomRow: [KeyDefinition] = [
        KeyDefinition(type: .symbols, size: CGSize(width: 2.0, height: 1)),
        KeyDefinition(type: .input(key: "\u{1F600}", alternate: nil), size: CGSize(width: 1.5, height: 1)),
        KeyDefinition(type: .spacebar(name: "espace"), size: CGSize(width: 4.5, height: 1)),
        KeyDefinition(type: .returnkey(name: "retour"), size: CGSize(width: 2.0, height: 1)),
    ]

    /// Symbols page bottom row: [ABC 1.2w] [space 4.7w] [return 1.8w]
    private static let symbolsBottomRow: [KeyDefinition] = [
        KeyDefinition(type: .symbols, size: CGSize(width: 2.5, height: 1)),
        KeyDefinition(type: .spacebar(name: "espace"), size: CGSize(width: 5.0, height: 1)),
        KeyDefinition(type: .returnkey(name: "retour"), size: CGSize(width: 2.5, height: 1)),
    ]

    // MARK: - French Long Press Accents (Phase 19 will populate fully)

    /// Long-press accent data for French keys.
    /// Phase 18 provides empty data -- Phase 19 will add accent variants.
    private static let frenchLongPress: [String: [String]] = {
        var longPress: [String: [String]] = [:]
        for (baseKey, accents) in AccentedCharacters.mappings {
            longPress[baseKey] = accents
        }
        return longPress
    }()

    // MARK: - Helper Functions

    /// Create a standard 1x1 input key.
    private static func key(_ char: String) -> KeyDefinition {
        KeyDefinition(type: .input(key: char, alternate: nil))
    }

    /// Create a row of standard input keys from variadic strings.
    private static func inputRow(_ keys: String...) -> [KeyDefinition] {
        keys.map { KeyDefinition(type: .input(key: $0, alternate: nil)) }
    }
}
