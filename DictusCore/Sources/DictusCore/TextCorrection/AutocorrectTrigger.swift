// DictusCore/Sources/DictusCore/TextCorrection/AutocorrectTrigger.swift
// Which keys end a word for autocorrect (#872).
import Foundation

/// The characters that commit the word before the cursor, besides the space.
///
/// Apple's French keyboard corrects `cuisinr,` into `cuisine,` and `bureai` + Return
/// into `bureau`. Until #872 Dictus corrected on space only, and the space after the
/// comma found a context ending in `,` and gave up (`suffix-mismatch`).
///
/// The apostrophe and the hyphen are deliberately absent: they sit inside words
/// (`l'`, `aujourd'hui`, `peut-être`), and correcting before them would rewrite half
/// a word.
public enum AutocorrectTrigger {

    /// Punctuation that ends a word, and the return key's newline.
    public static let committingCharacters: Set<String> = [",", ".", ";", ":", "!", "?", "\n"]

    /// Whether inserting `character` commits the word before the cursor.
    public static func commitsWord(_ character: String) -> Bool {
        committingCharacters.contains(character)
    }
}
