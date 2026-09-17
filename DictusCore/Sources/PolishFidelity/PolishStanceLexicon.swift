// DictusCore/Sources/PolishFidelity/PolishStanceLexicon.swift
// The four word sets axis 2 is made of (#570).
import Foundation
import DictusCore

/// Person, hedge, booster and negation markers, in the two languages the #570 corpus
/// is written in.
///
/// ### Why a committed lexicon and not a model
///
/// Every other number in this repo that decided a threshold came off a deterministic
/// check (#413, #414, #456, #466, #80) precisely so it could be re-run and disagreed
/// with. A model asked "did the stance change here" would give a different answer on
/// a different day and there would be no way to argue with it. A lexicon is wrong in
/// ways a reader can see, which is the property that matters for a measurement whose
/// job is to precede a decision.
///
/// ### What it covers, and what that costs
///
/// French and English. The #570 corpus and the #523 corpus are both one French
/// speaker, so nothing else is exercised — but a Spanish or German `Structuré`
/// dictation scores **zero** on axis 2 rather than passing it, and `bars.md` §9 says
/// so before the first number. An empty score is not a clean score.
///
/// Every entry is stored the way `PolishLexicon.words` produces words: lowercased,
/// diacritic-folded, and split at anything that is not a letter or a digit. So
/// `peut-être` is stored as `peut etre`, `ça m'échappe` as `ca m echappe`, and
/// `don't` as `don t`. Writing them in their natural spelling and folding at load
/// would be prettier and would silently stop matching the day the folding changed.
public enum PolishStanceLexicon {

    // MARK: - Person

    /// First-person markers, as single folded words.
    ///
    /// `j` and `m` are in the list because `PolishLexicon` splits at the apostrophe:
    /// `j'ai` is `j` + `ai` and `m'échappe` is `m` + `echappe`. Leaving them out would
    /// make `j'ai fait` read as impersonal, which is the single most common first
    /// person in spoken French.
    ///
    /// `nous` and `we` are here with `je` and `i`. #523's decision 5 is about the
    /// speaker's grammatical person surviving, and a first person plural is still the
    /// speaker's: the device defect the axis exists for turned `j'en ai fait une
    /// dizaine` into `il y a une dizaine qui ont été créées`, which is a move out of
    /// person entirely rather than from singular to plural.
    public static let firstPerson: Set<String> = [
        // French
        "je", "j", "me", "m", "moi", "mon", "ma", "mes", "nous", "notre", "nos",
        // English
        "i", "my", "mine", "we", "our", "ours", "us"
    ]

    // MARK: - Stance

    /// Hedges: the speaker marking their own claim as less than certain.
    ///
    /// The brief's own examples set the bar — `quand même` is not `effectivement`,
    /// `assez surpris` is not `surpris` — so the list carries the downtoners
    /// (`assez`, `un peu`, `plutôt`) beside the epistemic markers (`je pense`, `il me
    /// semble`), because both are what a hedge is made of in speech.
    public static let hedges: [[String]] = phrases([
        // French
        "je pense", "je crois", "il me semble", "me semble", "il semble", "on dirait",
        "je dirais", "peut etre", "sans doute", "probablement", "apparemment",
        "il parait", "plutot", "assez", "un peu", "quand meme", "a mon avis",
        "je sais pas", "je ne sais pas", "je suppose", "en gros", "a priori",
        // English
        "i think", "i believe", "i guess", "i suppose", "maybe", "perhaps",
        "probably", "apparently", "kind of", "sort of", "a bit", "rather",
        "it seems", "somewhat", "pretty much", "i d say"
    ])

    /// Boosters: the speaker marking their own claim as more than certain.
    ///
    /// The axis-2 defect this list exists for is `il coupe quand même pas mal de mots`
    /// coming back as `il enlève effectivement beaucoup de mots` — a concessive
    /// becoming a confirmation. One lexicon could not express that: a hedge going
    /// missing and a booster arriving are two different edits and the second is the
    /// one that changes what the sentence claims.
    ///
    /// `vraiment` and `really` are the ambiguous entries: `pas vraiment` is a hedge,
    /// not a booster. They stay because the check only fires when the booster is
    /// **absent from the input proposition**, and `pas vraiment` in the input puts
    /// `vraiment` there. An intensifier the speaker already used is never counted as
    /// one the model added.
    public static let boosters: [[String]] = phrases([
        // French
        "effectivement", "en effet", "vraiment", "evidemment", "clairement",
        "certainement", "absolument", "bien sur", "forcement", "tout a fait",
        "sans aucun doute", "de toute evidence",
        // English
        "indeed", "definitely", "clearly", "obviously", "certainly", "absolutely",
        "of course", "without a doubt", "really", "for sure"
    ])

    // MARK: - Polarity

    /// Negation markers, as single folded words.
    ///
    /// **Reported, never scored** — `bars.md` §4 declares this as an addition to the
    /// brief's four axes, because #570's own title is a dropped negation and the brief
    /// names no polarity axis.
    ///
    /// `ne` is deliberately absent: spoken French drops it (`je sais pas`), so its
    /// absence from an output says nothing, and ADR 0003 explicitly forbids the polish
    /// from adding it back. `plus` is absent for the opposite reason — `plus de temps`
    /// and `plus du tout` are opposite polarities spelled identically. What is left is
    /// the set whose presence is unambiguous.
    public static let negations: Set<String> = [
        // French
        "pas", "jamais", "aucun", "aucune", "rien", "ni", "sans",
        // English. A contraction folds to two words (`don't` -> `don` + `t`), so
        // `not` catches only the written-out form and `nt` would catch nothing.
        // Stated rather than silently missed.
        "not", "never", "no", "nothing", "none", "without", "cannot", "neither", "nor"
    ]

    // MARK: - Counting

    /// How many of `phrases` occur in `words`, counting each occurrence.
    ///
    /// Contiguous match over the folded word sequence, never a substring search on the
    /// text: `assez` must not match inside `assezoire`, and a substring search on
    /// folded text is exactly how that happens.
    public static func occurrences(of phrases: [[String]], in words: [String]) -> Int {
        var found = 0
        for phrase in phrases where !phrase.isEmpty {
            guard words.count >= phrase.count else { continue }
            for start in 0...(words.count - phrase.count)
            where Array(words[start..<(start + phrase.count)]) == phrase {
                found += 1
            }
        }
        return found
    }

    /// How many words of `words` are in `set`.
    public static func occurrences(of set: Set<String>, in words: [String]) -> Int {
        words.count { set.contains($0) }
    }

    /// Split each written phrase into the folded word sequence `PolishLexicon` would
    /// produce for it, so the lexicon and the text are cut by the same rule.
    private static func phrases(_ written: [String]) -> [[String]] {
        written.map { PolishLexicon.words(in: $0) }
    }
}
