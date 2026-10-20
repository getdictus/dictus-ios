# Voice notes transcription

- **ID:** `voice-notes`
- **Tier:** Pro
- **Targets:** DictusShare + DictusApp + DictusKeyboard + DictusWidgets
- **Screens:** `kbd.voice-note-reader`, `app.pro.voice-notes`, `app.onboarding.voice-notes-scene`, `app.voice-note.result` (not captured) — see [screens.md](screens.md)

## Sub-features

- Share an audio message from WhatsApp, Telegram, Signal or Messages to Dictus; it is transcribed and shown as result cards (optionally passed through a Smart Mode, « Après la transcription »).
- Keyboard reader: tap ☰ in the Dictus keyboard to read the latest voice note, « Insérer » it, open it in Dictus, delete it.
- Settings: language (« Détecter automatiquement » or fixed), after-transcription mode; on/off switch.
- A Live Activity follows a voice note in progress.
- Files: `DictusShare/ShareViewController.swift`, `DictusApp/VoiceNotes/`, `DictusKeyboard/KeyboardVoiceNotes.swift`, `DictusKeyboard/Views/VoiceNoteReaderView.swift`.

## How to get to it (user POV)

1. In a messaging app, long-press a received voice message → Partager → Dictus.
2. Dictus transcribes it; open the Dictus keyboard and tap ☰ to read or insert it.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh full-access && .claude/skills/verify-dictus-ios/scripts/drive.sh select-keyboard
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd menu                                   # ☰ tap: the reader
.claude/skills/verify-dictus-ios/scripts/evidence.sh voice-note-reader   # « Aucune note vocale récente »
.claude/skills/verify-dictus-ios/scripts/drive.sh kbd menu                                   # ✕ closes it (same spot)
```

Settings page: Pro on, then Réglages → `Dictus Pro, Pro actif` → `Messages vocaux, Transcrivez les messages vocaux que vous recevez, Activé`.

## Gotchas

- **Not drivable in the simulator:** the share sheet from a messaging app (none is installed), hence any transcription result. While `PremiumFlags.paywallVisible = false` the share extension refuses with "…not available in this version of Dictus." even in Debug.
- The reader's identifiers (`voiceNoteReaderInsert`…) live inside the keyboard and do not appear in the host's tree.
