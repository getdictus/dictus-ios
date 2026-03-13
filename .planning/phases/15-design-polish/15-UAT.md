---
status: resolved
phase: 15-design-polish
source: 15-01-SUMMARY.md, 15-02-SUMMARY.md, 15-03-SUMMARY.md, 15-04-SUMMARY.md, 15-05-SUMMARY.md
started: 2026-03-13T11:00:00Z
updated: 2026-03-13T13:20:00Z
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. French Accents — Settings & Home
expected: Open the app. Go to Settings (Réglages tab). All labels show correct French accents: "Réglages", "À propos", "Français". Go to Home tab: "Nouvelle dictée", "Modèle actif", "Télécharger", "Dernière transcription". Check Modèles tab label has accent.
result: pass

### 2. French Accents — Onboarding
expected: Reset onboarding (or fresh install). Go through onboarding flow. On MicPermissionPage: "Réglages" and "autorisé" have accents. On ModelDownloadPage: "modèle", "téléchargement", "Précis", "équilibré", "Recommandé" have accents. On KeyboardSetupPage: "Réglages", "détecté" have accents.
result: pass

### 3. Gauge Bar Blue Palette
expected: Open the Model Manager. Look at any model card's gauge bars. Both "Vitesse" and "Précision" bars should use blue tones only (no green anywhere). Preview colors are consistent blue shades.
result: pass

### 4. Log Export Spinner
expected: Go to Settings. Tap the log export option. While logs are being gathered, a spinning ProgressView indicator should appear. It disappears once the share sheet is ready.
result: pass

### 5. Model Card Tap Interaction
expected: Go to Model Manager. Tap an already-downloaded model card → it becomes the active model. Tap a not-yet-downloaded model card → download starts. No separate "Select" or "Download" buttons visible — the entire card is the tap target.
result: issue
reported: "Globalement ça marche mais plusieurs problèmes : 1) Barre de téléchargement trop petite en bas à droite, devrait prendre toute la largeur de la carte et masquer les jauges pendant download/optimisation (comme app Handy). 2) Quand on lance un download, la carte devrait passer de la section Disponible à la section Téléchargés en état downloading. 3) Zone de tap pas assez sensible, faut cliquer au centre de la carte, pas fluide, plusieurs clics nécessaires parfois. 4) Manque animation de press iOS standard (scale bounce : grossit légèrement puis revient). 5) Modèle actif : préfère une bordure bleu foncé autour de la carte plutôt que le fond teinté."
severity: major

### 6. Active Model Blue Highlight
expected: In Model Manager, the currently active model card has a subtle blue background tint distinguishing it from other cards. Other cards have no tint.
result: issue
reported: "Même remarque que test 5 : préfère bordure bleu foncé autour de la carte au lieu du fond teinté. Aussi enlever le check vert en bas à droite de la carte active. Et ajouter un feedback de chargement quand on switch de modèle (animation préparation en cours) pour montrer que le clic est pris en compte, car parfois le switch prend 1-2 secondes."
severity: major

### 7. Swipe-to-Delete Model
expected: In Model Manager, swipe left on a downloaded model that is NOT the active model. A red delete option appears. Tap it → confirmation alert. Confirm → model is deleted. The active model card should NOT be swipeable for delete.
result: issue
reported: "Le swipe fonctionne bien et la suppression aussi, mais le bouton Supprimer est bleu au lieu de rouge."
severity: minor

### 8. Recording Overlay Buttons & Haptics
expected: Start a dictation from the keyboard. The recording overlay appears. Tap the cancel or stop button — the tap target feels generous (easy to hit), and you feel a light haptic vibration on tap.
result: [pending]

### 9. Recording Overlay Transition Animation
expected: Start a dictation. The recording overlay should appear with a smooth fade+slide animation (not instant pop). When stopping/cancelling, it should disappear with a matching smooth animation.
result: issue
reported: "L'apparition en fade in est bien. Mais à la disparition, l'overlay descend vers le bas (slide down) — pas fan. Préfère un simple fade out sans mouvement."
severity: minor

### 10. Onboarding Success Screen
expected: During onboarding, complete the test recording step. After transcription succeeds, a full-screen success overlay appears with an animated checkmark (spring bounce effect) and a "Commencer" button. Tapping it completes onboarding.
result: issue
reported: "Le success screen fonctionne bien. Mais juste avant, il y a un gros bouton vert Terminé en plein milieu de l'écran qui est moche. Voudrait le supprimer : après transcription, afficher le résultat brièvement puis enchaîner automatiquement sur le success screen. Si la transcription échoue, proposer de réessayer."
severity: minor

### 11. Keyboard Detection After Settings Return
expected: During onboarding on the keyboard setup step, go to iOS Settings to enable the Dictus keyboard. Return to the app. The app should detect the keyboard without crashing or freezing. No race condition issues.
result: issue
reported: "Crash intermittent au retour de iOS Settings après avoir activé le clavier. L'app se relance (visible dans logs : appDidEnterBackground puis appLaunched). Pas de stack trace dans les logs actuels. Demande d'ajouter du logging autour de l'onboarding keyboard detection pour diagnostiquer en bêta."
severity: major

### 12. Active Model Name on Home Screen
expected: Home screen shows correct model name without engine prefix. Parakeet models show "Parakeet v3", WhisperKit models show "Small", "Medium", etc.
result: issue
reported: "Le modèle actif affiche 'Whisper Parakeet v3' alors que c'est un modèle Parakeet/NVIDIA. Le préfixe Whisper ne devrait pas apparaître pour les modèles Parakeet."
severity: major

### 13. Settings Tap Feedback
expected: When tapping items in Settings, the row flashes gray briefly (like native iOS Settings) to confirm the tap was registered.
result: issue
reported: "Aucun retour visuel quand on clique sur un item dans les réglages. Devrait avoir un feedback gris clair comme les Settings iOS natifs."
severity: minor

### 14. Model State Sync After Onboarding
expected: After completing onboarding, the model downloaded during onboarding appears as active in Model Manager — no download icon, properly recognized.
result: issue
reported: "Après l'onboarding, Parakeet v3 est dans Téléchargés mais affiche encore l'icône téléchargement ⬇ en bas à droite. Le modèle n'est pas reconnu comme actif/téléchargé correctement."
severity: major

### 15. Engine Descriptions Fixed Footer
expected: The WhisperKit and Parakeet description paragraphs are always at the bottom of the Models page as a fixed footer, not attached to any model card or section.
result: issue
reported: "La description Parakeet est collée au modèle Parakeet v3 et suit la carte dans la section Téléchargés quand le modèle est downloadé. Les deux descriptions doivent rester en pied de page fixe, toujours en bas de la page."
severity: minor

### 16. Section Headers Scroll With Content
expected: The "Téléchargés" and "Disponibles" section headers scroll naturally with the rest of the content — no sticky/pinned behavior that overlaps cards.
result: issue
reported: "Les headers de section Téléchargés et Disponibles restent collés (sticky) en haut et se superposent sur les cartes au scroll. Le texte Téléchargés se retrouve par dessus la carte Parakeet v3. Les headers doivent scroller avec le contenu."
severity: major

## Summary

total: 16
passed: 4
issues: 11
pending: 0
skipped: 0

## Gaps

- truth: "Model card tap interaction: full card tappable, download starts on tap, no separate buttons"
  status: resolved
  reason: "User reported: 1) Download progress bar too small, should be full-width hiding gauges during download/optimization (like Handy app). 2) Card should move from Available to Downloaded section when download starts. 3) Tap area not responsive enough, must tap center, multiple taps needed. 4) Missing iOS standard press animation (scale bounce). 5) Active model should have dark blue border instead of background tint."
  severity: major
  test: 5
  root_cause: "1) ProgressView width hardcoded to 60pt in ModelCardView.swift:184. 2) downloadedModels computed property in ModelManagerView.swift:40-48 only includes completed downloads. 3) Button wraps cardContent but no .contentShape(Rectangle()) to expand hitbox. 4) GlassPressStyle pressedScale 0.97 too subtle. 5) Active state uses background fill instead of stroke border."
  artifacts:
    - path: "DictusApp/Views/ModelCardView.swift"
      issue: "Progress bar 60pt hardcoded (L184), no contentShape on Button (L55-62), active highlight is background fill not border (L126-134)"
    - path: "DictusApp/Views/ModelManagerView.swift"
      issue: "downloadedModels filter excludes downloading state (L40-48)"
    - path: "DictusCore/Sources/DictusCore/Design/GlassModifier.swift"
      issue: "GlassPressStyle pressedScale 0.97 too subtle (L35-48)"
  missing:
    - "Full-width progress bar replacing gauge bars during download/optimization"
    - "Add downloading models to downloadedModels section immediately"
    - "Add .contentShape(Rectangle()) to Button for full-area tap"
    - "Increase pressedScale to ~0.95 for more visible bounce"
    - "Replace background fill with RoundedRectangle stroke for active model"

- truth: "Swipe-to-delete button appears in red (destructive action)"
  status: resolved
  reason: "User reported: Le bouton Supprimer en swipe est bleu au lieu de rouge"
  severity: minor
  test: 7
  root_cause: "Button role: .destructive is set (ModelManagerView.swift:85) but color not rendering red — likely needs explicit .tint(.red)"
  artifacts:
    - path: "DictusApp/Views/ModelManagerView.swift"
      issue: "swipeActions Button missing explicit .tint(.red) (L83-90)"
  missing:
    - "Add .tint(.red) to the swipe delete Button"

- truth: "Recording overlay disappears with smooth matching animation"
  status: resolved
  reason: "User reported: Fade in à l'apparition est bien, mais la disparition slide vers le bas — préfère un simple fade out sans mouvement"
  severity: minor
  test: 9
  root_cause: "Transition uses .opacity.combined(with: .move(edge: .bottom)) symmetrically for both appear and disappear (KeyboardRootView.swift:89)"
  artifacts:
    - path: "DictusKeyboard/KeyboardRootView.swift"
      issue: ".transition(.opacity.combined(with: .move(edge: .bottom))) applies slide to both insert and removal (L89)"
  missing:
    - "Use .asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity) for fade-only disappear"

- truth: "Onboarding success screen flows smoothly after test recording"
  status: resolved
  reason: "User reported: Le success screen marche mais le gros bouton vert Terminé juste avant est moche. Supprimer ce bouton, afficher le résultat de transcription brièvement puis enchaîner auto sur success screen. Si échec transcription, proposer réessayer."
  severity: minor
  test: 10
  root_cause: "RecordingView.swift:130-152 shows Terminé button on showResult when mode == .onboarding. User must tap it to trigger onComplete callback in TestRecordingPage.swift:28-30. No auto-transition."
  artifacts:
    - path: "DictusApp/Views/RecordingView.swift"
      issue: "Terminé button shown immediately on transcription complete (L130-152), blocks auto-transition"
    - path: "DictusApp/Onboarding/TestRecordingPage.swift"
      issue: "showSuccess only set on manual button tap callback (L28-30)"
  missing:
    - "Remove Terminé button from RecordingView onboarding mode"
    - "Auto-trigger onComplete after brief delay (1-2s) showing transcription result"
    - "Add retry option on transcription failure"

- truth: "Keyboard detection after iOS Settings return works without crash"
  status: resolved
  reason: "User reported: Crash intermittent au retour de Settings après activation du clavier. App se relance. Pas de stack trace disponible. Besoin de logging supplémentaire autour de l'onboarding keyboard detection pour diagnostiquer."
  severity: major
  test: 11
  root_cause: "Race condition in KeyboardSetupPage.swift:234-243 — UITextInputMode.activeInputModes accessed during rapid scenePhase transitions. No error handling around the access. 500ms debounce (L111-118) guards concurrent calls but not crashes inside the call itself."
  artifacts:
    - path: "DictusApp/Onboarding/KeyboardSetupPage.swift"
      issue: "UITextInputMode.activeInputModes access without error handling (L234-243), debounce guard insufficient (L111-118)"
  missing:
    - "Wrap UITextInputMode access in error handling"
    - "Add comprehensive logging: scenePhase transitions, detection start/end, mode count, errors"
    - "Consider longer debounce or exponential backoff for resilience"

- truth: "Active model card visually distinct with blue background tint"
  status: resolved
  reason: "User reported: Veut bordure bleu foncé au lieu du fond teinté. Enlever le check vert en bas à droite de la carte active. Ajouter feedback de chargement (animation préparation) quand on switch de modèle car le switch peut prendre 1-2s et l'utilisateur ne sait pas si le clic a été pris en compte."
  severity: major
  test: 6
  root_cause: "1) Active state uses .fill(Color.dictusAccent.opacity(0.10)) background (ModelCardView.swift:126-134). 2) Green checkmark hardcoded in .ready+isActive case (L202-209). 3) selectModel() is sync with no UI feedback (L145-150)."
  artifacts:
    - path: "DictusApp/Views/ModelCardView.swift"
      issue: "Background fill for active (L126-134), green checkmark (L202-209), no loading state on selectModel (L145-150)"
  missing:
    - "Replace background fill with dark blue stroke border"
    - "Remove green checkmark from active card"
    - "Add transient switching state with spinner/progress indicator"

- truth: "Active model name displays correctly on Home screen without wrong engine prefix"
  status: resolved
  reason: "User reported: Modèle actif affiche 'Whisper Parakeet v3' au lieu de 'Parakeet v3' — le préfixe Whisper est hardcodé"
  severity: major
  test: 12
  root_cause: "HomeView.swift:93 hardcodes 'Whisper' prefix: Text(\"Whisper \\(info?.displayName ?? modelName)\"). Parakeet models already have full name in displayName."
  artifacts:
    - path: "DictusApp/Views/HomeView.swift"
      issue: "Hardcoded 'Whisper' prefix on model name (L93)"
  missing:
    - "Remove hardcoded Whisper prefix, use displayName directly or make prefix conditional on engine type"

- truth: "Settings items show tap feedback (gray flash like native iOS Settings)"
  status: resolved
  reason: "User reported: Aucun retour visuel quand on clique dans les réglages"
  severity: minor
  test: 13
  root_cause: "SettingsView.swift List uses .scrollContentBackground(.hidden) and custom background (L114-115) which removes native row highlight. No button styling on interactive rows."
  artifacts:
    - path: "DictusApp/Views/SettingsView.swift"
      issue: ".scrollContentBackground(.hidden) removes native tap highlight (L114-115), no buttonStyle on rows"
  missing:
    - "Restore native list row highlighting or add custom tap feedback via listRowBackground or buttonStyle"

- truth: "Model downloaded during onboarding is recognized as active in Model Manager"
  status: resolved
  reason: "User reported: Après onboarding, Parakeet v3 dans Téléchargés mais affiche encore icône ⬇ — état pas synchronisé"
  severity: major
  test: 14
  root_cause: "ModelManager.loadState() (L87-93) reads downloadedModels from defaults but does NOT rebuild modelStates dictionary. init() sets modelStates once (L67-78). After loadState(), downloadedModels is updated but modelStates remains stale with .notDownloaded."
  artifacts:
    - path: "DictusApp/Models/ModelManager.swift"
      issue: "loadState() doesn't resync modelStates after reloading downloadedModels (L87-93)"
  missing:
    - "After loading downloadedModels in loadState(), rebuild modelStates for all models based on new downloadedModels set"

- truth: "Engine descriptions (WhisperKit/Parakeet) are fixed footer at bottom of Models page"
  status: resolved
  reason: "User reported: Description Parakeet collée au modèle et suit dans section Téléchargés. Veut descriptions fixes en pied de page."
  severity: minor
  test: 15
  root_cause: "Descriptions placed inside Section blocks in ModelManagerView.swift (L96-100 in Téléchargés, L127-130 in Disponibles). They move with section content when models change sections."
  artifacts:
    - path: "DictusApp/Views/ModelManagerView.swift"
      issue: "Engine descriptions inside Section blocks instead of outside List as fixed footer (L96-100, L127-130)"
  missing:
    - "Move descriptions outside both Sections, place as fixed footer below the List"

- truth: "Section headers (Téléchargés/Disponibles) scroll with content, no sticky overlap"
  status: resolved
  reason: "User reported: Les headers de section restent sticky et se superposent sur les cartes au scroll. Téléchargés se retrouve par dessus Parakeet v3."
  severity: major
  test: 16
  root_cause: "List Section headers in SwiftUI are sticky/pinned by default. ModelManagerView.swift uses Section with header: which enables iOS default sticky behavior. Combined with .listStyle(.plain) or similar, headers pin to top on scroll."
  artifacts:
    - path: "DictusApp/Views/ModelManagerView.swift"
      issue: "Section headers are sticky by default in SwiftUI List (L69-137)"
  missing:
    - "Either switch to ScrollView+VStack layout (no sticky headers) or use .headerProminence(.increased) with non-sticky list style, or move headers outside Section into inline Text views"
