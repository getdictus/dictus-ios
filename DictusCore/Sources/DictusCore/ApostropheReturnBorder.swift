// DictusCore/Sources/DictusCore/ApostropheReturnBorder.swift
// Who takes a tap at the border between the AZERTY apostrophe key and Return (#1080).
import CoreGraphics

/// On the French AZERTY page the apostrophe key sits right above the left end of Return.
/// A thumb aiming at the apostrophe after « c » lands a few points low and types a newline:
/// Pierre's device session of 2026-11-26 (build 2.1.0 (45), `TJ TAP` #69 and #74) wrote
/// « C⏎Est » twice. Spatial correction and adaptive touch only read letters, so nothing
/// caught it.
///
/// The rule: a touch the plain hit test gives to Return goes to the apostrophe when
/// - it lies under the apostrophe key's column,
/// - in the top `reach` row pitches of Return's target (its half of the gap between the rows
///   and the top of its keycap),
/// - and the word just before the cursor is one French elides before a vowel (`c`, `d`, `j`,
///   `l`, `m`, `n`, `s`, `t`, `qu` and the words ending in it: `jusqu`, `lorsqu`, `puisqu`),
///   in any case.
///
/// WHY a rule that reads the text, and not a smaller Return: Apple's French AZERTY on the
/// iOS 26.5 simulator types Return at both of Pierre's points, after « C » as after
/// « Bonjour ». Its key frames there split the gap between the rows down the middle, as
/// Dictus's do (`KeyPlaneGeometry`), so moving the border for every word would make Dictus
/// swallow Returns Apple types. After a lone « c » or « l », a newline is almost never what
/// was meant and the apostrophe almost always is, so only there does the border move.
/// Hex (anomalyco/hex, `KeyboardLayout.buildKeys`, MIT) also splits that gap down the middle
/// and moves taps only between letters (`FullKeyboardEngine.key(at:)`), so it has no rule to
/// reuse here.
public enum ApostropheReturnBorder {
    /// How far down Return's target the apostrophe reaches, in row pitches from the border:
    /// Return's half of the gap (5.5 pt on an iPhone 17) and the top 8 pt of its keycap.
    /// Pierre's taps were 0.04 and 0.08 below the border; Return's keycap centre is 0.5.
    public static let reach: CGFloat = 0.25

    /// The words French writes with an elided vowel, lowercased.
    static let elidingWords: Set<String> = ["c", "d", "j", "l", "m", "n", "s", "t", "qu"]

    /// Whether the word right before the cursor is one French elides (`c`, `qu`, `jusqu`...),
    /// so an apostrophe is what comes next. The word is the run of letters ending at the cursor,
    /// preceded by the start of the text or by a non-letter.
    public static func expectsApostrophe(after textBeforeCursor: String) -> Bool {
        let word = textBeforeCursor.reversed().prefix { $0.isLetter }
        guard !word.isEmpty, word.count <= 7 else { return false }
        let lowered = String(word.reversed()).lowercased()
        return elidingWords.contains(lowered) || lowered.hasSuffix("qu")
    }

    /// Whether a touch the plain hit test gave to Return is the apostrophe's.
    ///
    /// - Parameters:
    ///   - point: the touch, in the grid's coordinates (as the hit test reads it).
    ///   - apostrophe: the apostrophe key's touch target, in the row above Return's.
    ///   - returnKey: Return's touch target.
    ///   - rowPitch: from one row of keycaps to the next.
    ///   - textBeforeCursor: read only when the point is in the band, so a tap anywhere else
    ///     costs no text read.
    public static func takesApostrophe(
        _ point: CGPoint,
        apostrophe: CGRect,
        returnKey: CGRect,
        rowPitch: CGFloat,
        textBeforeCursor: () -> String
    ) -> Bool {
        guard rowPitch > 0, returnKey.contains(point),
              point.x >= apostrophe.minX, point.x < apostrophe.maxX,
              point.y < returnKey.minY + reach * rowPitch else { return false }
        return expectsApostrophe(after: textBeforeCursor())
    }
}
