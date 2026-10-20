// DictusCore/Sources/DictusCore/Polish/PolishIncompleteness.swift
// Did the model write the speaker's memory failing when the speaker never said so? (#581, #587)
import Foundation

/// Whether an output carries a sentence in which the speaker reports their own recall
/// failing, when the transcript carries none.
///
/// ### The defect, and why no other check sees it
///
/// `Structuré` keeps a speaker-flagged incompleteness — *"ah non, il y avait un dernier
/// truc, ça m'échappe"* — because the reader cannot know it was said (#523, decision 7).
/// The same rule taught the model that an output of this mode may **end** on one, and on
/// device it did, on dictations that said nothing of the kind: `Il y avait un autre truc,
/// mais ça m'échappe.`, the prompt's own worked example, verbatim, and three paraphrases
/// of it (#581, seven device outputs in three days, three of them inserted).
///
/// `segmentOverlap` (#414) refused some and accepted others, and it cannot be the
/// backstop: on a long dictation a generic sentence about memory shares `autre`, `truc`
/// or a form of `avoir` with the input and clears the 0.15 floor at 0.50 (#581, second
/// comment). The length band sees one appended sentence as nothing. So this is its own
/// check, answering one question, under its own slug.
///
/// ### Narrow on purpose (#587, decision 6)
///
/// #466 is what a check widened blind costs: 10 legitimate repairs of 10 refused, at
/// every threshold swept. So this matches **recall failing** and nothing wider — *ça
/// m'échappe*, *je ne me souviens pas*, *j'ai oublié un truc*, *I can't remember*. It
/// does not match *il y a autre chose* or *je reviendrai là-dessus*: a rewrite of *il y
/// a aussi autre chose à faire* into *il y a autre chose à faire* is ordinary, and those
/// phrases in the list would refuse it. What it cannot see is written down rather than
/// chased — see the last section.
///
/// ### Why the two sides are matched differently
///
/// The output side is the strict list. The input side is the strict list **plus the
/// spoken forms and bare verbs** the list does not carry: `je m'en souviens plus`, `je
/// sais plus`, `oublié`, `remember`. The mode is licensed to rewrite, so a speaker who
/// said `je m'en souviens plus si le message était bon` legitimately gets back `Je ne me
/// souviens pas si le message était bon` — and a symmetric match would refuse rule 7
/// doing its job. The 2026-09-19 07:03:42 device dictation has exactly that shape. The
/// asymmetry costs recall, never a false refusal: a dictation that mentions forgetting
/// anything lets a fabricated line through, which is the trade decision 6 asks for.
///
/// Since #580 a refusal on `Structuré` inserts the speaker's own words, so a false
/// refusal would cost the structure and never the dictation. That is why the check can
/// exist at all; it is not a licence to widen it.
///
/// ### Six languages, and the rest pass untested
///
/// French, English, Spanish, German, Italian and Portuguese. The phrases are word
/// sequences folded by `PolishLexicon`, so a script that writes no word separators and
/// a language nobody here wrote phrases for simply never matches — an output in
/// Japanese is accepted by this check whatever it says. Adding a language is adding
/// its lines to both lists below, with a test for each.
///
/// **Known holes, stated so nobody mistakes the check for more than it is:** a
/// fabricated incompleteness phrased outside the list (*"there was one more point"*); a
/// deferral rather than a recall failure (*"I'll come back to that"*); and any output
/// whose transcript mentions forgetting or remembering anything at all.
public enum PolishIncompleteness {

    /// Phrasings of the speaker's recall failing. Matched on the OUTPUT.
    ///
    /// Written naturally and folded through `PolishLexicon.words`, so the list and the
    /// text are cut by one rule: `ça m'échappe` becomes `ca m echappe`, and `I can't`
    /// becomes `i can t`.
    static let recallFailing: [[String]] = phrases([
        // French
        "je ne me souviens", "je ne m'en souviens", "je me souviens plus", "je me souviens pas",
        "je m'en souviens plus", "je m'en souviens pas", "je ne me rappelle", "je ne m'en rappelle",
        "je me rappelle plus", "je me rappelle pas", "ça m'échappe", "ça m'a échappé",
        "ça m'échappait", "il m'échappe", "elle m'échappe", "ça me reviendra", "ça me revient pas",
        "ça ne me revient pas", "j'ai oublié un truc", "j'ai oublié quelque chose",
        "j'ai oublié autre chose", "j'oublie quelque chose", "j'oublie un truc",
        "j'ai du mal à me souvenir", "je n'arrive pas à me souvenir", "je n'arrive plus à me souvenir",
        "je n'arrive pas à me rappeler", "la mémoire me manque", "ma mémoire a échoué",
        "ma mémoire a failli", "ma mémoire me fait défaut",
        // English
        "I don't remember", "I do not remember", "I can't remember", "I cannot remember",
        "I don't recall", "I can't recall", "I cannot recall", "it escapes me", "it's escaping me",
        "it slips my mind", "it slipped my mind", "I forgot something", "I forgot one thing",
        "I've forgotten something", "it'll come back to me", "my memory fails me",
        // Spanish
        "no me acuerdo", "no recuerdo", "se me escapa", "se me olvidó", "se me ha olvidado",
        "olvidé algo", "ya me acordaré", "no me viene a la cabeza",
        // German
        "ich erinnere mich nicht", "ich kann mich nicht erinnern", "ich kann mich nicht mehr erinnern",
        "es fällt mir nicht ein", "es fällt mir nicht mehr ein", "es ist mir entfallen",
        "das ist mir entfallen", "ich habe etwas vergessen", "es fällt mir wieder ein",
        // Italian
        "non mi ricordo", "non ricordo", "mi sfugge", "mi è sfuggito", "ho dimenticato qualcosa",
        "mi verrà in mente", "non mi viene in mente",
        // Portuguese
        "não me lembro", "não lembro", "me escapa", "esqueci alguma coisa", "esqueci uma coisa",
        "não me recordo", "vou me lembrar"
    ])

    /// What else counts as the speaker having said it. Matched on the INPUT only.
    ///
    /// The spoken forms (`je sais plus`) and the bare verbs (`oublié`, `remember`,
    /// `entfallen`), so a sentence the model rewrote from one of them is never read as
    /// invented. See the type's doc for why this side is wider than the other.
    static let spokenForms: [[String]] = phrases([
        // French
        "souviens", "souvient", "souvenir", "me rappelle", "m'en rappelle", "échappe", "échappait",
        "échappé", "oublié", "oublie", "reviendra", "revient pas", "sais plus", "mémoire",
        // English
        "remember", "recall", "forgot", "forget", "forgotten", "escapes", "slipped", "slips",
        "come back to me", "memory",
        // Spanish
        "me acuerdo", "acordaré", "recuerdo", "recordar", "escapa", "olvidé", "olvidó", "olvidado",
        "memoria",
        // German
        "erinnere", "erinnern", "entfallen", "vergessen", "fällt mir", "gedächtnis",
        // Italian
        "ricordo", "ricordare", "sfugge", "sfuggito", "dimenticato", "dimenticare", "in mente",
        // Portuguese
        "lembro", "lembrar", "recordo", "esqueci", "esquecer"
    ])

    /// Whether `polished` reports the speaker's recall failing while `raw` does not.
    ///
    /// `raw` is the text the engine saw — the pipeline passes `preprocessed`, for the
    /// reason every other check does.
    public static func isFabricated(polished: String, raw: String) -> Bool {
        reportsRecallFailing(polished) && !speakerSaidOne(raw)
    }

    /// Whether `text` carries one of the strict phrasings.
    public static func reportsRecallFailing(_ text: String) -> Bool {
        contains(any: recallFailing, in: PolishLexicon.words(in: text))
    }

    /// Whether a transcript carries a phrasing, a spoken form of one, or a bare verb.
    static func speakerSaidOne(_ raw: String) -> Bool {
        let words = PolishLexicon.words(in: raw)
        return contains(any: recallFailing, in: words) || contains(any: spokenForms, in: words)
    }

    /// Whether any phrase occurs in `words` as a contiguous run.
    private static func contains(any phrases: [[String]], in words: [String]) -> Bool {
        phrases.contains { phrase in
            guard !phrase.isEmpty, words.count >= phrase.count else { return false }
            return (0...(words.count - phrase.count)).contains { start in
                words[start..<(start + phrase.count)].elementsEqual(phrase)
            }
        }
    }

    private static func phrases(_ written: [String]) -> [[String]] {
        written.map { PolishLexicon.words(in: $0) }
    }
}
