// DictusCore/Sources/DictusCore/Languages/English.swift
// English language profile. Mirrors the data previously hardcoded in
// AOSPTrieEngine and SupportedLanguage.
import Foundation

/// English (`en`).
public let englishProfile = LanguageProfile(
    code: "en",
    displayName: "English",
    shortCode: "EN",
    defaultLayout: .qwerty,
    spaceName: "space",
    returnName: "return",
    overrides: [
        // Only unambiguous contractions — words that are NOT valid English on their own.
        // Excluded: "were" (we're), "well" (we'll), "wed" (we'd), "ill" (I'll),
        // "id" (I'd), "hell" (he'll), "hed" (he'd), "shed" (she'd), "shell" (she'll),
        // "its" (it's), "lets" (let's), "wont" (won't) — all valid standalone words.
        // "ill", "its" and "were" are restored from context: `contextualContractions`.
        "im": "i'm",
        "ive": "i've",
        "dont": "don't",
        "doesnt": "doesn't",
        "didnt": "didn't",
        "cant": "can't",
        "couldnt": "couldn't",
        "wouldnt": "wouldn't",
        "shouldnt": "shouldn't",
        "wasnt": "wasn't",
        "isnt": "isn't",
        "arent": "aren't",
        "werent": "weren't",
        "hasnt": "hasn't",
        "havent": "haven't",
        "hadnt": "hadn't",
        "youre": "you're",
        "youve": "you've",
        "youll": "you'll",
        "youd": "you'd",
        "theyre": "they're",
        "theyve": "they've",
        "theyll": "they'll",
        "theyd": "they'd",
        "weve": "we've",
        "hes": "he's",
        "shes": "she's",
        "itll": "it'll",
        "thats": "that's",
        "thatll": "that'll",
        "whats": "what's",
        "whos": "who's",
        "wholl": "who'll",
        "theres": "there's",
        "heres": "here's"
    ],
    accentMap: [:],         // English has no diacritics that AccentExpander handles.
    contractionPrefixes: [], // English contractions are handled via the override map.
    misspellings: englishMisspellings,
    contextualContractions: [
        // `ill` is the adjective after a form of be, become, get, feel, fall, look or
        // seem, an adverb of degree, a determiner, a negation, or in "speak ill of"
        // and "bode ill". Anywhere else, and at a sentence start, it is `I'll`.
        ContextualContraction(
            word: "ill", contraction: "I'll", atSentenceStart: true,
            after: .anyExcept([
                "be", "is", "was", "were", "are", "am", "been", "being",
                "i'm", "you're", "he's", "she's", "it's", "we're", "they're",
                "im", "youre", "hes", "shes", "theyre",
                "isn't", "wasn't", "aren't", "weren't", "isnt", "wasnt", "arent", "werent",
                "become", "becomes", "became", "becoming",
                "get", "gets", "got", "gotten", "getting",
                "feel", "feels", "felt", "feeling",
                "fall", "falls", "fell", "fallen", "falling",
                "look", "looks", "looked", "looking", "seem", "seems", "seemed", "taken",
                "so", "very", "too", "quite", "really", "rather", "pretty", "extremely",
                "slightly", "seriously", "critically", "terminally", "chronically",
                "mentally", "gravely", "desperately",
                "the", "an", "of", "not", "no",
                "speak", "speaks", "spoke", "spoken", "speaking", "bode", "bodes", "boded"
            ])
        ),
        // The possessive `its` follows almost any word (`has its own`, `of its`), so
        // `it's` is restored only where a possessive rarely starts: a sentence. Or once the
        // next word is one a possessive is never followed by (`before`): an article or
        // determiner, a pronoun, a preposition, a negation or adverb, a verb in -ing.
        // Not an adjective: "its own", "its new owner", "its true meaning" are possessive.
        ContextualContraction(
            word: "its", contraction: "it's", atSentenceStart: true, after: .only([]),
            before: [
                "a", "an", "the", "my", "your", "his", "her", "our", "their", "this", "that",
                "these", "those", "some", "any", "no", "all", "every", "another",
                "me", "you", "him", "us", "them", "what", "how", "who", "when", "where", "why",
                "in", "on", "at", "for", "from", "to", "with", "about", "like", "up", "out", "off",
                "into", "because", "not", "never", "so", "too", "really", "just", "also", "always",
                "already", "actually", "definitely", "probably", "almost", "totally", "literally",
                "basically", "quite", "kinda", "gonna", "ok", "okay",
                "been", "going", "getting", "coming", "raining", "snowing", "happening", "working",
                "looking", "taking", "starting"
            ]
        ),
        // `were` follows a subject (`we were`, `they were`) or opens a question
        // (`Were you there?`). `we're` follows a word that introduces a clause,
        // where a bare `were` has no subject. Not `sure`: "they sure were".
        ContextualContraction(
            word: "were", contraction: "we're", atSentenceStart: false,
            after: .only([
                "afraid", "glad", "hope", "guess", "think",
                "because", "cause", "if", "unless", "until", "maybe", "hopefully"
            ])
        )
    ]
)
