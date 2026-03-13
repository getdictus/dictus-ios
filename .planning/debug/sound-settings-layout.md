---
status: resolved
trigger: "SoundSettingsView layout bug - Debut d'enregistrement picker wraps below label"
created: 2026-03-13T00:00:00Z
updated: 2026-03-13T00:00:00Z
---

## Current Focus

hypothesis: Picker with .menu style inside HStack uses default label layout which wraps when label text is long
test: Check Picker style and HStack structure
expecting: Missing .pickerStyle(.menu) or label truncation issue
next_action: Report root cause

## Symptoms

expected: All three picker rows should show label on left, picker value on right (standard iOS settings row)
actual: "Debut d'enregistrement" row has its Picker wrapping below the label
errors: none
reproduction: Open SoundSettingsView, observe first picker row
started: Since initial implementation

## Eliminated

(none needed — root cause found on first inspection)

## Evidence

- timestamp: 2026-03-13
  checked: soundPickerRow function in SoundSettingsView.swift (lines 90-109)
  found: |
    1. Picker has NO explicit .pickerStyle(.menu) modifier — defaults to .automatic
    2. The default automatic style in a List/Form is NavigationLink-style which reserves full width for the label
    3. When label text is long ("Debut d'enregistrement" = 24 chars), the Picker's automatic layout pushes the value to a second line
    4. Shorter labels ("Fin d'enregistrement", "Annulation") fit without wrapping
    5. The HStack wrapping Picker + Spacer + Button is redundant with menu-style Picker which already has inline layout
  implication: Two issues — missing .pickerStyle(.menu) and the Spacer fighting with Picker's own layout

## Resolution

root_cause: |
  The Picker on line 92 has NO .pickerStyle(.menu) modifier. Despite the comment on line 88
  saying "WHY .menu picker style", the modifier was never actually applied. SwiftUI defaults
  to .automatic which in a List renders as a full-width label-above-value layout. The long
  "Debut d'enregistrement" label triggers wrapping because the automatic style tries to give
  the label its full natural width before placing the selected value.

  Additionally, the HStack + Spacer pattern on lines 91/99 conflicts with how .menu Picker
  lays itself out (it already places label-left, value-right inline).

fix: |
  1. Add .pickerStyle(.menu) to the Picker
  2. Remove the Spacer() since .menu Picker handles inline layout

files_changed:
  - DictusApp/Views/SoundSettingsView.swift
verification: All three rows should show label left, compact menu picker right, play button far right
