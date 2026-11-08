// DictusCore/Sources/PolishFidelity/PolishSummaryShape.swift
// The bars of the Résumé bench, as deterministic scorers (#571).
import Foundation
import NaturalLanguage

/// What one `Summary` output looks like against the bars declared in
/// `docs/research/571-summary/bars.md` before the first model call.
///
/// Every field is a **flag for a reader**, not a verdict on its own: the person and
/// fabrication checks are lexical, and a lexical check on fifteen languages is a
/// sieve. What they buy is that a human reads the flagged runs rather than all of
/// them, and that the unflagged majority is counted the same way every time.
public struct PolishSummaryShapeScore: Equatable, Sendable {
    /// `NLLanguageRecognizer`'s dominant language for the output, `nil` on an empty one.
    public let outputLanguage: String?
    /// Whether that language is the expected one, compared on the base code so that
    /// `zh-Hans` reads as `zh`.
    public let languageMatches: Bool
    /// Lines that are a bullet, a dash, a numbered item or a heading. Bar B is zero.
    public let listLines: Int
    /// Output characters over input characters, the guardrail's own ratio.
    public let ratio: Double
    /// A report-framing term (`the speaker`, `le locuteur`, …) absent from the input.
    public let reportFraming: [String]
    /// The output opens on a bare infinitive task, which is `List`'s shape. FR and EN.
    public let opensOnInfinitive: Bool
    /// The input speaks in the first person and the output never does. FR and EN;
    /// `false` wherever the check cannot run.
    public let firstPersonLost: Bool
    /// The output switches the speaker to a collective obligation they never used —
    /// `nous devons`, `we must` — where the input said `on`/`je`/`I` (#571 round 2,
    /// device: `j'aimerais qu'on fasse un point` → `Nous devons aborder`). FR and EN.
    public let collectiveSwitch: Bool
    /// The output opens on a preamble or a label (`Voici`, `In short`, `Summary:`).
    public let preamble: Bool
    /// Content of the prompt's own worked examples, absent from the input (#414).
    public let exampleContent: [String]
    /// Digit runs in the output that appear nowhere in the input. For a hand read:
    /// `six` spoken and `6` written is a legitimate conversion this cannot see.
    public let novelFigures: [String]
}

public enum PolishSummaryShape {

    /// Distinctive content of `SmartModeSummaryPrompt.defaultExamples`. Kept here
    /// rather than read off the prompt so that the scorer does not move when a
    /// candidate prompt does; a new example set means a new list, deliberately.
    public static let exampleMarkers = [
        "garagiste", "plaquettes", "grincement", "autoroute",
        "cupboard", "near the station", "sleep on it", "lower rent"
    ]

    /// Third-person report framings, per language, lowercased. A sieve, not a
    /// grammar: it catches the minute-taker's voice the genre prior pulls in.
    static let reportFramings: [String: [String]] = [
        "fr": ["le locuteur", "la locutrice", "l'orateur", "l'intervenant", "il explique", "elle explique",
               "l'auteur", "la personne", "il indique", "elle indique"],
        "en": ["the speaker", "the user", "the narrator", "the author", "he says", "she says",
               "he explains", "she explains", "the person"],
        "de": ["der sprecher", "die sprecherin", "der redner", "die person"],
        "es": ["el hablante", "el orador", "la persona"],
        "it": ["il parlante", "l'oratore", "chi parla", "la persona"],
        "pt": ["o falante", "o orador", "a pessoa"],
        "nl": ["de spreker", "de persoon"],
        "da": ["taleren", "personen"],
        "nb": ["taleren", "personen"],
        "sv": ["talaren", "personen"],
        "tr": ["konuşmacı"],
        "vi": ["người nói"],
        "zh": ["说话者", "讲话者", "说话人"],
        "ja": ["話者", "話し手"],
        "ko": ["화자", "말하는 사람"]
    ]

    static let preambles = [
        "voici", "here is", "here's", "en résumé", "en bref", "in short", "in summary",
        "summary", "résumé", "to summarize", "to summarise", "pour résumer", "en somme"
    ]

    public static func score(output: String, input: String, expectedLanguage: String) -> PolishSummaryShapeScore {
        let base = baseCode(expectedLanguage)
        let language = dominantLanguage(of: output)
        let lines = output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        let listLines = lines.filter(isListLine).count
        let loweredOutput = output.lowercased()
        let loweredInput = input.lowercased()
        let framing = (reportFramings[base] ?? []).filter {
            loweredOutput.contains($0) && !loweredInput.contains($0)
        }
        let examples = exampleMarkers.filter { loweredOutput.contains($0) && !loweredInput.contains($0) }
        let inputDigits = Set(digitRuns(in: input))
        let figures = digitRuns(in: output).filter { !inputDigits.contains($0) }
        return PolishSummaryShapeScore(
            outputLanguage: language,
            languageMatches: language.map(baseCode) == base,
            listLines: listLines,
            ratio: input.isEmpty ? 0 : Double(output.count) / Double(input.count),
            reportFraming: framing,
            opensOnInfinitive: opensOnInfinitive(output, language: base),
            firstPersonLost: firstPersonLost(output: output, input: input, language: base),
            collectiveSwitch: collectiveSwitch(output: output, input: input, language: base),
            preamble: opensOnPreamble(loweredOutput, firstLine: lines.first),
            exampleContent: examples,
            novelFigures: figures
        )
    }

    // MARK: - The parts

    /// `zh-Hans` → `zh`, `pt-BR` → `pt`, `nb` → `nb`.
    public static func baseCode(_ code: String) -> String {
        String(code.split(separator: "-").first ?? Substring(code)).lowercased()
    }

    static func dominantLanguage(of text: String) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    /// A bullet, a dash, a numbered item, or a short line ending on a colon — which
    /// is a heading in every language this bench runs.
    static func isListLine(_ line: String) -> Bool {
        if line.range(of: #"^([-*•–—]|\d+[.)])\s"#, options: .regularExpression) != nil { return true }
        return line.count <= 40 && (line.hasSuffix(":") || line.hasSuffix("："))
    }

    static func digitRuns(in text: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"\d+"#)
        let range = NSRange(text.startIndex..., in: text)
        return (regex?.matches(in: text, range: range) ?? []).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    static func opensOnPreamble(_ loweredOutput: String, firstLine: String?) -> Bool {
        let trimmed = loweredOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if preambles.contains(where: { trimmed.hasPrefix($0) }) { return true }
        guard let firstLine else { return false }
        return firstLine.count <= 40 && (firstLine.hasSuffix(":") || firstLine.hasSuffix("："))
    }

    /// `List`'s shape, read on the first word. The verb lists are the tasks the
    /// fixtures dictate; anything else is left to the hand read.
    static func opensOnInfinitive(_ output: String, language: String) -> Bool {
        let first = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace || $0 == "," }).first.map(String.init) ?? ""
        switch language {
        case "fr":
            return ["Rappeler", "Appeler", "Récupérer", "Faire", "Réserver", "Préparer", "Répondre",
                    "Changer", "Annuler", "Envoyer", "Vérifier", "Contacter", "Penser", "Lister"].contains(first)
        case "en":
            return ["Call", "Get", "Book", "Do", "Make", "Send", "Check", "Prepare", "Reply", "Cancel",
                    "Change", "Rotate", "Bump", "List", "Remember"].contains(first)
        default:
            return false
        }
    }

    /// FR and EN only: a collective subject or obligation in the output that the
    /// input never used. `nous` is not how a French speaker says "we" out loud (`on`
    /// is), so its appearance is the model's voice; in English only the obligation
    /// forms are flagged, because a spoken `we` is ordinary.
    static func collectiveSwitch(output: String, input: String, language: String) -> Bool {
        let pattern: String
        switch language {
        case "fr": pattern = #"(?i)(^|[^\p{L}])nous([^\p{L}]|$)"#
        case "en": pattern = #"(?i)(^|[^\p{L}])we (must|need to|have to|should)([^\p{L}]|$)"#
        default: return false
        }
        let has = { (text: String) in text.range(of: pattern, options: .regularExpression) != nil }
        return has(output) && !has(input)
    }

    /// FR and EN only: whether the speaker's first person, present in the input,
    /// survives anywhere in the output. `on` counts in French because it is how a
    /// French speaker says "we".
    static func firstPersonLost(output: String, input: String, language: String) -> Bool {
        let pattern: String
        switch language {
        case "fr": pattern = #"(?i)(^|[^\p{L}])(je|j'|j’|me|m'|m’|moi|mon|ma|mes|nous|notre|nos|on)([^\p{L}]|$)"#
        case "en": pattern = #"(^|[^\p{L}])(I|I'm|I'll|I've|I'd|my|me|we|We|our|Our|us|My)([^\p{L}]|$)"#
        default: return false
        }
        let speaks = { (text: String) in text.range(of: pattern, options: .regularExpression) != nil }
        return speaks(input) && !speaks(output)
    }
}
