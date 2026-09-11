#!/usr/bin/env python3
"""Build the candidate prompt files from the shipping ones.

Usage:  python3 make-candidates.py B      # prose only
        python3 make-candidates.py C      # prose + worked examples

A candidate is a small, named set of substitutions applied to `prompts/A-*`, so
the diff between an arm and its baseline is the experiment and nothing else.
Every substitution asserts its needle appears exactly once before replacing it:
a silently-missed edit would ship an arm measuring the shipping prompt under a
candidate's name.

**B before C because the prompt is priced in dictation length.** Instructions and
input share one 4 096-token window (#270), so every character of clause is paid
for in the longest dictation the polish will accept — the very dictations this
round exists to improve. B is the licence stated as prose and costs ~450
characters of prompt; C adds worked examples and costs ~1 380. C is only worth
measuring if B fails a bar, and `bars.md` §6 records the arithmetic.

The winning text is transcribed into the Swift builders at the end of the round,
and `swift test` pins the clauses that matter there.
"""

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent.parent
NBSP = " "


def sub(text, needle, replacement):
    assert text.count(needle) == 1, f"needle appears {text.count(needle)} times: {needle[:60]!r}"
    return text.replace(needle, replacement)


# ── The licence, as prose (candidate B) ──────────────────────────────────────

FR_RULE5_OLD = (
    "5. `<<NL>>` markers represent hard line breaks. Keep them character-for-character "
    "at the same position. Capitalize the first letter of the sentence that follows "
    "each marker. Do NOT alter, paraphrase, surround with spaces, or add new markers."
)
FR_RULE5_NEW = (
    "5. `<<NL>>` marks a hard line break. Keep every marker already in the input "
    "character-for-character at the same position; never split or paraphrase one. "
    "Capitalize the first letter of the sentence that follows a marker. You MAY also "
    "insert a new `<<NL>>` BETWEEN TWO SENTENCES, and only there, when the speaker "
    "moves to a different subject. Never inside a sentence. Copy every word on both "
    "sides of an inserted marker unchanged. On one single idea, insert none — zero is "
    "the normal answer and three is already a lot."
)

FR_FORBIDDEN_OLD = (
    "- Do NOT add `<<NL>>` markers where none existed. Do NOT split or alter existing markers."
)
FR_FORBIDDEN_NEW = (
    "- Do NOT add `<<NL>>` inside a sentence, and do NOT split or alter an existing "
    "marker. Rule 5 is the only structure you may add: no list, no bullet, no `1.` "
    "prefix, no heading — not even when the speaker announces an enumeration out loud. "
    "Those ordinals are the speaker's words and stay words inside sentences."
)

AUTO_RULE7_OLD = (
    "7. `<<NL>>` markers represent hard line breaks. Keep them character-for-character "
    "at the same position. Capitalize the first letter of the sentence that follows each "
    "marker where the language uses capitalization. Do NOT alter, paraphrase, surround "
    "with spaces, or add new markers."
)
AUTO_RULE7_NEW = (
    "7. `<<NL>>` marks a hard line break. Keep every marker already in the input "
    "character-for-character at the same position; never split or paraphrase one. "
    "Capitalize the first letter of the sentence that follows a marker where the "
    "language uses capitalization. You MAY also insert a new `<<NL>>` BETWEEN TWO "
    "SENTENCES, and only there, when the speaker moves to a different subject. Never "
    "inside a sentence. Copy every word on both sides of an inserted marker unchanged. "
    "On one single idea, insert none — zero is the normal answer and three is already "
    "a lot."
)

AUTO_FORBIDDEN_OLD = (
    "- Do NOT add `<<NL>>` markers where none existed. Do NOT split or alter existing markers."
)
AUTO_FORBIDDEN_NEW = (
    "- Do NOT add `<<NL>>` inside a sentence, and do NOT split or alter an existing "
    "marker. Rule 7 is the only structure you may add: no list, no bullet, no `1.` "
    "prefix, no heading — not even when the speaker announces an enumeration out loud. "
    "Those ordinals are the speaker's words and stay words inside sentences."
)

# ── The worked examples (candidate C only) ───────────────────────────────────
#
# Nothing here shares content with any of the six fixtures: the topic change is a
# meeting and a hard drive, the enumeration is a lease and a bank. Using fixture
# 4's own `trois étapes` would make bar 3 measure the example rather than the
# rule, which is the discipline #439's held-out repair pairs follow.

FR_EXAMPLE_OLD = (
    "Line-break marker example. `<<NL>>` represents a hard line break. Keep it at the "
    "same position; capitalize the sentence that follows:\n\n"
    "INPUT: bonjour, comment ça va ?<<NL>>j'espère que tu vas bien,<<NL>>à bientôt.\n"
    f"OUTPUT: Bonjour, comment ça va{NBSP}?<<NL>>J’espère que tu vas bien,<<NL>>À bientôt."
)
FR_EXAMPLE_NEW = f"""Marker examples. One kept where the speaker dictated it, one inserted at a change of subject, and the structure that is never authorised:

INPUT: bonjour, comment ça va ?<<NL>>j'espère que tu vas bien,<<NL>>à bientôt.
OUTPUT: Bonjour, comment ça va{NBSP}?<<NL>>J’espère que tu vas bien,<<NL>>À bientôt.

INPUT: la réunion de lundi est décalée à mercredi même salle sinon tu penses à rapporter le disque dur
OUTPUT: La réunion de lundi est décalée à mercredi, même salle.<<NL>>Sinon, tu penses à rapporter le disque dur{NBSP}?

INPUT: il y a deux trucs à faire le premier c'est résilier le bail le deuxième c'est prévenir la banque
WRONG: Il y a deux trucs à faire{NBSP}:<<NL>>1. Résilier le bail<<NL>>2. Prévenir la banque
RIGHT: Il y a deux trucs à faire. Le premier c'est résilier le bail, le deuxième c'est prévenir la banque."""

AUTO_EXAMPLE_OLD = (
    "Line-break marker example. `<<NL>>` represents a hard line break. Keep it at the "
    "same position:\n\n"
    "INPUT: hi how are you doing today<<NL>>see you soon\n"
    "OUTPUT: Hi, how are you doing today?<<NL>>See you soon."
)
AUTO_EXAMPLE_NEW = """Marker examples. One kept where the speaker dictated it, one inserted at a change of subject, and the structure that is never authorised:

INPUT: hi how are you doing today<<NL>>see you soon
OUTPUT: Hi, how are you doing today?<<NL>>See you soon.

INPUT: monday's meeting moved to wednesday same room also can you bring the hard drive back
OUTPUT: Monday's meeting moved to Wednesday, same room.<<NL>>Also, can you bring the hard drive back?

INPUT: there are two things to do the first one is to end the lease the second one is to tell the bank
WRONG: There are two things to do:<<NL>>1. End the lease<<NL>>2. Tell the bank
RIGHT: There are two things to do. The first one is to end the lease, the second one is to tell the bank."""

# ── D, the positive control ──────────────────────────────────────────────────
#
# Not a ship candidate: an imperative would split fixture 1, which bar 1 forbids.
# It exists to separate two explanations of a zero, which B and C cannot tell
# apart on their own — the model declining an optional licence, or the licence
# never reaching the model at all. D is C with `MAY` turned into `MUST` and
# nothing else. Breaks under D and not under C means the mechanism works and the
# permission is what is being declined; zero under D too means the finding is
# about the marker, not about the wording.

FR_RULE5_MUST = FR_RULE5_NEW.replace(
    "You MAY also insert a new `<<NL>>` BETWEEN TWO SENTENCES, and only there, when "
    "the speaker moves to a different subject.",
    "You MUST insert a new `<<NL>>` BETWEEN TWO SENTENCES every time the speaker moves "
    "to a different subject."
).replace(
    "On one single idea, insert none — zero is the normal answer and three is already a lot.",
    "A dictation that stays on one single idea gets none."
)
assert "MUST insert" in FR_RULE5_MUST and "MAY also" not in FR_RULE5_MUST

# ── E, the second positive control ───────────────────────────────────────────
#
# D isolates the wording; E isolates the TOKEN. The marker is an artefact of the
# pipeline — `encodeForEngine` hides dictated newlines behind it so the model
# cannot naturalise them into ", " — and reproducing one it was handed is a very
# different act from generating one that was never there. E asks for an ordinary
# line break instead, which `decodeNewlines` keeps as it is, and is otherwise D.

FR_RULE5_NEWLINE = (
    "5. `<<NL>>` marks a hard line break the speaker dictated. Keep every marker "
    "already in the input character-for-character at the same position; never split or "
    "paraphrase one. Capitalize the first letter of the sentence that follows a marker. "
    "SEPARATELY: you MUST start a NEW LINE — a real line break in your output — between "
    "two sentences every time the speaker moves to a different subject. Never inside a "
    "sentence. Copy every word on both sides of a line break unchanged. A dictation that "
    "stays on one single idea gets none."
)

FR_EXAMPLE_NEWLINE = FR_EXAMPLE_NEW.replace(
    "OUTPUT: La réunion de lundi est décalée à mercredi, même salle.<<NL>>Sinon, tu "
    f"penses à rapporter le disque dur{NBSP}?",
    "OUTPUT: La réunion de lundi est décalée à mercredi, même salle.\n"
    f"Sinon, tu penses à rapporter le disque dur{NBSP}?"
)
assert FR_EXAMPLE_NEWLINE != FR_EXAMPLE_NEW

# ── F, the licence stated where the model reads the task ─────────────────────
#
# B, C, D and E all put the licence in rule 5, two thirds of the way down a 6 KB
# prompt whose every other clause is about not changing anything. F states it in
# the GOAL line as part of what the task IS, which is the one position the other
# arms leave untested, and keeps rule 5's permissive wording so it stays a
# shipping-shaped candidate rather than a probe.

FR_GOAL_OLD = (
    "GOAL: produce text the speaker would type to a friend or colleague. Their voice, "
    "their words, their register — minus the involuntary imperfections of speech."
)
FR_GOAL_NEW = FR_GOAL_OLD + (
    " On a long dictation this includes PARAGRAPHING: start a new line each time the "
    "speaker moves to a different subject, so the result is not one wall of text."
)

AUTO_GOAL_OLD = (
    "GOAL: produce text the speaker would type to a friend or colleague. Their voice, "
    "their words, their register — minus the involuntary imperfections of speech. LIGHT "
    "corrections only."
)
AUTO_GOAL_NEW = (
    "GOAL: produce text the speaker would type to a friend or colleague. Their voice, "
    "their words, their register — minus the involuntary imperfections of speech. LIGHT "
    "corrections only. On a long dictation this includes PARAGRAPHING: start a new line "
    "each time the speaker moves to a different subject, so the result is not one wall "
    "of text."
)

# ── H, the arm that follows G's result ───────────────────────────────────────
#
# G moved the instruction into the USER turn and is the first arm to produce a
# break at all. What it produces is unstable and, on its best run, one line per
# sentence. So H keeps the user turn as the place the task is stated and turns
# rule 5 from a PERMISSION into a BOUND: the licence no longer has to compete
# with "zero is the normal answer" two thirds of a prompt away, and the rule
# spends its words on where a break may fall and on grouping, which is what run 1
# got wrong.

FR_RULE5_BOUND = (
    "5. `<<NL>>` marks a hard line break. Keep every marker already in the input "
    "character-for-character at the same position; never split or paraphrase one. "
    "Capitalize the first letter of the sentence that follows a marker or a line break. "
    "When you start a new line for a change of subject, put it BETWEEN TWO SENTENCES "
    "and never inside one, and copy every word on both sides of it unchanged. Group all "
    "the sentences on one subject together: a new line after every sentence is wrong. A "
    "dictation that stays on one single idea gets none."
)

AUTO_RULE7_BOUND = (
    "7. `<<NL>>` marks a hard line break. Keep every marker already in the input "
    "character-for-character at the same position; never split or paraphrase one. "
    "Capitalize the first letter of the sentence that follows a marker or a line break, "
    "where the language uses capitalization. When you start a new line for a change of "
    "subject, put it BETWEEN TWO SENTENCES and never inside one, and copy every word on "
    "both sides of it unchanged. Group all the sentences on one subject together: a new "
    "line after every sentence is wrong. A dictation that stays on one single idea gets "
    "none."
)

PROSE_FR = [(FR_RULE5_OLD, FR_RULE5_NEW), (FR_FORBIDDEN_OLD, FR_FORBIDDEN_NEW)]
PROSE_AUTO = [(AUTO_RULE7_OLD, AUTO_RULE7_NEW), (AUTO_FORBIDDEN_OLD, AUTO_FORBIDDEN_NEW)]

CANDIDATES = {
    "B": {
        "A-natural-fr-shipping.txt": ("B-natural-fr-prose.txt", PROSE_FR),
        "A-auto-shipping.txt": ("B-auto-prose.txt", PROSE_AUTO),
    },
    "C": {
        "A-natural-fr-shipping.txt": ("C-natural-fr-examples.txt",
                                      PROSE_FR + [(FR_EXAMPLE_OLD, FR_EXAMPLE_NEW)]),
        "A-auto-shipping.txt": ("C-auto-examples.txt",
                                PROSE_AUTO + [(AUTO_EXAMPLE_OLD, AUTO_EXAMPLE_NEW)]),
    },
    "D": {
        "A-natural-fr-shipping.txt": ("D-natural-fr-must.txt", [
            (FR_RULE5_OLD, FR_RULE5_MUST),
            (FR_FORBIDDEN_OLD, FR_FORBIDDEN_NEW),
            (FR_EXAMPLE_OLD, FR_EXAMPLE_NEW),
        ]),
    },
    "H": {
        "A-natural-fr-shipping.txt": ("H-natural-fr-bound.txt", [
            (FR_RULE5_OLD, FR_RULE5_BOUND),
            (FR_FORBIDDEN_OLD, FR_FORBIDDEN_NEW),
            (FR_EXAMPLE_OLD, FR_EXAMPLE_NEW),
        ]),
        "A-auto-shipping.txt": ("H-auto-bound.txt", [
            (AUTO_RULE7_OLD, AUTO_RULE7_BOUND),
            (AUTO_FORBIDDEN_OLD, AUTO_FORBIDDEN_NEW),
            (AUTO_EXAMPLE_OLD, AUTO_EXAMPLE_NEW),
        ]),
    },
    "K": {
        "A-natural-fr-shipping.txt": ("K-natural-fr-both-ends.txt", [
            (FR_GOAL_OLD, FR_GOAL_NEW),
            (FR_RULE5_OLD, FR_RULE5_BOUND),
            (FR_FORBIDDEN_OLD, FR_FORBIDDEN_NEW),
            (FR_EXAMPLE_OLD, FR_EXAMPLE_NEW),
        ]),
        "A-auto-shipping.txt": ("K-auto-both-ends.txt", [
            (AUTO_GOAL_OLD, AUTO_GOAL_NEW),
            (AUTO_RULE7_OLD, AUTO_RULE7_BOUND),
            (AUTO_FORBIDDEN_OLD, AUTO_FORBIDDEN_NEW),
            (AUTO_EXAMPLE_OLD, AUTO_EXAMPLE_NEW),
        ]),
    },
    "F": {
        "A-natural-fr-shipping.txt": ("F-natural-fr-goal.txt", [
            (FR_GOAL_OLD, FR_GOAL_NEW),
            (FR_RULE5_OLD, FR_RULE5_NEW),
            (FR_FORBIDDEN_OLD, FR_FORBIDDEN_NEW),
            (FR_EXAMPLE_OLD, FR_EXAMPLE_NEW),
        ]),
        "A-auto-shipping.txt": ("F-auto-goal.txt", [
            (AUTO_GOAL_OLD, AUTO_GOAL_NEW),
            (AUTO_RULE7_OLD, AUTO_RULE7_NEW),
            (AUTO_FORBIDDEN_OLD, AUTO_FORBIDDEN_NEW),
            (AUTO_EXAMPLE_OLD, AUTO_EXAMPLE_NEW),
        ]),
    },
    "E": {
        "A-natural-fr-shipping.txt": ("E-natural-fr-newline.txt", [
            (FR_RULE5_OLD, FR_RULE5_NEWLINE),
            (FR_FORBIDDEN_OLD, FR_FORBIDDEN_NEW.replace("`<<NL>>` inside a sentence",
                                                        "a line break inside a sentence")),
            (FR_EXAMPLE_OLD, FR_EXAMPLE_NEWLINE),
        ]),
    },
}

letter = sys.argv[1] if len(sys.argv) > 1 else "B"
for source, (target, edits) in CANDIDATES[letter].items():
    text = (HERE / "prompts" / source).read_text(encoding="utf-8")
    before = len(text)
    for needle, replacement in edits:
        text = sub(text, needle, replacement)
    (HERE / "prompts" / target).write_text(text, encoding="utf-8")
    print(f"{target}: {before} → {len(text)} chars (+{len(text) - before})")
