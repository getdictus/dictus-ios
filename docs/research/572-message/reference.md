# `Message` — the reference corpus and what the competition does

## The corpus

`corpus.json` holds four real messages the maintainer was about to send, captured on device
on 2026-09-17 (iPhone16,2, iOS 27.0, build 1.9.0 (34), Parakeet v3 + Normal polish). Each
row carries the raw transcript and what Normal polish returned. Fixture 1 also carries the
two things that make it a reference rather than a sample: **what the maintainer would have
typed**, and Superwhisper's output on the same content.

One substitution: the addressee's initials in fixture 2 are replaced with a first name. The
tracker is public and these are real messages to real people. Nothing else is altered.

**A limitation the maintainer stated himself and that bounds what this corpus proves:**
*"Je me suis peut-être trop forcé mentalement à faire une transcription de messages. J'aurais
peut-être dû plutôt faire un truc un peu plus brouillon."* These four are cleaner than his
ordinary speech. The mode's hardest input is not in this file yet.

## The one pair that carries a target

| | |
|---|---|
| **Raw** | `Yo man, j'espère que tu vas bien. Écoute, je suis en train de regarder le projet, je t'ai pas répondu mais je suis en train de travailler dessus, je te tiens au jus dès que. Dès que j'ai avancé un petit peu plus dessus, s'il te plaît. Enfin pardon, pas s'il te plaît je me suis planté.` |
| **Normal polish** | the same text, with the broken sentence and the whole self-correction intact |
| **Superwhisper** | one block, all periods, the hesitation repaired, `enfin pardon, je me suis planté` still there |
| **What he would have typed** | three blocks separated by blank lines, no terminal period anywhere, the self-correction gone entirely, `dès que j'ai avancé un petit peu plus dessus` shortened to `dès que j'avance un peu plus` |

Superwhisper beats us — it repairs the hesitation and drops half the self-correction. It
still does not reach the target: it keeps the apology and writes one paragraph of prose.

**The target's shape is the finding.** Three beats, one block each, a blank line between them,
and **not one terminal period** — while `!` survives. A message is not a paragraph with the
fillers removed. It is several short blocks, and the line break does the work the period does
in prose.

## What VivaDicta ships (`n0an/VivaDicta`, 115 stars, read 2026-09-17)

The same competitor whose glossary behaviour settled #536. It has **18+ presets**, and its
`chat` preset is the closest thing in the market to this mode:

```
- Rewrite the <TRANSCRIPT> text as a chat message: informal, concise, and conversational.
- Keep emotive markers and emojis if present; don't invent new ones.
- Lightly fix grammar, remove fillers and repeated words, and improve flow without changing meaning.
- Keep the original tone; only be professional if the <TRANSCRIPT> already is.
- Format like a modern chat message - short lines, natural breaks, emoji-friendly.
- Do not add greetings, sign-offs, or commentary.
- Output only the chat message.
```

Three of those lines are independent confirmations of decisions this issue had already locked:

| Their line | Our decision |
|---|---|
| `Keep the original tone; only be professional if the <TRANSCRIPT> already is` | decision 1 — the mode mirrors the register, never chooses it |
| `Do not add greetings, sign-offs, or commentary` | the hard bar written against what cut Email to #269 |
| `Keep emotive markers and emojis if present; don't invent new ones` | decision 2, refined: never **invent** one, keep a dictated one |

And one line is the thing the maintainer's target independently says: **`short lines, natural
breaks`**. Two sources, one conclusion, and it becomes decision 6.

### What their catalogue argues for our own discipline

Their `summary` returns **2-5 bullet points**, and `action_points`, `takeaways`, `key_points`
and `mind_map` are four more bullet modes beside it. That is the failure our five-mode axis
exists to avoid: a user facing `Summary`, `Key Points` and `Takeaways` has to guess what
separates them, and the honest answer is not much. It is also why #571 returns **prose** —
the bullet slot in this app is `Liste`, and it is occupied.

Their prompts are **8 lines**. Ours are 5 556 characters. Some of that difference is the
guardrail family we carry and they do not; some of it is #414, which measured what happens
when examples are removed. But the context ceiling this buys — ≈ 4 130 characters of speech
for `Structuré` — is a real cost, and `Message` serves short input, so it can afford to be
the first mode in this repo written tight.

They also wrap the transcript in `<TRANSCRIPT>` tags, which is #474 — measured on #518 as
clearing the false language refusal 0 of 10, and not landed only because tagging one prompt
of twelve is the half-tagged state #474 forbids.
