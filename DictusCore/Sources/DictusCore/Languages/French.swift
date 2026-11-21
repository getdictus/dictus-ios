// DictusCore/Sources/DictusCore/Languages/French.swift
// French language profile. Mirrors the data previously hardcoded in
// AOSPTrieEngine and SupportedLanguage; behavior must be byte-identical
// pre/post the LanguageProfile refactor.
import Foundation

/// French (`fr`) — Dictus's default and most-used language.
public let frenchProfile = LanguageProfile(
    code: "fr",
    displayName: "Fran\u{00E7}ais",
    shortCode: "FR",
    defaultLayout: .azerty,
    spaceName: "espace",
    returnName: "retour",
    overrides: [
        // Common unambiguous accent-missing words. These are NOT valid French without accents.
        // Excluded: "a"/"à" (both valid), "ou"/"où" (both valid), "meme" (could be English)
        "ca": "\u{00E7}a",                       // ca -> ça
        "tres": "tr\u{00E8}s",                   // tres -> très
        "apres": "apr\u{00E8}s",                 // apres -> après
        "deja": "d\u{00E9}j\u{00E0}",            // deja -> déjà
        "ete": "\u{00E9}t\u{00E9}",              // ete -> été
        "etre": "\u{00EA}tre",                   // etre -> être
        "voila": "voil\u{00E0}",                 // voila -> voilà
        "bientot": "bient\u{00F4}t",             // bientot -> bientôt
        "plutot": "plut\u{00F4}t",               // plutot -> plutôt
        "probleme": "probl\u{00E8}me",           // probleme -> problème
        "systeme": "syst\u{00E8}me",             // systeme -> système
        "etait": "\u{00E9}tait",                 // etait -> était
        "etaient": "\u{00E9}taient",             // etaient -> étaient
        "evenement": "\u{00E9}v\u{00E9}nement",  // evenement -> événement
        // Missed-apostrophe contractions colliding with rare-but-real dictionary
        // words. Without an override, the valid-word guard protects the rare word
        // and the contraction never fires ("je lai vu" stays broken). The rare
        // legitimate uses (a medieval "lai", nautical "lest") lose to the
        // overwhelmingly more frequent contraction (#222).
        // Excluded: "louvre" (l'ouvre) — the override lookup re-capitalizes, so
        // it would corrupt "Louvre" (the museum) into "L'ouvre".
        "lai": "l'ai",                           // lai -> l'ai (je l'ai vu)
        "lest": "l'est"                         // lest -> l'est (il l'est)
    ],
    accentMap: [
        "e": ["\u{00E9}", "\u{00E8}", "\u{00EA}", "\u{00EB}"],  // é, è, ê, ë
        "a": ["\u{00E0}", "\u{00E2}"],                          // à, â
        "i": ["\u{00EE}", "\u{00EF}"],                          // î, ï
        "o": ["\u{00F4}"],                                      // ô
        "u": ["\u{00F9}", "\u{00FB}", "\u{00FC}"],              // ù, û, ü
        "c": ["\u{00E7}"]                                      // ç
    ],
    contractionPrefixes: [
        // 1-character prefixes (l', d', c', j', n', s', m', t')
        "l'", "d'", "c'", "j'", "n'", "s'", "m'", "t'",
        // 2-character prefix (qu')
        "qu'"
    ],
    elisionRepair: ElisionRepair(
        // AZERTY neighbours of the prefix that was meant. Valid prefixes are not keys.
        prefixSlips: [
            "v": "c", "x": "c",              // v'est, x'est → c'est
            "f": "d",                        // f'un → d'un
            "g": "j", "h": "j", "k": "j",    // g'ai, h'ai, k'ai → j'ai
            "b": "n",                        // b'est → n'est
            "y": "t", "r": "t", "u": "t",    // y'es, r'es, u'es → t'es
            "q": "qu",                       // q'il → qu'il
            "qy": "qu", "qi": "qu", "qj": "qu"  // the keys left of, right of and under `u`
        ],
        // The key left of the apostrophe on the AZERTY letter page: `qunil` → `qu'il`.
        apostropheNeighbours: ["n"],
        // Only the elisions a slip or a space is repaired into: the shapes also occur
        // inside words and their typos.
        elidedWords: [
            "qu": ["il", "ils", "elle", "elles", "on", "un", "une"],
            "c": ["est", "\u{00E9}tait"]  // est, était
        ]
    ),
    // `il est arrive` → `arrivé`, `il arrive` stays (#994). The auxiliaries être and
    // avoir in their simple tenses, and the adverbs that sit between an auxiliary and
    // its participle (`sont déjà couchés`, `était presque déchargé`). French puts these
    // adverbs after a conjugated verb, so before one they announce a participle.
    // Excluded: `été`, also the noun (`l'été arrive`), and `tout`, also a pronoun
    // (`tout arrive`).
    participleContext: ParticipleContext(
        triggers: [
            "suis", "es", "est", "sommes", "\u{00EA}tes", "sont",
            "\u{00E9}tais", "\u{00E9}tait", "\u{00E9}tions", "\u{00E9}tiez", "\u{00E9}taient",
            "serai", "seras", "sera", "serons", "serez", "seront",
            "serais", "serait", "serions", "seriez", "seraient",
            "sois", "soit", "soyons", "soyez", "soient", "\u{00EA}tre", "\u{00E9}tant",
            "ai", "as", "a", "avons", "avez", "ont",
            "avais", "avait", "avions", "aviez", "avaient",
            "aurai", "auras", "aura", "aurons", "aurez", "auront",
            "aurais", "aurait", "aurions", "auriez", "auraient",
            "aie", "aies", "ait", "ayons", "ayez", "aient", "eu", "avoir", "ayant",
            "d\u{00E9}j\u{00E0}", "presque", "bien", "pas", "jamais", "encore", "toujours",
            "plus", "rien", "vraiment", "trop", "tr\u{00E8}s", "souvent", "tellement",
            "compl\u{00E8}tement"
        ],
        endings: ["\u{00E9}", "\u{00E9}e", "\u{00E9}s", "\u{00E9}es"]  // é, ée, és, ées
    )
)
