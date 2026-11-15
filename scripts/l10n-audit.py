#!/usr/bin/env python3
"""
Localization audit for Dictus (issue #418). Read-only, stdlib only, Python 3.9+.

    scripts/l10n-audit.py                 # markdown report on stdout
    scripts/l10n-audit.py -o report.md    # same, written to a file
    scripts/l10n-audit.py --langs fr,de   # restrict the target languages
    scripts/l10n-audit.py --root <dir>    # audit another checkout (e.g. the base)

Dictus 2.0 ships in four languages: fr, en, de, es. This script answers two
questions for all four, and changes nothing:

1. **Catalogs.** Every `.xcstrings` and every `.strings` / `.stringsdict` in the
   repo (app, keyboard, widgets / Live Activity, share extension, InfoPlist,
   the iOS Settings bundle). Per catalog and per language it counts:
   - `missing`: a translatable key with no value in that language. For `en`,
     the source language, a key with no `en` value falls back to the key
     itself, so it only counts when the key is an identifier such as
     `accessibility.backspace` that would be read out verbatim.
   - `review`: values in state `needs_review` or `new`, which ship but have not
     been signed off.
   - `stale`: keys Xcode marked `extractionState: stale` (no longer found in
     source), per catalog, not per language.
   - `same as en`: a value identical to the English source that is probably an
     untranslated copy. Numerals, format-only strings and brand / product
     names (Dictus, Parakeet, Whisper, Apple Intelligence...) are ignored.
   - `plural gaps`: the English source has `variations` (plural or device)
     that the language does not carry.
   - `placeholders`: `%@`, `%lld`, `%1$@`... count or type differs from the
     English source. A positional specifier (`%2$@`) may legitimately reorder.

2. **Swift.** Call sites that put a string in front of a user without going
   through a catalog:
   - non-English literals (accented letters) outside the files the issue lists
     as data (emoji search keywords, LLM prompt examples, speech regexes,
     `#Preview` blocks, the iOS keyboard-picker mock);
   - prose literals returned from `errorDescription` / `failureReason` /
     `recoverySuggestion`, passed to `handleError(_:)`, to `Text(verbatim:)`,
     or to a labelled String argument (`title:`, `message:`, `name:`, ...);
   - `String(localized: "...")` keys absent from their target's catalog
     (Xcode adds them at the next build; until then no language but English).
   The second group is heuristic: each hit is a candidate for a human to read,
   not a proven defect.

`Text("literal")` is NOT flagged: SwiftUI resolves a literal as a
`LocalizedStringKey`, so it already goes through the catalog.

Exit code is 0 whatever the findings; this is a report, not a gate.
"""

import argparse
import json
import os
import re
import sys
from collections import Counter, OrderedDict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ["fr", "en", "de", "es"]
SOURCE = "en"

# Directories never scanned: build products, package checkouts, vendored data.
SKIP_DIRS = {".git", "build", ".build", "DerivedData", "SourcePackages", "node_modules", "Pods"}
# tools/ holds developer harnesses that never ship.
SKIP_TOP = {"tools", "claudedocs", "designs", "assets", "docs", ".planning"}

# Words that stay the same in every language: product and platform names.
BRAND_WORDS = {
    "dictus", "pro", "parakeet", "whisper", "whisperkit", "turbo", "nemotron",
    "apple", "intelligence", "iphone", "ipad", "ios", "siri", "airpods",
    "bluetooth", "wi-fi", "fluidaudio", "core", "ml", "coreml", "github",
    "testflight", "app", "store", "telegram", "ok", "id", "emoji", "smileys",
    "large", "small", "base", "tiny", "medium", "v2", "v3", "mb", "gb", "kb",
    "ms", "s", "min", "hz", "khz", "fm", "stt", "llm", "ane", "url", "qwerty",
    "azerty", "qwertz", "abc", "pivi", "solutions", "safari", "notes", "x",
    "copyright", "mit", "beta", "debug", "log", "logs", "e-mail", "email", "group",
    "en", "fr", "de", "es",  # language codes shown as badges
}

# Language names written in their own language: identical everywhere by design.
ENDONYMS = {"english", "français", "deutsch", "español", "italiano", "português", "nederlands",
            "русский", "日本語", "中文", "한국어", "polski", "svenska", "dansk", "norsk", "suomi", "türkçe"}
BRAND_WORDS |= ENDONYMS

# Values that are legitimately identical to English in a given language.
COGNATES = {
    "fr": {"apps", "notifications", "microphone", "volume", "diagnostic", "version", "message", "messages", "mode", "modes", "notes", "normal", "contact",
           "transcription", "transcriptions", "options", "suggestions", "minute", "minutes",
           "parfait", "description", "absolument", "simple", "date", "total", "global",
           "standard", "type", "audio", "texte", "format", "info", "action", "actions",
           "lecture", "excellent", "important", "stable", "national", "local", "original",
           "service", "accent", "question", "questions", "liste", "pause", "punctuation",
           "relax", "concept", "client", "support", "documents", "document", "statistiques",
           "glossaire", "orange", "test", "tests", "chat", "rare", "rapide", "simple"},
    "de": {"version", "name", "modus", "normal", "status", "start", "stop", "minuten",
           "minute", "audio", "text", "format", "info", "tipps", "app", "apps", "details",
           "transkription", "smart", "mode", "modes", "test", "tests", "glossar", "chat",
           "standard", "original", "export", "import", "feedback", "support", "plan",
           "experte", "orange", "pause", "live", "activity", "activities", "updates", "update",
           "layout"},
    "es": {"general", "normal", "error", "total", "original", "audio", "texto", "chat",
           "local", "global", "final", "plan", "sonido", "idea", "no", "experto", "simple",
           "modo", "modos", "estándar", "versión", "versiones", "minutos", "pausa", "test",
           "apps", "doctor"},
}

PLACEHOLDER_RE = re.compile(
    r"%(?:(\d+)\$)?[-+ #0']*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j|L)?([@dDuUxXoOfFeEgGcCsSaAp])"
)
WORD_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ'’\-]*")
IDENTIFIER_KEY_RE = re.compile(r"^[a-z][A-Za-z0-9]*(\.[A-Za-z0-9_]+)+$")


# --------------------------------------------------------------------------- helpers

def rel(path):
    return os.path.relpath(path, ROOT)


def walk(root, exts):
    for dirpath, dirnames, filenames in os.walk(root):
        relative = os.path.relpath(dirpath, root)
        top = relative.split(os.sep)[0]
        if relative != "." and top in SKIP_TOP:
            dirnames[:] = []
            continue
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS and not d.endswith(".xcodeproj"))
        for name in sorted(filenames):
            if name.endswith(exts):
                yield os.path.join(dirpath, name)


def placeholders(text):
    """Multiset of placeholder types, positional ones keyed by position."""
    found = []
    for match in PLACEHOLDER_RE.finditer(text.replace("%%", "")):
        position, kind = match.groups()
        kind = {"i": "d", "D": "d", "u": "d", "U": "d"}.get(kind, kind)
        found.append((int(position) if position else None, kind))
    return found


def placeholder_signature(text):
    found = placeholders(text)
    if any(pos is not None for pos, _ in found):
        # Positional: compare the set of (position, kind) pairs, order free.
        sig, implicit = [], 1
        for pos, kind in found:
            sig.append((pos if pos is not None else implicit, kind))
            implicit += 1
        return ("positional", tuple(sorted(sig)))
    return ("sequential", tuple(kind for _, kind in found))


def signatures_match(a, b):
    if a == b:
        return True
    # A sequential source may be reordered positionally in a translation.
    seq = lambda s: tuple(sorted(s[1], key=lambda x: x[0])) if s[0] == "positional" else tuple(
        (i + 1, k) for i, k in enumerate(s[1]))
    return seq(a) == seq(b)


def letters_only(text):
    stripped = PLACEHOLDER_RE.sub(" ", text)
    return [w.lower() for w in WORD_RE.findall(stripped)]


def is_trivial(text):
    """No word a translator could act on: numerals, format fragments, brand names."""
    words = letters_only(text)
    if not words:
        return True
    return all(w in BRAND_WORDS or len(w) == 1 for w in words)


def suspicious_identical(lang, value, source):
    if value != source or is_trivial(source):
        return False
    words = [w for w in letters_only(source) if w not in BRAND_WORDS and len(w) > 1]
    return not all(w in COGNATES.get(lang, set()) for w in words)


def flatten_unit(entry):
    """(value, state) pairs of a localization entry: a stringUnit or every leaf of variations."""
    out = []
    if "stringUnit" in entry:
        unit = entry["stringUnit"]
        out.append((unit.get("value", ""), unit.get("state", "")))
    for axis in (entry.get("variations") or {}).values():
        for leaf in axis.values():
            out.extend(flatten_unit(leaf))
    for sub in (entry.get("substitutions") or {}).values():
        out.extend(flatten_unit(sub))
    return out


def variation_shape(entry):
    """{axis: set(categories)} for an entry's variations, substitutions included."""
    shape = {}
    for axis, cases in (entry.get("variations") or {}).items():
        shape[axis] = set(cases)
    for name, sub in (entry.get("substitutions") or {}).items():
        for axis, cases in (sub.get("variations") or {}).items():
            shape["%s:%s" % (name, axis)] = set(cases)
    return shape


# Minimum plural categories each language needs (CLDR, integer counts).
PLURAL_REQUIRED = {"en": {"one", "other"}, "fr": {"one", "other"}, "de": {"one", "other"},
                   "es": {"one", "other"}}


# --------------------------------------------------------------------------- catalogs

class CatalogReport:
    def __init__(self, path, kind):
        self.path = path
        self.kind = kind
        self.keys = 0
        self.translatable = 0
        self.stale = []
        self.per_lang = {lang: {"translated": 0, "missing": [], "review": [], "identical": [],
                                "plural": [], "placeholder": []} for lang in LANGS}


def audit_xcstrings(path, langs):
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
    report = CatalogReport(path, "xcstrings")
    source_lang = data.get("sourceLanguage", SOURCE)
    for key, item in data.get("strings", {}).items():
        report.keys += 1
        if item.get("extractionState") == "stale":
            report.stale.append(key)
        locs = item.get("localizations") or {}
        if item.get("shouldTranslate") is False:
            continue
        source_entry = locs.get(source_lang)
        source_text = key
        if source_entry and flatten_unit(source_entry):
            source_text = flatten_unit(source_entry)[0][0]
        if key == "" or is_trivial(source_text) and not IDENTIFIER_KEY_RE.match(key):
            continue
        report.translatable += 1
        source_sig = placeholder_signature(source_text)
        source_shape = variation_shape(source_entry) if source_entry else {}
        for lang in langs:
            bucket = report.per_lang[lang]
            entry = locs.get(lang)
            if lang == source_lang and entry is None:
                if IDENTIFIER_KEY_RE.match(key):
                    bucket["missing"].append(key)
                else:
                    bucket["translated"] += 1
                continue
            units = flatten_unit(entry) if entry else []
            if not units or all(not value for value, _ in units):
                bucket["missing"].append(key)
                continue
            bucket["translated"] += 1
            if any(state in ("needs_review", "new") for _, state in units):
                bucket["review"].append(key)
            if lang != source_lang and "stringUnit" in entry and "variations" not in entry:
                if suspicious_identical(lang, entry["stringUnit"].get("value", ""), source_text):
                    bucket["identical"].append(key)
            shape = variation_shape(entry)
            for axis, cases in source_shape.items():
                needed = PLURAL_REQUIRED.get(lang, {"other"}) if axis.endswith("plural") else cases
                if axis not in shape or not needed <= shape[axis]:
                    bucket["plural"].append(key)
                    break
            if not source_shape:
                for value, _ in units:
                    if not signatures_match(placeholder_signature(value), source_sig):
                        bucket["placeholder"].append(key)
                        break
    return report


STRINGS_LINE_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.M)


def parse_strings(path):
    with open(path, "rb") as handle:
        raw = handle.read()
    for encoding in ("utf-8", "utf-16"):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    return OrderedDict(STRINGS_LINE_RE.findall(text))


def audit_strings_group(base, name, files, langs):
    """`files` maps lang -> path for one table (`Root.strings`) across lproj folders."""
    report = CatalogReport(os.path.join(base, "*.lproj", name), "strings")
    tables = {lang: parse_strings(path) for lang, path in files.items()}
    source = tables.get(SOURCE) or next(iter(tables.values()))
    for key, source_value in source.items():
        report.keys += 1
        if is_trivial(source_value):
            continue
        report.translatable += 1
        for lang in langs:
            bucket = report.per_lang[lang]
            table = tables.get(lang)
            if table is None or key not in table or not table[key]:
                bucket["missing"].append(key)
                continue
            bucket["translated"] += 1
            if lang != SOURCE and suspicious_identical(lang, table[key], source_value):
                bucket["identical"].append(key)
            if not signatures_match(placeholder_signature(table[key]), placeholder_signature(source_value)):
                bucket["placeholder"].append(key)
    return report


_SWIFT_CORPUS = None


def referenced_in_swift(key):
    """Whether the longest placeholder-free run of `key` appears in any Swift source.

    Xcode marks a key stale when it cannot see it extracted, which includes keys that
    reach the catalog through `LocalizedStringKey(variable)` or a custom function's
    `LocalizedStringKey` parameter. Those are still used and must not be deleted."""
    global _SWIFT_CORPUS
    if _SWIFT_CORPUS is None:
        texts = []
        for root in SWIFT_ROOTS:
            for path in walk(os.path.join(ROOT, root), (".swift",)):
                with open(path, encoding="utf-8") as handle:
                    texts.append(handle.read())
        _SWIFT_CORPUS = "\n".join(texts)
    fragment = max(re.split(r"%(?:\d+\$)?l{0,2}[@dlf]|\n", key), key=len)[:50]
    return bool(fragment) and fragment in _SWIFT_CORPUS


def find_catalogs(langs):
    reports = []
    groups = {}
    for path in walk(ROOT, (".xcstrings", ".strings", ".stringsdict")):
        if path.endswith(".xcstrings"):
            reports.append(audit_xcstrings(path, langs))
            continue
        folder = os.path.dirname(path)
        if not folder.endswith(".lproj"):
            continue
        lang = os.path.basename(folder)[:-len(".lproj")]
        base = os.path.dirname(folder)
        groups.setdefault((base, os.path.basename(path)), {})[lang] = path
    for (base, name), files in sorted(groups.items()):
        if name.endswith(".stringsdict"):
            continue  # none in the repo today; reported as a table if one appears
        reports.append(audit_strings_group(base, name, files, langs))
    return reports


# --------------------------------------------------------------------------- swift scan

# Files whose non-English literals are data, not UI (issue #418, "Not a bug").
DATA_FILES = (
    "DictusKeyboard/Models/EmojiSearchFR.swift",
    "/Polish/Prompts/",
    "VerbalPunctuationPrepass.swift",
    "GlobeKeyTutorialPage.swift",  # mock of iOS's own keyboard picker ("Français")
    # Same class as the Prompts folder: lexicons, regexes and phrase lists the polish
    # guards match against dictated text in the language it was spoken in.
    "DictusCore/Sources/DictusCore/Polish/",
    "DictusCore/Sources/PolishFidelity/",
    "NonSpeechMarkers.swift",           # Whisper's non-speech tags, per language
    "DictusKeyboard/TextPrediction/",   # French words the predictor ranks
)
# Folders scanned for UI strings. Tests are not shipped.
SWIFT_ROOTS = ("DictusApp", "DictusKeyboard", "DictusCore/Sources", "DictusWidgets", "DictusShare")

STRING_LITERAL_RE = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
ACCENT_RE = re.compile(r"[À-ÖØ-öø-ÿŒœ]")
PROSE_RE = re.compile(r"^[A-ZÀ-Ö][^\n]*[a-zà-ÿ]{2,}[^\n]*\s[^\n]*[a-zà-ÿ]")
LOG_CALL_RE = re.compile(
    r"(@available|PersistentLog|DictusLogger|Logger|\blog\(|keyboardLog|print\(|debugPrint|assert|"
    r"precondition|fatalError|XCT|\.debug\(|\.info\(|\.error\(|\.warning\(|\.notice\(|"
    r"#if DEBUG|diagnostic|Diagnostic|details:|context:|reason:|evidence:|component:)")
UI_ARGUMENT_RE = re.compile(
    r"\b(title|message|name|label|subtitle|text|placeholder|prompt|caption|header|footer|"
    r"detail|hint|headline|body|buttonTitle|actionTitle|explanation):\s*\"((?:[^\"\\]|\\.)*)\"")
ERROR_GETTER_RE = re.compile(r"var\s+(errorDescription|failureReason|recoverySuggestion|helpAnchor)\b")
STRING_LOCALIZED_RE = re.compile(r'String\(\s*localized:\s*"((?:[^"\\]|\\.)*)"')


def strip_comment(line):
    """Drop a trailing // comment that is not inside a string literal."""
    in_string = False
    i = 0
    while i < len(line) - 1:
        char = line[i]
        if char == "\\" and in_string:
            i += 2
            continue
        if char == '"':
            in_string = not in_string
        elif not in_string and line[i:i + 2] == "//":
            return line[:i]
        i += 1
    return line


def preview_ranges(lines):
    """Line indices inside `#Preview { ... }` / `PreviewProvider` blocks."""
    inside = set()
    depth = None
    for index, line in enumerate(lines):
        if depth is None and ("#Preview" in line or "PreviewProvider" in line):
            depth = 0
            started = False
        if depth is not None:
            inside.add(index)
            depth += line.count("{") - line.count("}")
            started = started or "{" in line
            if started and depth <= 0:
                depth = None
    return inside


def debug_ranges(lines):
    """Line indices inside `#if DEBUG ... #endif`: debug builds only, never shipped."""
    inside = set()
    stack = []
    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("#if"):
            stack.append(stripped == "#if DEBUG")
        elif stripped.startswith("#else") and stack:
            stack[-1] = False
        elif stripped.startswith("#endif") and stack:
            stack.pop()
        if any(stack):
            inside.add(index)
    return inside


def interpolation_to_regex(literal):
    """`Optimization did not finish within \\(seconds)s.` -> regex over catalog keys."""
    parts = re.split(r"\\\((?:[^()]|\([^()]*\))*\)", literal)
    body = "%(?:\\d+\\$)?[-+ #0]*\\d*(?:\\.\\d+)?(?:ll|l|h|hh|q|z|t|j)?[@dDuUxXoOfeEgGcCsSaAp]"
    unescaped = [p.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\") for p in parts]
    return re.compile("^" + body.join(re.escape(p) for p in unescaped) + "$", re.S)


def load_catalog_keys():
    keys = {}
    for target in ("DictusApp", "DictusKeyboard", "DictusWidgets", "DictusShare"):
        path = os.path.join(ROOT, target, "Localizable.xcstrings")
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                keys[target] = set(json.load(handle).get("strings", {}))
    return keys


def scan_swift():
    findings = {"non_english": [], "error_getter": [], "handle_error": [], "verbatim": [],
                "ui_argument": [], "missing_key": []}
    catalog_keys = load_catalog_keys()
    for root in SWIFT_ROOTS:
        for path in walk(os.path.join(ROOT, root), (".swift",)):
            relative = rel(path)
            if "/Tests/" in relative:
                continue
            is_data = any(marker in relative for marker in DATA_FILES)
            target = relative.split("/")[0]
            with open(path, encoding="utf-8") as handle:
                lines = handle.read().split("\n")
            previews = preview_ranges(lines) | debug_ranges(lines)
            in_block_comment = False
            getter_depth = None  # brace depth inside an errorDescription-style getter
            for index, raw in enumerate(lines):
                line = raw
                if in_block_comment:
                    if "*/" in line:
                        in_block_comment = False
                        line = line.split("*/", 1)[1]
                    else:
                        continue
                if "/*" in line and '"' not in line.split("/*", 1)[0]:
                    head, _, tail = line.partition("/*")
                    if "*/" not in tail:
                        in_block_comment = True
                    line = head
                stripped = line.strip()
                if stripped.startswith("//") or stripped.startswith("///"):
                    continue
                code = strip_comment(line)
                where = "%s:%d" % (relative, index + 1)
                # A `comment:` argument is translator context, never shown.
                literals = STRING_LITERAL_RE.findall(re.sub(r'comment:\s*"(?:[^"\\]|\\.)*"', "", code))
                is_log = bool(LOG_CALL_RE.search(code))

                # Track errorDescription-style getters by brace depth.
                if getter_depth is None and ERROR_GETTER_RE.search(code):
                    getter_depth = 0
                if getter_depth is not None:
                    for literal in re.findall(r'return\s+"((?:[^"\\]|\\.)*)"', code):
                        if not is_trivial(literal):
                            findings["error_getter"].append((where, literal))
                    getter_depth += code.count("{") - code.count("}")
                    if getter_depth <= 0 and "}" in code:
                        getter_depth = None

                for literal in STRING_LOCALIZED_RE.findall(code):
                    if target in catalog_keys:
                        if literal in catalog_keys[target]:
                            continue
                        pattern = interpolation_to_regex(literal)
                        if not any(pattern.match(k) for k in catalog_keys[target]):
                            findings["missing_key"].append((where, literal))
                    elif target == "DictusCore":
                        pool = catalog_keys.get("DictusApp", set()) | catalog_keys.get("DictusKeyboard", set())
                        pattern = interpolation_to_regex(literal)
                        if literal not in pool and not any(pattern.match(k) for k in pool):
                            findings["missing_key"].append((where, literal))

                if index in previews or is_data:
                    continue
                for literal in literals:
                    if ACCENT_RE.search(literal) and not is_log:
                        findings["non_english"].append((where, literal))
                if is_log:
                    continue
                for literal in re.findall(r'handleError\(\s*"((?:[^"\\]|\\.)*)"', code):
                    findings["handle_error"].append((where, literal))
                for literal in re.findall(r'Text\(\s*verbatim:\s*"((?:[^"\\]|\\.)*)"', code):
                    words = letters_only(re.sub(r"\\\((?:[^()]|\([^()]*\))*\)", " ", literal))
                    if len(words) >= 3 and not is_trivial(literal) and PROSE_RE.match(literal):
                        findings["verbatim"].append((where, literal))
                for name, literal in UI_ARGUMENT_RE.findall(code):
                    if is_trivial(literal) or not PROSE_RE.match(literal):
                        continue
                    before = code[:code.find('%s: "%s"' % (name, literal))]
                    if re.search(r"(String\(localized:|LocalizedStringKey\(|LocalizedStringResource\()\s*$", before):
                        continue
                    if "\\(" in literal and literal.count(" ") < 2:
                        continue
                    # A catalog key passed to a `LocalizedStringKey` parameter resolves
                    # through the catalog; the scan cannot see the parameter type.
                    if literal in catalog_keys.get(target, ()):
                        continue
                    findings["ui_argument"].append((where, "%s: %s" % (name, literal)))
    return findings


# --------------------------------------------------------------------------- report

def render(reports, findings, langs):
    out = []
    w = out.append
    w("# Localization audit (Dictus, issue #418)\n")
    w("Generated by `scripts/l10n-audit.py`. Languages: %s. Source language: `en`.\n" % ", ".join(langs))
    w("## Catalog summary\n")
    w("`translatable` excludes empty keys, numerals, format-only strings and brand names. "
      "`stale` is per catalog (Xcode's `extractionState`).\n")
    header = "| catalog | keys | translatable | stale |" + "".join(
        " %s missing | %s review | %s same-as-en | %s plural | %s placeholder |" % ((l,) * 5) for l in langs)
    w(header)
    w("|" + " --- |" * (4 + 5 * len(langs)))
    totals = Counter()
    for r in reports:
        row = "| `%s` | %d | %d | %d |" % (rel(r.path), r.keys, r.translatable, len(r.stale))
        totals["keys"] += r.keys
        totals["translatable"] += r.translatable
        totals["stale"] += len(r.stale)
        for lang in langs:
            b = r.per_lang[lang]
            values = (len(b["missing"]), len(b["review"]), len(b["identical"]), len(b["plural"]), len(b["placeholder"]))
            for name, value in zip(("missing", "review", "identical", "plural", "placeholder"), values):
                totals[lang + name] += value
            row += " %d | %d | %d | %d | %d |" % values
        w(row)
    row = "| **total** | %d | %d | %d |" % (totals["keys"], totals["translatable"], totals["stale"])
    for lang in langs:
        row += "".join(" **%d** |" % totals[lang + n] for n in ("missing", "review", "identical", "plural", "placeholder"))
    w(row)
    w("")

    w("## Swift summary\n")
    labels = OrderedDict([
        ("non_english", "Non-English (accented) literals outside data files"),
        ("handle_error", "Literals passed to `handleError(_:)`"),
        ("error_getter", "Literals returned from `errorDescription` & co."),
        ("verbatim", "Prose in `Text(verbatim:)`"),
        ("ui_argument", "Prose literal in a labelled String argument (candidate)"),
        ("missing_key", "`String(localized:)` key absent from its catalog"),
    ])
    w("| check | hits |")
    w("| --- | --- |")
    for key, label in labels.items():
        w("| %s | %d |" % (label, len(findings[key])))
    w("")

    w("## Catalog details\n")
    for r in reports:
        lines = []
        for lang in langs:
            b = r.per_lang[lang]
            for name, title in (("missing", "missing"), ("review", "needs review / new"),
                                ("identical", "same as English"), ("plural", "plural / variation gap"),
                                ("placeholder", "placeholder mismatch")):
                if b[name]:
                    lines.append("**%s, %s (%d)**\n" % (lang, title, len(b[name])))
                    lines.extend("- `%s`" % k.replace("\n", "\\n") for k in b[name])
                    lines.append("")
        if r.stale:
            used = [k for k in r.stale if referenced_in_swift(k)]
            unused = [k for k in r.stale if k not in used]
            for title, keys in (("stale extraction, still referenced in Swift (keep)", used),
                                ("stale extraction, not found in Swift", unused)):
                if keys:
                    lines.append("**%s (%d)**\n" % (title, len(keys)))
                    lines.extend("- `%s`" % k.replace("\n", "\\n") for k in keys)
                    lines.append("")
        if lines:
            w("### `%s`\n" % rel(r.path))
            out.extend(lines)
    w("## Swift details\n")
    for key, label in labels.items():
        if findings[key]:
            w("### %s (%d)\n" % (label, len(findings[key])))
            for where, literal in findings[key]:
                w("- `%s` — `%s`" % (where, literal.replace("`", "'")))
            w("")
    return "\n".join(out) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("-o", "--output", help="write the markdown report here instead of stdout")
    parser.add_argument("--root", help="repository to audit (default: this script's repo)")
    parser.add_argument("--langs", default=",".join(LANGS), help="comma-separated target languages")
    args = parser.parse_args()
    if args.root:
        global ROOT
        ROOT = os.path.abspath(args.root)
    langs = [l.strip() for l in args.langs.split(",") if l.strip()]
    report = render(find_catalogs(langs), scan_swift(), langs)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(report)
    else:
        sys.stdout.write(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
