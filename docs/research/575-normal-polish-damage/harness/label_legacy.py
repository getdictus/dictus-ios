#!/usr/bin/env python3
"""The hand labels for the two legacy corpora, written as rules so each is auditable.

Every pair D-lost-1 flags on `longform` and `freepol` was read by hand (the reads are in
findings.md §5). The rules below reproduce those reads: they are not a classifier.
Run: label_legacy.py > labels.json
"""
import json
import detector_eval as d
from detect import lost_words
from protected import violations

DAMAGE_WORDS = {
    # 4-explanation: `en calcul` deleted (#439 bar 3), `avant` deleted,
    # `je t'explique` -> `je vais t'expliquer` (a rewrite the contract does not license).
    "calcul", "avant", "explique",
    # 5-rambling: `machin` -> `machine` (#439 bar 2), the trailing sentence deleted
    # (#385's signature), `voilà` deleted against rule 7, `peut-être` deleted (a hedge).
    "machin", "échappe", "reviendra", "voilà", "peut",
    # freepol 2-bilingue: anglicisms the Preserve list names, translated.
    "today", "push", "deadline", "review", "request",
    # freepol 3-long: `un petit peu` -> `un peu`.
    "petit",
    # freepol auto-verbal-fr#3: the output is a refusal sentence, the dictation is gone.
    "dossier",
}
# Read as faithful: `essaye`/`paye` -> `essaie`/`paie` (spelling variants), `honnête` ->
# `honnêtement` (rule-8 repair, R4 of #439), `le comptable le comptable` / `le site, le
# site` / `un grand un grand` collapsed (rule 6 on a repeated phrase), `type less` /
# `Type Laiss` -> `TypeLess` (a product name repaired), and every English clause of
# 3-message-draft / 5-erreur-parakeet brought back into French (rule 8).

labels = {}
for corpus, key, raw, out in d.corpora():
    if corpus == "round":
        continue
    lw = set(lost_words(raw, out))
    if not lw:
        continue
    # `+ne` (an oral negation formalised, e.g. `les autres c'est pas` -> `les autres ne
    # sont pas`) was first read past on 6-unscripted and found by protected.py; it is a
    # Preserve-list violation, so it is damage.
    damaged = (bool(lw & DAMAGE_WORDS) or (corpus == "longform" and "cela" in out.lower())
               or "+ne" in violations(raw, out))
    labels[key] = "damage" if damaged else "faithful"
print(json.dumps(labels, ensure_ascii=False, indent=1, sort_keys=True))
