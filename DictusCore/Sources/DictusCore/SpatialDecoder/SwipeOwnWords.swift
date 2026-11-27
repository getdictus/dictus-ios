// DictusCore/Sources/DictusCore/SpatialDecoder/SwipeOwnWords.swift
//
// After Hex's own words for swipe typing (anomalyco/hex@bfa25200aef7bce802c6c87aa9914dfd83626c69:
// `AutocorrectEngine.ownWords` in ios/HEXShared/FullKeyboard/Autocorrect/AutocorrectEngine.swift,
// `SwipeTyping.syncWords` in ios/HEXShared/FullKeyboard/SwipeTyping.swift), rewritten on
// Dictus's stores (#1090). No Hex code or data is copied; the idea and the cost are Hex's
// (`SwipeDecoder.ownWordCost`, ported with the decoder).
//
// MIT License
//
// Copyright (c) 2026 Christopher Langton
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// What differs from Hex: the learned words are `UserDictionary`'s, read under tap typing's
// adoption rule (`LearnedWordCorrection.isAdopted`), where Hex reads words kept twice; the
// contacts and text replacements are `SupplementaryLexicon`'s, written by its own decision;
// a learned word keeps the casing it was typed in (`LearnedWordCasing`), where Hex's are
// lowercase.
import Foundation

/// The user's own words for swipe typing (#1090): words the keyboard learned, contact names
/// and text replacements, the app names `CuratedNames` spells and the language's brand
/// names (`SwipeBrands`), read beside the model's words, and written as the user writes them.
///
/// WHY only adopted learned words (ADR 0004, amended by #1090): a swipe types its reading
/// without a tap, as space applies a correction. So a learned word reaches a swipe under the
/// rule that lets one reach a correction: used at least twice (`LearnedWordCorrection
/// .isAdopted`). One refusal learns a word at one use, and that word is often the typo itself
/// (#872): it is still offered in the bar and never corrected, but no swipe reads it.
///
/// WHY no such rule for the lexicon: a contact name or a text replacement is something the
/// user wrote in Réglages or Contacts, never a typo the keyboard picked up. Tap typing keeps
/// and recases them on their first use too.
public enum SwipeOwnWords {

    /// The words a swipe reads beside its model, once each and sorted, so the keyboard can
    /// tell when they changed: the adopted learned words (`learnedUses`, each word's usage
    /// count, `UserDictionary.allLearnedWords`), the lexicon's words
    /// (`SupplementaryLexicon.lowercasedWords`) and `CuratedNames`, lowercased, then the
    /// language's brand names (`brands`, `SwipeBrands.names(for:)`) in their casing. Words of
    /// one letter are tapped, never swiped.
    ///
    /// A brand goes in in its casing because the decoder hands back the text it was given
    /// (« Apple »), and `written` leaves a reading that is not lowercase as it is. It goes in
    /// only when none of the user's words is the same word: a learned « apple » or a contact
    /// is the user's own, and is written as the user writes it.
    public static func words(learnedUses: [String: Int], lexiconWords: [String], brands: [String] = []) -> [String] {
        var words = Set<String>()
        for (word, uses) in learnedUses where LearnedWordCorrection.isAdopted(uses: uses) {
            words.insert(word.lowercased())
        }
        for word in lexiconWords { words.insert(word.lowercased()) }
        for name in CuratedNames.recased { words.insert(name.lowercased()) }
        let own = words
        for name in brands where !own.contains(name.lowercased()) { words.insert(name) }
        return words.filter { $0.count >= 2 }.sorted()
    }

    /// Adds `words` to what the decoder reads beside its model, at Hex's cost of one of your
    /// own words (about a word ranked 20,000th), less the words the model has.
    ///
    /// WHY not the model's words: the model already reads them, at its own cost. Reading one
    /// as an own word instead would change how it ranks against every other word on its path,
    /// and a swipe of a dictionary word must read as it did before (#1090's bench). How it is
    /// written still follows the user (`written`).
    public static func add(_ words: [String], to extra: inout SwipeDecoder.ExtraWords, model: SpatialDecoderModel) {
        extra.add(words.filter { !model.contains($0.lowercased()) }, cost: SwipeDecoder.ownWordCost, model: model)
    }

    /// What a learned word is to a swipe: its usage count and the form it is typed in.
    public struct Learned: Equatable, Sendable {
        public var uses: Int
        public var casing: String?

        public init(uses: Int, casing: String?) {
            self.uses = uses
            self.casing = casing
        }
    }

    /// `reading` as the user writes it, before the sentence's capital and caps lock
    /// (`SwipeTypingText.cased`) apply:
    /// 1. a word of the lexicon or of `CuratedNames` in its casing (« zofiak » → « Zofiak »,
    ///    « whatsapp » → « WhatsApp »), by the lexicon's own decision, the one a tapped word
    ///    gets: a contact named « Pierre » leaves « pierre » alone, since the dictionary has it;
    /// 2. an adopted learned word in the form the user types it in (« Apple », « WisprFlow »);
    /// 3. else as the model spells it.
    ///
    /// A reading that is not lowercase (« I'm ») is already written and comes back as it is.
    /// A lexicon verdict that changes more than the casing (a text replacement's shortcut)
    /// is not a swipe's to apply.
    ///
    /// - Parameters:
    ///   - lexiconDecision: the lexicon's verdict on a word, with the dictionary check tap
    ///     typing makes (`TextPredictionEngine.lexiconDecision(for:)`).
    ///   - learned: the learned word's count and casing, nil when it is not learned.
    public static func written(
        _ reading: String,
        lexiconDecision: (String) -> SupplementaryLexicon.Decision?,
        learned: (String) -> Learned?
    ) -> String {
        guard reading == reading.lowercased() else { return reading }
        if case let .replace(text)? = lexiconDecision(reading), text.lowercased() == reading {
            return text
        }
        if let word = learned(reading), LearnedWordCorrection.isAdopted(uses: word.uses),
           let casing = word.casing, casing.lowercased() == reading {
            return casing
        }
        return reading
    }
}
