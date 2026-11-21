// DictusCore/Tests/DictusCoreTests/LanguageDetectionStubs.swift
// French and English dictionaries for the language detection tests (#1009).
@testable import DictusCore

/// A dictionary that answers from tables.
struct StubEvidence: LanguageEvidenceSource {
    let language: SupportedLanguage
    var words: [String: Double]
    var accents: [String: String] = [:]
    var contractions: [String: String] = [:]
    var corrections: [String: String] = [:]
    /// Keyed by "previous word".
    var bigrams: [String: Double] = [:]

    func logFrequency(of word: String) -> Double? { words[word] }
    func accentExpansion(_ word: String) -> String? { accents[word] }
    func contractionExpansion(_ word: String) -> String? { contractions[word] }
    func correction(of word: String) -> String? { corrections[word] }
    func bigram(_ word: String, after previous: String) -> Double { bigrams["\(previous) \(word)"] ?? 0 }
}

/// The shipped French and English dictionaries' answers for the words the tests type,
/// read off the tries and n-grams with
/// `tools/keyboard-bench/run.sh --pair fr,en --probe <words>` on 2026-11-21, rounded to
/// two decimals. A word absent from a table is absent from that dictionary.
enum ShippedDictionaries {
    static let french = StubEvidence(
        language: .french,
        words: [
            "est": -0.64, "trop": -3.55, "cool": -6.47, "on": -1.37, "se": -2.01, "fait": -2.52,
            "un": -0.85, "demain": -4.46, "matin": -4.59, "le": -0.67, "meeting": -8.93,
            "décalé": -11.15, "oui": -2.49, "je": -0.31, "regarde": -4.09, "ça": -1.43, "ce": -1.87,
            "soir": -3.98, "camp": -5.71, "thé": -6.18, "téléphone": -5.37, "juste": -4.07,
            "projet": -6.53, "client": -6.45, "table": -5.09, "ses": -3.00, "toi": -2.74, "fois": -3.41
        ],
        accents: ["the": "thé", "telephone": "téléphone"],
        contractions: ["cest": "c'est"],
        corrections: [
            "call": "camp", "sounds": "rounds", "good": "fois", "see": "ses", "you": "toi",
            "oji": "oui", "jusge": "juste"
        ],
        bigrams: [
            "trop cool": 0.39, "on se": 0.78, "se fait": 0.76, "fait un": 0.74, "demain matin": 0.40,
            "oui je": 0.54, "regarde ça": 0.50, "ce soir": 0.76
        ]
    )

    static let english = StubEvidence(
        language: .english,
        words: [
            "est": -5.99, "trop": -10.59, "cool": -6.02, "on": -1.82, "se": -6.37, "fait": -10.00,
            "un": -6.16, "call": -4.75, "le": -6.13, "meeting": -5.26, "oui": -10.42, "je": -7.80,
            "ce": -6.84, "sounds": -6.62, "good": -4.15, "see": -3.52, "you": -2.04, "tomorrow": -7.01,
            "camp": -6.49, "the": 0.00, "telephone": -5.91, "judge": -6.62, "oki": -9.47,
            "projet": -10.44, "client": -5.81, "table": -4.94, "remain": -6.63, "latin": -6.45,
            "decals": -8.94, "regards": -7.49, "ca": -5.18, "sour": -8.73, "trip": -6.17,
            "fair": -6.15, "in": -1.01, "he": -3.31
        ],
        corrections: [
            "trop": "trip", "fait": "fair", "un": "in", "demain": "remain", "matin": "latin",
            "décalé": "decals", "regarde": "regards", "ça": "ca", "soir": "sour", "thé": "the",
            "téléphone": "telephone", "oji": "oki", "jusge": "judge"
        ],
        bigrams: ["se fait": 0.12, "fait un": 0.11, "oui je": 0.07, "sounds good": 0.46, "see you": 0.75]
    )
}
