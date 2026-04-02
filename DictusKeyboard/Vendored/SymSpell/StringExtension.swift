// Vendored from SymSpellSwift by gdetari (MIT License)
// https://github.com/gdetari/SymSpellSwift
// Adapted for Dictus keyboard extension
//
// String+Extension.swift
// SymSpellSwift
//
// Created by Gabor Detari gabor@detari.dev
// Copyright (c) 2024 Gabor Detari. All rights reserved.
//

import Foundation

extension String {
    func distanceDamerauLevenshtein(between target: String) -> Int {
        guard count > 0 else { return target.count }
        guard target.count > 0 else { return count }

        var da: [Character: Int] = [:]
        var d = Array(repeating: Array(repeating: 0, count: target.count + 2), count: count + 2)

        let maxdist = count + target.count
        d[0][0] = maxdist
        d[1][0] = maxdist
        d[0][1] = maxdist

        for i in 2 ... count + 1 {
            var db = 1
            d[i][0] = maxdist
            d[i][1] = i - 1

            let selfChar = self[index(startIndex, offsetBy: i - 2)]

            for j in 2 ... target.count + 1 {
                d[0][j] = maxdist
                d[1][j] = j - 1

                let targetChar = target[target.index(target.startIndex, offsetBy: j - 2)]

                let k = da[targetChar] ?? 1
                let l = db
                var cost = 1
                if selfChar == targetChar {
                    cost = 0
                    db = j
                }

                d[i][j] = Swift.min(
                    d[i - 1][j - 1] + cost, // substitution
                    d[i][j - 1] + 1, // injection
                    d[i - 1][j] + 1, // deletion
                    d[k - 1][l - 1] + i - k + j - l - 1 // transposition
                )
            }

            da[selfChar] = i
        }

        return d[count + 1][target.count + 1]
    }

    subscript(i: Int) -> Character? {
        guard -count...count ~= i else { return nil }

        return self[index(i >= 0 ? startIndex : endIndex, offsetBy: i)]
    }

    subscript(range: Range<Int>) -> Substring? {
        guard let start = index(startIndex, offsetBy: range.lowerBound, limitedBy: endIndex),
                let end = index(startIndex, offsetBy: range.upperBound, limitedBy: endIndex) else { return nil }

        return self[start ..< end]
    }
}
