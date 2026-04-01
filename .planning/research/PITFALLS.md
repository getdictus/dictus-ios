# Domain Pitfalls

**Domain:** iOS keyboard extension — probability-based text prediction upgrade + cold start auto-return + stability fixes
**Researched:** 2026-04-01
**Confidence:** HIGH (based on SymSpell documentation, Apple DTS responses, issue #23 research report, issue #67/68 analysis, Dictus codebase audit, community reports)

**Context:** Dictus v1.4 adds SymSpell-based spell correction, n-gram/trigram next-word prediction, fixes autocorrect undo state bug (#67), and researches cold start auto-return (#23). All changes target the existing keyboard extension with a 50MB memory limit, offline-only constraint, and must not degrade typing fluidity (<10ms per prediction).

---

## Critical Pitfalls

Mistakes that cause rewrites, keyboard crashes, or multi-day stalls.

### Pitfall 1: SymSpell Dictionary Pre-computation Blows Memory Budget at Load Time

**What goes wrong:**
SymSpell's speed comes from pre-computing all deletion variants of dictionary words at startup. For a 82K-word dictionary with max edit distance 2, this generates ~25 delete variants per word = ~2M dictionary entries stored in a hash map. The C# reference implementation reports "significantly" higher memory when the dictionary is loaded all at once.

In the keyboard extension's 50MB budget, you have roughly 15-20MB available after the keyboard UI, toolbar, and system overhead. Loading a 100K-word French frequency dictionary into SymSpell can easily consume 15-30MB of RAM during pre-computation (the in-memory hash map of all delete variants plus the original entries). On 4GB RAM devices (iPhone 12, SE 3), iOS may terminate the extension mid-load with no crash log — the keyboard simply disappears.

The SymSpellSwift library (v0.1.4, August 2025) calls `loadDictionary()` synchronously, blocking the thread until all entries are processed. If loaded on the main thread or early in `viewDidLoad`, the keyboard takes 1-3 seconds to appear, triggering iOS's watchdog timer which kills extensions that don't present within ~6 seconds.

**Why it happens:**
SymSpell trades memory for speed. The algorithm pre-computes deletions so lookups are O(1), but the pre-computation requires holding all variants in memory simultaneously. Most SymSpell usage is in server-side applications with gigabytes of RAM, not 50MB iOS extensions.

**Consequences:**
Keyboard killed silently during dictionary load. Users see system keyboard appear instead of Dictus. On slower devices, keyboard appears blank for 1-3 seconds before keys render.

**Prevention:**
1. **Limit dictionary size to 30K-50K words maximum**: The top 30K French words cover ~99% of daily usage. Pre-compute on a Mac, measure RAM with Instruments on device, and reduce until comfortably under 10MB resident
2. **Use max edit distance 1, not 2**: Edit distance 1 generates ~5 deletes per word vs ~25 for distance 2. This cuts memory by ~5x. For a keyboard where context disambiguates, edit distance 1 catches most typos (adjacent key errors, missing/extra letter)
3. **Load dictionary on a background queue, never main thread**: Use `DispatchQueue(label:qos:)` with `.utility` priority. Show basic UITextChecker-based suggestions until SymSpell is ready (progressive enhancement)
4. **Pre-serialize the SymSpell data structure**: Instead of loading a text dictionary and computing deletions at runtime, serialize the fully-computed hash map to a binary file during development. Load the binary via `mmap` at runtime for near-instant startup with minimal memory overhead (only pages accessed are loaded)
5. **Profile on iPhone SE or iPhone 12 (4GB RAM)**: These devices have the tightest memory and are the canary for extension crashes. Test with Instruments > Allocations attached to the keyboard extension process

**Warning signs:**
Keyboard disappears after switching languages. Keyboard takes >1 second to appear. Instruments shows >15MB spike during startup.

**Phase to address:**
Prediction engine upgrade phase. Must be resolved before any n-gram model is added (SymSpell + n-gram together will be even tighter).

---

### Pitfall 2: N-gram Model Too Large or Too Slow Without mmap

**What goes wrong:**
A trigram language model trained on French Wikipedia/OpenSubtitles can easily reach 50-500MB as a raw text file. Even pruned to top-frequency trigrams, a usable French model is 5-20MB. If loaded entirely into RAM as a Swift `Dictionary<String, [String: Float]>`, the overhead of Swift's reference-counted objects, hash table buckets, and String allocations inflates the on-disk size by 3-5x in memory. A 10MB on-disk trigram file becomes 30-50MB in RAM — enough to kill the extension by itself.

Additionally, if using KenLM (C++ library), the model files use a custom binary format designed for `mmap`. KenLM's entire performance story relies on memory-mapped files — the OS loads pages on demand, and the resident memory is only the pages actually queried. But `mmap` in a keyboard extension has a subtlety: the file must be in the extension's bundle or in the shared App Group container. If the model file is in the main app bundle (not the extension bundle), `mmap` returns `MAP_FAILED` because the extension cannot access the main app's sandbox.

**Why it happens:**
Language models are designed for machines with abundant RAM. iOS keyboard extensions are among the most memory-constrained environments in mobile computing. Developers who prototype on the Simulator (which has the Mac's full RAM) never see the crash — it only appears on physical devices.

**Consequences:**
Extension crashes on first prediction query. Or: extension loads but crashes when user types a 3rd word (triggering the first trigram lookup that touches cold pages). Model works on Simulator but fails on every physical device.

**Prevention:**
1. **Use mmap from the start, not Dictionary in RAM**: Build a custom binary trie or use KenLM's binary format. Memory-map the file so only queried pages are resident. Target <2MB resident memory for the n-gram component
2. **Store model file in the keyboard extension bundle, not the app bundle**: In Xcode, add the model file's Target Membership to DictusKeyboard, not DictusApp. Or store in the App Group container (writable, accessible by both targets)
3. **Pure Swift trigram engine over KenLM unless C++ bridging is already needed**: KenLM is fast but adds C++ compilation complexity to the keyboard extension target (see Pitfall 3). A custom binary trie in pure Swift with `mmap` via `Data(contentsOf:options:.mappedIfSafe)` achieves the same result without bridging headers
4. **Prune aggressively**: Keep only trigrams that appear >5 times in the training corpus. For French, this typically reduces a 500MB model to 5-10MB while retaining 95%+ of prediction quality
5. **Single language loaded at a time**: Never load both French and English models simultaneously. Load on language switch, unmap the previous model. Current architecture already does this for FrequencyDictionary

**Warning signs:**
Extension works in Simulator but crashes on device. Memory climbs steadily as user types. `os_proc_available_memory()` returns <5MB after model load.

**Phase to address:**
Prediction engine upgrade phase (n-gram sub-task). Must test on physical device after every model size change.

---

### Pitfall 3: C++ Bridging Header in Keyboard Extension Breaks Build or Blocks APIs

**What goes wrong:**
If using KenLM (C++ library) for the n-gram model, the keyboard extension target needs either:
- A bridging header (traditional approach: Obj-C++ wrapper around C++ code)
- Swift-C++ interop enabled (Xcode 15+: set "C++ and Objective-C Interoperability" to "C/C++")

Both approaches have pitfalls in extension targets:

**Bridging header approach:**
- Keyboard extensions set `APPLICATION_EXTENSION_API_ONLY = YES` automatically. If KenLM or its dependencies use any UIKit API or `UIApplication.shared`, the build fails with "API unavailable for app extensions"
- KenLM uses `<iostream>`, `<unordered_map>`, `<string>` — standard C++ headers. These compile fine. But if KenLM's build configuration pulls in `pthread` or `mmap` POSIX APIs in ways that conflict with the extension sandbox, you get runtime crashes, not compile errors
- The bridging header affects ALL Swift files in the target. If it includes C++ headers that define macros conflicting with Swift keywords (e.g., `#define assert(...)` in a C++ header vs Swift's `assert()`), you get cryptic compile errors across unrelated files

**Swift-C++ interop approach:**
- This is newer (stable since Xcode 15/Swift 5.9). Not all C++ patterns are supported — KenLM uses templates, exceptions, and custom allocators that may not bridge cleanly
- The build setting applies to the entire target. If any existing ObjC code in the keyboard target doesn't compile under C++ interop mode, everything breaks

**Why it happens:**
KenLM was designed for Linux/server environments. It has never been tested in an iOS app extension sandbox. The documentation doesn't mention iOS at all.

**Consequences:**
Build fails with 50+ errors after adding KenLM. Hours spent chasing linker errors. Or: builds but crashes at runtime when KenLM calls a POSIX function restricted in the extension sandbox.

**Prevention:**
1. **Strongly prefer a pure Swift n-gram engine over KenLM**: Write a custom binary trie reader in Swift. The query logic is simple: given W1 and W2, look up P(W3|W1,W2) and return top-3 candidates. This avoids all C++ complexity
2. **If KenLM is chosen, wrap it in a static XCFramework**: Build KenLM as a static library (.a) on macOS with the iOS SDK, wrap it in an ObjC++ interface that exposes only `-(NSArray<NSString*>*)predictNext:(NSString*)context`, and import the framework. This isolates C++ from Swift
3. **Test the build on a clean checkout before adding any feature code**: Add the C++ files, verify `xcodebuild -target DictusKeyboard` succeeds, commit. Then add feature code. This prevents conflating C++ build issues with logic bugs
4. **Check KenLM does not call `fork()`, `exec()`, or `dlopen()`**: These are prohibited in app extensions. Grep KenLM source for these calls before integrating

**Warning signs:**
`Undefined symbols for architecture arm64` errors. `Use of undeclared identifier 'UIApplication'` in KenLM wrapper. Build succeeds but extension crashes on launch with `EXC_CRASH (SIGKILL)`.

**Phase to address:**
Prediction engine upgrade phase. Decision must be made BEFORE implementation starts: pure Swift or C++ bridge. Do not defer this decision.

---

### Pitfall 4: Cold Start Auto-Return is Fundamentally Impossible via Public API

**What goes wrong:**
The team spends days or weeks researching and prototyping auto-return approaches that have already been proven impossible. Issue #23 documents three failed approaches:
1. **KnownAppSchemes iteration with canOpenURL**: Always opens the first installed app (WhatsApp), not the source app. `canOpenURL` only checks if an app is installed, not if it's the most recent
2. **Host bundle ID detection from keyboard extension**: `_hostBundleID` is a private API — fragile and App Store rejection risk. No public API exposes the host app's identity
3. **Programmatic swipe-back simulation**: No public API for gesture simulation. Private APIs = guaranteed rejection

An Apple DTS engineer confirmed in January 2026: "There is no API for the containing app to bring the host app back to the foreground." The system back arrow (top-left) is the officially supported mechanism.

**Why it happens:**
Competitors like Wispr Flow appear to do auto-return, creating an expectation. In reality, their "return" is user-assisted (system back arrow + UX guidance), not programmatic. The illusion comes from fast session activation + clear UX instruction.

**Consequences:**
Wasted development time on impossible approaches. Risk of implementing private API usage that causes App Store rejection. Frustration cycle of "it almost works" with each new hack.

**Prevention:**
1. **Accept the constraint**: There is no auto-return API. Period. Apple DTS confirmed this. Do not re-research
2. **Optimize the existing swipe-back overlay UX instead**: The overlay (implemented in Phase 13) works 100% of the time for all apps. Invest in making it faster, clearer, and more polished:
   - Show the overlay within 200ms of cold start URL open
   - Auto-dismiss when `sceneDidEnterBackground` fires (user swiped back)
   - Optional: add the swipe-back instruction as a Dynamic Island Live Activity for even clearer guidance
3. **Explore `sourceApplication` as a refinement, not a solution**: When the keyboard opens DictusApp via URL scheme, `UIApplication.OpenURLOptionsKey.sourceApplication` in `application(_:open:options:)` MAY contain the host app's bundle ID. If it does, you could display "Swipe back to [App Name]" instead of generic text. But this is a UX polish, not auto-return
4. **Consider session-based model (Wispr Flow pattern)**: Keep the audio engine alive in background between recordings so cold starts are rare. This is already partially implemented via `collectSamples()` pattern. The real fix for cold start is preventing cold starts, not auto-returning from them

**Warning signs:**
Spending >4 hours researching auto-return approaches. Considering `_hostBundleID`. Testing `LSApplicationWorkspace` (already in Out of Scope).

**Phase to address:**
Cold start phase. Timebox research to 2 hours maximum. If no new public API has appeared since January 2026, move to UX refinement of existing overlay.

---

### Pitfall 5: Autocorrect State Corruption from Race Between Async Suggestions and User Input

**What goes wrong:**
Issue #67 exposes a specific race condition: `lastAutocorrect` state persists indefinitely after a correction, causing undo to fire on backspace even after the user has typed new characters. But the proposed fix (clear `lastAutocorrect` on any new character) introduces a subtler race when combined with the async prediction pipeline:

1. User types "helo" + space → autocorrect fires, sets `lastAutocorrect`
2. User immediately types "t" (fast typist, <100ms after space)
3. The space-triggered autocorrect runs on the suggestion queue (async). It sets `lastAutocorrect` AFTER the "t" character handler has already cleared it
4. Result: `lastAutocorrect` is set again despite new input, and the next backspace corrupts text

This race exists because `SuggestionState.updateAsync()` dispatches to `suggestionQueue` and publishes back to main thread. If autocorrect happens inside this async pipeline, the state mutation ordering depends on GCD scheduling, not user input ordering.

With SymSpell replacing UITextChecker, the race window may widen: SymSpell lookups are faster (<1ms vs UITextChecker's 5-20ms), but the dictionary load is async, so the first few keystrokes may use UITextChecker while SymSpell loads, then switch mid-word — creating inconsistent correction behavior.

**Why it happens:**
The current architecture has a synchronous path (`update(proxy:)` for delete/undo) and an asynchronous path (`updateAsync(context:)` for character input). Autocorrect state (`lastAutocorrect`) is mutated from both paths without synchronization. The DispatchWorkItem cancellation only prevents publishing stale suggestions, not stale autocorrect state.

**Consequences:**
Text corruption: words mangled by stale undo operations. User types "corriger test", backspace produces "CorrCorrigerr" (documented in issue #67). With SymSpell, this may manifest as double-corrections (SymSpell corrects a word that UITextChecker already corrected during the load transition).

**Prevention:**
1. **Fix issue #67 first, before any prediction engine changes**: The state management bug is independent of SymSpell. Fix the easy bug in isolation so you can verify the fix works with the current engine before adding complexity
2. **Clear `lastAutocorrect` synchronously on main thread in the key handler, before dispatching async work**: The character input handler in `DictusKeyboardBridge` runs on main. Clear `lastAutocorrect = nil` there immediately, not inside the async suggestion callback
3. **Make autocorrect a synchronous operation, not part of the async suggestion pipeline**: Autocorrect (replace word on space) should be a synchronous check on main thread — it's user-facing and must be deterministic. Only the suggestion bar population (showing 3 candidates) should be async
4. **Add a generation counter to prevent stale autocorrect**: Increment a counter on every keystroke. The autocorrect callback checks if the counter matches — if not, the autocorrect result is stale and should be discarded
5. **Test with rapid typing (>5 chars/second)**: Use `XCTestCase.measure {}` or a UI test that simulates fast typing to reproduce the race. The bug is invisible at normal typing speed

**Warning signs:**
Backspace produces garbled text. Autocorrect fires on a word the user already corrected manually. Different corrections appear for the same misspelling on consecutive attempts.

**Phase to address:**
Bug fix phase (issue #67) MUST complete before prediction engine upgrade. The race condition will be harder to debug with two correction engines (UITextChecker during load + SymSpell after load).

---

## Moderate Pitfalls

Issues that cause days of debugging or subtle UX regressions.

### Pitfall 6: SymSpell French Dictionary Quality — Garbage In, Garbage Out

**What goes wrong:**
SymSpell is only as good as its frequency dictionary. The current `fr_frequency.json` has ~1.3K words — far too small. Issue #68 proposes replacing it. The risk is choosing a bad source dictionary:

- **Raw Wikipedia word frequencies** include proper nouns (place names, people), technical terms, and foreign words that pollute suggestions. "Paris" appears 50,000 times in French Wikipedia but is rarely what someone means when typing "par"
- **OpenSubtitles frequencies** are better for conversational French but include slang, movie-specific terms, and English loanwords at inflated frequencies
- **Frequency lists without lemmatization** treat "mange", "manges", "mangeons", "mangez", "mangent" as separate entries, wasting dictionary space on conjugations that SymSpell should derive from the root

A bad dictionary makes SymSpell worse than UITextChecker, which at least uses Apple's curated system dictionary.

**Prevention:**
1. **Use a curated frequency list**: The [Lexique 3](http://www.lexique.org/) database is the gold standard for French word frequencies — used by French NLP researchers, covers 140K lemmas with frequency data from books and subtitles
2. **Filter aggressively**: Remove proper nouns, words with frequency < 0.1 per million, words shorter than 2 characters. Target 30K-50K entries
3. **Include common French contractions and elisions**: "l'homme", "j'ai", "c'est", "qu'il" must be in the dictionary or SymSpell will flag them as misspelled
4. **Test with real French text samples**: Run SymSpell against 100 real French sentences and compare suggestions to UITextChecker. If SymSpell is worse, the dictionary needs work
5. **Build an English dictionary from the same methodology**: Don't ship French-only. English speakers who switch languages will get zero corrections

**Phase to address:**
Prediction engine upgrade phase. Dictionary curation is a prerequisite — do not start coding SymSpell integration until the dictionary is validated.

---

### Pitfall 7: N-gram Model Ignores French Morphology (Elision, Contractions, Gender)

**What goes wrong:**
French text has elisions ("l'eau" not "le eau"), contractions ("du" = "de le"), gendered articles ("le/la/les"), and verb conjugations that English n-gram approaches handle poorly:

- A trigram model trained naively treats "l'" as a separate token, breaking the context chain: "je bois l'" gives no prediction because "l'" is not a word boundary
- The apostrophe in "l'eau" confuses `extractLastWord()` which uses `.byWords` enumeration — Swift may treat "l" and "eau" as separate words, or "l'eau" as one word, depending on locale
- Gender agreement: after "la", the model should predict feminine nouns. After "le", masculine. Without gender-aware training, the model suggests the most frequent word regardless of gender

**Prevention:**
1. **Tokenize French text with apostrophe-aware rules**: Treat `[word]'[word]` as two tokens where the first includes the apostrophe: ["l'", "eau"]. This preserves the elision context for n-gram lookup
2. **Train n-gram model on properly tokenized French corpus**: Use a tokenizer that handles French-specific patterns (elision, hyphenated compounds like "peut-etre", "c'est-a-dire")
3. **Test `extractLastWord()` with French edge cases**: Verify what Swift's `.byWords` enumeration returns for: "l'homme", "aujourd'hui", "peut-etre", "c'est", "qu'est-ce". If the results are wrong, implement a custom French tokenizer
4. **Consider HeliBoard's AOSP dictionary approach**: These dictionaries are pre-trained for specific languages including French and handle morphology natively. The binary format would need a Swift reader, but the linguistic quality is pre-validated

**Phase to address:**
Prediction engine upgrade phase (n-gram sub-task). French tokenization must be tested before model training.

---

### Pitfall 8: Prediction Engine Swap Breaks Suggestion Bar Timing Contract

**What goes wrong:**
The current `SuggestionState.updateAsync()` has a carefully tuned flow: read `documentContextBeforeInput` on main thread, dispatch computation to background, publish results back to main. This ensures suggestions appear within 1-2 frames (~16-33ms) of a keystroke.

Replacing `UITextChecker.completions()` with SymSpell changes the timing profile:
- **SymSpell lookup**: <1ms (faster) — but only after dictionary is loaded
- **SymSpell dictionary load**: 500ms-3s (blocking at startup)
- **N-gram lookup**: 1-10ms depending on model size and cache warmth

If the new engine isn't ready when the first keystroke arrives, `suggestions(for:)` returns empty. The suggestion bar shows nothing. The user types 3-4 characters with no suggestions, then suddenly gets suggestions when SymSpell finishes loading. This "suggestion pop-in" feels broken.

Additionally, if n-gram prediction runs after SymSpell correction (two sequential async operations), the total latency may exceed the 16ms frame budget, causing suggestion bar updates to lag behind typing.

**Prevention:**
1. **Progressive enhancement**: Start with UITextChecker (already loaded by iOS). When SymSpell finishes loading, swap the engine atomically. The suggestion bar should never show "nothing" — it should always show at least UITextChecker results
2. **Single async dispatch for both correction + prediction**: Don't chain two async operations. In one `DispatchWorkItem`, call SymSpell for correction AND n-gram for next-word, then publish both results to main thread in a single callback
3. **Pre-load SymSpell dictionary in `viewDidLoad`**: Start loading immediately when the keyboard extension launches, not on first keystroke. Use the 1-2 seconds before the user starts typing
4. **Measure end-to-end latency on device**: Use `OSSignposter` or `CFAbsoluteTimeGetCurrent()` to measure keystroke-to-suggestion-update latency. If >16ms consistently, the engine needs optimization

**Warning signs:**
Suggestion bar is empty for the first 2-3 words. Suggestions appear with visible delay after fast typing. Suggestion bar "flickers" (shows UITextChecker results then immediately replaces with SymSpell results).

**Phase to address:**
Prediction engine upgrade phase. Progressive enhancement pattern must be implemented from the start, not bolted on after.

---

### Pitfall 9: Two Prediction Engines Running Simultaneously Doubles Memory

**What goes wrong:**
During the transition period (SymSpell loading), both UITextChecker and SymSpell's hash map may be in memory. UITextChecker is loaded by iOS on demand and uses system memory, but its `completions()` and `guesses()` methods allocate temporary arrays. If SymSpell's 10-15MB hash map coexists with UITextChecker's allocations plus the n-gram model, the extension approaches the memory limit.

Even after SymSpell is fully loaded, if the code still holds a reference to the UITextChecker instance (the current `TextPredictionEngine` creates one in `init()`), it stays in memory.

**Prevention:**
1. **Release UITextChecker after SymSpell is ready**: Set `textChecker = nil` (make it optional) once SymSpell confirms successful load. This frees the system dictionary cache
2. **Never load both language dictionaries simultaneously**: Current code loads one language at a time — preserve this behavior. When switching FR<>EN, unload SymSpell FR completely before loading SymSpell EN
3. **Monitor memory at runtime**: Call `os_proc_available_memory()` after SymSpell loads. If <10MB remaining, disable n-gram model and fall back to SymSpell-only mode
4. **Budget**: SymSpell dict (~8MB) + n-gram model mmap'd (~2MB resident) + keyboard UI (~5MB) + system overhead (~15MB) = ~30MB. Leaves ~20MB headroom. This is tight but workable only if UITextChecker is released

**Phase to address:**
Prediction engine upgrade phase. Memory profiling after each component integration.

---

### Pitfall 10: SymSpellSwift Library is Minimally Maintained (16 Commits, Single Author)

**What goes wrong:**
SymSpellSwift (github.com/gdetari/SymSpellSwift) has 16 commits, one contributor, and was last updated August 2025. It is a direct port of the C# reference implementation. Risks:
- No community review of the Swift code (potential memory leaks, retain cycles, or inefficient Swift patterns)
- May not handle Swift String's Unicode complexity correctly (French accented characters, emoji in text)
- If a bug is found, there's no guarantee the maintainer will respond
- No test suite visible in the repository

If the library has a subtle bug (e.g., crashes on words with combining diacritical marks like "e\u0301" vs "e-acute"), debugging it requires understanding both SymSpell's algorithm AND the library's Swift implementation.

**Prevention:**
1. **Vendor the source code, do not use as SPM dependency**: Copy the Swift files into `DictusKeyboard/TextPrediction/SymSpell/`. This allows fixing bugs directly without waiting for upstream
2. **Write integration tests for French-specific cases**: Test with: accented characters (e, e-acute, e-grave, e-circumflex), elisions (l'homme), compound words (peut-etre), Unicode normalization (NFC vs NFD)
3. **Audit the source for obvious issues**: Check how it handles String iteration (should use `Character`, not `UInt8`). Check for `force try` or `fatalError` calls. Check dictionary loading for error handling
4. **Consider writing a minimal SymSpell from scratch**: The core algorithm is ~200 lines. Given the library's minimal maintenance, implementing the symmetric delete lookup directly may be more reliable than depending on an unmaintained port

**Phase to address:**
Prediction engine upgrade phase (first step — evaluate library or rewrite).

---

## Minor Pitfalls

Issues that cause hours of confusion but are quickly fixable once identified.

### Pitfall 11: `extractLastWord()` Apostrophe Handling Differs Between iOS Versions

**What goes wrong:**
The current `extractLastWord()` uses `enumerateSubstrings(options: .byWords)` to find the last word. This relies on iOS's ICU word boundary detection, which handles apostrophes inconsistently:
- iOS 17: "l'homme" may be split as ["l", "homme"] or kept as ["l'homme"] depending on locale
- iOS 18+: Word boundary detection may have changed (Apple ships ICU updates with each iOS version)

If `extractLastWord` returns "homme" for "l'homme", the prediction engine looks up "homme" in isolation, losing the context that the user was typing an elision. The suggestion "homme" would be wrong — "hommage" or "hommes" would make more sense.

**Prevention:**
1. **Implement a custom French-aware word extractor**: Don't rely solely on `.byWords`. After extracting the last word, check if the character before it is an apostrophe and include the prefix: "l'" + "homme" = "l'homme"
2. **Test on both iOS 17 and iOS 18**: Word boundary behavior may differ. Pin expected behavior in unit tests

**Phase to address:**
Prediction engine upgrade phase (tokenization sub-task).

---

### Pitfall 12: N-gram Training Corpus Contains English Bleeding Into French Predictions

**What goes wrong:**
French Wikipedia articles often contain English words (brand names, technical terms, anglicisms). If the training corpus isn't filtered, the French trigram model will suggest English words in French context: "je vais" → "to" (from code-switched Wikipedia sentences).

**Prevention:**
1. **Use a monolingual French corpus**: French OpenSubtitles or French literature corpora are cleaner than Wikipedia for conversational prediction
2. **Filter training data**: Remove sentences containing >20% non-French words (detected by character set or dictionary membership)
3. **Keep French and English models completely separate**: Never train a bilingual model. Load the active language's model exclusively

**Phase to address:**
Prediction engine upgrade phase (model training sub-task).

---

### Pitfall 13: Autocorrect Undo Fix (#67) Breaks Accent Suggestion Flow

**What goes wrong:**
The proposed fix for issue #67 is: clear `lastAutocorrect` on every new character. But the accent suggestion flow has a special case: user types "e" → suggestion bar shows ["e", "e-acute", "e-grave"]. If the user taps "e-acute", the suggestion handler replaces "e" with "e-acute" — this is functionally an autocorrect operation. If `lastAutocorrect` is set for this replacement, the next backspace undoes it (expected behavior for accents). But if the fix clears `lastAutocorrect` on the next character, accent undo still works correctly.

The subtle issue: if accent suggestion triggers `lastAutocorrect`, and the user types a space (triggering spell-check autocorrect on the SAME word), the state gets confused — which correction should undo restore? The original unaccented character, or the pre-autocorrect word?

**Prevention:**
1. **Separate autocorrect state from accent state**: Use two optional states: `lastAutocorrect` for spell corrections, `lastAccentReplace` for accent selections. Backspace checks both, with accent replacement taking priority (it happened more recently)
2. **Test the sequence: type vowel → tap accent → type more → space (autocorrect) → backspace**: Verify the undo produces the correct result at each step

**Phase to address:**
Bug fix phase (issue #67). Must be tested before prediction engine changes.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Bug fix #67 (autocorrect undo) | State corruption from async race (#5), accent flow interaction (#13) | Fix synchronously on main thread, separate accent state from autocorrect state |
| SymSpell integration | Memory blow-up at load (#1), dictionary quality (#6), library quality (#10) | 30K word limit, edit distance 1, vendor source, curate dictionary first |
| N-gram model | Memory without mmap (#2), C++ bridging (#3), French morphology (#7), English bleed (#12) | Pure Swift binary trie with mmap, French-aware tokenizer, monolingual corpus |
| Prediction engine swap | Timing regression (#8), double memory (#9) | Progressive enhancement, release UITextChecker after swap, single async dispatch |
| Cold start auto-return | Impossible via public API (#4) | Accept constraint, polish swipe-back overlay, explore sourceApplication for UX text only |
| French tokenization | Apostrophe handling (#11), elision context (#7) | Custom French tokenizer, test on multiple iOS versions |

## Sources

- [SymSpell algorithm documentation](https://github.com/wolfgarbe/SymSpell) — pre-computation strategy, memory characteristics (HIGH confidence)
- [SymSpellSwift library](https://github.com/gdetari/SymSpellSwift) — Swift port, v0.1.4, 16 commits (HIGH confidence, source code reviewed)
- [SymSpell dictionary loading optimization issue #16](https://github.com/wolfgarbe/SymSpell/issues/16) — loading time, memory optimization techniques (HIGH confidence)
- [Apple DTS response on auto-return (January 2026)](https://github.com/getdictus/dictus-ios/issues/23#issuecomment-4117827144) — "No API exists" confirmation (HIGH confidence)
- [Dictus issue #23 research report](https://github.com/getdictus/dictus-ios/blob/99300f9/assets/reference/issue-23-report.md) — failed auto-return approaches documented (HIGH confidence)
- [Dictus issue #67](https://github.com/getdictus/dictus-ios/issues/67) — autocorrect undo state bug, root cause analysis (HIGH confidence)
- [Dictus issue #68](https://github.com/getdictus/dictus-ios/issues/68) — prediction upgrade proposal with SymSpell + n-gram architecture (HIGH confidence)
- [Swift-C++ interop project setup](https://www.swift.org/documentation/cxx-interop/project-build-setup/) — bridging header requirements, extension limitations not documented (MEDIUM confidence)
- [Apple: Custom Keyboard programming guide](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html) — extension memory limits, API restrictions (HIGH confidence)
- [iOS keyboard extension memory limits](https://developer.apple.com/forums/thread/85478) — 30-50MB experimentally determined, device-dependent (MEDIUM confidence)
- [Dealing with memory limits in iOS app extensions](https://blog.kulman.sk/dealing-with-memory-limits-in-app-extensions/) — practical memory management strategies (MEDIUM confidence)
- [HeliBoard / AOSP dictionaries](https://codeberg.org/Helium314/aosp-dictionaries) — pre-trained language models for 80+ languages (HIGH confidence)
- [KenLM paper](https://kheafield.com/papers/avenue/kenlm.pdf) — mmap-based data structures for language models (HIGH confidence)
- [sourceApplication API documentation](https://developer.apple.com/documentation/uikit/uiapplication/openurloptionskey/sourceapplication) — bundle ID of requesting app (HIGH confidence)
- Dictus codebase: `TextPredictionEngine.swift`, `SuggestionState.swift`, `DictusKeyboardBridge.swift` — current architecture audit (HIGH confidence)
