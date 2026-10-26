// DictusCore/Sources/PolishFidelity/VocabularyJudgeScore.swift
// The labelled pairs file and the go/no-go of #512 step 2, deterministic and model-free.
import Foundation

// WHY this lives in PolishFidelity, whose name says polish: it is the package's
// measurement library, the one target that is testable and linked into neither app
// (see Package.swift). The step 2 verdict is a decision rule with three thresholds,
// and a rule nobody can test is a rule nobody should believe. The model half (Apple
// FM judging each pair) stays in polish-harness, where Apple Intelligence is.

/// The file `polish-harness vocabpairs` writes and `vocabjudge` reads (step 2 brief,
/// decision 5).
///
/// One line per pair, `P01 | canonical | observed | sentence`, which the maintainer
/// prefixes with `v` (true: the engine wrote `observed` for `canonical`) or `f`
/// (false), blind, before any judge verdict exists. Plain text rather than JSON so
/// labelling is typing one letter at the start of a line in any editor.
///
/// **The file holds dictation text.** It is written outside the repository and never
/// committed; only synthetic examples are.
public enum VocabularyPairsFile {

    public static let separator = " | "

    /// `P01`, `P02`, … in rank order. Two digits: the file holds twenty.
    public static func pairID(_ index: Int) -> String {
        String(format: "P%02d", index + 1)
    }

    /// One unlabelled line.
    public static func line(id: String, canonical: String, observed: String, sentence: String) -> String {
        [id, canonical, observed, sentence].joined(separator: separator)
    }

    /// Whether a canonical can sit in a line without breaking the parse: the
    /// separator and line breaks are refused. `observed` is tokenizer output and
    /// cannot carry either; `sentence` is the last field and may hold anything on one
    /// line.
    public static func isWritable(canonical: String) -> Bool {
        !canonical.contains("|") && !canonical.contains(where: \.isNewline)
    }

    /// The instructions at the top of the file, as `#` comment lines.
    public static let header = """
    # Dictus #512 step 2: candidate vocabulary pairs, ranked by similarity.
    # THIS FILE HOLDS DICTATION TEXT. Keep it outside any repository; never commit it.
    #
    # Prefix every pair line with one letter and a space, before running the judge:
    #   v  true:  in this sentence the engine wrote <observed> for <canonical>
    #   f  false: <observed> means what it says here, or the pair is wrong otherwise
    # Example:  v P01 | Claude Code | cloud code | j'utilise cloud code tous les jours
    # Label blind: decide from the sentence, not from the rank.
    # Then: swift run polish-harness vocabjudge <this file>
    #
    # id | canonical | observed | sentence
    """

    /// One line of a labelled file.
    public struct Entry: Equatable, Sendable {
        public let id: String
        public let canonical: String
        public let observed: String
        public let sentence: String
        /// True for `v`, false for `f`, nil when the line carries no label yet.
        public let isTrue: Bool?

        public init(id: String, canonical: String, observed: String, sentence: String, isTrue: Bool?) {
            self.id = id
            self.canonical = canonical
            self.observed = observed
            self.sentence = sentence
            self.isTrue = isTrue
        }
    }

    public enum ParseError: Error, Equatable, CustomStringConvertible {
        /// A non-comment line that is not `[v|f] Pnn | canonical | observed | sentence`.
        case malformed(lineNumber: Int)
        case duplicateID(String)

        public var description: String {
            switch self {
            case .malformed(let number):
                return "line \(number) is not `[v|f] Pnn | canonical | observed | sentence`"
            case .duplicateID(let id):
                return "pair \(id) appears twice"
            }
        }
    }

    /// Every pair line of a file, labelled or not. Blank lines and `#` lines skipped.
    public static func parse(_ text: String) throws -> [Entry] {
        var entries: [Entry] = []
        var seen = Set<String>()
        for (offset, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            guard let entry = entry(from: line) else { throw ParseError.malformed(lineNumber: offset + 1) }
            guard seen.insert(entry.id).inserted else { throw ParseError.duplicateID(entry.id) }
            entries.append(entry)
        }
        return entries
    }

    private static func entry(from line: String) -> Entry? {
        var rest = Substring(line)
        var isTrue: Bool?
        if let first = rest.first, "vVfF".contains(first),
           rest.dropFirst().first?.isWhitespace == true {
            isTrue = first.lowercased() == "v"
            rest = rest.dropFirst().drop(while: \.isWhitespace)
        }
        let fields = rest.components(separatedBy: separator)
        guard fields.count >= 4 else { return nil }
        let id = fields[0].trimmingCharacters(in: .whitespaces)
        guard id.count >= 2, id.first == "P", id.dropFirst().allSatisfy(\.isNumber) else { return nil }
        let canonical = fields[1].trimmingCharacters(in: .whitespaces)
        let observed = fields[2].trimmingCharacters(in: .whitespaces)
        // The sentence is the last field and may itself contain the separator.
        let sentence = fields[3...].joined(separator: separator).trimmingCharacters(in: .whitespaces)
        guard !canonical.isEmpty, !observed.isEmpty else { return nil }
        return Entry(id: id, canonical: canonical, observed: observed, sentence: sentence, isTrue: isTrue)
    }
}

/// What the judge said about one pair over its runs (decision 6: three runs per pair,
/// any disagreement between runs counts as an error).
public enum VocabularyJudgeReading: Equatable, Sendable {
    case yes
    case no
    /// The runs answered differently.
    case inconsistent
    /// At least one run threw (refusal, guardrail, rate limit…): no reading.
    case failed

    /// One run's answer: true for yes, false for no, nil when the call failed.
    public init(runs: [Bool?]) {
        if runs.isEmpty || runs.contains(where: { $0 == nil }) {
            self = .failed
        } else if runs.allSatisfy({ $0 == true }) {
            self = .yes
        } else if runs.allSatisfy({ $0 == false }) {
            self = .no
        } else {
            self = .inconsistent
        }
    }
}

/// The step 2 go/no-go, exactly as the brief writes it (decision 6).
///
/// - **≥ 17 of 20 true**: the generator ships alone, and Apple FM is not called.
/// - Otherwise the judge runs. It **passes** if it rejects ≥ 80 % of the false pairs
///   and keeps ≥ 80 % of the true ones; an inconsistent or failed reading is an error
///   on both sides (a true pair it did not keep, a false pair it did not reject).
/// - **Judge fails**: the generator ships alone if ≥ 14 of 20 are true; below that,
///   step 2 is dropped and the work moves to step 3.
///
/// ### On a file that does not hold twenty pairs
///
/// The thresholds are written for twenty. With fewer (a short History) the same
/// shares are applied, 17/20 and 14/20 compared in integers so twenty pairs give the
/// brief's numbers exactly, and `isBriefSample` is false so the caller says the
/// verdict is not the brief's.
public struct VocabularyJudgeVerdict: Equatable, Sendable {

    public static let sampleSize = 20
    public static let generatorAloneFloor = 17
    public static let generatorAfterFailedJudgeFloor = 14
    /// 80 %, as a fraction compared in integers: `hits * 5 >= total * 4`.
    static let judgeNumerator = 4
    static let judgeDenominator = 5

    public enum Decision: String, Sendable {
        case generatorAloneJudgeNotCalled
        case generatorWithJudge
        case generatorAloneJudgeFailed
        case stepDropped

        /// The sentence the command prints.
        public var summary: String {
            switch self {
            case .generatorAloneJudgeNotCalled:
                return "GO: the generator ships alone. Enough pairs are true; Apple FM is not called."
            case .generatorWithJudge:
                return "GO: the generator ships with the Apple FM judge."
            case .generatorAloneJudgeFailed:
                return "GO: the generator ships alone. The judge failed, the generator clears the 14 of 20 floor."
            case .stepDropped:
                return "NO-GO: step 2 is dropped. Move to step 3."
            }
        }
    }

    public let total: Int
    public let trueCount: Int
    public var falseCount: Int { total - trueCount }
    /// True pairs the judge kept, consistently; nil when it did not run.
    public let trueKept: Int?
    /// False pairs the judge rejected, consistently; nil when it did not run.
    public let falseRejected: Int?
    public let decision: Decision

    public var isBriefSample: Bool { total == Self.sampleSize }
    public var judgeRan: Bool { trueKept != nil }

    /// Whether the labels alone settle it, so the judge must not run.
    public static func labelsSettle(trueCount: Int, total: Int) -> Bool {
        total > 0 && trueCount * sampleSize >= generatorAloneFloor * total
    }

    /// Decide.
    ///
    /// - Parameters:
    ///   - labels: the maintainer's labels, true for `v`.
    ///   - readings: the judge's reading per pair, same order; nil when it did not run.
    ///     Required whenever `labelsSettle` is false: deciding without the judge then
    ///     would answer a question the brief says to ask the model.
    public init?(labels: [Bool], readings: [VocabularyJudgeReading]?) {
        let total = labels.count
        let trueCount = labels.filter { $0 }.count
        self.total = total
        self.trueCount = trueCount
        guard total > 0 else { return nil }

        if Self.labelsSettle(trueCount: trueCount, total: total) {
            trueKept = nil
            falseRejected = nil
            decision = .generatorAloneJudgeNotCalled
            return
        }
        guard let readings, readings.count == total else { return nil }
        let pairs = zip(labels, readings)
        let kept = pairs.filter { $0.0 && $0.1 == .yes }.count
        let rejected = pairs.filter { !$0.0 && $0.1 == .no }.count
        trueKept = kept
        falseRejected = rejected
        if Self.clears(kept, of: trueCount), Self.clears(rejected, of: total - trueCount) {
            decision = .generatorWithJudge
        } else if trueCount * Self.sampleSize >= Self.generatorAfterFailedJudgeFloor * total {
            decision = .generatorAloneJudgeFailed
        } else {
            decision = .stepDropped
        }
    }

    /// At least 80 % of a non-empty set. An empty set clears nothing: a judge with no
    /// true pair to keep has shown nothing about keeping them.
    static func clears(_ hits: Int, of count: Int) -> Bool {
        count > 0 && hits * judgeDenominator >= count * judgeNumerator
    }
}
