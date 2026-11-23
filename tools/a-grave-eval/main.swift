// Measures the French `a`/`à` rule (#501) on real sentences: every standalone `a`
// or `à` of a Tatoeba sentence is typed as `a` (`A` when written with a capital),
// and the rule's answer is compared with what the sentence wrote. Sentence starts
// (#979) are counted apart: there Tatoeba often writes `À` as a plain `A`.
import DictusCore
import Foundation

let args = CommandLine.arguments
guard args.count >= 2, let text = try? String(contentsOfFile: args[1], encoding: .utf8) else {
    print("usage: a-grave-eval <fra_sentences.tsv> [--show-wrong N]")
    exit(2)
}
var showWrong = 0
if let flag = args.firstIndex(of: "--show-wrong") {
    guard flag + 1 < args.count, let count = Int(args[flag + 1]), count >= 0 else {
        print("usage: a-grave-eval <fra_sentences.tsv> [--show-wrong N]")
        exit(2)
    }
    showWrong = count
}
guard let rule = frenchProfile.contextualHomographs.first(where: { $0.typed == "a" }) else {
    print("French has no a/à rule")
    exit(1)
}

// A standalone `a`, `à`, `A` or `À` at the start or after a space, with a word boundary after it.
let target = try NSRegularExpression(pattern: "(?<=^|\\s)(a|\u{00E0}|A|\u{00C0})(?=$|[\\s.,;:!?\u{2026}])")
var verbs = 0, verbsAccented = 0, prepositions = 0, prepositionsAccented = 0
var startPlain = 0, startPlainAccented = 0, startGrave = 0, startGraveAccented = 0
var wrong: [String] = []

for line in text.split(separator: "\n") {
    let sentence = String(line.split(separator: "\t").last ?? "")
    let ns = sentence as NSString
    for match in target.matches(in: sentence, range: NSRange(location: 0, length: ns.length)) {
        let truth = ns.substring(with: match.range)
        let typed = truth == "a" || truth == "\u{00E0}" ? "a" : "A"
        let context = ns.substring(to: match.range.location) + typed
        let accented = rule.accentedForm(of: typed, context: context) != nil
        if ProperNounGuard.isAtSentenceStart(context: context, word: typed) {
            if truth.lowercased() == "a" {
                startPlain += 1
                if accented { startPlainAccented += 1 }
            } else {
                startGrave += 1
                if accented { startGraveAccented += 1 }
            }
        } else if truth == "A" || truth == "\u{00C0}" {
            continue  // a capital inside a sentence: a name or an initial, not scored
        } else if truth == "a" {
            verbs += 1
            if accented {
                verbsAccented += 1
                wrong.append(sentence)
            }
        } else {
            prepositions += 1
            if accented { prepositionsAccented += 1 }
        }
    }
}

func percent(_ part: Int, _ whole: Int) -> String {
    String(format: "%.2f%%", 100 * Double(part) / Double(max(whole, 1)))
}
print("| written | occurrences | typed `a` became `à` |")
print("|---|---:|---:|")
print("| `a` (verb) | \(verbs) | \(verbsAccented) (\(percent(verbsAccented, verbs))) |")
print("| `à` (preposition) | \(prepositions) | \(prepositionsAccented) (\(percent(prepositionsAccented, prepositions))) |")
print("| sentence start, written `a`/`A` | \(startPlain) | \(startPlainAccented) (\(percent(startPlainAccented, startPlain))) |")
print("| sentence start, written `à`/`À` | \(startGrave) | \(startGraveAccented) (\(percent(startGraveAccented, startGrave))) |")
for sentence in wrong.prefix(showWrong) { print("wrong: \(sentence)") }
