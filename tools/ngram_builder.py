#!/usr/bin/env python3
"""
ngram_builder.py -- Build NGRM binary dictionaries for Dictus next-word prediction.

Downloads bigram/trigram frequency data from Google Books Ngram corpus,
processes it, and generates compact binary files for mmap-based lookup on iOS.

Usage:
    python3 tools/ngram_builder.py --lang fr --output DictusKeyboard/Resources/fr_ngrams.dict
    python3 tools/ngram_builder.py --lang en --output DictusKeyboard/Resources/en_ngrams.dict

Options:
    --min-freq N        Minimum n-gram frequency to include (default: 2)
    --max-bigrams N     Maximum bigram entries (default: unlimited)
    --max-trigrams N    Maximum trigram entries (default: unlimited)
    --fallback-json P   Use frequency JSON instead of downloading n-gram CSVs
"""

import argparse
import json
import math
import os
import re
import struct
import sys
import urllib.request
import urllib.error
from collections import defaultdict
from typing import Optional


# --- Constants ---
NGRM_MAGIC = b"NGRM"
NGRM_VERSION = 1
NGRM_HEADER_SIZE = 32
NGRM_MAX_RESULTS = 8

# Google Books Ngram frequency data (CSV: ngram,frequency)
NGRAM_BASE_URL = "https://raw.githubusercontent.com/orgtre/google-books-ngram-frequency/main/ngrams"

LANG_MAP = {
    "fr": "french",
    "en": "english",
}

# Common French function words for synthetic bigram generation
FR_FUNCTION_WORDS = [
    "je", "tu", "il", "elle", "on", "nous", "vous", "ils", "elles",
    "de", "la", "le", "les", "un", "une", "des", "du", "au", "aux",
    "et", "ou", "mais", "que", "qui", "en", "dans", "sur", "pour",
    "avec", "par", "pas", "plus", "ne", "se", "ce", "sa", "son", "ses",
    "est", "sont", "ont", "fait", "dit", "va", "peut", "dois", "veux",
    "sais", "aime", "ai", "as", "a", "avons", "avez",
    "mon", "ma", "mes", "ton", "ta", "tes", "notre", "votre", "leur",
    "me", "te", "lui", "y", "si", "bien", "très", "aussi", "tout",
    "cette", "ces", "être", "avoir", "faire", "aller", "voir", "dire",
]

EN_FUNCTION_WORDS = [
    "i", "you", "he", "she", "it", "we", "they",
    "the", "a", "an", "and", "or", "but", "that", "which", "who",
    "in", "on", "at", "to", "for", "with", "by", "from", "of",
    "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "do", "does", "did", "will", "would",
    "can", "could", "shall", "should", "may", "might", "must",
    "not", "no", "this", "these", "those", "my", "your", "his",
    "her", "its", "our", "their", "me", "him", "us", "them",
    "what", "how", "when", "where", "why", "if", "so", "very",
    "just", "also", "more", "most", "than", "then", "now",
]


# --- FNV-1a 32-bit hash (must match C++ exactly) ---
def fnv1a_32(data: bytes) -> int:
    """FNV-1a 32-bit hash. Must match the C++ implementation exactly."""
    h = 0x811c9dc5
    for b in data:
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


# --- Token validation ---
def is_valid_token(token: str) -> bool:
    """Check if a token is valid for inclusion in n-gram data."""
    if len(token) < 1:
        return False
    # Allow apostrophe words (French elisions like l'homme)
    # Remove numbers and punctuation-only tokens
    if re.match(r'^[\d\W]+$', token):
        return False
    # Allow letters, apostrophes, hyphens within words
    if re.match(r"^[a-zA-ZÀ-ÿ'']+(?:[-'][a-zA-ZÀ-ÿ'']+)*$", token):
        return True
    return False


def normalize_token(token: str) -> str:
    """Normalize a token: lowercase and normalize apostrophes."""
    token = token.lower().strip()
    # Normalize curly apostrophes to straight
    token = token.replace("\u2019", "'").replace("\u2018", "'")
    return token


# --- Data sourcing ---
def download_ngram_csv(lang: str, n: int) -> Optional[str]:
    """Download n-gram CSV from GitHub. Returns CSV text or None on failure."""
    lang_name = LANG_MAP.get(lang)
    if not lang_name:
        print(f"  Unknown language: {lang}")
        return None

    url = f"{NGRAM_BASE_URL}/{n}grams_{lang_name}.csv"
    print(f"  Downloading {url}...")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Dictus/1.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read().decode("utf-8", errors="replace")
            print(f"  Downloaded {len(data)} bytes")
            return data
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError) as e:
        print(f"  Download failed: {e}")
        return None


def parse_ngram_csv(csv_text: str, n: int, min_freq: int) -> dict[str, list[tuple[str, int]]]:
    """
    Parse CSV n-gram data into a dict: key -> [(predicted_word, frequency), ...]

    For bigrams (n=2): key = previous word, predicted = next word
    For trigrams (n=3): key = "word1\\0word2", predicted = next word
    """
    result: dict[str, list[tuple[str, int]]] = defaultdict(list)
    lines_processed = 0
    lines_skipped = 0

    for line in csv_text.splitlines():
        line = line.strip()
        if not line or line.startswith("ngram"):
            continue

        # CSV format: ngram,frequency
        # The ngram itself may contain commas in rare cases, so split from right
        parts = line.rsplit(",", 1)
        if len(parts) != 2:
            lines_skipped += 1
            continue

        ngram_text, freq_str = parts
        try:
            freq = int(freq_str.strip())
        except ValueError:
            lines_skipped += 1
            continue

        if freq < min_freq:
            continue

        tokens = ngram_text.strip().split()
        if len(tokens) != n:
            lines_skipped += 1
            continue

        # Normalize and validate all tokens
        normalized = [normalize_token(t) for t in tokens]
        if not all(is_valid_token(t) for t in normalized):
            lines_skipped += 1
            continue

        # Key is context words, value is predicted word
        if n == 2:
            key = normalized[0]
            predicted = normalized[1]
        else:  # n == 3
            key = normalized[0] + "\0" + normalized[1]
            predicted = normalized[2]

        result[key].append((predicted, freq))
        lines_processed += 1

    print(f"  Parsed {lines_processed} valid {n}-grams (skipped {lines_skipped})")
    return dict(result)


def generate_fallback_bigrams(freq_json_path: str, lang: str) -> dict[str, list[tuple[str, int]]]:
    """
    Generate synthetic bigrams from frequency dictionary when download fails.

    Pairs common function words with top vocabulary words.
    Lower quality but functional for basic predictions.
    """
    print(f"  Generating fallback bigrams from {freq_json_path}...")
    with open(freq_json_path, "r", encoding="utf-8") as f:
        freq_data: dict[str, int] = json.load(f)

    # Get top N words sorted by frequency
    top_words = sorted(freq_data.items(), key=lambda x: x[1], reverse=True)[:5000]
    top_word_set = {w.lower() for w, _ in top_words}

    func_words = FR_FUNCTION_WORDS if lang == "fr" else EN_FUNCTION_WORDS
    result: dict[str, list[tuple[str, int]]] = defaultdict(list)

    # For each function word, pair with top words to create synthetic bigrams
    for fw in func_words:
        fw_lower = fw.lower()
        if fw_lower not in top_word_set:
            continue
        fw_freq = freq_data.get(fw_lower, freq_data.get(fw, 1))

        for word, freq in top_words[:500]:
            word_lower = word.lower()
            if word_lower == fw_lower:
                continue
            # Synthetic bigram frequency: geometric mean of individual frequencies
            syn_freq = int(math.sqrt(fw_freq * freq))
            if syn_freq < 2:
                continue
            result[fw_lower].append((word_lower, syn_freq))

    # Also create bigrams between function words (very common pairs)
    for i, fw1 in enumerate(func_words):
        for fw2 in func_words[i + 1:]:
            fw1_lower = fw1.lower()
            fw2_lower = fw2.lower()
            f1 = freq_data.get(fw1_lower, 0)
            f2 = freq_data.get(fw2_lower, 0)
            if f1 > 0 and f2 > 0:
                syn_freq = int(math.sqrt(f1 * f2))
                if syn_freq >= 2:
                    result[fw1_lower].append((fw2_lower, syn_freq))
                    result[fw2_lower].append((fw1_lower, syn_freq))

    total_pairs = sum(len(v) for v in result.values())
    print(f"  Generated {total_pairs} synthetic bigram pairs for {len(result)} keys")
    return dict(result)


def cap_and_sort_results(
    ngram_data: dict[str, list[tuple[str, int]]], max_results: int = NGRM_MAX_RESULTS
) -> dict[str, list[tuple[str, int]]]:
    """Sort results by frequency descending and cap at max_results per key."""
    capped: dict[str, list[tuple[str, int]]] = {}
    for key, results in ngram_data.items():
        # Merge duplicates (same predicted word from different sources)
        merged: dict[str, int] = {}
        for word, freq in results:
            merged[word] = max(merged.get(word, 0), freq)
        sorted_results = sorted(merged.items(), key=lambda x: x[1], reverse=True)[:max_results]
        if sorted_results:
            capped[key] = sorted_results
    return capped


# --- Binary serialization ---
def build_string_table(bigrams: dict, trigrams: dict) -> tuple[dict[str, int], bytes]:
    """
    Build packed null-terminated string table from all predicted words.
    Returns (word -> offset map, table bytes).
    """
    # Collect all unique predicted words
    words: set[str] = set()
    for results in bigrams.values():
        for word, _ in results:
            words.add(word)
    for results in trigrams.values():
        for word, _ in results:
            words.add(word)

    # Sort for deterministic output
    sorted_words = sorted(words)

    # Build table: each word is null-terminated UTF-8
    table = bytearray()
    offsets: dict[str, int] = {}
    for word in sorted_words:
        offsets[word] = len(table)
        table.extend(word.encode("utf-8"))
        table.append(0)  # null terminator

    return offsets, bytes(table)


def normalize_scores(data: dict[str, list[tuple[str, int]]]) -> dict[str, list[tuple[str, int]]]:
    """Normalize all frequencies to uint16 (0-65535) using log-scale."""
    # Find global max frequency
    max_freq = 1
    for results in data.values():
        for _, freq in results:
            max_freq = max(max_freq, freq)

    log_max = math.log(max_freq + 1)
    normalized: dict[str, list[tuple[str, int]]] = {}
    for key, results in data.items():
        norm_results = []
        for word, freq in results:
            score = int(math.log(freq + 1) / log_max * 65535)
            score = min(65535, max(1, score))  # minimum score of 1 for included entries
            norm_results.append((word, score))
        normalized[key] = norm_results
    return normalized


def serialize_section(
    data: dict[str, list[tuple[str, int]]],
    string_offsets: dict[str, int],
    is_trigram: bool,
) -> tuple[bytes, int]:
    """
    Serialize bigram or trigram entries to binary.

    Each entry:
      key_hash:     uint32 LE (FNV-1a of key bytes)
      result_count: uint8
      results[]:    (word_offset: uint32 LE, score: uint16 LE) * result_count

    Entries sorted by key_hash ascending for binary search.
    Returns (section_bytes, entry_count).
    """
    entries: list[tuple[int, bytes]] = []

    for key, results in data.items():
        # Hash the key
        if is_trigram:
            # Key is already "word1\0word2" (null-separated)
            key_bytes = key.encode("utf-8")
        else:
            key_bytes = key.encode("utf-8")

        key_hash = fnv1a_32(key_bytes)

        # Build entry bytes
        result_count = min(len(results), NGRM_MAX_RESULTS)
        entry = bytearray()
        entry.extend(struct.pack("<I", key_hash))
        entry.append(result_count)

        for word, score in results[:result_count]:
            word_off = string_offsets.get(word, 0)
            entry.extend(struct.pack("<IH", word_off, score))

        entries.append((key_hash, bytes(entry)))

    # Sort by key_hash for binary search
    entries.sort(key=lambda x: x[0])

    # Concatenate
    buf = bytearray()
    for _, entry_bytes in entries:
        buf.extend(entry_bytes)

    return bytes(buf), len(entries)


def serialize_ngrm(
    bigrams: dict[str, list[tuple[str, int]]],
    trigrams: dict[str, list[tuple[str, int]]],
    output_path: str,
) -> tuple[int, int, int]:
    """
    Serialize bigrams and trigrams to NGRM binary format.
    Returns (bigram_count, trigram_count, file_size).
    """
    # Normalize scores to uint16
    bigrams_norm = normalize_scores(bigrams)
    trigrams_norm = normalize_scores(trigrams)

    # Build string table
    string_offsets, string_table = build_string_table(bigrams_norm, trigrams_norm)

    # Serialize sections
    bigram_bytes, bigram_count = serialize_section(bigrams_norm, string_offsets, is_trigram=False)
    trigram_bytes, trigram_count = serialize_section(trigrams_norm, string_offsets, is_trigram=True)

    # Calculate offsets
    bigram_offset = NGRM_HEADER_SIZE
    trigram_offset = bigram_offset + len(bigram_bytes)
    string_table_offset = trigram_offset + len(trigram_bytes)

    # Build header
    header = bytearray()
    header.extend(NGRM_MAGIC)
    header.extend(struct.pack("<H", NGRM_VERSION))
    header.extend(struct.pack("<H", 0))  # flags (reserved)
    header.extend(struct.pack("<I", bigram_count))
    header.extend(struct.pack("<I", trigram_count))
    header.extend(struct.pack("<I", bigram_offset))
    header.extend(struct.pack("<I", trigram_offset))
    header.extend(struct.pack("<I", string_table_offset))
    header.extend(struct.pack("<I", len(string_table)))
    assert len(header) == NGRM_HEADER_SIZE, f"Header is {len(header)} bytes, expected {NGRM_HEADER_SIZE}"

    # Write file
    with open(output_path, "wb") as f:
        f.write(header)
        f.write(bigram_bytes)
        f.write(trigram_bytes)
        f.write(string_table)

    file_size = NGRM_HEADER_SIZE + len(bigram_bytes) + len(trigram_bytes) + len(string_table)
    return bigram_count, trigram_count, file_size


# --- Main pipeline ---
def build_ngrams(
    lang: str,
    output_path: str,
    min_freq: int = 2,
    max_bigrams: Optional[int] = None,
    max_trigrams: Optional[int] = None,
    fallback_json: Optional[str] = None,
) -> None:
    """Full pipeline: download/load -> process -> serialize -> write."""
    print(f"\n=== Building n-gram dictionary for '{lang}' ===\n")

    # --- Load bigram data ---
    bigram_data: dict[str, list[tuple[str, int]]] = {}
    trigram_data: dict[str, list[tuple[str, int]]] = {}

    if fallback_json:
        # Use fallback JSON directly
        bigram_data = generate_fallback_bigrams(fallback_json, lang)
        # No trigram data in fallback mode
        trigram_data = {}
    else:
        # Try downloading from Google Books Ngram
        print("Loading bigram data...")
        bigram_csv = download_ngram_csv(lang, 2)
        if bigram_csv:
            bigram_data = parse_ngram_csv(bigram_csv, 2, min_freq)
        else:
            # Fallback to frequency JSON
            fallback_path = f"DictusKeyboard/Resources/{lang}_frequency.json"
            if os.path.exists(fallback_path):
                print(f"  Falling back to {fallback_path}")
                bigram_data = generate_fallback_bigrams(fallback_path, lang)
            else:
                print(f"  ERROR: No data source available for {lang} bigrams")
                sys.exit(1)

        print("\nLoading trigram data...")
        trigram_csv = download_ngram_csv(lang, 3)
        if trigram_csv:
            trigram_data = parse_ngram_csv(trigram_csv, 3, min_freq)
        else:
            print("  No trigram data available (download failed)")
            trigram_data = {}

    # --- Process ---
    print("\nProcessing...")

    # Cap results per key
    bigram_data = cap_and_sort_results(bigram_data)
    trigram_data = cap_and_sort_results(trigram_data)

    # Optionally limit total entries
    if max_bigrams and len(bigram_data) > max_bigrams:
        # Keep keys with highest total frequency
        scored = sorted(
            bigram_data.items(),
            key=lambda x: sum(f for _, f in x[1]),
            reverse=True,
        )[:max_bigrams]
        bigram_data = dict(scored)
        print(f"  Limited to {max_bigrams} bigram keys")

    if max_trigrams and len(trigram_data) > max_trigrams:
        scored = sorted(
            trigram_data.items(),
            key=lambda x: sum(f for _, f in x[1]),
            reverse=True,
        )[:max_trigrams]
        trigram_data = dict(scored)
        print(f"  Limited to {max_trigrams} trigram keys")

    unique_words: set[str] = set()
    for results in bigram_data.values():
        for word, _ in results:
            unique_words.add(word)
    for results in trigram_data.values():
        for word, _ in results:
            unique_words.add(word)

    print(f"  Bigram keys: {len(bigram_data)}")
    print(f"  Trigram keys: {len(trigram_data)}")
    print(f"  Unique predicted words: {len(unique_words)}")

    # --- Serialize ---
    print(f"\nSerializing to {output_path}...")
    bigram_count, trigram_count, file_size = serialize_ngrm(
        bigram_data, trigram_data, output_path
    )

    size_mb = file_size / (1024 * 1024)
    print(f"\n=== Summary ===")
    print(f"  Language: {lang}")
    print(f"  Bigram entries: {bigram_count}")
    print(f"  Trigram entries: {trigram_count}")
    print(f"  Unique words: {len(unique_words)}")
    print(f"  File size: {file_size:,} bytes ({size_mb:.2f} MiB)")
    print(f"  Output: {output_path}")

    if size_mb > 15:
        print(f"\n  WARNING: File exceeds 15 MiB budget!")
    print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build NGRM binary dictionaries for Dictus next-word prediction."
    )
    parser.add_argument(
        "--lang", required=True, choices=["fr", "en"],
        help="Language code (fr or en)"
    )
    parser.add_argument(
        "--output", required=True,
        help="Output binary file path"
    )
    parser.add_argument(
        "--min-freq", type=int, default=2,
        help="Minimum n-gram frequency threshold (default: 2)"
    )
    parser.add_argument(
        "--max-bigrams", type=int, default=None,
        help="Maximum number of bigram entries"
    )
    parser.add_argument(
        "--max-trigrams", type=int, default=None,
        help="Maximum number of trigram entries"
    )
    parser.add_argument(
        "--fallback-json", type=str, default=None,
        help="Path to frequency JSON for fallback bigram generation"
    )

    args = parser.parse_args()

    # Ensure output directory exists
    out_dir = os.path.dirname(args.output)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    build_ngrams(
        lang=args.lang,
        output_path=args.output,
        min_freq=args.min_freq,
        max_bigrams=args.max_bigrams,
        max_trigrams=args.max_trigrams,
        fallback_json=args.fallback_json,
    )


if __name__ == "__main__":
    main()
