// DictusCore/Tests/DictusCoreTests/LoneLetterCorrectionTests.swift
// A French lone letter is corrected to the neighbouring key that is a word, or kept (#977).

import XCTest
@testable import DictusCore

final class LoneLetterCorrectionTests: XCTestCase {

    private let french = frenchProfile

    /// The rule alone, as `SupplementaryLexicon.earlyAnswer` asks it, on AZERTY unless told.
    private func decide(
        _ word: String, context: String? = nil, layout: LayoutType = .azerty,
        learned: Set<String> = []
    ) -> LoneLetterCorrection.Decision? {
        LoneLetterCorrection.decision(
            for: word, words: french.loneLetterWords, layout: layout, context: context,
            markers: french.loneLetterMarkers, homographs: french.contextualHomographs,
            isLearned: learned.contains
        )
    }

    // MARK: - Corrected

    /// The device report (2026-11-19): `vas avoir des problème z` kept the `z`.
    func testTheReportedSentenceGetsItsA() {
        XCTAssertEqual(decide("z", context: "vas avoir des problème z"), .correct("a"))
    }

    func testTheKeysNextToAAreCorrectedToA() {
        XCTAssertEqual(decide("z"), .correct("a"))
        XCTAssertEqual(decide("q"), .correct("a"))
    }

    func testTheKeysNextToYAreCorrectedToY() {
        for letter in ["t", "u", "g", "h"] {
            XCTAssertEqual(decide(letter), .correct("y"), letter)
        }
        XCTAssertEqual(decide("t", context: "il t"), .correct("y"))
    }

    /// The corrected `a` goes through the a/à rule (#501) as a typed one would.
    func testTheCorrectionTakesTheGraveAccentWhereTheSentenceCallsForIt() {
        XCTAssertEqual(decide("z", context: "je vais z"), .correct("\u{00E0}"))
        XCTAssertEqual(decide("q", context: "il q"), .correct("a"))
    }

    /// The neighbours come from the layout in use: on QWERTY `z` and `q` still touch `a`,
    /// and `w` does too.
    func testNeighboursFollowTheLayout() {
        XCTAssertEqual(decide("z", layout: .qwerty), .correct("a"))
        XCTAssertEqual(decide("q", layout: .qwerty), .correct("a"))
        XCTAssertEqual(decide("w", layout: .qwerty), .correct("a"))
        XCTAssertEqual(decide("w", layout: .azerty), .keep)
    }

    // MARK: - Kept

    /// `a`, `à` and `y` are words: the usual path decides them, the a/à rule included.
    func testTheLettersThatAreWordsAreNotTheRules() {
        for word in ["a", "\u{00E0}", "y", "A", "Y"] {
            XCTAssertNil(decide(word), word)
        }
    }

    /// A letter with no neighbouring word stays as typed: `l` is not `le`.
    func testALetterWithNoNeighbouringWordIsKept() {
        for letter in ["b", "c", "d", "e", "l", "m", "n", "s", "x"] {
            XCTAssertEqual(decide(letter), .keep, letter)
        }
    }

    /// `plan B`, `vitamine C`, and an initial at the start of a sentence.
    func testACapitalLetterIsKept() {
        XCTAssertEqual(decide("B", context: "on passe au plan B"), .keep)
        XCTAssertEqual(decide("Z", context: "la lettre Z"), .keep)
        XCTAssertEqual(decide("T", context: "T"), .keep)
        XCTAssertEqual(decide("H", context: "Merci. H"), .keep)
    }

    /// Titus's review of #1061: after a determiner or `lettre` the letter is the letter.
    /// `le h aspiré` was `le y aspiré` on develop too, through the trie.
    func testALetterNamedAsALetterIsKept() {
        XCTAssertEqual(decide("h", context: "le h"), .keep)
        XCTAssertEqual(decide("z", context: "un z"), .keep)
        XCTAssertEqual(decide("b", context: "la lettre b"), .keep)
        XCTAssertEqual(decide("z", context: "la lettre z"), .keep)
        XCTAssertEqual(decide("p", context: "du p"), .keep)
        XCTAssertEqual(decide("t", context: "Le t"), .keep)
        XCTAssertEqual(decide("q", context: "avec une q"), .keep)
        XCTAssertEqual(decide("u", context: "des u"), .keep)
        XCTAssertEqual(decide("z", context: "le mot d\u{2019} z"), .keep)
    }

    /// A marker counts only right before the letter, and `les` is not one: it is also the
    /// pronoun of `il les a vus`.
    func testOnlyTheWordRightBeforeMarksALetter() {
        XCTAssertEqual(decide("z", context: "le problème z"), .correct("a"))
        XCTAssertEqual(decide("t", context: "il t"), .correct("y"))
        XCTAssertEqual(decide("z", context: "il les z"), .correct("a"))
        // Nothing before it: the start of a sentence, where #501 writes `à` (`À demain`).
        XCTAssertEqual(decide("z", context: "z"), .correct("\u{00E0}"))
    }

    func testALearnedLetterIsKept() {
        XCTAssertEqual(decide("z", learned: ["z"]), .keep)
        XCTAssertEqual(decide("q", learned: ["z"]), .correct("a"))
    }

    /// `le mot commence par l'h`: develop wrote `l'y`, because the French dictionary has
    /// no `h` and the trie read it alone.
    func testALetterAfterAnApostropheIsKept() {
        XCTAssertEqual(decide("l'h", context: "le mot commence par l'h"), .keep)
        XCTAssertEqual(decide("l\u{2019}h"), .keep)
        XCTAssertEqual(decide("qu'z"), .keep)
        XCTAssertEqual(decide("L'H"), .keep)
    }

    /// An elided `a` or `y` (`l'a`, `j'y`), a longer word and a bare prefix are the usual
    /// path's.
    func testAnElidedWordIsNotTheRules() {
        for word in ["l'a", "j'y", "qu'\u{00E0}", "l'eau", "aujourd'hui", "l'", "l'1"] {
            XCTAssertNil(decide(word), word)
        }
    }

    func testOnlyLettersAreTheRules() {
        XCTAssertNil(decide(""))
        XCTAssertNil(decide("za"))
        XCTAssertNil(decide("-"))
        XCTAssertNil(decide("'"))
    }

    /// The other languages have no list yet (#977 asks for them separately).
    func testTheRuleIsOffWhereNoListWasWritten() {
        for profile in [englishProfile, spanishProfile, germanProfile] {
            XCTAssertNil(profile.loneLetterWords, profile.code)
            XCTAssertNil(LoneLetterCorrection.decision(
                for: "z", words: profile.loneLetterWords, layout: profile.defaultLayout, isLearned: { _ in false }
            ), profile.code)
        }
    }

    // MARK: - The user's lexicon, as on a real iPhone

    /// What a device lexicon holds next to names (`FrenchAGraveTests.deviceLexicon`):
    /// `a` and `ma`, and here a contact's initial `T`. Device test of #1061
    /// (2026-11-25): `il t a` stayed `il t`, then became `il t à`.
    private let deviceLexicon = SupplementaryLexicon(entries: [
        (userInput: "a", documentText: "a"),
        (userInput: "ma", documentText: "ma"),
        (userInput: "T", documentText: "T"),
        (userInput: "Zofiak", documentText: "Zofiak")
    ])

    /// The French dictionary holds every letter but `h`, `p` and `r`; a longer word is
    /// taken as known, which is all the lexicon asks.
    private static func frenchDictionaryKnows(_ word: String) -> Bool {
        !["h", "p", "r"].contains(word.lowercased())
    }

    /// `earlyAnswer` as `TextPredictionEngine` asks it on space: the previous word
    /// and the text before the cursor both come from `context`.
    private func early(
        _ word: String, _ context: String, lexicon: SupplementaryLexicon? = nil
    ) -> SupplementaryLexicon.EarlyAnswer? {
        let words = context.split(separator: " ").map(String.init)
        return (lexicon ?? deviceLexicon).earlyAnswer(
            for: word, previousWord: words.dropLast().last, context: context,
            rules: .init(profile: french, layout: .azerty, isLearned: { _ in false }),
            isDictionaryWord: Self.frenchDictionaryKnows(word)
        )
    }

    /// The `T` of a contact kept the `t` before the rule could see it: a lexicon word the
    /// dictionary knows yields to the rule, as it yields to the context rules (#501).
    func testALexiconLetterTheDictionaryKnowsYieldsToTheRule() {
        XCTAssertEqual(early("t", "il t"), .loneLetter(.correct("y")))
        XCTAssertEqual(early("t", "il t", lexicon: .empty), .loneLetter(.correct("y")))
        XCTAssertEqual(early("z", "problème z"), .loneLetter(.correct("a")))
    }

    /// A name the dictionary lacks, and a shortcut, still come first.
    func testALexiconNameOrShortcutStillComesFirst() {
        let contactH = SupplementaryLexicon(entries: [(userInput: "H", documentText: "H")])
        XCTAssertEqual(early("h", "il h", lexicon: contactH), .lexicon(.keep))
        XCTAssertEqual(early("h", "il h", lexicon: .empty), .loneLetter(.correct("y")))
        let shortcut = SupplementaryLexicon(entries: [(userInput: "t", documentText: "toi")])
        XCTAssertEqual(early("t", "il t", lexicon: shortcut), .lexicon(.replace(with: "toi")))
    }

    /// The a/à rule reads the text before the cursor, which holds the corrected `y`
    /// once the space after `t` has replaced it: `il y a` keeps the verb. Left as `t`,
    /// the letter read as a noun and `il t a` took the accent.
    func testTheARuleReadsTheCorrectedLetter() {
        XCTAssertEqual(early("a", "il y a"), .lexicon(.keep))
        XCTAssertNil(early("a", "il y a", lexicon: .empty))
        XCTAssertEqual(early("a", "il y en a"), .lexicon(.keep))
        XCTAssertEqual(early("a", "il t a"), .homograph("\u{00E0}"))
    }

    // MARK: - Lists, e-mail addresses and URLs, typed key by key

    /// A document whose mirror always agrees with it.
    private final class Document: TextDocumentEditing {
        var text = ""
        var contextBeforeInput: String? { text.isEmpty ? nil : text }
        func deleteBackward() { if !text.isEmpty { text.removeLast() } }
        func insertText(_ inserted: String) { text += inserted }
    }

    /// What the keyboard does for each key, in `DictusKeyboardBridge`'s order: put back a
    /// correction the key shows was inside an address, then correct the word before the
    /// space or a committing mark unless the token is an address, then insert the key.
    /// `earlyAnswer`, with the device lexicon, stands in for the spell checker: the
    /// lexicon, the lone-letter rule and both context rules, the a/à rule included.
    private func type(_ keys: String, lexicon: SupplementaryLexicon? = nil) -> String {
        let document = Document()
        let mirror = MirrorSyncState()
        var pendingUndo: (original: String, corrected: String)?
        for character in keys {
            let key = String(character)
            if let undo = pendingUndo, AddressCorrectionRevert.apply(
                editor: document, original: undo.original, corrected: undo.corrected, next: key, mirror: mirror
            ) {
                pendingUndo = nil
            }
            if AutocorrectTrigger.commitsWord(key) || key == " " {
                pendingUndo = nil
                if !AddressLikeToken.atCursor(document.text, followedBy: key),
                   let (_, word) = AutocorrectRejectionMemory.wordAtCursor(context: document.contextBeforeInput),
                   let correction = correction(of: word, context: document.text, lexicon: lexicon),
                   case .applied = AutocorrectCountingSite.apply(
                       editor: document, word: word, correction: correction, trailing: "", mirror: mirror
                   ) {
                    pendingUndo = key == " " ? nil : (word, correction)
                }
            }
            document.insertText(key)
        }
        return document.text
    }

    /// The spelling `earlyAnswer` writes for `word`, or nil where it keeps it.
    private func correction(of word: String, context: String, lexicon: SupplementaryLexicon?) -> String? {
        switch early(word, context, lexicon: lexicon) {
        case .loneLetter(.correct(let spelling)), .homograph(let spelling), .contextOverride(let spelling),
             .lexicon(.replace(let spelling)):
            return spelling
        case .loneLetter(.keep), .lexicon(.keep), nil:
            return nil
        }
    }

    func testTheSpaceBarCorrectsTheReportedSentence() {
        XCTAssertEqual(type("vas avoir des problème z "), "vas avoir des problème a ")
        XCTAssertEqual(type("il t a "), "il y a ")
    }

    /// Pierre's device test of #1061 (2026-11-25), with a `T` in the lexicon:
    /// `il t a` gave `il t à`.
    func testIlTAGivesIlYAWithALetterInTheLexicon() {
        XCTAssertEqual(type("il t a "), "il y a ")
        XCTAssertEqual(type("il t avait "), "il y avait ")
        XCTAssertEqual(type("il t en a "), "il y en a ")
        XCTAssertEqual(type("Il t a "), "Il y a ")
        XCTAssertEqual(type("il t a ", lexicon: .empty), "il y a ")
    }

    func testAYTypedRightStays() {
        XCTAssertEqual(type("il y a "), "il y a ")
        XCTAssertEqual(type("il y avait "), "il y avait ")
        XCTAssertEqual(type("il y en a "), "il y en a ")
    }

    /// An elided `t'` is the usual path's, and a letter named as a letter is kept.
    func testAnElidedTAndANamedTAreKept() {
        XCTAssertEqual(type("je t'aime "), "je t'aime ")
        XCTAssertEqual(type("t'as vu "), "t'as vu ")
        XCTAssertEqual(type("je t\u{2019}aime "), "je t\u{2019}aime ")
        XCTAssertEqual(type("la lettre t "), "la lettre t ")
        XCTAssertEqual(type("le t de "), "le t de ")
    }

    /// `problème z` gives what a typed `problème a` gives: the corrected letter goes
    /// through the a/à rule, which keeps the verb after a noun (`le problème a été`).
    func testTheCorrectedLetterTakesTheSameARuleAsATypedOne() {
        XCTAssertEqual(type("problème z "), "problème a ")
        XCTAssertEqual(type("problème a "), "problème a ")
        XCTAssertEqual(type("je vais z "), "je vais \u{00E0} ")
        XCTAssertEqual(type("je vais a "), "je vais \u{00E0} ")
    }

    func testTheSpaceBarKeepsALetterNamedAsALetter() {
        XCTAssertEqual(type("le h aspiré "), "le h aspiré ")
        XCTAssertEqual(type("un z et la lettre b du p "), "un z et la lettre b du p ")
    }

    /// A closing parenthesis does not commit a word, and the space after it finds none.
    func testAListMarkerIsKept() {
        XCTAssertEqual(type("q) oui t) non "), "q) oui t) non ")
    }

    func testALetterInsideAnEmailAddressIsKept() {
        XCTAssertEqual(type("écris à t.martin@gmail.com "), "écris à t.martin@gmail.com ")
        XCTAssertEqual(type("z@exemple.fr "), "z@exemple.fr ")
        XCTAssertEqual(type("jean@q.fr "), "jean@q.fr ")
    }

    func testALetterInsideAUrlIsKept() {
        XCTAssertEqual(type("va sur https://z.fr "), "va sur https://z.fr ")
        XCTAssertEqual(type("va sur www.t.fr "), "va sur www.t.fr ")
        XCTAssertEqual(type("le site q.com "), "le site q.com ")
    }
}
