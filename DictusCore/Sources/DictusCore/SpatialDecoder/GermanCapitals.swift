// DictusCore/Sources/DictusCore/SpatialDecoder/GermanCapitals.swift
//
// Ported from Hex (anomalyco/hex@4f3a45e0, ios/HEXShared/FullKeyboard/GermanCapitals.swift)
// (#948, German swipe typing).
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
// What the port changed: the shares are kept as one byte per word of the German model
// (95,000 bytes) rather than a dictionary of strings, since the keyboard extension counts
// every megabyte; Dictus's table is its own (`tools/typing-model/build-german-capitals.py`,
// cross-checked with a CC0 word list); and it serves swipe typing, where Hex reads it in
// autocorrect. Hex's shares and its determiner list are unchanged.
import Foundation

/// German nouns' share of capitalised uses, read from `de.capitals` beside the German model.
/// German writes every noun with a capital and the model is lowercase, so this table is what
/// knows that "haus" is "Haus" and "gehen" stays "gehen".
///
/// Each line is `word<TAB>percent`: how often the word is written with a capital in the
/// books the model was counted from (100 for a word the word list has only with a capital),
/// capped at 94 for a word that is also a common verb form or stem ("frage", "kauf").
public struct GermanCapitals: Sendable {
    /// A word written with a capital this often is a noun wherever it stands.
    public static let alwaysShare: UInt8 = 95
    /// From this share it is a noun after an article or determiner ("das leben") and
    /// whatever shares its spelling elsewhere ("zu leben", "ich frage").
    public static let sometimesShare: UInt8 = 50

    private let model: SpatialDecoderModel
    /// The share of each model word, by its index; 0 for a word the table leaves out.
    private let shares: [UInt8]

    /// The table at `path` for `model` (the German model it was built from); nil when the
    /// file is missing or holds no word of the model.
    public init?(path: String, model: SpatialDecoderModel) {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        var shares = [UInt8](repeating: 0, count: model.wordCount)
        var found = false
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count == 2, let percent = UInt8(fields[1]),
                  (Self.sometimesShare...100).contains(percent),
                  let index = model.index(of: String(fields[0])) else { continue }
            shares[index] = percent
            found = true
        }
        guard found else { return nil }
        self.model = model
        self.shares = shares
    }

    /// The share of the word's uses written with a capital (50-100), or nil when the table
    /// leaves it out.
    public func percent(of word: String) -> UInt8? {
        guard let index = model.index(of: word.lowercased()), shares[index] > 0 else { return nil }
        return shares[index]
    }

    /// Whether `word`, all lowercase, is a noun here: written with a capital at least
    /// `alwaysShare` percent of the time, or `sometimesShare` percent after an article or a
    /// determiner (`previous`, lowercase).
    public func capitalises(_ word: String, after previous: String?) -> Bool {
        guard word.count >= 2, word == word.lowercased(), let share = percent(of: word) else { return false }
        if share >= Self.alwaysShare { return true }
        return previous.map { Self.determiners.contains($0.lowercased()) } ?? false
    }

    /// `reading` as German writes it after `previous`: "haus" is "Haus", "gehen" stays.
    public func written(_ reading: String, after previous: String?) -> String {
        guard capitalises(reading, after: previous), let first = reading.first else { return reading }
        return first.uppercased() + reading.dropFirst()
    }

    /// A swipe's readings as German writes them, after the text before the cursor.
    public func written(_ readings: [String], before: String?) -> [String] {
        let previous = SwipeTypingText.previousWord(before: before)
        return readings.map { written($0, after: previous) }
    }

    /// Articles, determiners, their contractions and possessives, after which German writes
    /// the noun with a capital ("das haus", "im haus", "mein haus"), so a word the books
    /// write both ways is a noun here ("das leben", never "zu leben"). Hex's list: "in" is
    /// in ("in Ruhe", "in Frage"); "ihr" is out, being the pronoun before a verb more often
    /// than the possessive ("wollt ihr essen"); "ohne" is out ("ohne essen").
    public static let determiners: Set<String> = [
        "der", "die", "das", "den", "dem", "des",
        "ein", "eine", "einen", "einem", "einer", "eines",
        "kein", "keine", "keinen", "keinem", "keiner", "keines",
        "mein", "meine", "meinen", "meinem", "meiner", "meines",
        "dein", "deine", "deinen", "deinem", "deiner", "deines",
        "sein", "seine", "seinen", "seinem", "seiner", "seines",
        "ihre", "ihren", "ihrem", "ihrer", "ihres",
        "unser", "unsere", "unseren", "unserem", "unserer", "unseres",
        "euer", "eure", "euren", "eurem", "eurer", "eures",
        "dies", "dieser", "diese", "dieses", "diesem", "diesen",
        "jeder", "jede", "jedes", "jedem", "jeden",
        "im", "in", "am", "zum", "zur", "vom", "beim", "ins", "ans"
    ]
}
