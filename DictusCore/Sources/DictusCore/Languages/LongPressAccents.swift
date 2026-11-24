// DictusCore/Sources/DictusCore/Languages/LongPressAccents.swift
// Per-language long-press accent lists, as Apple's keyboard shows them (#1042).
//
// The lists are Hex's: `KeyboardLanguage.letterHolds` in
// ios/HEXShared/FullKeyboard/KeyboardLanguage.swift (github.com/anomalyco/hex, branch dev),
// which Hex observed on Apple's keyboard (iOS 27.2 simulator, every key held, the callout
// read from the accessibility tree). Hex's own key is dropped from the front of each list,
// since the popup adds it (`KeyboardView.longpressKeys`), and nothing else is changed.
// That file carries no notice of its own and Hex's THIRD_PARTY_NOTICES.md does not list it,
// so it is under Hex's root licence:
//
//   MIT License — Copyright (c) 2026 Christopher Langton
//
//   Permission is hereby granted, free of charge, to any person obtaining a copy of this
//   software and associated documentation files (the "Software"), to deal in the Software
//   without restriction, including without limitation the rights to use, copy, modify,
//   merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//   permit persons to whom the Software is furnished to do so, subject to the following
//   conditions:
//
//   The above copyright notice and this permission notice shall be included in all copies
//   or substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
//   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
//   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
//   FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//   OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//   DEALINGS IN THE SOFTWARE.
//
// The credit also appears in Settings → Licences (`LicensesView`, Hex entry).
//
// Cross-checked for #1042 against Apple's own keyboards on an iOS 26.5 simulator
// (2026-11-24, every listed key held, the callout screenshotted): French (France) AZERTY,
// Spanish (Spain), German (Germany) and English (US) offer exactly these options, in this
// order read outward from the key.
import Foundation

/// What each language's held letter keys offer, read by `LanguageProfile.longPressAccents`.
///
/// Each value lists the variants nearest the base letter first, which is the order Apple's
/// callout shows them in, read from the key outward. Every variant is one precomposed
/// character (NFC: `é` is U+00E9, not `e` plus a combining accent), except Spanish's `l·l`,
/// which Apple's Spanish keyboard offers as one option for Catalan.
///
/// WHY one table per language rather than one for all (#1042): the shared table had no œ
/// and no æ, so French could not type "cœur" by hand, and it gave every language French's
/// accents. Apple's keyboards differ per language in what they offer and in what order.
enum LongPressAccents {

    /// Apple's French (France) keyboard, AZERTY. œ on o and æ on a.
    static let french: [String: [String]] = [
        "a": ["à", "â", "æ", "á", "ä", "ã", "å", "ā", "ª"],
        "e": ["é", "è", "ê", "ë", "ę", "ė", "ē"],
        "y": ["ÿ"],
        "u": ["û", "ù", "ü", "ú", "ū"],
        "i": ["î", "ï", "ì", "í", "į", "ī"],
        "o": ["ö", "ô", "œ", "ò", "ó", "õ", "ø", "ō", "º"],
        "c": ["ç", "ć", "č"],
        "n": ["ñ", "ń"]
    ]

    /// Apple's English keyboard, QWERTY. Its callouts for e, u, i and o open on both sides
    /// of the key, so there is no single "outward" order: these follow Hex, Apple's row read
    /// from the far end on the key's right-hand side (u: ū ǔ û | ù ú ü ũ ű ů ų).
    static let english: [String: [String]] = [
        "w": ["ŵ"],
        "e": ["ë", "é", "è", "ê", "ě", "ẽ", "ē", "ė", "ę"],
        "r": ["ř"],
        "t": ["ț", "ť", "þ"],
        "y": ["ý", "ŷ", "ÿ"],
        "u": ["ū", "ǔ", "û", "ù", "ú", "ü", "ũ", "ű", "ů", "ų"],
        "i": ["ǐ", "î", "ì", "í", "ï", "ĩ", "ī", "ı", "į"],
        "o": ["ô", "ò", "ó", "ö", "ǒ", "œ", "ø", "õ", "ō", "ő"],
        "a": ["à", "á", "â", "ä", "ǎ", "æ", "ã", "å", "ā", "ă", "ą"],
        "s": ["ß", "ş", "ș", "ś", "š"],
        "d": ["ď", "ð"],
        "g": ["ğ", "ġ"],
        "h": ["ħ"],
        "k": ["ķ"],
        "l": ["ł", "ļ", "ľ"],
        "z": ["ź", "ž", "ż"],
        "c": ["ç", "ć", "č", "ċ"],
        "n": ["ñ", "ń", "ņ", "ň"]
    ]

    /// Apple's Spanish keyboard, QWERTY with a ñ key of its own: ñ is in
    /// `spanishLettersWithOwnKey`, and Dictus's QWERTY, which has no ñ key, holds it on n.
    static let spanish: [String: [String]] = [
        "e": ["é", "è", "ë", "ê", "ę", "ė", "ē"],
        "u": ["ú", "ü", "ù", "û", "ū"],
        "i": ["í", "ï", "ì", "î", "į", "ī"],
        "o": ["ö", "ó", "ò", "ô", "õ", "ø", "œ", "ō", "º"],
        "a": ["á", "à", "ä", "â", "ã", "å", "ą", "æ", "ā", "ª"],
        "s": ["š"],
        "d": ["đ"],
        "l": ["l·l"],
        "c": ["ç", "ć", "č"],
        "n": ["ń"]
    ]

    /// The letters Apple's Spanish layout has keys for.
    static let spanishLettersWithOwnKey = ["ñ"]

    /// Apple's German keyboard, QWERTZ with keys of its own for ä ö ü, which are in
    /// `germanLettersWithOwnKey`. ß is held on s, as on Apple's.
    static let german: [String: [String]] = [
        "e": ["é", "è", "ê", "ë", "ė"],
        "u": ["û", "ù", "ú", "ū"],
        "i": ["î", "ï", "í", "ī", "ì"],
        "o": ["ô", "ò", "ó", "õ", "œ", "ø", "ō"],
        "a": ["à", "á", "â", "æ", "ã", "å", "ā"],
        "s": ["ß", "ś", "š"],
        "y": ["ÿ"],
        "c": ["ç", "ć", "č"],
        "n": ["ñ", "ń"]
    ]

    /// The letters Apple's German layout has keys for.
    static let germanLettersWithOwnKey = ["ä", "ö", "ü"]
}
