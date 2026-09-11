#!/usr/bin/env python3
"""Extract a prompt's literal text from its Swift source file.

Usage:  python3 extract-prompt.py <Prompt.swift> > candidate.txt

`polish-harness prompt` dumps the per-language prompt a fixture resolves to, and
it says so and exits on the Auto path: a fixture routed through auto has no
per-language prompt to resolve. `PolishAutoPrompt` is one of the two routes this
round has to measure, so its bytes have to come from somewhere.

They come from the one place that cannot drift: the multi-line string literal in
the Swift file the build compiles. The prompt builders carry no interpolation and
no escapes, so the literal IS the string. This script checks that rather than
assuming it, and refuses to print anything when it is not true.

Verified against `polish-harness prompt --out` on the French Natural prompt: the
two agree byte for byte. See findings.md.
"""

import re
import sys

DELIM = '"' * 3

src = open(sys.argv[1], encoding="utf-8").read()
body = re.search(DELIM + r'\n(.*?)\n(\s*)' + DELIM, src, re.S)
if not body:
    sys.exit(f"{sys.argv[1]}: no multi-line string literal found")
text, indent = body.group(1), body.group(2)

# A literal carrying either of these is not its own text, and a silently wrong
# prompt file would make every number in this round measure the wrong bytes.
if "\\(" in text:
    sys.exit(f"{sys.argv[1]}: the literal interpolates - extraction is not safe")
if re.search(r"\\[^\\]", text):
    sys.exit(f"{sys.argv[1]}: the literal carries escapes - extraction is not safe")

# Swift strips the closing delimiter's indentation from every line, and the
# literal ends without a trailing newline - which is what the engine is handed,
# so the file must not gain one either.
sys.stdout.write("\n".join(
    line[len(indent):] if line.startswith(indent) else line
    for line in text.split("\n")
))
