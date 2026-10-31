// tools/split-pass-bench/main.swift
// Runs every case of the glued-word corpus through the keyboard's text prediction
// engine as it ships, and counts what the space bar would have written (#499).
//
// Compiled by run.sh together with the unmodified engine sources
// (DictusKeyboard/TextPrediction/TextPredictionEngine.swift, AOSPTrieEngine.swift,
// the vendored C++ trie) and DictusCore, then run on an iOS Simulator.
import Foundation
import DictusCore

// MARK: - Corpus

struct Case {
    let id: String
    let lang: String
    let category: String
    let typed: String
    let expected: String
}

func readCorpus(_ path: String) -> [Case] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("cannot read corpus at \(path)")
    }
    var cases: [Case] = []
    for line in text.components(separatedBy: "\n") where !line.isEmpty && !line.hasPrefix("#") {
        let f = line.components(separatedBy: "\t")
        guard f.count == 6, f[0] != "id" else { continue }
        cases.append(Case(id: f[0], lang: f[1], category: f[2], typed: f[3], expected: f[4]))
    }
    return cases
}

// MARK: - Engine readiness

/// Spins the main run loop until `condition` holds: both engines load on a
/// background queue and post their completion to the main queue.
func wait(_ what: String, timeout: TimeInterval = 30, until condition: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else { fatalError("timed out waiting for \(what)") }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}

let engine = TextPredictionEngine.shared

/// A second trie, loaded from the same files, that the bench asks the questions
/// `spellCheck` asks internally (is this a word, what is this bigram). It only
/// explains a result; the result itself always comes from `engine`.
let probe = AOSPTrieEngine()

func load(_ lang: SupportedLanguage) {
    // Makes LayoutType.active this language's default layout, the one the
    // engine reads its spacebar neighbours from.
    SupportedLanguage.activate(lang)
    engine.setLanguage(lang.rawValue)
    var probeLoaded = false
    probe.load(language: lang.rawValue) { ok in
        guard ok else { fatalError("probe trie failed to load \(lang.rawValue)") }
        probeLoaded = true
    }
    wait("probe trie \(lang.rawValue)") { probeLoaded && probe.ngramsLoaded }
    wait("engine trie \(lang.rawValue)") { engine.isUnknownToDictionary("qzxqzxwq") }
    // The engine loads its n-grams right after its trie, on the same queue. Its
    // prediction after a frequent word stops being the frequency fallback then.
    let fallback = engine.predictNextWords(after: ["qzxqzxwq"])
    wait("engine n-grams \(lang.rawValue)") { engine.predictNextWords(after: ["de"]) != fallback
        || engine.predictNextWords(after: ["the"]) != fallback }
    RunLoop.main.run(until: Date().addingTimeInterval(0.3))
}

// MARK: - Outcomes

/// Lowercase without diacritics: "Pas mal" and "pas mal" are the same split.
func norm(_ s: String) -> String {
    s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
}

func outcome(_ c: Case, _ result: String?) -> String {
    let legit = c.category.hasPrefix("legit")
    guard let result else { return legit ? "kept" : "nothing" }
    if legit {
        if norm(result) == norm(c.typed) { return "kept" }
        return result.contains(" ") ? "false-split" : "false-replacement"
    }
    if norm(result) == norm(c.expected) { return "split-correct" }
    return result.contains(" ") ? "wrong-split" : "replaced"
}

// MARK: - Causes

/// Copy of `TextPredictionEngine.shortSplitAllowlist` and `isValidSplitPart`
/// (private there). Used only to explain a miss.
let shortSplitAllowlist: Set<String> = [
    "je", "tu", "il", "on", "me", "te", "se", "ne",
    "le", "la", "un", "du", "au", "en",
    "et", "ou", "ni", "si", "ça", "où", "ce",
    "pu", "vu",
    "to", "is", "in", "at", "by", "be", "go", "my",
    "es", "mi", "lo",
    "an", "er"
]
func isValidSplitPart(_ part: String) -> Bool {
    part.count >= 3 || (part.count == 2 && shortSplitAllowlist.contains(part))
}

struct Evidence {
    var leftInTrie = false
    var rightInTrie = false
    var bigram: UInt16 = 0
    /// The n-gram file keeps at most 16 followers per word (NGRM_MAX_RESULTS in
    /// dictus_ngram_format.h). A word with all 16 taken has no room for any other.
    var leftFollowersFull = false
}

func evidence(_ c: Case) -> (Evidence, left: String, right: String)? {
    let parts = c.expected.components(separatedBy: " ")
    guard parts.count == 2 else { return nil }
    var e = Evidence()
    e.leftInTrie = probe.wordExists(parts[0])
    e.rightInTrie = probe.wordExists(parts[1])
    e.bigram = probe.bigramScore(for: parts[1], after: parts[0])
    e.leftFollowersFull = probe.predictNextWords(after: [parts[0]], maxResults: 16).count >= 16
    return (e, parts[0], parts[1])
}

/// Why a glued case did not come out as its expected split. Walks the order of
/// `TextPredictionEngine.spellCheck(_:isAtSentenceStart:)`: the branches that
/// return before the split pass, then the split pass's own requirements.
/// The lexicon (#873) is empty here, so it never decides.
func cause(_ c: Case, _ outcome: String, _ result: String?) -> String {
    let w = c.typed
    if probe.languageOverride(for: w) != nil { return "before-split:language-override" }
    if probe.accentExpansion(w) != nil { return "before-split:accent-expansion" }
    if probe.wordExists(w) { return "before-split:glue-is-a-word" }
    if probe.contractionExpansion(w) != nil { return "before-split:contraction" }
    guard let (e, left, right) = evidence(c) else { return "other:unparsable" }
    let gluedBySpace = left + right == w
    let gluedByNeighbour = !gluedBySpace && w.count == left.count + right.count + 1
        && w.hasPrefix(left) && w.hasSuffix(right)
    if !gluedBySpace && !gluedByNeighbour { return "other:needs-more-than-a-space" }
    if !isValidSplitPart(left) || !isValidSplitPart(right) { return "part-too-short" }
    if !e.leftInTrie || !e.rightInTrie { return "part-not-in-dictionary" }
    if gluedBySpace && e.bigram == 0 {
        return e.leftFollowersFull ? "no-bigram:left-word-followers-full" : "no-bigram:left-word-has-room"
    }
    switch outcome {
    case "replaced": return "correction-preferred"
    case "wrong-split": return "other:another-split-won"
    default: return "other:unexplained"
    }
}

/// Top-level bucket for the report: the four the issue asks about.
func bucket(_ detail: String) -> String {
    switch detail {
    case "no-bigram:left-word-followers-full", "no-bigram:left-word-has-room": return "no-bigram"
    case "correction-preferred": return "correction-preferred"
    case "lexicon": return "lexicon"
    default: return "other"
    }
}

// MARK: - Run

let args = CommandLine.arguments
guard args.count >= 3 else {
    fatalError("usage: split-pass-bench <corpus.tsv> <cases-out.tsv>")
}
let cases = readCorpus(args[1])
var rows = ["id\tlang\tcategory\ttyped\texpected\tresult\toutcome\tcause\tstart_result\tstart_outcome"
    + "\ttyped_in_trie\tleft_in_trie\tright_in_trie\tbigram\tleft_followers_full"]

struct Tally {
    var total = 0
    var counts: [String: Int] = [:]
}
var byCategory: [String: Tally] = [:]
var startByCategory: [String: Tally] = [:]
var causes: [String: [String: Int]] = [:]
var bigramCoverage: [String: (withBigram: Int, total: Int)] = [:]
var failures: [String] = []

var order: [String] = []
for c in cases where !order.contains(c.lang) { order.append(c.lang) }

for lang in order {
    guard let language = SupportedLanguage(rawValue: lang) else { fatalError("unknown language \(lang)") }
    load(language)
    print("loaded \(lang): layout=\(LayoutType.active.rawValue)")
    for c in cases where c.lang == lang {
        // Mid-sentence, as most glues happen: lowercase, no proper-noun guard.
        let result = engine.spellCheck(c.typed, previousWord: nil, isAtSentenceStart: false)?.correction
        let out = outcome(c, result)
        // At the start of a field, autocapitalised: the condition of the
        // spacebar research's simulator sample.
        let capital = c.typed.prefix(1).uppercased() + c.typed.dropFirst()
        let startResult = engine.spellCheck(capital, previousWord: nil, isAtSentenceStart: true)?.correction
        let startOut = outcome(c, startResult)

        let key = "\(lang)\t\(c.category)"
        byCategory[key, default: Tally()].total += 1
        byCategory[key, default: Tally()].counts[out, default: 0] += 1
        startByCategory[key, default: Tally()].total += 1
        startByCategory[key, default: Tally()].counts[startOut, default: 0] += 1

        var detail = ""
        let ev = evidence(c)
        if !c.category.hasPrefix("legit") {
            if let (e, _, _) = ev {
                var cov = bigramCoverage[key] ?? (0, 0)
                cov.total += 1
                if e.bigram > 0 { cov.withBigram += 1 }
                bigramCoverage[key] = cov
            }
            if out != "split-correct" {
                detail = cause(c, out, result)
                causes[key, default: [:]][detail, default: 0] += 1
            }
        } else if out != "kept" {
            detail = result?.contains(" ") == true ? "split-pass" : "single-word-correction"
        }
        if out != "split-correct" && out != "kept" {
            failures.append("\(c.id)\t\(c.typed)\t\(c.expected)\t\(result ?? "-")\t\(out)\t\(detail)")
        }
        rows.append([
            c.id, lang, c.category, c.typed, c.expected, result ?? "", out, detail,
            startResult ?? "", startOut, String(probe.wordExists(c.typed)),
            ev.map { String($0.0.leftInTrie) } ?? "", ev.map { String($0.0.rightInTrie) } ?? "",
            ev.map { String($0.0.bigram) } ?? "", ev.map { String($0.0.leftFollowersFull) } ?? ""
        ].joined(separator: "\t"))
    }
}

do {
    try (rows.joined(separator: "\n") + "\n").write(toFile: args[2], atomically: true, encoding: .utf8)
} catch {
    fatalError("cannot write \(args[2]): \(error)")
}

// MARK: - Report

func pct(_ n: Int, _ d: Int) -> String {
    d == 0 ? "-" : String(format: "%.0f%%", Double(n) * 100 / Double(d))
}

func printTable(_ title: String, _ tallies: [String: Tally]) {
    print("\n## \(title)\n")
    print("| lang | category | cases | split correct | wrong correction (replaced / wrong split) | nothing | kept (legit) | false split | false replacement |")
    print("|---|---|---|---|---|---|---|---|---|")
    for key in tallies.keys.sorted(by: sortKey) {
        let t = tallies[key] ?? Tally()
        let k = key.components(separatedBy: "\t")
        let n = t.counts
        let wrong = (n["replaced"] ?? 0) + (n["wrong-split"] ?? 0)
        if k[1].hasPrefix("legit") {
            print("| \(k[0]) | \(k[1]) | \(t.total) | | | | \(n["kept"] ?? 0) (\(pct(n["kept"] ?? 0, t.total))) "
                + "| \(n["false-split"] ?? 0) (\(pct(n["false-split"] ?? 0, t.total))) "
                + "| \(n["false-replacement"] ?? 0) (\(pct(n["false-replacement"] ?? 0, t.total))) |")
        } else {
            let ok = n["split-correct"] ?? 0
            let none = n["nothing"] ?? 0
            print("| \(k[0]) | \(k[1]) | \(t.total) | \(ok) (\(pct(ok, t.total))) "
                + "| \(wrong) (\(pct(wrong, t.total))): \(n["replaced"] ?? 0) / \(n["wrong-split"] ?? 0) "
                + "| \(none) (\(pct(none, t.total))) | | | |")
        }
    }
}

let categoryOrder = ["observed", "missed-space", "neighbour-key", "legit-compound", "legit-rare"]
func sortKey(_ a: String, _ b: String) -> Bool {
    let ka = a.components(separatedBy: "\t"), kb = b.components(separatedBy: "\t")
    let la = order.firstIndex(of: ka[0]) ?? 0, lb = order.firstIndex(of: kb[0]) ?? 0
    if la != lb { return la < lb }
    return (categoryOrder.firstIndex(of: ka[1]) ?? 0) < (categoryOrder.firstIndex(of: kb[1]) ?? 0)
}

print("\n# Split-pass bench, \(cases.count) cases")
printTable("Mid-sentence (lowercase, isAtSentenceStart false): the headline", byCategory)
printTable("Start of field (autocapitalised, isAtSentenceStart true)", startByCategory)

print("\n## Glued cases that failed, by cause (mid-sentence)\n")
print("| lang | category | failures | no bigram | correction preferred | lexicon | other | detail |")
print("|---|---|---|---|---|---|---|---|")
for key in causes.keys.sorted(by: sortKey) {
    let d = causes[key] ?? [:]
    var b: [String: Int] = [:]
    for (k, v) in d { b[bucket(k), default: 0] += v }
    let total = d.values.reduce(0, +)
    let detail = d.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
    let k = key.components(separatedBy: "\t")
    print("| \(k[0]) | \(k[1]) | \(total) | \(b["no-bigram"] ?? 0) | \(b["correction-preferred"] ?? 0) "
        + "| \(b["lexicon"] ?? 0) | \(b["other"] ?? 0) | \(detail) |")
}

print("\n## Bigram coverage of the expected pairs (glued cases)\n")
print("| lang | category | pairs | bigram > 0 |")
print("|---|---|---|---|")
for key in bigramCoverage.keys.sorted(by: sortKey) {
    let v = bigramCoverage[key] ?? (0, 0)
    let k = key.components(separatedBy: "\t")
    print("| \(k[0]) | \(k[1]) | \(v.total) | \(v.withBigram) (\(pct(v.withBigram, v.total))) |")
}

print("\n## Every case that did not come out right (mid-sentence)\n")
print("id\ttyped\texpected\tresult\toutcome\tcause")
failures.forEach { print($0) }
