#!/usr/bin/env python3
"""
Curate English frequency dictionary from Norvig's count_1w.txt.

Downloads count_1w.txt (Google Trillion Word Corpus), takes top 40K words,
outputs JSON {word: count} where higher count = more common.
"""

import json
import os
import urllib.request

NORVIG_URL = "https://norvig.com/ngrams/count_1w.txt"
TXT_FILE = "count_1w.txt"
OUTPUT = os.path.join(os.path.dirname(__file__), "..", "DictusKeyboard", "Resources", "en_frequency.json")


def download_norvig():
    """Download Norvig's count_1w.txt if not already present."""
    if os.path.exists(TXT_FILE):
        print(f"[INFO] Using existing {TXT_FILE}")
        return
    print(f"[INFO] Downloading Norvig count_1w.txt from {NORVIG_URL}...")
    urllib.request.urlretrieve(NORVIG_URL, TXT_FILE)
    print(f"[INFO] Downloaded {os.path.getsize(TXT_FILE)} bytes")


def main():
    download_norvig()
    print("[INFO] Parsing count_1w.txt...")

    freq_dict = {}
    with open(TXT_FILE, "r", encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("\t")
            if len(parts) == 2:
                word = parts[0].strip().lower()
                try:
                    count = int(parts[1])
                except ValueError:
                    continue
                if word and count > 0:
                    freq_dict[word] = count

    print(f"[INFO] Parsed {len(freq_dict)} words from count_1w.txt")

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
