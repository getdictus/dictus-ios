# Voice notes transcription

- **ID:** `voice-notes`
- **Tier:** Pro
- **Targets:** DictusShare + DictusApp + DictusKeyboard + DictusWidgets
- **Screens:** `kbd.voice-note-reader`, `app.pro.voice-notes`, `app.onboarding.voice-notes-scene`, `app.voice-note.result` (not captured) — see [screens.md](screens.md)

## Sub-features

- `voice-notes.share-in`: Share a received audio message from a messaging app to Dictus.
- `voice-notes.transcribe`: The shared audio is transcribed into result cards.
- `voice-notes.after-mode`: « Après la transcription »: transcript only, or passed through a Smart Mode.
- `voice-notes.language`: Transcription language: « Détecter automatiquement » or fixed.
- `voice-notes.reader`: ☰ in the keyboard opens the latest voice note.
- `voice-notes.insert`: « Insérer » puts the transcript in the current field.
- `voice-notes.delete`: Delete a voice note from the reader.
- `voice-notes.toggle`: « Messages vocaux » on/off switch.
- `voice-notes.progress-activity`: A Live Activity follows a voice note being transcribed.

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

- **Not drivable in the simulator:** sharing from a messaging app (none is installed), so the share-in and the transcription that follows cannot be driven. The share extension itself is not the blocker: with `dictus.debugProEntitlementForced` set and `dictus.voiceNotesEnabled` on, it accepts the request even while `PremiumFlags.paywallVisible = false`. In a Release build, where the forced entitlement does not exist, it refuses with "…not available in this version of Dictus."
- The reader's identifiers (`voiceNoteReaderInsert`…) live inside the keyboard and do not appear in the host's tree.
