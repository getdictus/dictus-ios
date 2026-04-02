// DictusCore/Sources/DictusCore/FrequencyDictionary.swift
// Loads word frequency rankings from JSON and provides rank-based lookup.
import Foundation

/// A dictionary that maps words to frequency counts (higher count = more common).
///
/// WHY a struct with mutating load:
/// FrequencyDictionary is a value type holding a simple [String: Int] dictionary.
/// Load is mutating because we only load the active language (not both at once)
/// to keep memory usage low -- important for keyboard extension's ~50MB limit.
/// The `load(from:)` entry point accepts raw Data so unit tests can inject
/// JSON without needing a Bundle, keeping tests fast and deterministic.
public struct FrequencyDictionary {

    private var counts: [String: Int] = [:]

    public init() {}

    /// Loads frequency data from raw JSON Data.
    /// Expected format: `{"word": count, ...}` where count is an Int (higher = more common).
    /// This is the testable entry point -- no Bundle dependency.
    public mutating func load(from data: Data) {
        do {
            let decoded = try JSONDecoder().decode([String: Int].self, from: data)
            counts = decoded
        } catch {
            print("[FrequencyDictionary] Failed to decode frequency data: \(error)")
            counts = [:]
        }
    }

    /// Loads frequency data for the given language from a JSON file in the specified bundle.
    /// Looks for `{language}_frequency.json` (e.g., `fr_frequency.json`).
    /// If the file is missing, prints a warning and leaves counts empty.
    public mutating func load(language: String, bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "\(language)_frequency", withExtension: "json") else {
            print("[FrequencyDictionary] Missing \(language)_frequency.json in bundle")
            counts = [:]
            return
        }
        do {
            let data = try Data(contentsOf: url)
            load(from: data)
        } catch {
            print("[FrequencyDictionary] Failed to read \(language)_frequency.json: \(error)")
            counts = [:]
        }
    }

    /// Returns the word frequency count (higher = more common).
    /// Returns 0 if the word is not in the dictionary.
    /// Lookup is case-insensitive.
    public func rank(of word: String) -> Int {
        return counts[word.lowercased()] ?? 0
    }
}
