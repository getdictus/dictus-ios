// DictusCore/Sources/DictusCore/Polish/SmartModeListCheck.swift
// Whether a list mode's output is a list worth inserting (#573, decision 5 amended).
import Foundation

/// The output check behind `SmartMode.minimumListItems`, and the time rule for what
/// replaces a declined output.
///
/// ### What it declines, and only that
///
/// `Liste` always runs, and a list of **one** item is a title over a lone dash-line,
/// the defect #573 names. That single case is declined: the dictation gets Normal polish
/// and the "Trop court pour une liste" notice.
///
/// Everything else keeps the path it had before the check existed, because the code
/// review of PR #629 found two ways the first version said "too short" when nothing was
/// too short:
///
/// - **No list at all.** A fallback engine returns the transcript unchanged, and a model
///   can answer in paragraphs. Neither holds a single list line, and neither is a
///   dictation too short for a list: telling a user who spoke 400 characters that it was
///   is false. Zero items is inserted as it came, exactly as before #573's check.
/// - **Another bullet style.** `•`, `*`, `–`, `1.` and `1)` are list lines too. They are
///   counted, and rewritten to `- `, the shape the prompt asks for and the one every
///   example shows, so a list reaches the document in one style whichever the model used.
///
/// A non-model engine (`announcesProcessingStage == false`, the passthrough) is never
/// judged at all: its output is not a list attempt.
public enum SmartModeListCheck {

    /// What the check decided about one output.
    public enum Verdict: Equatable, Sendable {
        /// Insert this text. It is the output with its list markers normalised to `- `,
        /// or the output untouched when the check does not apply.
        case accept(String)
        /// The model returned `items` list lines, fewer than the mode's `minimum` and at
        /// least one: a genuine one-item list.
        case decline(items: Int, minimum: Int)
    }

    /// Judge `output` for `mode`. `engineIsModel` is false for an engine that does not
    /// generate (the passthrough), whose output is never judged.
    public static func evaluate(_ output: String, mode: SmartMode, engineIsModel: Bool) -> Verdict {
        guard let minimum = mode.minimumListItems, engineIsModel else { return .accept(output) }
        let normalised = normalisingListMarkers(output)
        let items = listItemCount(in: normalised)
        if items >= minimum { return .accept(normalised) }
        if items >= 1 { return .decline(items: items, minimum: minimum) }
        return .accept(output)
    }

    /// `- ` lines in `text`, after any leading spaces.
    public static func listItemCount(in text: String) -> Int {
        text.split(separator: "\n", omittingEmptySubsequences: false).count { line in
            line.drop { $0 == " " || $0 == "\t" }.hasPrefix("- ")
        }
    }

    /// `text` with every line opening on `•`, `*`, `–`, `—`, `1.` or `1)` (after
    /// optional indentation, followed by a space) rewritten to open on `- `. A hyphen
    /// or a number inside a line is left alone.
    public static func normalisingListMarkers(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let string = String(line)
            guard let range = string.range(of: #"^\s*(?:[•*–—]|\d{1,2}[.)])\s+"#, options: .regularExpression)
            else { return string }
            return "- " + string[range.upperBound...]
        }.joined(separator: "\n")
    }

    // MARK: - The second call (PR #629 review, finding 1)

    /// Worst per-character cost measured on device, in seconds: the 391-character
    /// dictation of 2026-08-23 that took 12,002 ms (`PolishTimeBudget`'s table).
    static let expectedSecondsPerCharacter: TimeInterval = 0.031

    /// Head-room kept under the ceiling for the post-pass and the insertion.
    static let safetyMargin: TimeInterval = 2

    /// Whether a Normal polish of `characters` can still finish before the keyboard's
    /// stage watchdog, `elapsed` seconds after the dictation's polish began.
    ///
    /// The watchdog (`PolishTimeBudget.generationCeiling`) is sized for **one** model
    /// call, and it starts when the keyboard hands the dictation to `PolishService`. A
    /// declined `Liste` output has already spent part of it, and a Normal polish that
    /// overruns makes the keyboard declare polish stuck and close the overlay, which
    /// loses the dictation. So the second call runs only when its worst measured cost
    /// fits in what is left; otherwise the caller inserts the deterministic floor, the
    /// punctuated transcript. Less polish beats lost text.
    public static func secondCallFits(elapsed: TimeInterval, characters: Int) -> Bool {
        let expected = Double(max(0, characters)) * expectedSecondsPerCharacter
        let ceiling = PolishTimeBudget.generationCeiling(forCharacters: characters)
        return elapsed + expected + safetyMargin <= ceiling
    }
}
