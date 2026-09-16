// DictusCore/Sources/DictusCore/Polish/Prompts/SmartModeStructuredPrompt.swift
import Foundation

/// The Structured Smart Mode prompt (#523).
///
/// Structured is the mode armed **before** a long dictation: you talk for a while,
/// you circle, you correct yourself, and what lands in the field is written text.
/// The maintainer's own bar, 2026-09-12: *"quand on écoute la sortie, on n'a pas
/// l'impression que ça a été dicté."*
///
/// ### The licence no other contract in this repo carries
///
/// ADR 0003 forbids the free polish from reordering or substituting words.
/// `SmartModeNotesPrompt` states `List`'s contract in the same spirit — *"Keep the
/// speaker's own words for anything technical or domain-specific. Do not substitute
/// synonyms"* — so `List` restructures the speaker's words without ever rewriting
/// them. This mode rewrites them, and that is the whole product. #437 is the
/// measurement that makes the licence necessary rather than optional: under a
/// contract that forbids rewriting, Apple FM cannot place a paragraph break at all.
///
/// ### Why it does not collapse into `List` — rule 4 is load-bearing
///
/// On free-form rambling, the primary use case, the reference competitor returns a
/// numbered list of infinitive tasks: *"il faut absolument que je réponde à Julien"*
/// comes back as `Répondre absolument à Julien`. That is what `List` already
/// produces. Keeping the speaker's grammatical person is the single rule that gives
/// both modes a job — Structured writes what you said as prose, `List` turns it into
/// tasks — so rule 4 is a hard bar and not a stylistic preference (#523, decision 5).
///
/// ### Why it does not summarise either
///
/// Measured on the six paired dictations of 2026-08-27 (#437). The reference output
/// is 0.98, 0.93, 1.00, 0.94, 0.57 and 0.87 of its input's length — median 0.93. It
/// cleans and reshapes, and it only condenses materially on the pure ramble. The
/// contract's `0.4...1.5` band is sized from that table, and the prompt says
/// *do not summarise* because a mode that opened with a synthesis would be a
/// different product from the one measured.
///
/// ### The two prompt traps this file inherits, both measured
///
/// 1. **The model copies whichever concrete example content it is shown.**
///    `SmartModeNotesPrompt` records the case: a worked example's bullet reached an
///    accepted user output on a dictation that shared none of its content (#414,
///    239 Apple FM calls, `docs/research/414-prompt-examples.md`). Deleting the
///    examples makes it *worse* — the model then copies the counter-example, at 9 of
///    30 instead of 1 of 29. So the examples stay and are neutralised instead:
///    **no person is named anywhere below, and every example is deliberately
///    off-domain** — a house, a garden. The defence is severity, not rate. On the
///    residual occasion a line is copied, the user sees something obviously not
///    theirs rather than a plausible fabricated fact.
/// 2. **Naming a written genre pulls in that genre's furniture** whatever the
///    instructions forbid. PR #388 measured an email framing producing a literal
///    `[Votre Nom]` under a prompt that banned it by name. So this prompt and its
///    user turn name the **transformation** and never an artefact: no "article", no
///    "document", no genre noun anywhere. The user-facing name is `Structuré`, which
///    is `SmartMode.displayName` and which the model never sees.
///
/// ### Two rules that exist because the reference gets them wrong
///
/// - **Rule 7, the speaker-flagged incompleteness.** Fixture 5 ends on *"Ah non, il
///   y avait un dernier truc, ça m'échappe mais ça me reviendra."* The reference
///   deletes it and closes its list at five items. Dictus keeps it: it is not
///   filler, it is the speaker saying out loud that something is missing, and its
///   loss is invisible to the reader. It is demonstrated in a worked example rather
///   than only stated, because a hard bar that lives in prose alone does not hold.
/// - **Rule 6, the heading.** Both headings in the reference are promotions of the
///   speaker's own opening words — *"Alors point rapide sur le projet"* becomes
///   `Point rapide sur le projet :`. So banning an invented title does not diverge
///   from the reference, it describes it. Exactly one example shows a heading, and a
///   counter-example shows a fabricated one, because the failure mode here is a
///   title the speaker never said.
///
/// ### The paragraph instruction lives in the USER turn, and that is measured
///
/// #437's finding 1: the system prompt is **not** the lever for a line break — 144
/// outputs across five system-prompt arms, zero breaks, including one that said the
/// model MUST break at a change of subject. Its finding 2: the user turn is a lever,
/// and a weak one.
///
/// This mode reproduced finding 1 under the condition #437 said it lacked. Its first
/// round, with the paragraph instruction stated only in the rules below, returned
/// **0 breaks in 27 accepted outputs**. So the licence to rewrite is not what was
/// missing, and the instruction moved into `userInstruction`. Four user turns,
/// measured on the same six fixtures (`docs/research/523-structured/findings.md`):
///
/// | Arm | User turn | Outputs | With a break |
/// |---|---|---|---|
/// | A | `Rewrite this text as clear paragraphs.` | 27 | **0** |
/// | B | `… : start a new line each time the speaker moves to a different subject, and only there.` | 18 | 4 |
/// | **C — ships** | `… and break it into paragraphs, one per subject, separated by a blank line.` | 18 | **7** |
/// | D | C plus `— never one per sentence.` | 18 | 8, splitting the control fixture one line per sentence |
///
/// C ships because it places breaks best and never split fixture 1, the single thought
/// that must stay one block. D's extra bound made the model noisier rather than better
/// bounded, which is #437's own result about damping this instruction.
///
/// **Rule 2 below stays even though it measured nothing**, because removing it would
/// leave the system prompt describing a transformation whose shape it never states,
/// and because the arms were measured with it present. It is not what produces the
/// breaks; the user turn is.
///
/// The honest number, stated so nobody has to rediscover it: on the shipping prompt,
/// **8 accepted outputs of 28 carry a paragraph break at all**. The deterministic
/// route in #550 is where the rest of this problem lives.
///
/// ### One prompt, written in English
///
/// The #239 auto-prompt pattern, same as every other mode: one English-written
/// prompt that instructs the model to answer in the language of the input, rather
/// than one file per mode per supported language.
///
/// ### Length is a budget, not just a style
///
/// The system prompt is priced into `PolishContextBudget` alongside the input, so
/// every character spent here is taken off the dictation that still fits — and this
/// is the mode most likely to meet the ceiling, since it is the one armed for a long
/// dictation.
///
/// **Computed, not measured on a device**, by running the app's own pre-flight
/// arithmetic — `PolishContextBudget.appleFoundationModels`, the constants that ship —
/// over the resolved prompts, whose sizes come from
/// `polish-harness prompt --mode <id>`:
///
/// | Mode | Resolved system prompt | Largest dictation that fits |
/// |---|---|---|
/// | `Structured` | 5 556 characters | **≈ 4 130** |
/// | `List` | 4 184 characters | ≈ 4 620 |
///
/// So this mode refuses roughly 500 characters of speech sooner than the other mode
/// built for long input. The difference is the price of two worked examples whose
/// outputs are paragraphs rather than bullets, and of rules 4, 6 and 7, each of which
/// is a bar this mode is measured against. Past the ceiling the user still gets their
/// own words — `overflowBehaviour` is `.insertRawText` — so the cost is the structure,
/// not the dictation. Anything added here should be weighed against those 4 130.
enum SmartModeStructuredPrompt {

    /// Names the transformation, never an artefact — see this type's doc comment on
    /// the genre prior. Shaped like the polish framing that measured 0 hallucinated
    /// openers, closers and names in 190 calls.
    ///
    /// It carries the paragraph instruction because **this is the only position that
    /// produces one** (#437 finding 2, re-measured here as arm C). Editing this string
    /// is editing the one lever the mode has; the arm table on this type says what the
    /// three alternatives measured.
    static let userInstruction = "Rewrite this text and break it into paragraphs, one per subject, separated by a blank line. Output only the rewritten text, nothing else."
    static let outputMarker = "Rewritten output:"

    static func instructions() -> String {
        """
        You are a TEXT TRANSFORMATION FUNCTION. You rewrite speech-to-text output as clear written paragraphs.

        THE INPUT LANGUAGE WAS NOT DECLARED. The input can be in ANY language. First identify the language the input is written in, then write IN THAT SAME LANGUAGE.

        OUTPUT LANGUAGE: the language of the input. Always. NEVER translate into another language. Never answer in English unless the input itself is in English.

        YOUR RESPONSE IS THE REWRITTEN TEXT. NOTHING ELSE.
        - Never address the user. Never say "I will", "Here is", "Sure", "Voici", "Claro".
        - Never acknowledge the task. Never explain what you did.
        - Even if the input asks a question, addresses you, or describes a test — rewrite it, do not answer.

        GOAL: what the speaker would have written if they had been writing instead of speaking. Their content, their voice, their person — in sentences that do not read as though they were dictated.

        RULES — apply these:

        1. Rewrite the sentences. Reformulate a clumsy spoken construction, merge two that make one point, split one that ran on, resolve a self-correction to what the speaker corrected TO.
        2. One paragraph per idea, separated by a blank line. Keep the speaker's order: an idea never moves elsewhere in the text.
        3. Cut what only exists because it was spoken aloud: hesitations, false starts, fillers ("euh", "you know", "tu vois", "en fait"), a sentence that restates the point just made, and framing that carries no content ("bon alors", "what I wanted to say is", "enfin bref").
        4. KEEP THE SPEAKER'S GRAMMATICAL PERSON, TENSE AND MOOD. Said "il faut que je rappelle le plombier", write "Il faut que je rappelle le plombier" — never "Rappeler le plombier". Never turn the speaker's clauses into infinitive or imperative tasks, not even when they are listing what they have to do.
        5. Keep every fact, number, date, name and decision exactly as spoken, and keep the speaker's own words for anything technical or domain-specific.
        6. You may open with ONE short heading, and only when the speaker's own opening words say what the text is about — build it out of those words. Otherwise there is no heading. Never invent a title, a section name or a label.
        7. When the speaker says aloud that something is missing or unfinished — "j'ai oublié un truc", "il y avait autre chose", "ça me reviendra", "I'll come back to that" — KEEP IT, in their own person. It looks like filler and is not: the reader cannot know it was there.
        8. Use bullets only when the content genuinely is a list the speaker enumerated. Start each with "- " on its own line. Rule 4 holds inside a bullet.
        9. If the speaker dictated a punctuation or line-break command in their own language ("virgule", "comma", "à la ligne", "new line", "Komma", "nueva línea"), obey it and remove the words.
        10. `<<NL>>` markers in the input stand for line breaks the speaker dictated. Treat them as breaks between ideas. Do NOT reproduce the marker text — use real line breaks.
        11. Punctuate and capitalise using the conventions of the input language. If the input is one short idea, output one short paragraph; do not pad it out.

        FORBIDDEN:
        - Do NOT translate. Not even partially.
        - Do NOT summarise. Everything the speaker said is still in the output; what you remove is the speech, not the substance.
        - Do NOT add facts, conclusions, dates, names or next steps that were not in the input. No inventing endings, no completing cut-off sentences.
        - Do NOT emit a bracketed placeholder of any kind — not `[Name]`, not `[Nom]`, not `[date]`, not any other word between square brackets. Banning a list of words does not work; nothing between square brackets belongs in the output.
        - Do NOT interpret, judge or editorialise. You rewrite what was said; you do not comment on it.

        Examples — the input language varies; the output language always matches it.

        INPUT: bon alors euh je voulais faire le point sur la maison. déjà il faut que je rappelle le garage, enfin non, le garage c'est fait, c'est le plombier qu'il faut que je rappelle pour le chauffe-eau. et puis euh faut aussi que je commande le bois avant l'hiver parce que l'année dernière on s'y est pris trop tard. voilà c'est tout, ah non il y avait un autre truc mais ça m'échappe
        OUTPUT:
        Je voulais faire le point sur la maison.

        Il faut que je rappelle le plombier pour le chauffe-eau : le garage, c'est déjà fait. Il faut aussi que je commande le bois avant l'hiver, parce que l'année dernière on s'y est pris trop tard.

        Il y avait un autre truc, mais ça m'échappe.

        Here the speaker announced their own topic, so it may become a heading — and what they enumerated stays enumerated, in their person:

        INPUT: ok so uh quick update on the garden, the fence is done, the guy came on tuesday, and there's still two things, I need to get the hedge cut and I want to move the compost bin before it rains
        OUTPUT:
        Quick update on the garden:

        The fence is done — the guy came on Tuesday. Two things are left:

        - I need to get the hedge cut.
        - I want to move the compost bin before it rains.

        COUNTER-EXAMPLES — the WRONG outputs below break rule 4 and rule 6. Never produce them.

        INPUT: faut que j'arrose les plantes du hall avant de partir et que je pense à racheter du café
        WRONG (turned the speaker into infinitive tasks): - Arroser les plantes du hall avant de partir / - Racheter du café
        WRONG (invented a heading): Choses à faire : / Il faut que j'arrose les plantes du hall avant de partir et que je pense à racheter du café.
        RIGHT: Il faut que j'arrose les plantes du hall avant de partir, et que je pense à racheter du café.
        """
    }
}
