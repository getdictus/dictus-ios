// Vendored from SymSpellSwift by gdetari (MIT License)
// https://github.com/gdetari/SymSpellSwift
// Adapted for Dictus keyboard extension
//
// SymSpell.swift
// SymSpellSwift
//
// Created by Gabor Detari gabor@detari.dev
// Copyright (c) 2024 Gabor Detari. All rights reserved.
//

import Foundation

public class SymSpell {
    /// .top: Top suggestion with the highest term frequency of the suggestions of smallest edit distance found.
    /// .closest: All suggestions of smallest edit distance found, suggestions ordered by term frequency.
    /// .all: All suggestions within maxEditDistance, suggestions ordered by edit distance , then by term frequency (slower, no early termination).
    public enum Verbosity: CaseIterable {
        case top, closest, all
    }

    public struct Segmentation {
        public var segmentedString = ""
        public var correctedString = ""
        public var distanceSum = 0
        public var probabilityLogSum = 0.0
    }

    public var wordCount: Int { words.count }
    public var entryCount: Int { deletes.count }

    /// Maximum edit distance for dictionary precalculation.
    private(set) var maxDictionaryEditDistance = 2
    /// Length of prefix, from which deletes are generated.
    private(set) var prefixLength = 7

    private var deletes = [Int: [Int]]()
    private var words = [Int: (String, Int)]()

    private var bigrams = [String: Int]()
    private var bigramCountMin = Int.max

    private let separator: Character = " "

    private var maxDictionaryWordLength: Int = 0
    private var totalCorpusWords = 0

    /// Create a new instanc of SymSpell.
    /// - Parameters:
    ///   - maxDictionaryEditDistance: Maximum edit distance for doing lookups.
    ///   - prefixLength: The length of word prefixes used for spell checking.
    public init(maxDictionaryEditDistance: Int = 2, prefixLength: Int = 7) {
        precondition(maxDictionaryEditDistance >= 0, "maxDictionaryEditDistance must be non-negative")
        precondition(prefixLength > 1 && prefixLength > maxDictionaryEditDistance, "Invalid prefixLength")

        self.maxDictionaryEditDistance = maxDictionaryEditDistance
        self.prefixLength = prefixLength
    }

    /// Load multiple dictionary entries from a file of word/frequency count pairs.
    /// Merges with any dictionary data already loaded.
    /// - Parameters:
    ///   - from: The url of the file.
    ///   - termIndex:The column position of the word.
    ///   - countIndex: The column position of the frequency count.
    public func loadBigramDictionary(from url: URL, termIndex: Int = 0, countIndex: Int = 2, termCount: Int = 64000) async throws {
        let expectedComponentsCount = max(termIndex + 1, countIndex) + 1
        bigrams.reserveCapacity(termCount)
        for try await line in url.lines {
            let components = line.split(separator: self.separator, maxSplits: expectedComponentsCount - 1)

            if components.count >= expectedComponentsCount, let count = Int(components[countIndex]) {
                let key = components[termIndex] + " " + components[termIndex + 1]
                self.bigrams[String(key)] = count
                self.bigramCountMin = min(self.bigramCountMin, count)
            }
        }
    }

    /// Load multiple dictionary entries from a file of word/frequency count pairs.
    /// Merges with any dictionary data already loaded.
    /// - Parameters:
    ///   - from: The url of the file.
    ///   - termIndex:The column position of the word.
    ///   - countIndex: The column position of the frequency count.
    ///   - termCount: The number of words in the dictionary. If provided, it can speed up the load.
    public func loadDictionary(from url: URL, termIndex: Int = 0, countIndex: Int = 1, termCount: Int = 64000) async throws {
        maxDictionaryWordLength = 0
        let expectedComponentsCount = max(termIndex, countIndex) + 1
        deletes.reserveCapacity(termCount)

        for try await line in url.lines {
            let components = line.split(separator: self.separator, maxSplits: expectedComponentsCount - 1)
            if components.count == expectedComponentsCount, let count = Int(components[countIndex]) {
                let key = components[termIndex]

                self.createDictionaryEntry(key: String(key), count: count)
            }
        }
    }

    /// Create a dictionary from a file containing plain text.
    /// Merges with any dictionary data already loaded.
    /// - Parameters:
    ///   - from: The url of the file.
    public func createDictionary(from url: URL) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        try createDictionary(from: content)
    }

    /// Create a dictionary from a string containing plain text.
    /// Merges with any dictionary data already loaded.
    /// - Parameters:
    ///   - from: The string containing the words.
    public func createDictionary(from string: String) throws {
        string.enumerateLines { line, _ in
            for word in self.parseWords(line) {
                self.createDictionaryEntry(key: word, count: 1)
            }
        }
    }

    /// Find suggested spellings for a given input word.
    /// - Parameters:
    ///   - input: The word being spell checked.
    ///   - verbosity: The value controlling the quantity/closeness of the retuned suggestions.
    ///   - maxEditDistance: The maximum edit distance between input and suggested words.
    /// - Returns: Array of `SuggestItem` representing suggested correct spellings for the input word, sorted by edit distance, and secondarily by count frequency.
    public func lookup(_ input: String, verbosity: Verbosity, maxEditDistance: Int? = nil) -> [SuggestItem] {
        let maxEditDistance = min(maxEditDistance ?? maxDictionaryEditDistance, maxDictionaryEditDistance)
        var suggestions = [SuggestItem]()
        let inputLen = input.count

        guard inputLen - maxEditDistance <= maxDictionaryWordLength else { return [] }

        if let count = words[input.hashValue]?.1 {
            suggestions.append(SuggestItem(term: input, distance: 0, count: count))
            if verbosity != .all { return suggestions }
        }

        guard maxEditDistance > 0 else { return suggestions }

        var consideredDeletes = Set<Substring>()
        var consideredSuggestions = Set<String>([input])

        var maxEditDistance2 = maxEditDistance
        var candidatePointer = 0
        var candidates = [Substring]()

        let inputPrefixLen = min(inputLen, prefixLength)
        candidates.append(input.prefix(inputPrefixLen))

        while candidatePointer < candidates.count {
            let candidate = candidates[candidatePointer]
            candidatePointer += 1
            let candidateLen = candidate.count
            let lengthDiff = inputPrefixLen - candidateLen

            if lengthDiff > maxEditDistance2 {
                if verbosity == .all { continue }
                break
            }

            for suggestion in resolveToWords(hash: candidate.hashValue) {
                let suggestionLen = suggestion.count
                if suggestion == input { continue }
                if abs(suggestionLen - inputLen) > maxEditDistance2 || suggestionLen < candidateLen ||
                    (suggestionLen == candidateLen && suggestion != candidate) { continue }

                let suggPrefixLen = min(suggestionLen, prefixLength)
                if suggPrefixLen > inputPrefixLen, (suggPrefixLen - candidateLen) > maxEditDistance2 { continue }

                var distance = 0
                let minLength = min(inputLen, suggestionLen)

                if candidateLen == 0 {
                    distance = max(inputLen, suggestionLen)
                    if distance > maxEditDistance2 || !consideredSuggestions.insert(suggestion).inserted { continue }
                } else if suggestionLen == 1 {
                    if !input.contains(suggestion) {
                        distance = inputLen
                    } else {
                        distance = inputLen - 1
                    }
                    if distance > maxEditDistance2 || !consideredSuggestions.insert(suggestion).inserted { continue }
                } else if prefixLength - maxEditDistance == candidateLen,
                          (minLength - prefixLength > 1 && !input.hasSuffix(suggestion.suffix(minLength - prefixLength))) ||
                          (minLength - prefixLength > 0 && input[prefixLength - minLength] != suggestion[prefixLength - minLength] &&
                              ((input[prefixLength - minLength - 1] != suggestion[prefixLength - minLength]) || (input[prefixLength - minLength] != suggestion[prefixLength - minLength - 1]))) {
                    continue
                } else {
                    if verbosity != .all && !deleteInSuggestionPrefix(candidate, candidateLen, suggestion, suggestionLen) ||
                        !consideredSuggestions.insert(suggestion).inserted { continue }
                    distance = input.distanceDamerauLevenshtein(between: suggestion)
                }

                if distance <= maxEditDistance2 {
                    let count = words[suggestion.hashValue]?.1 ?? 0
                    let si = SuggestItem(term: suggestion, distance: distance, count: count)
                    if !suggestions.isEmpty {
                        switch verbosity {
                        case .closest:
                            if distance < maxEditDistance2 { suggestions.removeAll() }
                        case .top:
                            if distance < maxEditDistance2 || count > suggestions[0].count {
                                maxEditDistance2 = distance
                                suggestions[0] = si
                            }
                            continue
                        case .all:
                            break
                        }
                    }
                    if verbosity != .all { maxEditDistance2 = distance }
                    suggestions.append(si)
                }
            }


            if lengthDiff < maxEditDistance, candidateLen <= prefixLength {
                if verbosity != .all, lengthDiff >= maxEditDistance2 { continue }
                for index in candidate.indices {
                    let delete = candidate.prefix(upTo: index) + candidate.suffix(from: candidate.index(after: index))

                    if consideredDeletes.insert(delete).inserted {
                        candidates.append(delete)
                    }
                }
            }
        }

        return suggestions.sorted()
    }

    /// Find suggested spellings for a multi-word input string (supports word splitting/merging).
    /// - Parameters:
    ///   - input: The string being spell checked.
    ///   - maxEditDistance: The maximum edit distance between input and suggested words.
    /// - Returns: Array of `SuggestItem`  representing suggested correct spellings for the input string.
    public func lookupCompound(_ input: String, maxEditDistance: Int? = nil) -> [SuggestItem] {
        let maxEditDistance = min(maxEditDistance ?? maxDictionaryEditDistance, maxDictionaryEditDistance)
        let termList = parseWords(input)
        var suggestions = [SuggestItem]()
        var suggestionParts = [SuggestItem]()

        var lastCombi = false

        for i in 0 ..< termList.count {
            suggestions = lookup(termList[i], verbosity: .top, maxEditDistance: maxEditDistance)

            if i > 0, !lastCombi {
                var suggestionsCombi = lookup(termList[i - 1] + termList[i], verbosity: .top, maxEditDistance: maxEditDistance)
                if !suggestionsCombi.isEmpty {
                    let best1 = suggestionParts[suggestionParts.count - 1]
                    let best2: SuggestItem = if !suggestions.isEmpty {
                        suggestions[0]
                    } else {
                        SuggestItem(term: termList[i], distance: maxEditDistance + 1, count: Int(10 / pow(10.0, Double(termList[i].count))))
                    }

                    let distance1 = best1.distance + best2.distance

                    if distance1 >= 0, suggestionsCombi[0].distance + 1 < distance1 ||
                        (suggestionsCombi[0].distance + 1 == distance1 && Double(suggestionsCombi[0].count) > Double(best1.count) / Double(totalCorpusWords) * Double(best2.count)) {
                        suggestionsCombi[0].distance += 1
                        suggestionParts[suggestionParts.count - 1] = suggestionsCombi[0]
                        lastCombi = true
                        continue
                    }
                }
            }

            lastCombi = false

            if !suggestions.isEmpty, suggestions[0].distance == 0 || termList[i].count == 1 {
                suggestionParts.append(suggestions[0])
            } else {
                var suggestionSplitBest: SuggestItem?

                if !suggestions.isEmpty {
                    suggestionSplitBest = suggestions[0]
                }

                if termList[i].count > 1 {
                    for j in 1 ..< termList[i].count {
                        let part1 = String(termList[i].prefix(j))
                        let part2 = String(termList[i].suffix(termList[i].count - j))

                        var suggestionSplit = SuggestItem(term: "", distance: 0, count: 0)
                        let suggestions1 = lookup(part1, verbosity: .top, maxEditDistance: maxEditDistance)

                        if !suggestions1.isEmpty {
                            let suggestions2 = lookup(part2, verbosity: .top, maxEditDistance: maxEditDistance)

                            if !suggestions2.isEmpty {
                                suggestionSplit.term = suggestions1[0].term + " " + suggestions2[0].term
                                var distance2 = termList[i].distanceDamerauLevenshtein(between: suggestionSplit.term)
                                if distance2 < 0 { distance2 = maxEditDistance + 1 }

                                if let best = suggestionSplitBest {
                                    if distance2 > best.distance { continue }
                                    if distance2 < best.distance { suggestionSplitBest = nil }
                                }

                                suggestionSplit.distance = distance2
                                if let bigramCount = bigrams[suggestionSplit.term] {
                                    suggestionSplit.count = bigramCount

                                    if !suggestions.isEmpty {
                                        if suggestions1[0].term + suggestions2[0].term == termList[i] {
                                            suggestionSplit.count = max(suggestionSplit.count, suggestions[0].count + 2)
                                        } else if suggestions1[0].term == suggestions[0].term || suggestions2[0].term == suggestions[0].term {
                                            suggestionSplit.count = max(suggestionSplit.count, suggestions[0].count + 1)
                                        }
                                    } else if suggestions1[0].term + suggestions2[0].term == termList[i] {
                                        suggestionSplit.count = max(suggestionSplit.count, max(suggestions1[0].count, suggestions2[0].count) + 2)
                                    }
                                } else {
                                    suggestionSplit.count = min(bigramCountMin, Int(Double(suggestions1[0].count) / Double(totalCorpusWords) * Double(suggestions2[0].count)))
                                }

                                if suggestionSplitBest == nil || suggestionSplit.count > suggestionSplitBest!.count {
                                    suggestionSplitBest = suggestionSplit
                                }
                            }
                        }
                    }

                    if let bestSplit = suggestionSplitBest {
                        suggestionParts.append(bestSplit)
                    } else {
                        let si = SuggestItem(term: termList[i], distance: maxEditDistance + 1, count: Int(10 / pow(10.0, Double(termList[i].count))))
                        suggestionParts.append(si)
                    }
                } else {
                    let si = SuggestItem(term: termList[i], distance: maxEditDistance + 1, count: Int(10 / pow(10.0, Double(termList[i].count))))
                    suggestionParts.append(si)
                }
            }
        }

        var suggestion = SuggestItem(term: "", distance: 0, count: 0)
        var count = Double(totalCorpusWords)
        var s = ""

        for si in suggestionParts {
            s += si.term + " "
            count *= Double(si.count) / Double(totalCorpusWords)
        }

        suggestion.count = Int(count)
        suggestion.term = s.trimmingCharacters(in: .whitespaces)
        suggestion.distance = input.distanceDamerauLevenshtein(between: suggestion.term)

        return [suggestion]
    }

    /// Divides a string into words by inserting missing spaces at the appropriate positions.
    /// Misspelled words are corrected and do not affect segmentation, existing spaces are allowed and considered for optimum segmentation.
    /// - Parameters:
    ///   - input:
    ///   - maxEditDistance:
    /// - Returns: A `Segmentation` struct, containing:
    ///    - the segmented string,
    ///    - the segmented and spelling corrected string,
    ///    - the Edit distance sum between input string and corrected string,
    ///    - the Sum of word occurence probabilities in log scale (a measure of how common and probable the corrected segmentation is).

    public func wordSegmentation(_ input: String, maxEditDistance: Int = 0) -> Segmentation {
        // Normalize ligatures and replace hyphens
        let input = input.precomposedStringWithCompatibilityMapping.replacingOccurrences(of: "\u{002D}", with: "")

        let arraySize = min(maxDictionaryWordLength, input.count)
        var compositions: [Segmentation] = Array(repeating: Segmentation(), count: arraySize)
        var circularIndex = -1

        // Outer loop (columns): all possible part start positions
        for j in 0 ..< input.count {
            // Inner loop (rows): all possible part lengths (from start position)

            for i in 1 ... min(input.count - j, maxDictionaryWordLength) {
                guard var partSubstr = input[j ..< j + i] else { continue }

                var separatorLength = 0
                var topEd = 0
                var topProbabilityLog = 0.0
                var topResult = ""

                if partSubstr.first?.isWhitespace == true {
                    // Remove leading space for edit distance calculation
                    partSubstr.removeFirst()
                } else {
                    // Space had to be inserted
                    separatorLength = 1
                }

                // Calculate edit distance
                topEd += partSubstr.count
                let part = partSubstr.replacingOccurrences(of: " ", with: "")
                topEd -= part.count

                let results = lookup(part.lowercased(), verbosity: .top, maxEditDistance: maxEditDistance)

                if let result = results.first {
                    topResult = result.term
                    if part.first?.isUppercase == true {
                        topResult = topResult.prefix(1).uppercased() + topResult.dropFirst()
                    }
                    topEd += result.distance
                    topProbabilityLog = log10(Double(result.count) / Double(totalCorpusWords))
                } else {
                    topResult = part
                    topEd += part.count
                    topProbabilityLog = log10(10.0 / (Double(totalCorpusWords) * pow(10.0, Double(part.count))))
                }

                let destinationIndex = (i + circularIndex) % arraySize

                if j == 0 {
                    compositions[destinationIndex] = Segmentation(segmentedString: part, correctedString: topResult, distanceSum: topEd, probabilityLogSum: topProbabilityLog)
                } else if i == maxDictionaryWordLength
                    || ((compositions[circularIndex].distanceSum + topEd == compositions[destinationIndex].distanceSum) || (compositions[circularIndex].distanceSum + separatorLength + topEd == compositions[destinationIndex].distanceSum)) && (compositions[destinationIndex].probabilityLogSum < compositions[circularIndex].probabilityLogSum + topProbabilityLog)
                    || compositions[circularIndex].distanceSum + separatorLength + topEd < compositions[destinationIndex].distanceSum {
                    if topResult.count == 1, topResult.first?.isPunctuation == true {
                        compositions[destinationIndex] = Segmentation(
                            segmentedString: compositions[circularIndex].segmentedString + part,
                            correctedString: compositions[circularIndex].correctedString + topResult,
                            distanceSum: compositions[circularIndex].distanceSum + topEd,
                            probabilityLogSum: compositions[circularIndex].probabilityLogSum + topProbabilityLog
                        )
                    } else {
                        compositions[destinationIndex] = Segmentation(
                            segmentedString: compositions[circularIndex].segmentedString + " " + part,
                            correctedString: compositions[circularIndex].correctedString + " " + topResult,
                            distanceSum: compositions[circularIndex].distanceSum + separatorLength + topEd,
                            probabilityLogSum: compositions[circularIndex].probabilityLogSum + topProbabilityLog
                        )
                    }
                }
            }
            circularIndex += 1
            if circularIndex == arraySize { circularIndex = 0 }
        }

        return compositions[circularIndex]
    }

    /// Completes a correctly spelled prefix to different suggestions
    /// - Parameters:
    ///   - input: the prefix needed to be completed
    /// - Returns: Array of `SuggestItem`  representing suggested correct spellings for the input string.
    public func complete(_ input: String) -> [SuggestItem] {
        let uncodeInput = input.unicodeScalars
        let results = words.values.filter { $0.0.unicodeScalars.starts(with: uncodeInput) }
        var suggestions = [SuggestItem]()
        for term in results {
            let item = SuggestItem(term: term.0, distance: term.1 - input.count, count: term.1)
            suggestions.append(item)
        }

        return suggestions.sorted { item1, item2 in
            item1.count > item2.count
        }
    }

    /// Create/Update an entry in the dictionary. For every word there are deletes with an edit distance of 1..maxEditDistance created and added to the dictionary. Every delete entry has a suggestions list, which points to the original term(s) it was created from.
    /// The dictionary may be dynamically updated (word frequency and new words) at any time by calling CreateDictionaryEntry
    /// - Parameters:
    ///   - key: The word to add to dictionary.
    ///   - count: The frequency count for word.
    /// - Returns: True if the word was added as a new correctly spelled word, or false if the word is added as a below threshold word, or updates an existing correctly spelled word.
    public func createDictionaryEntry(key: String, count: Int) {
        guard count >= 0 else { return }

        totalCorpusWords += count

        if let previousCount = words[key.hashValue]?.1 {
            words[key.hashValue] = (key, count + previousCount)
            return
        }

        words[key.hashValue] = (key, count)
        maxDictionaryWordLength = max(maxDictionaryWordLength, key.count)

        let edits = editsPrefix(key)
        let hash = key.hashValue

        for delete in edits {
            deletes[delete.hashValue, default: []].append(hash)
        }
    }

    private func resolveToWords(hash: Int) -> [String] {
        guard let wordHashes = deletes[hash] else { return [] }
        return wordHashes.compactMap { words[$0]?.0 }
    }

    private func deleteInSuggestionPrefix(_ delete: Substring, _ deleteLen: Int, _ suggestion: String, _ suggestionLen: Int) -> Bool {
        guard deleteLen != 0 else { return true }

        let suggestionLen = min(prefixLength, suggestionLen)
        let suggestionPrefix = suggestion.prefix(suggestionLen)
        return !delete.prefix(deleteLen).contains { !suggestionPrefix.contains($0) }
    }

    private func parseWords(_ text: String) -> [String] {
        var words = [String]()
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { substring, _, _, _ in
            if let substring {
                words.append(substring)
            }
        }
        return words
    }

    private func editsPrefix(_ key: String) -> Set<Substring> {
        var prefixWords = Set<Substring>()
        if key.count <= maxDictionaryEditDistance { prefixWords.insert("") }
        let prefixKey = key.prefix(prefixLength)
        prefixWords.insert(prefixKey)
        edits(prefixKey, 0, &prefixWords)

        return prefixWords
    }

    private func edits(_ word: Substring, _ editDistance: Int, _ deleteWords: inout Set<Substring>) {
        let editDistance = editDistance + 1
        for index in word.indices {
            let delete = word.prefix(upTo: index) + word.suffix(from: word.index(after: index))
            if deleteWords.insert(delete).inserted, editDistance < maxDictionaryEditDistance, delete.count > 1 {
                edits(delete, editDistance, &deleteWords)
            }
        }
    }
}
