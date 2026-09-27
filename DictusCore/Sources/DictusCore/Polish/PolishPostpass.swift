// DictusCore/Sources/DictusCore/Polish/PolishPostpass.swift
import Foundation

/// Code-level corrections applied AFTER the polish engine returns.
///
/// Round 4 round-1 testing showed Apple Foundation Models has two
/// behavioural floors we cannot prompt-tune past:
///
/// 1. Raw `\n` characters in the input get "naturalised" into `, ` + capital
///    on output. The model interprets a newline as a sentence-boundary cue
///    and rewrites the boundary in prose form, no matter how the prompt
///    spells out "preserve newlines".
///
/// 2. The model never inserts the U+00A0 NO-BREAK SPACE before `?`, `!`,
///    `;`, `:` even when the rule line says so and the examples literally
///    contain NBSP bytes. ASCII space and NBSP are indistinguishable to
///    its sampling.
///
/// Both are deterministic transformations — handling them in code is more
/// reliable than coaxing the model. The pre-engine `encodeForEngine` step
/// hides newlines behind a multi-char ASCII marker that survives the
/// round-trip; the post-engine `decodeFromEngine` step restores the
/// newlines and applies the French typographic spacing.
public enum PolishPostpass {

    /// String the engine sees in place of `\n`. Apple FM treats this as
    /// opaque text and passes it through unaltered (round-1 testing).
    /// The marker is intentionally verbose so user speech won't accidentally
    /// transcribe to the same bytes.
    public static let newlineMarker = "<<NL>>"

    /// Encode `\n` characters as the engine-safe marker. Run on the pre-pass
    /// output before handing the string to Apple FM.
    public static func encodeForEngine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: newlineMarker)
    }

    /// Language-agnostic half of the decode: restores newlines from markers
    /// and collapses stray blank lines. This is the ONLY post-pass applied in
    /// Auto-detect mode (#239) — the language typography below is per-language
    /// and would mangle unknown scripts (e.g. CJK full-width punctuation).
    public static func decodeNewlines(_ polished: String) -> String {
        var out = polished

        // Every rule below is written for LF. Nothing upstream normalises a CRLF or
        // a lone CR, so without this line `a\r\n\r\n\r\nb` would walk past both the
        // trim and the cap and reach the field as three breaks.
        out = out.replacingOccurrences(of: "\r\n", with: "\n")
        out = out.replacingOccurrences(of: "\r", with: "\n")

        // A DICTATED break is exactly one line break, and it absorbs whatever the
        // model stacked around it. "retour à la ligne" encodes to exactly one
        // marker, but the model adds its OWN breaks around the marker when the text
        // looks structured (a meeting recap, an enumeration), so after a naive
        // decode those stack into `\n\n\n\n`. The marker wins: the user asked for
        // one break and gets one.
        let marker = NSRegularExpression.escapedPattern(for: newlineMarker)
        out = out.replacingOccurrences(
            of: "[ \t\n]*(?:" + marker + "[ \t\n]*)+",
            with: "\n",
            options: [.regularExpression]
        )

        // A MODEL-EMITTED break survives with its shape (#523). Trim the spaces
        // hugging every break, then cap a run at one blank line.
        //
        // This distinction used to be dropped — every run, dictated or not,
        // collapsed to a single `\n` — on the ground that "the model mangles blank
        // lines unreliably anyway". #523 measured what that costs: the Structured
        // mode's user turn asks for paragraphs "separated by a blank line", the
        // engine's output was the only place a blank line could exist, and this
        // function erased it before the guardrail, the log or the text field ever
        // saw it. Nothing downstream could tell a paragraph break from a line break
        // because nothing downstream was ever shown one.
        out = out.replacingOccurrences(
            of: #"[ \t]*\n[ \t]*"#,
            with: "\n",
            options: [.regularExpression]
        )
        out = out.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: [.regularExpression]
        )
        return out
    }

    /// Drops every trailing line made only of a layout mark — a code fence
    /// (```` ``` ````), a rule (`---`, `***`), a lone dash, an ellipsis — and the blank
    /// lines before them (#587).
    ///
    /// The short `Structuré` prompt closed 18 of 354 Mac outputs on such a line, and
    /// every one of the 18 was accepted: the guardrails judge words, and a fence
    /// carries none, so nothing refused it. It is the model closing a block it thinks
    /// it opened, not something the speaker said — nobody dictates three backticks.
    ///
    /// **It can never remove a word.** A line goes only when, trimmed, it is exactly
    /// one of those two tokens, and only while it is the last line: a fence or a rule
    /// anywhere else, or one sharing its line with any other character, is left alone.
    /// The tokens a trailing line may consist of and be dropped.
    ///
    /// The fence and the rule came from round 1 of #587; the lone dash and the ellipsis
    /// from round 2, where a Swedish output ended on three `-` lines and a Korean one on
    /// `...`, both accepted. Every one of them is a layout mark the model closed on, and
    /// none of them is a word: a line that carries anything else keeps them.
    private static let trailingArtefacts: Set<String> = ["```", "---", "-", "...", "…", "***"]

    public static func stripTrailingFenceLines(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        var stripped = false
        while let last = lines.last {
            let trimmed = last.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty, stripped || lines.count > 1 {
                lines.removeLast()
            } else if trailingArtefacts.contains(trimmed) {
                lines.removeLast()
                stripped = true
            } else {
                break
            }
        }
        return stripped ? lines.joined(separator: "\n") : text
    }

    /// Blank lines become single line breaks when `text` is shorter than `limit`
    /// characters (#572). Longer text is returned untouched.
    ///
    /// Only runs of blank lines are touched: a single line break is already the
    /// layout wanted, and every other character — punctuation included — is kept, so
    /// this can never change what the text says. See
    /// `SmartModePrompt.shortOutputBlockLimit` for why it exists and why it is not a
    /// prompt rule.
    public static func tightenBlocks(_ text: String, whenShorterThan limit: Int) -> String {
        guard text.count < limit else { return text }
        return text.replacingOccurrences(
            of: #"\n[ \t]*(?:\n[ \t]*)+"#, with: "\n", options: [.regularExpression]
        )
    }

    /// Run on the engine's output. Restores newlines from markers and
    /// applies language-specific typography Apple FM is unreliable about.
    public static func decodeFromEngine(_ polished: String,
                                        language: SupportedLanguage) -> String {
        var out = decodeNewlines(polished)

        switch language {
        case .french:
            // NBSP before ? ! ; :. Pattern matches ONE ASCII space (U+0020)
            // immediately preceding the mark; any existing NBSP (U+00A0)
            // stays untouched. `[ ]` is the literal space character class
            // — avoids `\s` which would also match `\n` and `\t`.
            out = out.replacingOccurrences(
                of: #"[ ]([?!;:])"#,
                with: "\u{00A0}$1",
                options: [.regularExpression]
            )
            // Restore the accent on a sentence-initial capital `A` — Apple FM
            // drops accents on capitals just like it drops the NBSP. Narrow on
            // purpose: a standalone `A` at a sentence start (string start, after
            // a newline, or after `. ! ? :`) followed by a lowercase word is
            // almost always the preposition `À` (À très vite / bientôt / plus
            // tard). If the next word is uppercase (acronym, proper noun) or it
            // is `A.` (abbreviation), the pattern does not match and we leave it.
            out = out.replacingOccurrences(
                of: #"(^|\n|[.!?:]\s+)A(\s+\p{Ll})"#,
                with: "$1À$2",
                options: [.regularExpression]
            )
        case .english, .spanish, .german:
            break
        }
        return out
    }
}
