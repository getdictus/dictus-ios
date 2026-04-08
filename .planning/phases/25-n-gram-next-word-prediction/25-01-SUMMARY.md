---
phase: 25-n-gram-next-word-prediction
plan: 01
subsystem: prediction
tags: [ngram, c++, mmap, fnv1a, binary-format, python]

requires:
  - phase: 24.1-replace-symspell-with-aosp-style-compressed-trie
    provides: C++ vendored engine pattern, mmap loading, ObjC++ bridge pattern
provides:
  - NGRM binary format for n-gram data (dictus_ngram_format.h)
  - Python pipeline to generate NGRM binaries from Google Books Ngram data
  - C++ NgramEngine with mmap loading and O(log n) binary search
  - French and English n-gram binary files (bigrams + trigrams)
  - Bigram and trigram scoring APIs for correction boosting
affects: [25-02, 25-03, prediction-engine, keyboard-extension]

tech-stack:
  added: [google-books-ngram-frequency (data source)]
  patterns: [NGRM binary format, FNV-1a hashing for n-gram keys, Stupid Backoff scoring, index-based binary search on variable-length entries]

key-files:
  created:
    - tools/ngram_builder.py
    - DictusKeyboard/Vendored/AOSPTrie/include/dictus_ngram_format.h
    - DictusKeyboard/Vendored/AOSPTrie/include/dictus_ngram.h
    - DictusKeyboard/Vendored/AOSPTrie/src/dictus_ngram.cpp
    - DictusKeyboard/Resources/fr_ngrams.dict
    - DictusKeyboard/Resources/en_ngrams.dict
  modified: []

key-decisions:
  - "NGRM binary format: 32-byte header + sorted variable-length entries with FNV-1a key hashes + packed string table"
  - "Index-based binary search: build vector of (hash, pointer) pairs at load time for O(log n) lookup on variable-length entries"
  - "Google Books Ngram data via orgtre/google-books-ngram-frequency GitHub repo (ngrams/ subdirectory)"
  - "Stupid Backoff with lambda=0.4: trigram results + discounted bigram fallback, merged and sorted"

patterns-established:
  - "NGRM binary format: consistent with DTRI trie format pattern (magic bytes, version, mmap-friendly)"
  - "FNV-1a 32-bit hash: shared between Python builder and C++ engine for key lookup"
  - "Index building at load time: pre-scan variable-length sections into sorted (hash, ptr) vectors"

requirements-completed: [PRED-04, PRED-06]

duration: 4min
completed: 2026-04-03
---

# Phase 25 Plan 01: N-gram Data Pipeline & C++ Engine Summary

**NGRM binary format with Python builder pipeline and C++ NgramEngine for bigram/trigram next-word prediction via mmap and FNV-1a binary search**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-03T13:01:59Z
- **Completed:** 2026-04-03T13:06:28Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created NGRM binary format (32-byte header, sorted entries, FNV-1a hashing, packed string table)
- Built Python ngram_builder.py that downloads Google Books Ngram CSVs and serializes to NGRM binary
- Generated fr_ngrams.dict (769 bigrams, 1329 trigrams, 38 KiB) and en_ngrams.dict (1083 bigrams, 1651 trigrams, 44 KiB)
- Implemented C++ NgramEngine with mmap loading, index-based O(log n) binary search, and Stupid Backoff scoring

## Task Commits

Each task was committed atomically:

1. **Task 1: Python ngram_builder.py and n-gram binary format** - `8f61384` (feat)
2. **Task 2: C++ NgramEngine with mmap loading and binary search** - `408d41e` (feat)

## Files Created/Modified
- `tools/ngram_builder.py` - Python pipeline: downloads n-gram CSVs, processes, serializes to NGRM binary
- `DictusKeyboard/Vendored/AOSPTrie/include/dictus_ngram_format.h` - NGRM binary format constants and NgramHeader struct
- `DictusKeyboard/Vendored/AOSPTrie/include/dictus_ngram.h` - C++ NgramEngine class declaration
- `DictusKeyboard/Vendored/AOSPTrie/src/dictus_ngram.cpp` - mmap loading, index building, binary search, Stupid Backoff scoring
- `DictusKeyboard/Resources/fr_ngrams.dict` - French bigram+trigram binary (38 KiB)
- `DictusKeyboard/Resources/en_ngrams.dict` - English bigram+trigram binary (44 KiB)

## Decisions Made
- **NGRM binary format**: 32-byte header with magic/version/counts/offsets, followed by sorted variable-length entries (key_hash + result_count + results), followed by packed string table. Consistent with existing DTRI trie format pattern.
- **Index-based binary search**: Since entries are variable-length, we build a sorted vector of (hash, pointer) pairs at load time instead of computing offsets on the fly. This trades O(n) setup time for O(log n) lookup.
- **Google Books Ngram source**: Data from orgtre/google-books-ngram-frequency GitHub repo (the files are in the `ngrams/` subdirectory, not root).
- **Stupid Backoff scoring**: Trigram results merged with 0.4x discounted bigram results, deduplicated by word, sorted by score descending.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed Google Books Ngram download URL**
- **Found during:** Task 1 (running ngram_builder.py)
- **Issue:** Plan specified URL path without `/ngrams/` subdirectory, causing 404 errors
- **Fix:** Changed base URL to include `/ngrams/` path component
- **Files modified:** tools/ngram_builder.py
- **Verification:** Downloads succeed, CSVs parsed correctly
- **Committed in:** 8f61384 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** URL fix necessary for data sourcing. No scope creep.

## Issues Encountered
None beyond the URL fix documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- NGRM binary files ready for Plan 02 (Swift bridge + Xcode integration)
- C++ NgramEngine header/source ready to be added to Xcode build
- FNV-1a hash consistency between Python and C++ verified
- Binary files well under 15 MiB budget (both under 50 KiB currently -- will grow if higher-quality n-gram sources are used)

---
*Phase: 25-n-gram-next-word-prediction*
*Completed: 2026-04-03*
