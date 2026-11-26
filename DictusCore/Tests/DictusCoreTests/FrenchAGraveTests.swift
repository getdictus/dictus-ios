// DictusCore/Tests/DictusCoreTests/FrenchAGraveTests.swift
// French `a` (avoir) or `à` (#501), on real sentences from Tatoeba (tatoeba.org,
// CC BY 2.0 FR) unless marked otherwise.
import XCTest
@testable import DictusCore

final class FrenchAGraveTests: XCTestCase {

    private var rule: ContextualHomograph {
        guard let rule = frenchProfile.contextualHomographs.first(where: { $0.typed == "a" }) else {
            preconditionFailure("French has no a/à rule")
        }
        return rule
    }

    /// Types `sentence` word by word with every `à` typed as `a`, and lets the rule
    /// decide each one when its space is pressed, as the keyboard does.
    private func retyped(_ sentence: String) -> String {
        var text = ""
        for word in sentence.split(separator: " ") {
            if !text.isEmpty { text += " " }
            if word == "a" || word == "\u{00E0}" {
                text += rule.accentedForm(of: "a", context: text + "a") ?? "a"
            } else {
                text += word
            }
        }
        return text
    }

    func test_prepositionIsAccented() {
        let sentences = [
            "Je vais \u{00E0} l'\u{00E9}glise en voiture.",
            "Il est \u{00E0} la hauteur de la t\u{00E2}che.",
            "Je pense \u{00E0} vous tout le temps.",
            "C'est \u{00E0} toi de chanter.",
            "Il a commenc\u{00E9} \u{00E0} travailler s\u{00E9}rieusement.",
            "Je n'arrive pas \u{00E0} le croire !",
            "Tu dois m'aider \u{00E0} r\u{00E9}soudre ce probl\u{00E8}me.",
            "J'ai du mal \u{00E0} entendre.",
            "Elle est arriv\u{00E9}e \u{00E0} temps pour son bus.",
            "Il n'y a rien \u{00E0} annuler.",
            "Fais attention \u{00E0} ce qu'il dit.",
            "Je me suis habitu\u{00E9} \u{00E0} vivre seul.",
            "Nous sommes all\u{00E9}s \u{00E0} Londres l'ann\u{00E9}e derni\u{00E8}re."
        ]
        for sentence in sentences {
            XCTAssertEqual(retyped(sentence), sentence)
        }
    }

    func test_verbIsKept() {
        let sentences = [
            "Elle a le teint clair alors que son fr\u{00E8}re a la peau fonc\u{00E9}e.",
            "Il y a un probl\u{00E8}me que tu ne vois pas.",
            "Qui a peint ce tableau ?",
            "\u{00C7}a a \u{00E9}t\u{00E9} \u{00E9}crit par Taro Akagawa.",
            "Tom a achet\u{00E9} une voiture flambant neuve.",
            "Mon p\u{00E8}re a une cravate bleue et grise.",
            "Il nous a \u{00E9}t\u{00E9} facile de trouver Jane.",
            "Tout le monde a ses forces et ses faiblesses.",
            "Ce que tu as fait a d\u{00E9}shonor\u{00E9} toute la classe.",
            "Chacun a son propre caract\u{00E8}re.",
            "Il en a apr\u{00E8}s toi.",
            "Elle aussi a ses torts."
        ]
        for sentence in sentences {
            XCTAssertEqual(retyped(sentence), sentence)
        }
    }

    /// The two examples the issue states (not from Tatoeba).
    func test_issueExamples() {
        XCTAssertEqual(retyped("il a"), "il a")
        XCTAssertEqual(retyped("je vais \u{00E0} Paris"), "je vais \u{00E0} Paris")
    }

    /// Sentence 5 of the keyboard bench corpus, before and after its autocorrection
    /// of `decalee` (`tools/keyboard-bench/corpus/fr.txt`).
    func test_benchSentence() {
        XCTAssertEqual(retyped("la r\u{00E9}union est d\u{00E9}cal\u{00E9}e \u{00E0} jeudi matin"),
                       "la r\u{00E9}union est d\u{00E9}cal\u{00E9}e \u{00E0} jeudi matin")
        XCTAssertEqual(retyped("la r\u{00E9}gion est d\u{00E9}valer \u{00E0} jeudi matin"),
                       "la r\u{00E9}gion est d\u{00E9}valer \u{00E0} jeudi matin")
    }

    /// After a noun the sentence alone cannot tell (`le chien a` and `la machine à`
    /// both occur), so the typed `a` stays: a missed accent rather than a broken verb.
    func test_nounBeforeLeavesTheTypedWord() {
        XCTAssertEqual(retyped("On a un compte a r\u{00E9}gler."), "On a un compte a r\u{00E9}gler.")
        XCTAssertEqual(retyped("Le train a \u{00E9}t\u{00E9} retard\u{00E9}."), "Le train a \u{00E9}t\u{00E9} retard\u{00E9}.")
    }

    func test_nameBeforeKeepsTheVerb() {
        XCTAssertNil(rule.accentedForm(of: "a", context: "Je pense que Marie a"))
        XCTAssertNil(rule.accentedForm(of: "a", context: "Hier Va a"))
    }

    func test_punctuationStartsANewClause() {
        XCTAssertNil(rule.accentedForm(of: "a", context: "Je vais bien. Il a"))
        XCTAssertEqual(rule.accentedForm(of: "a", context: "Bon, je vais a"), "\u{00E0}")
    }

    func test_onlyTheLowercaseTypedWordIsConsidered() {
        XCTAssertNil(rule.accentedForm(of: "A", context: "je vais A"))
        XCTAssertNil(rule.accentedForm(of: "as", context: "je vais as"))
        XCTAssertNil(rule.accentedForm(of: "a", context: "je vais a "))
    }

    // MARK: - Sentence start (#979)

    func test_sentenceStart_isAccented() {
        XCTAssertEqual(rule.accentedForm(of: "a", context: "a"), "\u{00E0}")
        XCTAssertEqual(retyped("\u{00E0} demain"), "\u{00E0} demain")
        XCTAssertEqual(retyped("\u{00E0} quoi tu penses"), "\u{00E0} quoi tu penses")
        XCTAssertEqual(rule.accentedForm(of: "a", context: "Je rentre. a"), "\u{00E0}")
        XCTAssertEqual(rule.accentedForm(of: "a", context: "Salut\na"), "\u{00E0}")
    }

    func test_sentenceStart_keepsTheKeyboardsCapital() {
        // The keyboard capitalises the first word: `A` at the start becomes `À`.
        XCTAssertEqual(rule.accentedForm(of: "A", context: "A"), "\u{00C0}")
        XCTAssertEqual(rule.accentedForm(of: "A", context: "Bien vu ! A"), "\u{00C0}")
    }

    func test_clauseStartAfterAComma_isNotASentenceStart() {
        XCTAssertNil(rule.accentedForm(of: "a", context: "ce qu'il dit, a"))
        XCTAssertNil(rule.accentedForm(of: "A", context: "ce qu'il dit, A"))
    }

    func test_sentenceStart_isOffForAHomographWithoutTheFlag() {
        let plain = ContextualHomograph(
            typed: "a", accented: "\u{00E0}", typedAfter: [], accentedAfter: [],
            accentedTwoAfter: [], clauseOpeners: []
        )
        XCTAssertNil(plain.accentedForm(of: "a", context: "a"))
    }

    func test_typographicApostropheMatchesTheStraightOne() {
        XCTAssertEqual(rule.accentedForm(of: "a", context: "C\u{2019}est a"), "\u{00E0}")
        XCTAssertNil(rule.accentedForm(of: "a", context: "Il n\u{2019}y a"))
    }

    func test_jusquaIsAlwaysAccented() {
        XCTAssertEqual(applyOverride(profile: frenchProfile, word: "jusqu'a"), "jusqu'\u{00E0}")
    }

    func test_onlyFrenchHasAContextualHomograph() {
        for language in SupportedLanguage.allCases where language != .french {
            XCTAssertTrue(language.profile.contextualHomographs.isEmpty, "\(language)")
        }
    }

    // MARK: - The user's lexicon (#873), as on a real iPhone

    /// What the iPhones of the device tests held (#501, #500): `a` and `ma` as lexicon
    /// words, from contacts or text replacements, next to a name and a shortcut.
    private let deviceLexicon = SupplementaryLexicon(entries: [
        (userInput: "a", documentText: "a"),
        (userInput: "ma", documentText: "ma"),
        (userInput: "Zofiak", documentText: "Zofiak"),
        (userInput: "qqc", documentText: "quelque chose")
    ])

    /// `earlyAnswer` as the keyboard calls it on space: the previous word and the
    /// text before the cursor both come from `context`.
    private func earlyAnswer(
        _ word: String, _ context: String, isDictionaryWord: Bool = true,
        lexicon: SupplementaryLexicon? = nil, profile: LanguageProfile = frenchProfile
    ) -> SupplementaryLexicon.EarlyAnswer? {
        let words = context.split(separator: " ").map(String.init)
        return (lexicon ?? deviceLexicon).earlyAnswer(
            for: word, previousWord: words.dropLast().last, context: context,
            rules: .init(profile: profile, layout: profile.defaultLayout, isLearned: { _ in false }),
            isDictionaryWord: isDictionaryWord
        )
    }

    func test_lexiconWordA_stillTakesTheAccent() {
        XCTAssertEqual(earlyAnswer("a", "je vais a"), .homograph("\u{00E0}"))
    }

    func test_lexiconWordA_isKeptWhereItIsTheVerb() {
        XCTAssertEqual(earlyAnswer("a", "il a"), .lexicon(.keep))
    }

    /// Both context rules fire with `a` and `ma` in the lexicon, each on its own word.
    func test_lexiconWithAAndMa_bothContextRulesFire() {
        XCTAssertEqual(earlyAnswer("a", "je vais a"), .homograph("\u{00E0}"))
        XCTAssertEqual(earlyAnswer("ma", "il ma"), .contextOverride("m'a"))
        XCTAssertEqual(earlyAnswer("ma", "c'est ma"), .lexicon(.keep))
    }

    /// `A` and `Ma` as contact names: the lowercase dictionary words typed in a
    /// sentence still take both rules, and the names do not recase them.
    func test_contactNamesAAndMa_doNotBlockTheRules() {
        let contacts = SupplementaryLexicon(entries: [
            (userInput: "A", documentText: "A"),
            (userInput: "Ma", documentText: "Ma")
        ])
        XCTAssertEqual(earlyAnswer("a", "je vais a", lexicon: contacts), .homograph("\u{00E0}"))
        XCTAssertEqual(earlyAnswer("ma", "il ma", lexicon: contacts), .contextOverride("m'a"))
        XCTAssertEqual(earlyAnswer("a", "il a", lexicon: contacts), .lexicon(.keep))
        XCTAssertEqual(earlyAnswer("ma", "c'est ma", lexicon: contacts), .lexicon(.keep))
    }

    func test_lexiconWordTheDictionaryDoesNotKnow_isKeptBeforeTheRule() {
        XCTAssertEqual(earlyAnswer("a", "je vais a", isDictionaryWord: false), .lexicon(.keep))
    }

    /// A contact the dictionary does not know is kept before both context rules. `ma`
    /// is a dictionary word, so it stands here for a name the trie lacks: told it is
    /// unknown, the kept word wins over the `il ma` override it would otherwise take.
    func test_keptNameOutranksBothContextRules() {
        let contact = SupplementaryLexicon(entries: [(userInput: "Ma", documentText: "Ma")])
        XCTAssertEqual(earlyAnswer("Ma", "il Ma", isDictionaryWord: false, lexicon: contact), .lexicon(.keep))
        XCTAssertEqual(earlyAnswer("Zofiak", "il Zofiak", isDictionaryWord: false), .lexicon(.keep))
    }

    func test_shortcutStillReplacesFirst() {
        XCTAssertEqual(earlyAnswer("qqc", "je vais qqc"), .lexicon(.replace(with: "quelque chose")))
        let shortcutMa = SupplementaryLexicon(entries: [(userInput: "ma", documentText: "maman")])
        XCTAssertEqual(earlyAnswer("ma", "il ma", lexicon: shortcutMa), .lexicon(.replace(with: "maman")))
    }

    func test_withoutALexiconEntry_theRulesAnswerAlone() {
        XCTAssertEqual(earlyAnswer("a", "je vais a", lexicon: .empty), .homograph("\u{00E0}"))
        XCTAssertEqual(earlyAnswer("ma", "il ma", lexicon: .empty), .contextOverride("m'a"))
        XCTAssertNil(earlyAnswer("a", "il a", lexicon: .empty))
    }

    func test_otherLanguages_keepTheLexiconAsBefore() {
        XCTAssertEqual(earlyAnswer("a", "i have a", profile: englishProfile), .lexicon(.keep))
    }
}
