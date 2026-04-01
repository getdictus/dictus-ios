---
created: 2026-03-30T08:10:44.154Z
title: Adaptive accent key shows apostrophe after "qu"
area: ui
files:
  - DictusKeyboard/DictusKeyboardBridge.swift
  - DictusKeyboard/FrenchKeyboardLayouts.swift
---

## Problem

The adaptive accent key on AZERTY row 3 currently shows the accent for "u" (ù) after typing "qu". In French, "qu" is almost always followed by either a vowel (que, qui, quoi) or an apostrophe (qu'il, qu'elle, qu'on). Showing ù after "qu" is rarely useful — the apostrophe is far more likely needed.

User feedback during Phase 19 UAT: after typing "qu", the accent key should propose apostrophe (') instead of ù, to easily type qu'il, qu'elle, etc.

## Solution

In the adaptive accent key logic (handleAdaptiveAccentKey / updateAccentKeyDisplay in DictusKeyboardBridge), add a special case: if the last two characters are "qu" (case-insensitive), show apostrophe instead of the vowel accent. This requires checking `lastInsertedCharacter` plus the character before it (or tracking a 2-char buffer).
