// DictusCore/Tests/DictusCoreTests/MockFrequencyProvider.swift
// Test double for FrequencyProvider — stores word→frequency in a dict.
import Foundation
@testable import DictusCore

/// Test double that returns frequencies from an in-memory dict.
///
/// Use it to drive `AccentExpander`, `ContractionExpander`, and other
/// helpers under controlled conditions: set `frequencies` before each test
/// and assert that the algorithm picks the right candidate.
final class MockFrequencyProvider: FrequencyProvider {
    var isReady: Bool = true
    var frequencies: [String: UInt16] = [:]

    init(isReady: Bool = true, frequencies: [String: UInt16] = [:]) {
        self.isReady = isReady
        self.frequencies = frequencies
    }

    func frequency(of word: String) -> UInt16 {
        frequencies[word] ?? 0
    }

    func wordExists(_ word: String) -> Bool {
        frequencies[word] != nil
    }
}
