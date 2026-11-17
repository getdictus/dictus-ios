// Measures the French `a`/`à` rule (#501) on real sentences: every standalone `a`
// or `à` after the first word of a Tatoeba sentence is typed as `a`, and the
// rule's answer is compared with what the sentence wrote.
import DictusCore
import Foundation

let args = CommandLine.arguments
guard args.count >= 2, let text = try? String(contentsOfFile: args[1], encoding: .utf8) else {
    print("usage: a-grave-eval <fra_sentences.tsv> [--show-wrong N]")
    exit(2)
}
let showWrong = args.firstIndex(of: "--show-wrong").flatMap { Int(args[$0 + 1]) } ?? 0
guard let rule = frenchProfile.contextualHomographs.first(where: { $0.typed == "a" }) else {
    print("French has no a/à rule")
    exit(1)
}

// A standalone `a` or `à` with a space before it and a word boundary after it.
let target = try NSRegularExpression(pattern: "(?<=\\s)(a|\u{00E0})(?=$|[\\s.,;:!?\u{2026}])")
var verbs = 0, verbsAccented = 0, prepositions = 0, prepositionsAccented = 0
var wrong: [String] = []

for line in text.split(separator: "\n") {
    let sentence = String(line.split(separator: "\t").last ?? "")
    let ns = sentence as NSString
    for match in target.matches(in: sentence, range: NSRange(location: 0, length: ns.length)) {
        let truth = ns.substring(with: match.range)
        let context = ns.substring(to: match.range.location) + "a"
        let accented = rule.accentedForm(of: "a", context: context) != nil
        if truth == "a" {
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
for sentence in wrong.prefix(showWrong) { print("wrong: \(sentence)") }
