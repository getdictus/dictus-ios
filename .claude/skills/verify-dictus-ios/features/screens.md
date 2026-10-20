# Dictus screen map

One stable ID per screen, `<surface>.<area>[.<sub>]`, with `app` (DictusApp), `kbd` (the keyboard extension, drawn inside any host app), `share`, `widget` and `sys` (iOS system screens Dictus depends on). Like feature IDs, screen IDs name what the user sees, not the SwiftUI view, so another platform can map its own screens onto them.

Captures are in [`docs/agents/screens/`](../../../../docs/agents/screens/), one `<screen-id>.png` each, iPhone 17, iOS 26.5, French device, status bar fixed at 09:41, resized to 874 px high. They were taken with this skill's scripts on 2026-10-20; re-take one with `evidence.sh <name>` and `sips -Z 874` (see `../SKILL.md`, Evidence). Recipes abbreviate `drive.sh`; `…` repeats the previous row's command.

| Screen ID | Screen | How to reach it | Features | Capture |
| --- | --- | --- | --- | --- |
| `app.onboarding.welcome` | Onboarding: « Parlez. Dictus écrit. » intro carousel | launch.sh (fresh install) | onboarding | [oui](../../../../docs/agents/screens/app.onboarding.welcome.png) |
| `app.onboarding.language` | Onboarding: « Votre langue » + layout | tap-id onboarding.primary on the intro | onboarding, keyboard.languages | [oui](../../../../docs/agents/screens/app.onboarding.language.png) |
| `app.onboarding.keyboard-setup` | Onboarding: « Activez le clavier » | set-default dictus.onboardingStep -string keyboardSetup | onboarding | [oui](../../../../docs/agents/screens/app.onboarding.keyboard-setup.png) |
| `app.onboarding.apple-intelligence` | Onboarding: « Apple Intelligence se prépare » | … -string appleIntelligence | onboarding, polish | [oui](../../../../docs/agents/screens/app.onboarding.apple-intelligence.png) |
| `app.onboarding.smart-modes-scene` | Onboarding scene: « Un appui long, un Smart Mode » | … -string smartModesScene | onboarding, smart-modes | [oui](../../../../docs/agents/screens/app.onboarding.smart-modes-scene.png) |
| `app.onboarding.smart-mode-pick` | Onboarding: « Vos 3 Smart Modes » picker | … -string smartModePick | onboarding, smart-modes | [oui](../../../../docs/agents/screens/app.onboarding.smart-mode-pick.png) |
| `app.onboarding.voice-notes-scene` | Onboarding scene: voice memos | … -string voiceNotesScene | onboarding, voice-notes | [oui](../../../../docs/agents/screens/app.onboarding.voice-notes-scene.png) |
| `app.onboarding.vocabulary-scene` | Onboarding scene: « Vos mots, bien écrits » | … -string vocabularyScene | onboarding, vocabulary | [oui](../../../../docs/agents/screens/app.onboarding.vocabulary-scene.png) |
| `app.onboarding.history-scene` | Onboarding scene: « Tout se retrouve » | … -string historyScene | onboarding, history | [oui](../../../../docs/agents/screens/app.onboarding.history-scene.png) |
| `app.onboarding.model-preparation` | Onboarding: model download and preparation | … -string modelPreparation (starts a download) | onboarding, models.transcription | non |
| `app.onboarding.microphone` | Onboarding: « Dictus a besoin du micro » | … -string microphonePrompt | onboarding | [oui](../../../../docs/agents/screens/app.onboarding.microphone.png) |
| `app.onboarding.first-dictation` | Onboarding: « Essayez maintenant » practice field | … -string firstDictation | onboarding, dictation.keyboard | [oui](../../../../docs/agents/screens/app.onboarding.first-dictation.png) |
| `app.onboarding.stop-standby` | Onboarding: « Pour arrêter Dictus » | … -string stopStandby | onboarding, live-activity | [oui](../../../../docs/agents/screens/app.onboarding.stop-standby.png) |
| `app.onboarding.completion` | Onboarding: « C'est prêt » | … -string completion | onboarding | [oui](../../../../docs/agents/screens/app.onboarding.completion.png) |
| `app.whats-new` | What's new (existing user behind 2.0.0) | set-default dictus.hasCompletedOnboarding -bool YES, then dictus.lastVersionSeen -string 1.8.0 | onboarding | [oui](../../../../docs/agents/screens/app.whats-new.png) |
| `app.home` | Tab Accueil (no model: « Télécharger un modèle pour commencer ») | launch.sh --skip-onboarding | dictation.in-app, history | [oui](../../../../docs/agents/screens/app.home.png) |
| `app.recording` | Full-screen in-app recording | Accueil → « Nouvelle dictée » (needs a model; records the Mac's mic) | dictation.in-app | non |
| `app.history` | History sheet (empty state) | Pro on, Accueil → tap-label Historique | history | [oui](../../../../docs/agents/screens/app.history.png) |
| `app.history.detail` | Transcription detail | History → a row (needs a transcription) | history, vocabulary | non |
| `app.models` | Tab Modèles | tab Modèles | models.transcription | [oui](../../../../docs/agents/screens/app.models.png) |
| `app.models.languages` | Supported languages sheet | Modèles → tap-label « Langues prises en charge » | models.transcription | [oui](../../../../docs/agents/screens/app.models.languages.png) |
| `app.models.loading` | Full-screen model preparation overlay | select a downloaded model | models.transcription | non |
| `app.settings` | Tab Réglages | tab Réglages | keyboard.languages, polish, typing.*, live-activity, diagnostics.logs | [oui](../../../../docs/agents/screens/app.settings.png) |
| `app.settings.sounds` | Réglages → Sons | Réglages, scroll, tap-label Sons | feedback.sounds-haptics | [oui](../../../../docs/agents/screens/app.settings.sounds.png) |
| `app.settings.diagnostic` | Réglages → Diagnostic | Réglages, scroll to À propos, tap-label Diagnostic | diagnostics.logs | [oui](../../../../docs/agents/screens/app.settings.diagnostic.png) |
| `app.settings.debug-logs` | Réglages → Debug Logs | … tap-label « Debug Logs » | diagnostics.logs | [oui](../../../../docs/agents/screens/app.settings.debug-logs.png) |
| `app.settings.licences` | Réglages → Licences | … tap-label Licences | diagnostics.logs | [oui](../../../../docs/agents/screens/app.settings.licences.png) |
| `app.settings.polish-debug` | Polish debug screen | Réglages → tap « Version » five times | polish | non |
| `app.pro.hub` | Dictus Pro hub | Pro on, Réglages → tap-label « Dictus Pro, Pro actif » | pro.subscription | [oui](../../../../docs/agents/screens/app.pro.hub.png) |
| `app.pro.smart-modes` | Pro → Mode intelligent (pinned modes) | hub → « Mode intelligent, … » | smart-modes | [oui](../../../../docs/agents/screens/app.pro.smart-modes.png) |
| `app.pro.history` | Pro → Historique (switch, demo) | hub → « Historique, … » | history | [oui](../../../../docs/agents/screens/app.pro.history.png) |
| `app.pro.vocabulary` | Pro → Vocabulaire (terms, suggestions) | hub → « Vocabulaire, … » | vocabulary | [oui](../../../../docs/agents/screens/app.pro.vocabulary.png) |
| `app.pro.vocabulary.term-editor` | « Nouveau terme » sheet | Vocabulaire → « Ajouter un terme » | vocabulary | non |
| `app.pro.voice-notes` | Pro → Messages vocaux (language, after transcription) | hub → « Messages vocaux, … » | voice-notes | [oui](../../../../docs/agents/screens/app.pro.voice-notes.png) |
| `app.paywall` | Paywall (three plans) | unreachable while PremiumFlags.paywallVisible = false | pro.subscription | non |
| `app.pro.trial-announcement` | Reverse-trial announcement sheet | unreachable while paywallVisible = false | pro.subscription | non |
| `app.voice-note.result` | Voice-note result cards | share an audio file to Dictus (no messaging app in the simulator) | voice-notes | non |
| `kbd.keys` | Dictus keyboard, letters (AZERTY), toolbar with ☰ and mic | full-access, select-keyboard | dictation.keyboard, typing.autocorrect | [oui](../../../../docs/agents/screens/kbd.keys.png) |
| `kbd.no-full-access` | Keyboard bar « Accès complet requis », mic disabled | select-keyboard before full-access | dictation.keyboard | non |
| `kbd.dictation-error` | Keyboard after a mic tap with no model (failure message) | kbd mic with no model installed (proof run) | dictation.keyboard | [oui](../../../../docs/agents/screens/kbd.dictation-error.png) |
| `kbd.recording` | Keyboard recording overlay (✕ / ✓, waveform) | kbd mic with a model (records the Mac's mic) | dictation.keyboard | non |
| `kbd.panel` | Keyboard panel: languages and layouts | kbd menu-hold | keyboard.languages | [oui](../../../../docs/agents/screens/kbd.panel.png) |
| `kbd.emoji` | Emoji picker | kbd emoji | keyboard.emoji | [oui](../../../../docs/agents/screens/kbd.emoji.png) |
| `kbd.voice-note-reader` | Voice-note reader (empty: « Aucune note vocale récente ») | kbd menu | voice-notes | [oui](../../../../docs/agents/screens/kbd.voice-note-reader.png) |
| `kbd.smart-mode-fan` | Smart Mode fan (greyed: no Apple Intelligence) | Pro on, kbd mic-fan, screenshot during the drag | smart-modes | [oui](../../../../docs/agents/screens/kbd.smart-mode-fan.png) |
| `kbd.suggestions` | Suggestion bar above the keys (undo chip after a correction) | Rappels, `type bonjoru`, `space` (see typing.autocorrect) | typing.autocorrect | [oui](../../../../docs/agents/screens/kbd.suggestions.png) |
| `sys.settings.full-access` | iOS Réglages → Claviers → Dictus, « Autoriser l'accès complet » on | full-access | dictation.keyboard | [oui](../../../../docs/agents/screens/sys.settings.full-access.png) |
| `share.voice-note` | Share extension sheet | Partager → Dictus from a messaging app | voice-notes | non |
| `widget.live-activity` | Live Activity in the Dynamic Island | leave Dictus with standby on (not reproduced) | live-activity | non |

36 of 49 screens captured. Each « non » is explained in the Gotchas of the feature it belongs to: a model download, a recording of the Mac's microphone, Apple Intelligence, StoreKit, a messaging app, or `paywallVisible = false`.
