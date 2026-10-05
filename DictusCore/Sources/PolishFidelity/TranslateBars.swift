// DictusCore/Sources/PolishFidelity/TranslateBars.swift
// The bars of the Translate bench, as deterministic scorers (#648).
import Foundation
import NaturalLanguage

/// One hand-written check from `docs/research/648-translate/bars.json`. `require` must
/// match the output, `forbid` must not; a check carrying both passes only when both hold.
public struct TranslateBarCheck: Codable, Equatable, Sendable {
    public let label: String
    public let require: String?
    public let forbid: String?

    public init(label: String, require: String? = nil, forbid: String? = nil) {
        self.label = label
        self.require = require
        self.forbid = forbid
    }
}

/// One fixture's bars: (a) `drop`, (b) `keep`, (c) `add`, (e) `critical`. Bar (d), the
/// output language, needs no list. `id: "*"` applies to every fixture.
public struct TranslateBars: Codable, Equatable, Sendable {
    public let id: String
    public let register: String?
    public let drop: [TranslateBarCheck]?
    public let keep: [TranslateBarCheck]?
    public let add: [TranslateBarCheck]?
    public let critical: [TranslateBarCheck]?

    public init(id: String, register: String? = nil, drop: [TranslateBarCheck]? = nil,
                keep: [TranslateBarCheck]? = nil, add: [TranslateBarCheck]? = nil,
                critical: [TranslateBarCheck]? = nil) {
        self.id = id
        self.register = register
        self.drop = drop
        self.keep = keep
        self.add = add
        self.critical = critical
    }

    var allChecks: [TranslateBarCheck] {
        (drop ?? []) + (keep ?? []) + (add ?? []) + (critical ?? [])
    }
}

/// The bars of every file given, merged by fixture id.
///
/// Merged rather than replaced because one fixture is split across two files on
/// purpose: `translate-fr-05` is a personal opinion, so its public entry carries only
/// what the issue already quotes and the rest lives in the git-excluded corpus. Every
/// pattern is compiled at decode, before the first model call, so a typo in a regex
/// costs an error then rather than a silently passing bar after a round.
public struct TranslateBarSet: Sendable {
    public private(set) var byID: [String: TranslateBars] = [:]

    public enum DecodeError: Error, CustomStringConvertible {
        case invalidRegex(fixture: String, label: String, pattern: String)

        public var description: String {
            switch self {
            case let .invalidRegex(fixture, label, pattern):
                return "[\(fixture)] '\(label)': invalid regex /\(pattern)/"
            }
        }
    }

    public init() {}

    public static func decode(_ files: [Data]) throws -> TranslateBarSet {
        var set = TranslateBarSet()
        for data in files {
            for entry in try JSONDecoder().decode([TranslateBars].self, from: data) {
                set.merge(entry)
            }
        }
        for entry in set.byID.values {
            for check in entry.allChecks {
                for pattern in [check.require, check.forbid].compactMap({ $0 })
                where (try? NSRegularExpression(pattern: pattern)) == nil {
                    throw DecodeError.invalidRegex(fixture: entry.id, label: check.label, pattern: pattern)
                }
            }
        }
        return set
    }

    private mutating func merge(_ entry: TranslateBars) {
        guard let existing = byID[entry.id] else {
            byID[entry.id] = entry
            return
        }
        byID[entry.id] = TranslateBars(
            id: entry.id,
            register: existing.register ?? entry.register,
            drop: (existing.drop ?? []) + (entry.drop ?? []),
            keep: (existing.keep ?? []) + (entry.keep ?? []),
            add: (existing.add ?? []) + (entry.add ?? []),
            critical: (existing.critical ?? []) + (entry.critical ?? [])
        )
    }

    /// The fixture's own entry with the `*` additions folded in.
    public func bars(for fixtureID: String) -> TranslateBars {
        let own = byID[fixtureID]
        let shared = byID["*"]
        return TranslateBars(
            id: fixtureID,
            register: own?.register,
            drop: own?.drop ?? [],
            keep: own?.keep ?? [],
            add: (shared?.add ?? []) + (own?.add ?? []),
            critical: own?.critical ?? []
        )
    }
}

/// What one output failed, bar by bar. Each entry names the check and why.
///
/// Flags for a reader, not verdicts: a regex cannot see a disfluency rendered with a
/// word nobody foresaw, nor a sentence that kept its keyword and lost its fact. What it
/// buys is that every run is counted the same way, and that a reader starts from the
/// flagged ones.
public struct TranslateScore: Codable, Equatable, Sendable {
    public var drop: [String] = []
    public var keep: [String] = []
    public var add: [String] = []
    public var critical: [String] = []
    /// The fixture's own `expect` entries it missed: #412's bars, on `translate-en.json`.
    public var expect: [String] = []
    /// `NLLanguageRecognizer`'s dominant reading of the output.
    public var outputLanguage: String?

    public init() {}

    public static func score(output: String, bars: TranslateBars) -> TranslateScore {
        var score = TranslateScore()
        score.drop = failures(of: bars.drop ?? [], in: output)
        score.keep = failures(of: bars.keep ?? [], in: output)
        score.add = failures(of: bars.add ?? [], in: output)
        score.critical = failures(of: bars.critical ?? [], in: output)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(output)
        score.outputLanguage = recognizer.dominantLanguage?.rawValue
        return score
    }

    /// The score of a private fixture, as a committed capture may carry it.
    ///
    /// Counts survive, words do not. A `drop` or `keep` label of `translate-fr-05` comes
    /// from the private bars and paraphrases the opinion, so it becomes a placeholder; an
    /// `add` label is a public `*` check, but the span it found is the output's own words,
    /// so the span goes. `critical` stays whole: its labels and its two forbidden spans
    /// are the ones the issue already quotes.
    public func redacted() -> TranslateScore {
        var copy = self
        copy.drop = drop.map { _ in Self.privateCheck }
        copy.keep = keep.map { _ in Self.privateCheck }
        copy.add = add.map {
            $0.replacingOccurrences(of: #" \[found ".*"\]$"#, with: " [found]", options: .regularExpression)
        }
        return copy
    }

    public static let privateCheck = "<private check>"

    private static func failures(of checks: [TranslateBarCheck], in output: String) -> [String] {
        checks.compactMap { check in
            if let forbid = check.forbid, let hit = firstMatch(forbid, in: output) {
                return "\(check.label) [found \"\(hit)\"]"
            }
            if let require = check.require, firstMatch(require, in: output) == nil {
                return "\(check.label) [missing]"
            }
            return nil
        }
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        // `TranslateBarSet.decode` compiled every pattern already; a check built by hand
        // with a bad one matches nothing rather than crashing a round.
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }
}
