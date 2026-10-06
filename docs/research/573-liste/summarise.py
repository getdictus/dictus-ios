#!/usr/bin/env python3
"""Read the #573 captures against the bars in bars.md §5.

    python3 docs/research/573-liste/summarise.py baseline c1 [c2 …]

The first round named is the baseline (`develop`'s prompt), every other one a candidate.
A round is the set of `captures/<round>-<fixture set>.json` files it produced. Every screen
below FLAGS; nothing here calls a bar on its own. The flags are printed so the hand read
that adjudicates them can be checked against the same text.

The fidelity axes in the captures are `Structuré`'s contract; only axis 1 (unrecalled
propositions) is read here, for B6, and only as a comparison between rounds.
"""

import json
import re
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
FIXTURES = HERE.parent.parent.parent / "DictusCore/Sources/polish-harness/fixtures"
SETS = {
    "N": "notes-fr",
    "S": "liste-statements",
    "M": "liste-mixed",
    "L": "longform-fr",
    "T": "translated-structured",
    "R": "liste-round2",
}

# Content-free words a title may carry without them being "the speaker's words".
STOP = set("""
le la les un une des du de d l au aux et ou à a en pour sur dans par avec ce cet cette ces
mon ma mes ton ta tes son sa ses notre nos votre vos leur leurs qui que quoi dont
the a an of for on in at to and or with my your his her our their this that these those
""".split())


def load_round(name):
    runs = []
    for key, fixture_set in SETS.items():
        path = HERE / "captures" / f"{name}-{fixture_set}.json"
        if not path.exists():
            continue
        fixtures = {f["id"]: f for f in json.loads((FIXTURES / f"{fixture_set}.json").read_text())}
        for record in json.loads(path.read_text()):
            fixture = fixtures[record["fixture"]]
            record["set"] = key
            record["round"] = name
            record["raw"] = fixture["raw"]
            record["expect"] = fixture.get("expect", [])
            record.setdefault("rejectedCheck", None)
            runs.append(record)
    if not runs:
        print(f"error: no capture for round {name!r} under captures/")
        raise SystemExit(1)
    return runs


def scored(r):
    return r.get("hasEngineOutput", True)


def accepted(r):
    return scored(r) and r["outcome"] == "success"


def lines(output):
    return [line for line in output.split("\n") if line.strip()]


def is_list_line(line):
    return re.match(r"^\s*([-*•–]|\d+[.)])\s", line) is not None


def shape(output):
    """(title, bullets, defects) — decision 2 and 4's shape, read off the text."""
    rows = lines(output)
    defects = []
    if not rows:
        return None, [], ["empty"]
    title = rows[0].strip()
    if is_list_line(title):
        defects.append("noTitle")
        title = None
    elif not re.search(r"[:：]$", title):
        defects.append("titleNoColon")
    body = rows[1:] if title is not None else rows
    bullets = [row for row in body if row.startswith("- ")]
    if any(re.match(r"^\s+[-*•–]\s", row) for row in body):
        defects.append("indented")
    if any(re.match(r"^\s*\d+[.)]\s", row) for row in body):
        defects.append("numbered")
    if any(not is_list_line(row) for row in body):
        defects.append("extraNonListLine")
    if not bullets:
        defects.append("noBullet")
    return title, bullets, defects


def fold(text):
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def words(text):
    return re.findall(r"[^\W\d_]+", fold(text))


def cjk(language):
    return language.split("-")[0] in ("ja", "zh")


def title_unsupported(title, raw, language):
    """Title words with no trace in the input (B1c). A screen, never a verdict."""
    if not title:
        return []
    body = title.rstrip(":： ")
    if cjk(language):
        chars = [c for c in body if unicodedata.category(c).startswith("L")]
        return [c for c in chars if c not in raw]
    raw_words = words(raw)
    missing = []
    for word in words(body):
        if len(word) < 4 or word in STOP:
            continue
        stem = word[:5]
        if not any(candidate.startswith(stem) or stem.startswith(candidate[:5]) for candidate in raw_words
                   if len(candidate) >= 4):
            missing.append(word)
    return missing


def numbers_unsupported(output, raw):
    """Digit groups in the output absent from the input's digits (B1b). A spoken number
    converted to digits is flagged too, and cleared by the hand read."""
    raw_digits = set(re.findall(r"\d+", raw.replace(" ", "")))
    return [n for n in re.findall(r"\d+", output.replace(" ", "")) if n not in raw_digits]


def section(title):
    print(f"\n\n════ {title}\n")


def by_round(runs, rounds):
    for name in rounds:
        yield name, [r for r in runs if r["round"] == name]


def b1(runs, rounds):
    section("B1 — invented facts or names, title included (bars.md §5)")
    for name, rows in by_round(runs, rounds):
        refused = defaultdict(int)
        for r in rows:
            if r["rejectedCheck"] in ("grounding", "segmentOverlap"):
                refused[r["rejectedCheck"]] += 1
        print(f"── {name}: refused by grounding/segmentOverlap: {dict(refused) or 0}")
        for r in rows:
            if not scored(r):
                continue
            title, _, _ = shape(r["output"])
            language = r.get("expectedLanguage") or "und"
            flags = []
            missing = title_unsupported(title, r["raw"], language)
            if missing:
                flags.append(f"title words not in input: {missing}")
            numbers = numbers_unsupported(r["output"], r["raw"])
            if numbers:
                flags.append(f"numbers not in input digits: {numbers}")
            if r["rejectedCheck"] in ("grounding", "segmentOverlap"):
                flags.append(f"refused({r['rejectedCheck']})")
            if flags:
                print(f"   [{r['set']}] {r['fixture']}#{r['run']} {r['outcome']}: " + "; ".join(flags))
                print(f"       title: {title!r}")


def b2(runs, rounds):
    section("B2 — output language, per round and language (bars.md §5)")
    print(f"{'round':10}{'lang':9}{'outputs':9}{'refusedLang':13}{'%':7}{'wrongAccepted':15}{'wrongAny':9}")
    for name, rows in by_round(runs, rounds):
        table = defaultdict(list)
        for r in rows:
            if scored(r):
                table[r.get("expectedLanguage") or "und"].append(r)
        for language in sorted(table):
            cell = table[language]
            wrong = lambda r: r["outputLanguage"] != r["expectedLanguage"] or bool(r["foreignSentences"])
            refused = sum(r["rejectedCheck"] == "language" for r in cell)
            print(f"{name:10}{language:9}{len(cell):<9}{refused:<13}{100 * refused / len(cell):<7.1f}"
                  f"{sum(accepted(r) and wrong(r) for r in cell):<15}{sum(wrong(r) for r in cell):<9}")
    print("\nEvery flagged output, for the hand read:")
    for r in runs:
        if scored(r) and (r["outputLanguage"] != r["expectedLanguage"] or r["foreignSentences"]):
            print(f"  [{r['round']}/{r['set']}] {r['fixture']}#{r['run']} {r['outcome']}"
                  f"{'(' + r['rejectedCheck'] + ')' if r['rejectedCheck'] else ''} "
                  f"read={r['outputLanguage']} expected={r['expectedLanguage']}")
            for sentence in r["foreignSentences"]:
                print(f"      FOREIGN: {sentence}")


# A French bullet opening on an infinitive, or an English one opening on a bare verb from
# the commonest task verbs. Both are screens to point the hand read, nothing more.
FR_INFINITIVE = re.compile(r"^- (?:[Nn]e pas )?[A-ZÀ-Ü][a-zà-ÿ]+(?:er|ir|re|oir)\b")
EN_TASK = re.compile(r"^- (?:Fix|Check|Investigate|Choose|Pick|Reduce|Filter|Simplify|Correct|Look|Make|"
                     r"Review|Update|Improve|Contact|Call|Ask|Send|Test|Use|Keep|Add|Remove|Replace|Monitor|"
                     r"Book|Buy|Get|Plan|Prepare|Follow|Find|Treat|Repair|Consider|Go|Bring)\b")


def b3(runs, rounds):
    section("B3 — tasks fabricated from a statement, set S, every line (bars.md §5)")
    for name, rows in by_round(runs, rounds):
        s_rows = [r for r in rows if r["set"] == "S" and scored(r)]
        screened = 0
        print(f"── {name}: {len(s_rows)} outputs, {sum(accepted(r) for r in s_rows)} accepted")
        for r in s_rows:
            _, bullets, _ = shape(r["output"])
            hits = [b for b in bullets if FR_INFINITIVE.match(b) or EN_TASK.match(b)]
            screened += bool(hits)
            marker = "TASK?" if hits else "     "
            print(f"   {marker} {r['fixture']}#{r['run']} {r['outcome']}: "
                  + r["output"].replace("\n", " ⏎ "))
        print(f"   screen: {screened} outputs with a line opening on an infinitive or a task verb")


def contains_expectations(r):
    return [e["contains"] for e in r["expect"] if "contains" in e]


def b4(runs, rounds):
    section("B4 — no regression on N1-N6 against the baseline (bars.md §5)")
    print(f"{'round':10}{'runs':6}{'accepted':10}{'expectLost':12}{'wrongLang':11}refusedBy")
    for name, rows in by_round(runs, rounds):
        n_rows = [r for r in rows if r["set"] == "N" and scored(r)]
        lost = []
        for r in n_rows:
            if accepted(r):
                for needle in contains_expectations(r):
                    if needle.lower() not in r["output"].lower():
                        lost.append(f"{r['fixture']}#{r['run']}:{needle}")
        refused = defaultdict(int)
        for r in n_rows:
            if r["rejectedCheck"]:
                refused[r["rejectedCheck"]] += 1
        wrong = sum(accepted(r) and (r["outputLanguage"] != r["expectedLanguage"] or bool(r["foreignSentences"]))
                    for r in n_rows)
        print(f"{name:10}{len(n_rows):<6}{sum(accepted(r) for r in n_rows):<10}{len(lost):<12}{wrong:<11}"
              f"{', '.join(f'{k}={v}' for k, v in sorted(refused.items())) or '-'}")
        for item in lost:
            print(f"      lost: {item}")


def b5(runs, rounds):
    section("B5 — the shape: title, colon, flat bullets (bars.md §5)")
    print(f"{'round':10}{'set':5}{'accepted':10}{'shapeOK':9}defects")
    for name, rows in by_round(runs, rounds):
        for key in SETS:
            cell = [r for r in rows if r["set"] == key and accepted(r)]
            if not cell:
                continue
            defects = defaultdict(int)
            ok = 0
            for r in cell:
                _, _, found = shape(r["output"])
                ok += not found
                for d in found:
                    defects[d] += 1
            print(f"{name:10}{key:5}{len(cell):<10}{ok:<9}"
                  f"{', '.join(f'{k}={v}' for k, v in sorted(defects.items())) or '-'}")
    print("\nEvery accepted output off-shape on N, S, M, L (candidates only: the baseline has no title by design):")
    for r in runs:
        if accepted(r) and r["set"] != "T" and r["round"] != rounds[0]:
            _, _, found = shape(r["output"])
            if found:
                print(f"  [{r['round']}/{r['set']}] {r['fixture']}#{r['run']} {found}: "
                      + r["output"][:200].replace("\n", " ⏎ "))
    print("\nT, shape OK per language (accepted only):")
    for name, rows in by_round(runs, rounds):
        table = defaultdict(lambda: [0, 0])
        for r in rows:
            if r["set"] == "T" and accepted(r):
                table[r["expectedLanguage"]][0] += 1
                table[r["expectedLanguage"]][1] += not shape(r["output"])[2]
        if table:
            print(f"  {name}: " + "  ".join(f"{k} {v[1]}/{v[0]}" for k, v in sorted(table.items())))


def b6(runs, rounds):
    section("B6 — nothing dropped: axis 1 on N + M + L, and L5's trailing line (bars.md §5)")
    print(f"{'round':10}{'outputs':9}{'withUnrecalled':16}{'unrecalledTotal':17}L5 trailing kept")
    for name, rows in by_round(runs, rounds):
        cell = [r for r in rows if r["set"] in ("N", "M", "L") and scored(r)]
        l5 = [r for r in rows if r["set"] == "L" and r["fixture"].startswith("5") and scored(r)]
        kept = sum(bool(re.search(r"échappe|reviendra", r["output"])) for r in l5)
        print(f"{name:10}{len(cell):<9}{sum(bool(r['unrecalled']) for r in cell):<16}"
              f"{sum(len(r['unrecalled']) for r in cell):<17}{kept}/{len(l5)}")


def b7(runs, rounds):
    section("B7 — the band: refusals on check=length, and ratios (bars.md §5)")
    for name, rows in by_round(runs, rounds):
        cell = [r for r in rows if scored(r) and r["set"] != "T"]
        ratios = sorted(r["outputChars"] / r["rawChars"] for r in cell if r["rawChars"])
        refused = sum(r["rejectedCheck"] == "length" for r in cell)
        refused_t = sum(r["rejectedCheck"] == "length" for r in rows if r["set"] == "T")
        if ratios:
            print(f"  {name}: N+S+M+L refused on length {refused}/{len(cell)}, T {refused_t}; "
                  f"ratio min {ratios[0]:.2f} median {ratios[len(ratios) // 2]:.2f} max {ratios[-1]:.2f}")


def reported(runs, rounds):
    section("Reported, never barred: outcomes by round and set")
    print(f"{'round':10}{'set':5}{'runs':6}{'noOutput':10}{'success':9}refusedBy")
    for name, rows in by_round(runs, rounds):
        for key in SETS:
            cell = [r for r in rows if r["set"] == key]
            if not cell:
                continue
            out = [r for r in cell if scored(r)]
            refused = defaultdict(int)
            for r in out:
                if r["rejectedCheck"]:
                    refused[r["rejectedCheck"]] += 1
            print(f"{name:10}{key:5}{len(cell):<6}{len(cell) - len(out):<10}{sum(accepted(r) for r in out):<9}"
                  f"{', '.join(f'{k}={v}' for k, v in sorted(refused.items())) or '-'}")


# Round 2 (bars.md §8). Screens only: every flag is adjudicated by hand.
GENERIC = {"notes", "note", "résumé", "resume", "summary", "liste", "list", "points", "récap", "recap",
           "récapitulatif", "à faire", "a faire", "to do", "todo", "tâches", "taches", "tasks", "status",
           "current status", "état actuel", "estado actual", "stato attuale", "status atual"}
TIME_WORDS = re.compile(r"(?i)\b(lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|aujourd'hui|demain|hier|"
                        r"matin|soir|midi|monday|tuesday|wednesday|thursday|friday|saturday|sunday|today|"
                        r"tomorrow|yesterday|morning|evening|tonight|week|semaine)\b")


def content(text):
    return {w for w in words(text) if len(w) >= 4 and w not in STOP}


def round2(runs, rounds):
    section("ROUND 2 — title bars T1-T4, past facts P1, post-check P2 (bars.md §8)")
    for name, rows in by_round(runs, rounds):
        cell = [r for r in rows if accepted(r) and r["set"] != "T"]
        if not any(r["set"] == "R" for r in rows):
            continue
        t1 = t2 = t3 = t4 = 0
        print(f"── {name}: {len(cell)} accepted outputs on N, S, M, L, R")
        for r in cell:
            title, bullets, _ = shape(r["output"])
            if not title:
                continue
            bare = title.rstrip(":： ").strip()
            flags = []
            tc = content(bare)
            if tc and any(len(tc & content(b)) / len(tc) >= 0.7 for b in bullets):
                flags.append("T1 title≈a bullet"); t1 += 1
            invented = [w for w in TIME_WORDS.findall(bare) if w.lower() not in r["raw"].lower()]
            invented += numbers_unsupported(bare, r["raw"])
            if invented:
                flags.append(f"T2 not in input: {invented}"); t2 += 1
            if fold(bare) in {fold(g) for g in GENERIC} or re.match(r"(?i)^(tasks|actions|to do|à faire|a faire)\b", bare):
                flags.append("T3 generic"); t3 += 1
            short = [b for b in bullets if len(b[2:].split()) <= 2]
            if short and r["set"] in ("R", "M", "N"):
                flags.append(f"T4? short bullets {short}"); t4 += 1
            if flags:
                print(f"   [{r['set']}] {r['fixture']}#{r['run']}: {title!r} — " + "; ".join(flags))
        print(f"   screens: T1={t1} T2={t2} T3={t3} T4?={t4} (T4 lists every ≤ 2-word bullet; most are items, not fragments)")
        print("   P1, past facts on R1-R5 (every bullet, read by hand):")
        for r in rows:
            if r["set"] == "R" and r["fixture"][:3] in ("R1-", "R2-", "R3-", "R4-", "R5-") and scored(r):
                _, bullets, _ = shape(r["output"])
                hits = [b for b in bullets if FR_INFINITIVE.match(b)]
                print(f"     {'TASK?' if hits else '     '} {r['fixture']}#{r['run']}: " + " | ".join(bullets))
        print("   P2, list items per run (R6, R7 must be ≥ 2; R10 reported):")
        for r in rows:
            if r["set"] == "R" and r["fixture"][:3] in ("R6-", "R7-", "R10") and scored(r):
                print(f"     {r['fixture']}#{r['run']}: {len(shape(r['output'])[1])} bullet(s)")


def main():
    rounds = sys.argv[1:] or ["baseline", "c1"]
    runs = [r for name in rounds for r in load_round(name)]
    print(f"{len(runs)} runs loaded, rounds: {', '.join(rounds)}")
    b1(runs, rounds)
    b2(runs, rounds)
    b3(runs, rounds)
    b4(runs, rounds)
    b5(runs, rounds)
    b6(runs, rounds)
    b7(runs, rounds)
    round2(runs, rounds)
    reported(runs, rounds)


if __name__ == "__main__":
    main()
