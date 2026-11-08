// DictusCore/Sources/polish-harness/LanguageCheckReadings.swift
// Every reading the language check makes on committed outputs, written down so the
// variants #598 asks about can be scored without touching the shipping check.
import Foundation
import NaturalLanguage
import DictusCore

/// The raw material of `PolishGuardrail.detectedLanguageMatches`, recorded per output
/// (#598).
///
/// WHY readings and not verdicts. #598 asks what three different rules would do — the
/// whole output only, an `es`/`pt` family, a longer segment floor — and every one of them
/// is a function of the same few numbers: the whole output's top reading, and each
/// segment's length and top reading. Recording those once lets
/// `docs/research/598-short-line-language-check/summarise.py` score every variant without
/// a second copy of the check living here, and without editing the shipping one to add a
/// seam nobody ships. The shipping verdict is recorded alongside, from the shipping
/// function itself, and the script refuses to report anything unless its own reading of
/// the rule reproduces that verdict on every output.
///
/// The readings are `NLLanguageRecognizer`'s on the machine that ran this, and its model
/// ships with the OS: a file written on macOS is a macOS measurement.
enum LanguageCheckReadings {

    struct Reading: Encodable {
        let code: String?
        let confidence: Double
    }

    /// The output itself is not stored: its segments are its lines, marker stripped, and
    /// the capture it came from is committed alongside. Storing both doubled the file.
    struct Segment: Encodable {
        let text: String
        /// `String.count`, i.e. Characters — the unit the check's thresholds are in.
        let characters: Int
        let reading: Reading
    }

    struct Record: Encodable {
        /// `K414` (hand-labelled, `docs/research/413-414-guardrail/`) or `C587` (a bench
        /// capture, labelled by #598 itself).
        let corpus: String
        let file: String
        let fixture: String
        let run: Int
        let arm: String?
        let outcome: String?
        let rejectedCheck: String?
        /// The fixture's declared language, when the record names one.
        let fixtureLanguage: String?
        /// The code the check is asked to match. K414: the corpus's `expectedLang`, which
        /// is what `polish-harness guardrail` scores against. C587: the input's own
        /// reading, which is what `.sameAsInput` hands the check in production. Nil when
        /// that reading is too weak, in which case the pipeline passes the output through.
        let expected: String?
        /// K414's hand label: `sameLanguage`, `bilingual` or `wrongLanguage`.
        let label: String?
        /// Characters of the trimmed output; under 12 the check passes untested.
        let trimmedCharacters: Int
        let whole: Reading
        let segments: [Segment]
        /// `PolishGuardrail.detectedLanguageMatches(polished:inputLanguageCode:)`, the
        /// shipping function, unmodified. Nil when `expected` is.
        let shippingAccepts: Bool?
    }

    // MARK: - Inputs

    /// The fields this reads off a `polish-harness fidelity` or `summary` capture. Both
    /// formats carry them under the same names.
    private struct CaptureRecord: Decodable {
        let fixture: String
        let run: Int
        let arm: String?
        let outcome: String?
        let rejectedCheck: String?
        let output: String
        let hasEngineOutput: Bool?
    }

    /// The fields this reads off a K414 corpus entry.
    private struct LabelledRecord: Decodable {
        let source: String
        let fixture: String
        let run: Int
        let inputLang: String
        let expectedLang: String
        let language: String
        let output: String
    }

    /// Every fixture in `paths`, by id. Exits on a conflicting duplicate: two transcripts
    /// under one id would make the expected language depend on load order.
    static func loadFixtures(_ paths: [String]) -> [String: Fixture] {
        var byID: [String: Fixture] = [:]
        for path in paths {
            let loaded: [Fixture]
            do {
                loaded = try FixtureLoader.load(path)
            } catch {
                print("error: cannot load fixtures at \(path): \(error)")
                exit(1)
            }
            for fixture in loaded {
                if let previous = byID[fixture.id], previous.raw != fixture.raw {
                    print("error: fixture id \(fixture.id) has two different transcripts (\(path))")
                    exit(1)
                }
                byID[fixture.id] = fixture
            }
        }
        return byID
    }

    /// Read every output in `paths`. A file whose entries carry `expectedLang` is a K414
    /// corpus; anything else is a capture, resolved against `fixtures`.
    static func records(paths: [String], fixtures: [String: Fixture]) -> [Record] {
        paths.flatMap { path -> [Record] in
            guard let data = FileManager.default.contents(atPath: path) else {
                print("error: cannot read \(path)")
                exit(1)
            }
            let file = path.hasPrefix("../") ? String(path.dropFirst(3)) : path
            if let labelled = try? JSONDecoder().decode([LabelledRecord].self, from: data) {
                return labelled.map { item in
                    record(corpus: "K414", file: file, fixture: "\(item.source):\(item.fixture)", run: item.run,
                           arm: nil, outcome: nil, rejectedCheck: nil, fixtureLanguage: item.inputLang,
                           expected: item.expectedLang, label: item.language, output: item.output)
                }
            }
            let captured: [CaptureRecord]
            do {
                captured = try JSONDecoder().decode([CaptureRecord].self, from: data)
            } catch {
                print("error: \(path) is neither a K414 corpus nor a capture: \(error)")
                exit(1)
            }
            // A run with no engine output has nothing for the check to read (see
            // `FidelityRun.hasEngineOutput`).
            return captured.filter { $0.hasEngineOutput ?? true }.map { item in
                guard let fixture = fixtures[item.fixture] else {
                    print("error: \(path) names fixture \(item.fixture), which no --fixtures file holds")
                    exit(1)
                }
                return record(corpus: "C587", file: file, fixture: item.fixture, run: item.run,
                              arm: item.arm, outcome: item.outcome, rejectedCheck: item.rejectedCheck,
                              fixtureLanguage: fixture.lang, expected: expectedCode(for: fixture),
                              label: nil, output: item.output)
            }
        }
    }

    /// What `PolishPipeline.languageGuardrailPasses` hands the check on `.sameAsInput`:
    /// the pre-passed transcript's own reading at the pipeline's default floor.
    private static func expectedCode(for fixture: Fixture) -> String? {
        let preprocessed = fixture.language.map { VerbalPunctuationPrepass.apply(fixture.raw, language: $0) }
            ?? fixture.raw
        return PolishPipeline.detectLanguageCode(in: preprocessed)
    }

    // swiftlint:disable:next function_parameter_count
    private static func record(corpus: String, file: String, fixture: String, run: Int,
                               arm: String?, outcome: String?, rejectedCheck: String?,
                               fixtureLanguage: String?, expected: String?, label: String?,
                               output: String) -> Record {
        // The same trim and the same cut the check makes, so a segment here is a segment
        // there.
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return Record(
            corpus: corpus, file: file, fixture: fixture, run: run, arm: arm, outcome: outcome,
            rejectedCheck: rejectedCheck, fixtureLanguage: fixtureLanguage, expected: expected,
            label: label, trimmedCharacters: trimmed.count,
            whole: reading(trimmed),
            segments: PolishSegmentation.segments(of: trimmed).map {
                Segment(text: $0, characters: $0.count, reading: reading($0))
            },
            shippingAccepts: expected.map {
                PolishGuardrail.detectedLanguageMatches(polished: output, inputLanguageCode: $0)
            }
        )
    }

    /// The recogniser's top hypothesis with no floor, as the check reads it.
    private static func reading(_ text: String) -> Reading {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let top = recognizer.languageHypotheses(withMaximum: 1).max { $0.value < $1.value }
        return Reading(code: top?.key.rawValue, confidence: top?.value ?? 0)
    }

    // MARK: - Output

    /// One output per line (JSON Lines): greppable by fixture, and half the size of the
    /// pretty-printed array for a file of six thousand outputs.
    static func write(_ records: [Record], to path: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            // `JSONEncoder` only ever emits UTF-8, so the fallback is unreachable; it is
            // there because the failable initializer is the one the lint accepts.
            let lines = try records.map { record -> String in
                String(bytes: try encoder.encode(record), encoding: .utf8) ?? ""
            }
            try (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("error: cannot write \(path): \(error)")
            exit(1)
        }
    }
}
