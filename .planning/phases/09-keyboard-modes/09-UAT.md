---
status: complete
phase: 09-keyboard-modes
source: 09-01-SUMMARY.md, 09-02-SUMMARY.md, 09-03-SUMMARY.md
started: 2026-03-09T22:30:00Z
updated: 2026-03-10T08:30:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. Mode Picker in Settings
expected: In DictusApp Settings, the "Clavier" section shows a segmented control with three options: Micro, Emoji+, Complet. Tapping each option selects it and the selection persists.
result: pass

### 2. Conditional Toggles per Mode
expected: When "Complet" is selected, AZERTY/QWERTY layout toggle and autocorrect toggle are visible. When "Micro" is selected, haptics toggle is hidden. When "Emoji+" is selected, layout toggles are hidden.
result: pass

### 3. Onboarding Mode Selection Step
expected: Onboarding now has 6 steps. Step 3 shows a mode selection page with the same Micro/Emoji+/Complet picker and miniature previews. The "Continuer" button is disabled until a mode is selected.
result: pass

### 4. Micro Mode Keyboard
expected: After selecting Micro mode in Settings, open the keyboard in any app. The keyboard shows a large mic pill button (120pt) with "Dicter" label and a globe button in the bottom-left. No letter keys, no emoji, no toolbar — just the mic and globe.
result: issue
reported: "Le micro ne marche pas tout le temps, impossible de le faire fonctionner même après redémarrage de l'app. Background color mismatch — le gris du clavier ne matche pas le fond blanc/clair en bas. Le globe fait doublon avec celui du système. Il manque des touches utiles en bas : emoji, espace, retour ligne, supprimer."
severity: major

### 5. Emoji+ Mode Keyboard
expected: After selecting Emoji+ mode, the keyboard shows the emoji picker grid (4 rows, continuous scroll) with a simplified toolbar above containing a globe button and a mic pill. No letter keys visible.
result: issue
reported: "Largeur de la grille emoji dépasse du cadre du clavier (coupée à gauche et droite). Toolbar/category bar coupée en haut. Globe en haut à gauche devrait être remplacé par le module réglages comme sur le clavier Complet (globe système déjà présent en bas). Devrait reprendre exactement le layout du emoji picker du mode Complet qui fonctionne bien."
severity: major

### 6. Full Mode Keyboard (Unchanged)
expected: After selecting Complet mode, the keyboard shows the standard AZERTY/QWERTY layout with all keys, toolbar, mic button, and emoji toggle — the same behavior as before Phase 9.
result: issue
reported: "Le mode picker ne persiste pas toujours le changement — impossible de passer en mode Complet depuis un autre mode sans rebuild. Le mode Complet lui-même fonctionne correctement une fois actif (retours optiques, corrections auto OK). Besoin de logs sur le choix du clavier pour diagnostiquer la sync App Group."
severity: major

### 7. Recording Overlay Across Modes
expected: Start a dictation recording from any of the three modes. The recording overlay (waveform, timer, controls) appears correctly on top of the current mode's layout without layout jumps or visual glitches.
result: issue
reported: "Impossible de tester — la communication App Group entre l'app et le clavier est cassée. Le mode ne switch pas et la dictation ne se lance pas depuis le clavier emoji. Probablement le même bug de sync/persistance App Group que le test 6."
severity: blocker

## Summary

total: 7
passed: 3
issues: 4
pending: 0
skipped: 0

## Gaps

- truth: "Micro mode keyboard shows large mic pill that reliably triggers dictation, with matching background color and appropriate utility keys"
  status: failed
  reason: "User reported: Le micro ne marche pas tout le temps, impossible de le faire fonctionner même après redémarrage de l'app. Background color mismatch — le gris du clavier ne matche pas le fond blanc/clair en bas. Le globe fait doublon avec celui du système. Il manque des touches utiles en bas : emoji, espace, retour ligne, supprimer."
  severity: major
  test: 4
  artifacts: []
  missing: []

- truth: "Emoji+ mode keyboard shows emoji picker grid properly fitted within keyboard bounds with correct toolbar"
  status: failed
  reason: "User reported: Largeur de la grille emoji dépasse du cadre du clavier (coupée à gauche et droite). Toolbar/category bar coupée en haut. Globe en haut à gauche devrait être remplacé par le module réglages comme sur le clavier Complet (globe système déjà présent en bas). Devrait reprendre exactement le layout du emoji picker du mode Complet qui fonctionne bien."
  severity: major
  test: 5
  artifacts: []
  missing: []

- truth: "Mode picker in Settings reliably switches keyboard mode and the keyboard extension picks up the new mode without rebuild"
  status: failed
  reason: "User reported: Le mode picker ne persiste pas toujours le changement — impossible de passer en mode Complet depuis un autre mode sans rebuild. Besoin de logs sur le choix du clavier pour diagnostiquer la sync App Group."
  severity: major
  test: 6
  artifacts: []
  missing: []

- truth: "Recording overlay works across all three keyboard modes without layout issues"
  status: failed
  reason: "User reported: Impossible de tester — la communication App Group entre l'app et le clavier est cassée. Le mode ne switch pas et la dictation ne se lance pas depuis le clavier emoji. Probablement le même bug de sync/persistance App Group que le test 6."
  severity: blocker
  test: 7
  artifacts: []
  missing: []
