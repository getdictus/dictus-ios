---
status: complete
phase: 06-infrastructure-app-polish
source: [06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md]
started: 2026-03-07T21:20:00Z
updated: 2026-03-07T21:35:00Z
---

## Current Test

[testing complete]

## Tests

### 1. App Icon on Home Screen
expected: The app icon on the home screen shows the Dictus brand: 3 vertical bars (blue gradient center bar, white semi-transparent side bars) on a dark navy background. Light, dark, and tinted variants adapt to system appearance settings.
result: issue
reported: "Les barres n'ont pas les bonnes proportions ni la bonne position par rapport au brand kit. Les barres sont center-aligned au lieu de bottom-aligned, les hauteurs sont incorrectes. Pas de difference entre theme clair et sombre - toujours le meme logo."
severity: major

### 2. HomeView — No Duplicate Title
expected: Opening the app shows the HomeView with the Dictus logo section at top. There is NO duplicate white "Dictus" navigation title bar above the logo area.
result: pass

### 3. HomeView — Model Card Display
expected: The model card on HomeView shows a human-readable name like "Whisper Small" and approximate size (e.g. "~250 MB") instead of a raw identifier like "openai_whisper-small".
result: pass

### 4. HomeView — Fresh State After Onboarding
expected: After completing onboarding (including model download), the HomeView immediately shows the correct downloaded model info without needing to relaunch the app.
result: issue
reported: "L'etat du modele est toujours stale apres l'onboarding, il faut fermer et reouvrir l'app. Aussi le contenu de la HomeView (logo, carte modele, bouton) est trop haut - devrait etre centre verticalement sur l'ecran."
severity: major

### 5. Recording Screen — Immersive UI
expected: Tapping the mic button opens an immersive recording screen with a centered animated mic button, ambient waveform animation at low opacity in the background, and a fade-to-text transcription display when recording stops.
result: issue
reported: "La barre de navigation reapparait quelques secondes apres la transcription, decalant tout vers le haut. Elle devrait rester masquee tant qu'on n'a pas tape Terminer ou Nouvelle dictee. Aussi l'animation de processing (logo) casse la fluidite - il faudrait garder la waveform en mode sinusoidal pendant le processing au lieu de changer d'ecran."
severity: major

### 6. Onboarding — No Swiping Between Steps
expected: During onboarding, swiping left/right does NOT change the step. Steps only advance via the dedicated buttons (Continue, etc.). Step indicator dots show current progress.
result: pass

### 7. Onboarding — Keyboard Auto-Detection
expected: On the keyboard setup page, after enabling "Dictus" in Settings > Keyboards and returning to the app, the page auto-detects that the keyboard is enabled (shows a checkmark) and advances to the next step after a brief delay. No manual "Confirm" button needed.
result: pass

### 8. Onboarding — Model Download Page
expected: The model download page shows clear French instructions explaining what will be downloaded and why. The download does NOT auto-advance — the user controls when to proceed.
result: pass

## Summary

total: 8
passed: 5
issues: 3
pending: 0
skipped: 0

## Gaps

- truth: "App icon matches brand kit proportions with light/dark/tinted variants"
  status: failed
  reason: "User reported: Les barres n'ont pas les bonnes proportions ni la bonne position par rapport au brand kit. Les barres sont center-aligned au lieu de bottom-aligned, les hauteurs sont incorrectes. Pas de difference entre theme clair et sombre."
  severity: major
  test: 1
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "HomeView shows fresh model state immediately after onboarding"
  status: failed
  reason: "User reported: L'etat du modele est toujours stale apres l'onboarding, il faut fermer et reouvrir l'app. Aussi le contenu de la HomeView est trop haut - devrait etre centre verticalement."
  severity: major
  test: 4
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""

- truth: "Recording screen stays immersive until user taps Terminer or Nouvelle dictee"
  status: failed
  reason: "User reported: La barre de navigation reapparait quelques secondes apres la transcription, decalant tout vers le haut. Aussi l'animation de processing casse la fluidite - garder la waveform en sinusoidal pendant le processing."
  severity: major
  test: 5
  root_cause: ""
  artifacts: []
  missing: []
  debug_session: ""
