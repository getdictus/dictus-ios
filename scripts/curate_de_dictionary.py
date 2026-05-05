#!/usr/bin/env python3
"""
Curate German frequency dictionary from HermitDave's FrequencyWords (2018).

Downloads de_50k.txt (OpenSubtitles 2018, German top 50K words), takes top 40K,
outputs JSON {word: count} where higher count = more common.

WHY HermitDave: Same source family used implicitly by ngram_builder.py
(OpenSubtitles via orgtre's top sentences). Stable, well-known, conversational
register that matches the keyboard's typical use case.

Per ADR 0001 (non-native maintainer launch), no curated additions
(SMS abbreviations, proper nouns) are layered in for first ship —
populated post-launch from feedback on issue #109.
"""

import json
import os
import urllib.request

HERMITDAVE_URL = "https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/de/de_50k.txt"
TXT_FILE = "de_50k.txt"
OUTPUT = os.path.join(os.path.dirname(__file__), "..", "DictusKeyboard", "Resources", "de_frequency.json")


def download_hermitdave():
    """Download HermitDave de_50k.txt if not already present."""
    if os.path.exists(TXT_FILE):
        print(f"[INFO] Using existing {TXT_FILE}")
        return
    print(f"[INFO] Downloading HermitDave de_50k.txt from {HERMITDAVE_URL}...")
    urllib.request.urlretrieve(HERMITDAVE_URL, TXT_FILE)
    print(f"[INFO] Downloaded {os.path.getsize(TXT_FILE)} bytes")


def main():
    download_hermitdave()
    print("[INFO] Parsing de_50k.txt...")

    freq_dict = {}
    with open(TXT_FILE, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) == 2:
                word = parts[0].strip().lower()
                try:
                    count = int(parts[1])
                except ValueError:
                    continue
                if word and count > 0:
                    freq_dict[word] = count

    print(f"[INFO] Parsed {len(freq_dict)} words from de_50k.txt")

    # Sort by count descending, take top 40,000
    sorted_words = sorted(freq_dict.items(), key=lambda x: -x[1])[:40000]
    result = {word: count for word, count in sorted_words}

    # Output
    output_path = os.path.abspath(OUTPUT)
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, separators=(",", ":"))

    print(f"[DONE] Wrote {len(result)} entries to {output_path}")

    # Cleanup downloaded file
    if os.path.exists(TXT_FILE):
        os.remove(TXT_FILE)
        print(f"[INFO] Cleaned up {TXT_FILE}")


if __name__ == "__main__":
    main()
