---
status: diagnosed
trigger: "App icon bars don't match the brand kit proportions"
created: 2026-03-07T00:00:00Z
updated: 2026-03-07T00:00:00Z
---

## Current Focus

hypothesis: Two root causes — (1) bars are vertically centered instead of bottom-aligned within the icon's visual space, and (2) dark mode icon is identical to light mode icon
test: Compare brand kit SVG coordinates vs generate script geometry
expecting: Mismatched Y positions and identical dark/light output
next_action: Document findings (diagnosis only)

## Symptoms

expected: 3 vertical bars bottom-aligned with asymmetric heights matching brand kit SVG. Light/dark/tinted variants should differ.
actual: Bars are center-aligned vertically with wrong proportions. No visible difference between light and dark theme.
errors: none
reproduction: Build and inspect app icon in Xcode / Settings
started: Since icon generation script was created

## Eliminated

(none needed — root causes found on first investigation)

## Evidence

- timestamp: 2026-03-07
  checked: Brand kit SVG bar geometry (80x80 viewBox)
  found: |
    Bar 1 (left):   x=19, y=34, w=9, h=18, rx=4.5, fill=white opacity=0.45
    Bar 2 (center): x=35.5, y=22, w=9, h=42, rx=4.5, fill=gradient #6BA3FF->#2563EB
    Bar 3 (right):  x=52, y=29, w=9, h=27, rx=4.5, fill=white opacity=0.65
    All bars share bottom edge at y=52 (bar1: 34+18=52, bar2: 22+42=64... WAIT)
  implication: Need to recalculate — bars do NOT share bottom edge in SVG

- timestamp: 2026-03-07
  checked: Recalculated brand kit bar bottom edges
  found: |
    Bar 1 bottom: y + height = 34 + 18 = 52
    Bar 2 bottom: y + height = 22 + 42 = 64
    Bar 3 bottom: y + height = 29 + 27 = 56
    Bars are NOT bottom-aligned in the SVG either. Each bar has a different bottom edge.
    The bars are positioned absolutely within the viewBox.
  implication: The brand kit has specific absolute positions, not a simple bottom-alignment

- timestamp: 2026-03-07
  checked: generate-app-icon.swift bar positioning logic
  found: |
    Script computes bottomY = centerY + tallestBarHeight (center bar bottom)
    Then positions each bar: barYPositions[i] = bottomY - barHeights[i]
    This means ALL bars share the SAME bottom edge.
    But in the brand kit SVG, bars have DIFFERENT bottom edges:
      Bar 1 bottom = 52, Bar 2 bottom = 64, Bar 3 bottom = 56
  implication: Script forces bottom-alignment; brand kit does NOT bottom-align bars

- timestamp: 2026-03-07
  checked: Brand kit bar vertical centering vs script centering
  found: |
    In brand kit (80pt viewBox, center = 40):
      Bar 1: top=34, bottom=52, center=43 (below icon center)
      Bar 2: top=22, bottom=64, center=43 (below icon center)
      Bar 3: top=29, bottom=56, center=42.5 (below icon center)
    The bars' visual center of mass is at ~43, which is 3pt below the geometric center.
    This gives the impression of being slightly bottom-heavy / bottom-aligned visually.

    In the script:
      centerY = (1024 - tallestBarHeight) / 2 = (1024 - 645.12) / 2 = 189.44
      bottomY = 189.44 + 645.12 = 834.56
      All bars share bottom at 834.56
      This bottom-aligns all bars AND centers the tallest bar vertically.
  implication: Script's bottom-alignment creates different proportions than brand kit

- timestamp: 2026-03-07
  checked: Exact proportional differences (brand kit ratios vs script)
  found: |
    Brand kit ratios in 80pt viewBox:
      Bar 1: y=34/80=0.425, h=18/80=0.225
      Bar 2: y=22/80=0.275, h=42/80=0.525
      Bar 3: y=29/80=0.3625, h=27/80=0.3375

    Script should reproduce these exact ratios at 1024px, but instead:
    1) Applies a 1.2x enlargement factor (bars are 20% bigger than brand kit proportions)
    2) Forces bottom-alignment (all bars share same bottom edge)

    Brand kit bar positions (normalized to 80pt):
      Bar 1: starts at 42.5% from top, ends at 65.0% from top
      Bar 2: starts at 27.5% from top, ends at 80.0% from top
      Bar 3: starts at 36.25% from top, ends at 70.0% from top

    Script bar positions (with 1.2x scale, centered tallest):
      Tallest bar (center) is centered, so starts at ~18.5%, ends at ~81.5%
      All bars share same bottom at 81.5%
      Bar 1: starts at 81.5% - (18*12.8*1.2/1024)=81.5%-27%= 54.5%, ends at 81.5%
      Bar 3: starts at 81.5% - (27*12.8*1.2/1024)=81.5%-40.5%= 41.0%, ends at 81.5%

    vs brand kit:
      Bar 1: starts at 42.5%, ends at 65.0%  (script: 54.5% to 81.5%)
      Bar 3: starts at 36.25%, ends at 70.0% (script: 41.0% to 81.5%)
    The script pushes bars much lower and forces shared bottom edge.
  implication: Bars are significantly mispositioned

- timestamp: 2026-03-07
  checked: Dark mode icon generation
  found: |
    generateDark() simply calls generateStandard() — produces identical output.
    The Contents.json correctly declares light/dark/tinted appearances.
    But the dark PNG is a byte-identical copy of the standard PNG.
  implication: No visual difference between light and dark because they render identically

- timestamp: 2026-03-07
  checked: Tinted icon generation
  found: |
    generateTinted() draws black bars on transparent background.
    This is correct for iOS tinted icons (iOS applies user's tint color).
    However the same geometry issues (1.2x scale, bottom-alignment) apply.
  implication: Tinted has correct concept but wrong geometry

## Resolution

root_cause: |
  THREE issues found in scripts/generate-app-icon.swift:

  1. BAR GEOMETRY - 1.2x ENLARGEMENT (lines 47-55):
     The script applies a 1.2x multiplier to all bar dimensions "for better visibility at small sizes."
     This makes bars 20% larger than the brand kit specifies, changing proportions and spacing.

  2. BAR POSITIONING - FORCED BOTTOM-ALIGNMENT (lines 78-83):
     The script calculates a shared bottomY and positions all bars to share the same bottom edge.
     The brand kit SVG has each bar at a DIFFERENT vertical position:
       Bar 1: y=34 (bottom at 52)
       Bar 2: y=22 (bottom at 64)
       Bar 3: y=29 (bottom at 56)
     The bars are NOT bottom-aligned in the brand kit. They have staggered bottoms.
     The script's forced bottom-alignment is the primary visual discrepancy.

  3. DARK MODE - IDENTICAL TO STANDARD (lines 193-195):
     generateDark() simply calls generateStandard(), producing byte-identical output.
     For meaningful light/dark differentiation, the dark variant should differ
     (e.g., brighter bars, different gradient, or the "surface" variant from brand kit).

fix: (diagnosis only — not applied)
verification: (diagnosis only)
files_changed: []
