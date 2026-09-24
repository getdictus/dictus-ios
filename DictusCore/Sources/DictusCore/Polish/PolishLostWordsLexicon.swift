// DictusCore/Sources/DictusCore/Polish/PolishLostWordsLexicon.swift
// Which dictated words may leave a free-polish output, per language (#575).
import Foundation

/// The words `PolishLostWords` does not count as lost, for one language.
///
/// ### Why it is a separate type from the check
///
/// The check is the mechanism — count what the speaker dictated, count what came
/// back, report the difference. This is the judgement: which differences are the
/// Natural contract doing its job and which are damage. ADR 0003's 2026-09-24
/// amendment moved that line (the bar is meaning, not wording), and the next move
/// will be a PR against these lists, not against the counting.
///
/// ### Why French only
///
/// Every number behind the check was measured on French (#575, `findings.md` §5): the
/// function-word list, the 4.3 % false-refusal rate, and the pairs below, which are the
/// shapes that round's outputs showed plus the French prompt's own PRESERVE list. No
/// lexicon exists for another language, so `lexicon(for:)` answers `nil` and the check
/// passes that output untested. A check nobody measured on a language must not start
/// refusing on it — the rule `PolishAcceptanceContract`'s flags follow for modes.
/// Adding a language is adding a lexicon **and** a measured corpus.
///
/// ### How the entries are written
///
/// Naturally, with accents and apostrophes, and cut by `PolishLostWords.keys(in:)` —
/// the same function that cuts the dictation and the output — so the list and the text
/// can never disagree about what a word is. `s'il te plaît` becomes `s il te plait`.
public struct PolishLostWordsLexicon: Sendable {

    /// A form the speaker may have dictated, and the standard forms that license its
    /// disappearance when one of them is in the output.
    ///
    /// The standard forms are **prefixes** of a folded output word, so one entry covers
    /// a verb's conjugation: `verifi` answers `vérifier`, `vérifie` and `vérifiés`.
    public struct RegisterPair: Sendable {
        public let dictated: Set<String>
        public let standardPrefixes: [String]
    }

    /// Words whose loss is never evidence: articles, pronouns, auxiliaries, the
    /// commonest prepositions — grammar a punctuation pass legitimately touches — plus
    /// the rule-7 fillers and the rule-4 verbal-punctuation words.
    public let ignoredWords: Set<String>
    /// Spoken numbers and their units, which rule 3 may turn into digits. Ignored only
    /// when the output gained a number.
    public let numberWords: Set<String>
    /// Negations. Never licensed by a prefix or a pair, whatever else matches: a lost
    /// `pas` is the #570 shape, a meaning inverted.
    public let negations: Set<String>
    /// Politeness formulas and sign-offs, which may vanish outright. Longest first, so a
    /// `merci d'avance` is taken whole before `merci` alone is looked for.
    public let droppablePhrases: [[String]]
    /// Register lifts that are licensed only when their standard form is in the output.
    public let registerPairs: [RegisterPair]

    /// The lexicon for an `NLLanguage` raw code, or `nil` when there is none — and then
    /// the check does not run. See the type's doc.
    public static func lexicon(for languageCode: String?) -> PolishLostWordsLexicon? {
        languageCode == "fr" ? .french : nil
    }

    // MARK: - French

    /// French, from #575's round and the Natural prompt's PRESERVE list.
    public static let french = PolishLostWordsLexicon(
        ignoredWords: words(frenchFunctionWords + frenchFillers + ["virgule", "point"]),
        numberWords: words(frenchNumberWords),
        negations: words(["pas", "plus", "non", "jamais", "rien", "personne", "aucun", "aucune"]),
        droppablePhrases: frenchDroppablePhrases
            .map { PolishLostWords.keys(in: $0) }
            .sorted { $0.count > $1.count },
        registerPairs: frenchRegisterPairs.map { dictated, standard in
            RegisterPair(dictated: words(dictated), standardPrefixes: standard)
        }
    )

    /// D-lost's `STOP` list (`docs/research/575-normal-polish-damage/harness/detect.py`)
    /// with four words taken OUT and six put in.
    ///
    /// Out: `pas`, `plus`, `non`, `oui`. The research detector ignored them to find
    /// substitutions; the brief refuses a dropped negation or answer by name, and on
    /// this list they would have passed untested.
    ///
    /// In: the forms of `aller` that make the near future. ADR 0003 names `ça va` +
    /// infinitive → simple future as a register lift (`ça va déborder` → `ça
    /// débordera`), and the auxiliary is the one word that lift removes.
    static let frenchFunctionWords = [
        "le", "la", "les", "un", "une", "des", "du", "de", "au", "aux", "à",
        "et", "ou", "mais", "donc", "or", "ni", "car", "que", "qu", "qui", "quoi", "dont",
        "où", "ce", "ça", "cela", "ceci", "cet", "cette", "ces", "se", "si",
        "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles", "me",
        "te", "lui", "leur", "en", "ne", "est", "es", "suis",
        "sont", "ai", "as", "avons", "avez", "ont", "être", "avoir", "pour", "par", "sur",
        "dans", "avec", "sans", "sous", "chez", "vers", "entre", "mon", "ma", "mes", "ton",
        "ta", "tes", "son", "sa", "ses", "notre", "nos", "votre", "vos", "leurs", "tout",
        "tous", "toute", "toutes", "bien", "très", "aussi", "alors", "puis", "comme",
        "fait", "vois", "sais",
        "va", "vas", "vais", "vont", "allons", "allez"
    ]

    /// Rule 7's fillers.
    static let frenchFillers = ["euh", "hum", "bah", "heu", "ben", "hein"]

    /// Rule 3: what a spoken number is made of, and the units the digits replace
    /// (`dix-huit heures trente` → `18h30`, `vingt euros` → `20 €`).
    static let frenchNumberWords = [
        "zéro", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix",
        "onze", "douze", "treize", "quatorze", "quinze", "seize", "vingt", "vingts",
        "trente", "quarante", "cinquante", "soixante", "cent", "cents", "mille",
        "million", "millions", "milliard", "milliards", "premier", "première", "deuxième",
        "troisième", "quatrième", "cinquième", "demi", "demie", "quart",
        "heure", "heures", "euro", "euros", "pourcent"
    ]

    /// Politeness formulas and sign-offs: tolerated when dropped (#575, the brief's
    /// fourth row), because the message still says what the speaker meant.
    ///
    /// **Never a sign-off that carries a time** — `à demain`, `à lundi`, `à tout à
    /// l'heure` say when the two will next talk, and dropping one changes the message.
    ///
    /// `à` is kept apart from `a` by the tokeniser, so `à plus` never matches the `a
    /// plus` of *il n'y a plus de pain*, where `plus` is a negation.
    static let frenchDroppablePhrases = [
        "s'il te plaît", "s'il vous plaît", "s'te plaît", "stp", "svp",
        "merci", "merci beaucoup", "merci bien", "merci d'avance", "merci encore",
        "merci à toi", "merci à vous", "mille mercis", "je te remercie", "je vous remercie",
        "bisous", "bisou", "des bisous", "gros bisous", "plein de bisous", "bises",
        "grosses bises", "la bise", "biz", "bizz", "je t'embrasse", "je vous embrasse",
        "bonne journée", "bonne soirée", "bonne nuit", "bonne fin de journée",
        "bonne fin de soirée", "bonne semaine", "bon week-end", "bon weekend",
        "bonne continuation", "à plus", "à plus tard", "à bientôt", "à la prochaine",
        "cordialement", "bien cordialement", "amicalement", "bien à toi", "bien à vous",
        "ciao", "tchao", "bye", "bye bye", "thanks", "thank you"
    ]

    /// Register lifts the brief tolerates: a listed anglicism into its French
    /// equivalent, and an oral contraction or abbreviation into its full form.
    ///
    /// The anglicisms are the French Natural prompt's PRESERVE list, plus the ones
    /// #575's round saw translated (`checker`, `settings`, `hello`). An abbreviation
    /// whose full form *starts with it* (`dispo`, `resto`, `appart`) needs no entry:
    /// `PolishLostWords` licenses that shape generically.
    ///
    /// **A familiar synonym is not here, on purpose**: `bosser` → `travailler`,
    /// `pourrais` → `peux` and `usage` → `utilisation` are a different word, which the
    /// brief refuses whatever its register.
    static let frenchRegisterPairs: [([String], [String])] = [
        // Anglicisms
        (["check", "checker", "checke", "checkes", "checkent", "checkez", "checking"],
         ["verifi", "control", "regard"]),
        (["mail", "mails"], ["email", "courriel", "message"]),
        (["settings", "setting"], ["parametre", "reglage", "configuration"]),
        (["hello", "hi"], ["bonjour", "salut", "coucou"]),
        (["today"], ["aujourd"]),
        (["meeting", "meetings", "meet"], ["reunion", "rendez", "rdv", "visio"]),
        (["call", "calls"], ["appel"]),
        (["deadline", "deadlines"], ["echeance", "delai", "limite"]),
        (["feature", "features"], ["fonctionnalit"]),
        (["bug", "bugs"], ["bogue", "erreur", "probleme", "anomalie", "dysfonction"]),
        (["release", "releases"], ["version", "sortie", "publication", "livraison"]),
        (["deploy"], ["deploi", "deploy", "mise"]),
        (["ship"], ["livr", "expedi", "sort"]),
        (["push"], ["pouss", "envoi", "envoy", "publi"]),
        (["pull"], ["recuper", "tir"]),
        (["merge"], ["fusion"]),
        (["commit", "commits"], ["valid", "enregistr"]),
        (["build", "builds"], ["compil", "version", "construi"]),
        (["debug"], ["debog", "corrig"]),
        (["fix", "fixes"], ["corrig", "correct", "repar", "regl"]),
        (["review", "reviews"], ["relecture", "relir", "revue", "examen", "avis", "verifi", "regard"]),
        (["request", "requests"], ["demande", "requete"]),
        (["feedback"], ["retour", "avis"]),
        (["daily"], ["quotidien"]),
        (["weekly"], ["hebdo"]),
        (["slides", "slide"], ["diapo", "present"]),
        (["job"], ["travail", "boulot", "emploi", "poste"]),
        (["team"], ["equipe"]),
        (["update", "updates"], ["mise", "actualis"]),
        (["planning"], ["calendrier", "programme"]),
        (["cool"], ["sympa", "genial", "super"]),
        (["ok", "okay"], ["accord", "entendu"]),
        (["sorry"], ["desole", "pardon"]),
        // Oral contractions and abbreviations whose full form does not start with them
        (["chuis", "chui"], ["suis"]),
        (["tit", "tite", "ptit", "ptite"], ["petit"]),
        (["ouais", "ouai"], ["oui"]),
        (["nan"], ["non"]),
        (["sieur", "msieur"], ["monsieur"]),
        (["tet", "ptet"], ["peut"]),
        (["bcp"], ["beaucoup"]),
        (["pb", "pbs"], ["probleme"]),
        (["rdv"], ["rendez"]),
        (["tjrs", "tjs"], ["toujours"]),
        (["qqch"], ["quelque"]),
        (["frigo"], ["refrigerateur", "frigidaire"])
    ]

    private static func words(_ written: [String]) -> Set<String> {
        Set(written.flatMap { PolishLostWords.keys(in: $0) })
    }
}
