// Vendored from SymSpellSwift by gdetari (MIT License)
// https://github.com/gdetari/SymSpellSwift
// Adapted for Dictus keyboard extension
//
// SuggestItem.swift
// SymSpellSwift
//
// Created by Gabor Detari gabor@detari.dev
// Copyright (c) 2024 Gabor Detari. All rights reserved.
//

import Foundation

/// Spelling suggestion returned from lookup
public struct SuggestItem: Comparable, Hashable {
    /// The suggested correctly spelled word
    public var term = ""
    /// Edit distance between searched for word and suggestion.
    public var distance = 0
    /// Frequency of suggestion in the dictionary (a measure of how common the word is)
    public var count = 0

    public static func < (lhs: SuggestItem, rhs: SuggestItem) -> Bool {
        lhs.distance == rhs.distance ? lhs.count > rhs.count: lhs.distance < rhs.distance
    }

    public static func == (lhs: SuggestItem, rhs: SuggestItem) -> Bool {
        lhs.term == rhs.term
    }
}
