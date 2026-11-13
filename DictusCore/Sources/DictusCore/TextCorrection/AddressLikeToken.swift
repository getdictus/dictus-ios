// DictusCore/Sources/DictusCore/TextCorrection/AddressLikeToken.swift
// A word inside an e-mail address or a URL is never autocorrected (#919).
import Foundation

/// Whether the text at the cursor is an e-mail address or a URL rather than prose.
///
/// A field can declare itself an address field through its traits (`HostFieldPolicy`,
/// #200), but a chat box or a note does not. Since #872 a full stop corrects the word
/// before it, so `helene.bethmont@gmail.com` typed there came out
/// `Hélène.bethmont@Gmail.com`. Same rule as getdictus/dictus-android#333.
public enum AddressLikeToken {

    /// Marks that join the parts of an address.
    static let separators: Set<Character> = [".", ":", "/", "_"]

    /// Symbols that continue an address when glued after a separator, besides
    /// letters and digits: `https:/`, `helene.+tag@`, `john._doe`.
    private static let continuingSymbols: Set<Character> = ["/", "_", "@", "+", "-"]

    /// Whether `token`, a run of text without whitespace, reads as an address: it
    /// holds `@` or `://`, starts with `www.`, or has a separator with a letter, a
    /// digit or a continuing symbol glued after it. `Bonjour.`, `etc.,`, `M.` and
    /// `Bonjour...` do not.
    public static func matches(_ token: String) -> Bool {
        if token.contains("@") || token.contains("://") || token.lowercased().hasPrefix("www.") {
            return true
        }
        return zip(token, token.dropFirst()).contains { separators.contains($0) && continuesAddress($1) }
    }

    /// Whether the token the cursor ends, followed by `next`, reads as an address.
    /// `next` is the key about to be typed: `www` followed by `.` already is one.
    public static func atCursor(_ context: String, followedBy next: String = "") -> Bool {
        let start = context.lastIndex(where: \.isWhitespace).map(context.index(after:)) ?? context.startIndex
        return matches(String(context[start...]) + next)
    }

    /// Whether `character`, typed right after a separator, continues an address.
    static func continuesAddress(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || continuingSymbols.contains(character)
    }
}
