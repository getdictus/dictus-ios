# Feature Landscape

**Domain:** iOS Keyboard Extension - Prediction Engine Upgrade, Cold Start Auto-Return, Stability (v1.4)
**Researched:** 2026-04-01
**Focus:** SymSpell spell correction, n-gram next-word prediction, cold start auto-return, autocorrect undo bug fix, license updates

## Table Stakes

Features users expect from a keyboard with text prediction. Missing = product feels broken.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Word completion while typing | Every mobile keyboard does this | Med | Upgrade from UITextChecker (alphabetical) to SymSpell (frequency-ranked) |
| Spell correction on space | iOS native keyboard standard | Med | SymSpell provides better corrections with edit-distance control |
| Undo autocorrect on backspace | iOS standard since iOS 6 | Low | Bug #67: undo triggers after new chars typed. One-line fix. |
| Accent correction ("cafe" -> "cafe") | Essential for French keyboard | Low | Already works. SymSpell preserves with frequency dictionary. |
| 3-slot suggestion bar | Standard iOS keyboard UI | Done | Implemented in v1.1, wired in Phase 20 |

## Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Next-word prediction | Predicts what user types AFTER completing current word | High | Custom n-gram model (2-3MB). KenLM rejected (too heavy). |
| Cold start auto-return | After mic opens DictusApp, return to messaging app | High | Limited to ~20 known apps. No universal API exists. |
| Offline-only prediction | All prediction data on-device, no cloud | Low | Already the architecture. Bundled data files. |

## Anti-Features

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| LLM/transformer prediction | 50-200MB model, impossible in 50MB extension | N-gram frequency lookup (2-3MB) |
| Swipe typing | Massive effort, patent risks | Defer to v2+ |
| User dictionary learning | Storage, privacy, sync complexity | Bundled dictionaries only |
| Universal auto-return | No public iOS API. Private APIs broken in iOS 26.4 | Support top 15-20 apps via URL schemes |
| Personalized n-gram | Training pipeline complexity | Pre-built corpus model |

## Feature Dependencies

```
SymSpell integration -> n-gram predictor (vocabulary source)
SymSpell integration -> autocorrect improvement (replaces UITextChecker)
sourceApplication test -> auto-return implementation (determines feasibility)
autocorrect bug fix (#67) -> independent
license updates (#63) -> independent
```

## MVP Recommendation

Prioritize:
1. **Autocorrect bug fix (#67)** -- one-line fix, immediate value
2. **License updates (#63)** -- compliance, trivial
3. **SymSpell integration** -- replaces UITextChecker, better corrections
4. **N-gram next-word prediction** -- biggest visible upgrade
5. **sourceApplication test** -- 5-min test determines auto-return strategy

Defer: Full auto-return -- only build if sourceApplication test succeeds.

## Sources

- Codebase: TextPredictionEngine.swift, SuggestionState.swift, KnownAppSchemes.swift
- `assets/reference/issue-23-report.md`
- [SymSpell](https://github.com/wolfgarbe/SymSpell)
- PROJECT.md out-of-scope decisions
