#!/usr/bin/env python3
"""Aggregate the committed #570 / #581 captures into the tables in findings.md.

    python3 docs/research/570-structured-fidelity/summarise.py capture-*.json
    python3 docs/research/570-structured-fidelity/summarise.py --additions capture-*.json

WHY a script and not the harness. Two reasons, and `docs/research/550-paragraph-placement/score.py`
exists for the first of them.

1. **One question here is a grep, not an axis.** "Did this output copy the prompt's
   own worked example" is answered by looking for `plombier`, `compost`, `hedge` —
   content that belongs to the prompt and to no dictation in the corpus. That is not a
   property of a polish output in general, it is a property of *this* prompt family, so
   it has no business in a scorer that ships beside the guardrails.

2. **Rounds 1-3 were captured before `engineErr` got its own column.** The JSON is the
   evidence and it carries `outcome` per run, so the corrected tables are recomputed
   from it rather than re-measured — re-running would produce different samples and
   answer a different question. Two runs of 306 are affected, both ~35 s Apple FM
   timeouts on a 68-character input.

Every number in findings.md that is not read straight off a `raw/` capture comes from
here.
"""

import json
import re
import sys
from collections import Counter
from pathlib import Path

ENGINE_FAILED = "engineFailed"


def scored(r):
    """Whether a run is in the denominators: the engine produced output.

    Captures rescored after PR #583's review carry `hasEngineOutput`; older ones do
    not, and for them only `engineFailed` ever occurred without output.
    """
    if "hasEngineOutput" in r:
        return r["hasEngineOutput"]
    return r["outcome"] != ENGINE_FAILED

# Content that exists in `SmartModeStructuredPrompt`'s examples and in no dictation of
# either corpus. A hit is the model copying its own instructions (#414's trap 1).
LEAK_MARKERS = {
    "example 1 (house)": r"plombier|chauffe-eau|commande le bois|le garage",
    "example 2 (garden)": r"\bhedge\b|compost|\bfence\b|\bgarden\b",
    "counter-example (plants)": r"arrose les plantes|racheter du caf",
}
# The rule 7 clause, which is the leak #581 is about: a sentence about the speaker's own
# memory, which fits onto the end of any dictation there is.
SPEAKER_STATE = r"autre truc|m'échappe|me souviens|me reviendra|dernier machin|souviens plus"

ARM_ORDER = ["shipping", "V1-rule7-property", "V2-fidelity", "device"]


def arms_of(runs):
    seen = [r["arm"] for r in runs]
    return [a for a in ARM_ORDER if a in seen] + sorted(set(seen) - set(ARM_ORDER))


def pad(text, width):
    return str(text).ljust(width)


def axes_table(runs, title):
    print(f"\n════ {title}\n")
    header = ["unrecalled", "personLost", "hedgeLost", "hardened", "fabricated", "dropped", "clean"]
    print(pad("arm", 22) + pad("outputs", 9) + "".join(pad(h, 12) for h in header) + "engineErr")
    for arm in arms_of(runs):
        rows = [r for r in runs if r["arm"] == arm and scored(r)]
        errors = sum(1 for r in runs if r["arm"] == arm and not scored(r))
        if not rows:
            continue
        n = len(rows)

        def share(predicate):
            return f"{sum(1 for r in rows if predicate(r))}/{n}"

        cells = [
            share(lambda r: r["unrecalled"]),
            share(lambda r: r["personLost"] > 0),
            share(lambda r: r["hedgeLost"] > 0),
            share(lambda r: r["stanceHardened"] > 0),
            share(lambda r: r["speakerState"] == "fabricated"),
            share(lambda r: r["speakerState"] == "dropped"),
            share(lambda r: not (r["unrecalled"] or r["personLost"] or r["hedgeLost"]
                                 or r["stanceHardened"]
                                 or r["speakerState"] in ("fabricated", "dropped"))),
        ]
        print(pad(arm, 22) + pad(n, 9) + "".join(pad(c, 12) for c in cells) + str(errors))
    print("\n  engineErr runs are in no column and in no denominator.")
    print("  Order and the negation count are observables and are in no column here.")


def observables_table(runs, title):
    print(f"\n════ {title} — reported, never barred\n")
    print(pad("arm", 22) + pad("inversions", 13) + pad("dispersed", 12)
          + pad("negDropped", 13) + "speakerState preserved")
    for arm in arms_of(runs):
        rows = [r for r in runs if r["arm"] == arm and scored(r)]
        if not rows:
            continue
        n = len(rows)
        print(pad(arm, 22)
              + pad(sum(r["inversions"] for r in rows), 13)
              + pad(sum(r["dispersed"] for r in rows), 12)
              + pad(f"{sum(1 for r in rows if r['negationDropped'] > 0)}/{n}", 13)
              + f"{sum(1 for r in rows if r['speakerState'] == 'preserved')}/{n}")


def leak_table(runs, title):
    """The #414 trap 1 grep: did the output copy the prompt's own example content?"""
    print(f"\n════ {title} — prompt content reaching an output (#414 trap 1, #581)\n")
    print(pad("arm", 22) + pad("outputs", 9)
          + "".join(pad(name, 26) for name in LEAK_MARKERS)
          + pad("rule-7 shape", 14) + pad("FABRICATED", 12) + "closing")
    for arm in arms_of(runs):
        rows = [r for r in runs if r["arm"] == arm and scored(r)]
        if not rows:
            continue
        cells = [str(sum(1 for r in rows if re.search(p, r["output"], re.I)))
                 for p in LEAK_MARKERS.values()]
        # A rule 7 sentence in the output is only a LEAK when the input had none. When
        # the speaker said one, its presence is rule 7 doing its job and #523's decision
        # 7 holding — which is why the scorer tells the two apart by the INPUT and this
        # table reports both columns rather than one.
        shape = [r for r in rows if re.search(SPEAKER_STATE, r["output"], re.I)]
        fabricated = [r for r in rows if r["speakerState"] == "fabricated"]
        closing = [r for r in fabricated if r["closesOnSpeakerState"]]
        print(pad(arm, 22) + pad(len(rows), 9) + "".join(pad(c, 26) for c in cells)
              + pad(len(shape), 14) + pad(len(fabricated), 12) + str(len(closing)))
    print("\n  A hit in the first three columns is the model reproducing content that exists")
    print("  in its own instructions and in no dictation of either corpus (#414 trap 1).")
    print("  `rule-7 shape` counts outputs carrying a speaker-state sentence AT ALL;")
    print("  `FABRICATED` is the subset whose INPUT had none, which is #581. The rest is")
    print("  rule 7 doing its job and #523 decision 7 holding, and must not be read as a leak.")


def outcomes(runs, title):
    print(f"\n════ {title} — pipeline outcomes\n")
    for arm in arms_of(runs):
        rows = [r for r in runs if r["arm"] == arm]
        tally = Counter(r["outcome"] for r in rows)
        checks = Counter(r["rejectedCheck"] for r in rows if r.get("rejectedCheck"))
        print(f"  {pad(arm, 22)}{dict(tally)}" + (f"  refused by {dict(checks)}" if checks else ""))


# --- The accepted-additions screen (PR #583 review) ---------------------------------
#
# CodeRabbit showed that the scorer's axis 4 is not an exhaustive count of accepted
# fabrications: it matches a list of speaker-state phrasings, so an invented sentence
# phrased any other way — or a plumber lifted from the prompt — reads as `absent`. This
# screen asks #414's precision question of every ACCEPTED output sentence: what share
# of its content words does the transcript carry? A sentence under half is printed for
# a human to read. Most of what it prints is legitimate paraphrase, and a fabrication
# that reuses the speaker's own words escapes it (`J'ai oublié un truc.` on a dictation
# that says `un truc` scores 0.50), so it is a screen for a hand read and not a count.
# The hand labels it produced are in `accepted-additions.json`.
#
# The word list is a coarse copy of `PolishGrounding`'s, plus the apostrophe
# fragments. It decides only what gets printed for a reader, never a number.

_FUNCTION_WORDS = set("""le la les un une des du de d au aux et ou ni mais donc or car que qui quoi
dont a en y il elle ils elles on nous vous je tu me te se ce cet cette ces son sa ses leur leurs mon
ma mes ton ta tes notre nos votre vos pour par avec sans sur sous dans chez vers entre pas ne plus
tres bien tout tous toute toutes meme aussi comme si quand alors depuis apres avant encore deja etre
avoir fait faire est sont etait ete suis es sommes etes ont as ai avons avez peut peux pouvoir doit
dois devoir va vais aller the a an of to in on at for with by from as is are was were be been and or
but not no so if then than that this these those it its we you i my our c l j m n s t qu""".split())
_FIXTURE_FILES = [
    "../../../DictusCore/Sources/polish-harness/fixtures/device-structured-fr.json",
    "../../../DictusCore/Sources/polish-harness/fixtures/longform-fr.json",
    "shortprobe-fr.json",
    "leakprobe-fr.json",
]


def _content(text):
    import unicodedata
    folded = "".join(c for c in unicodedata.normalize("NFD", text.lower())
                     if unicodedata.category(c) != "Mn")
    return [w for w in re.split(r"[^0-9a-z]+", folded) if w and w not in _FUNCTION_WORDS]


def additions_screen(paths, floor=0.5):
    here = Path(__file__).parent
    raws = {}
    for f in _FIXTURE_FILES:
        for fixture in json.loads((here / f).read_text()):
            raws[fixture["id"]] = fixture["raw"]
    flagged = 0
    print(pad("capture", 32) + pad("arm", 20) + pad("run", 26) + pad("share", 7) + "sentence")
    for path in paths:
        for r in json.loads(Path(path).read_text()):
            if r["outcome"] != "success":
                continue
            spoken = set(_content(raws[r["fixture"]]))
            for sentence in re.split(r"(?<=[.!?])\s+|\n+", r["output"]):
                words = _content(sentence)
                if len(words) < 2:
                    continue
                share = sum(1 for w in words if w in spoken) / len(words)
                if share < floor:
                    flagged += 1
                    print(pad(Path(path).stem, 32) + pad(r["arm"], 20)
                          + pad(f"{r['fixture']}#{r['run']}", 26) + pad(f"{share:.2f}", 7)
                          + sentence.strip()[:160])
    print(f"\n  {flagged} accepted sentences under {floor:.2f} of the transcript's content words.")
    print("  A screen for a hand read, not a count: see accepted-additions.json for the labels.")


def main(paths):
    for path in paths:
        runs = json.loads(Path(path).read_text())
        name = Path(path).stem
        print(f"\n\n████████ {name} — {len(runs)} runs")
        axes_table(runs, f"AXES — {name}")
        observables_table(runs, f"OBSERVABLES — {name}")
        leak_table(runs, f"LEAKS — {name}")
        outcomes(runs, name)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    if sys.argv[1] == "--additions":
        additions_screen(sys.argv[2:])
    else:
        main(sys.argv[1:])
