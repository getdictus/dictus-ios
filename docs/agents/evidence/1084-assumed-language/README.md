# #1084 PR 1: a voice note read by Apple's model says which language it was read in

Simulator: iPhone 17, iOS 26.5, slimmed (simslim), Debug build of this branch (`09deb63a`), deleted after
the run (`verify-dictus-ios`). State: Pro forced (`dictus.debugProEntitlementForced`, Debug only), voice
notes on, voice-note language on automatic detection (the default), keyboard language `fr`, Apple's model
picked on the Models screen (`dictus.speechEngineChoice = apple`), no Dictus model downloaded.

No iOS simulator ships Apple's speech model, so the Debug-simulator-only `SimulatorHostRecognizer`
(#1036) asks a throwaway helper on the Mac running macOS's own `SpeechTranscriber` (not committed),
on port 47813 (`dictus.debugSimulatorHostPort`).

The audio is fictional and **Spanish**, synthesised on the Mac with `say -v Paulina` (10 s), copied into
Files › On My iPhone and shared to Dictus from Files. Read in French, it comes out as the user in #1084
got it: "Hla piercrio para confirmer la seena delado en casa de mana…".

| File | What it shows |
|---|---|
| `01-card-assumed-language-fr.png` | The card: FR chip, "Transcrit en français, votre langue de dictée. Le modèle d'Apple ne détecte pas la langue.", and the link "Changer la langue des messages vocaux". |
| `02-card-from-history-fr.png` | The same note opened again from History: same line. |
| `03-history-entry-fr.png` | The History entry reads FR. On develop it read AUTO. |
| `04-settings-footer-fr.png` | The screen the link opens, with the new footer of the language picker. |
| `05-flow-share-to-card.mp4` | Files › long press › Share › Dictus, then Dictus opened on the card, then the link (re-encoded to 602 px wide, no audio). |

The History file on disk after the first run: `language: fr`, `sttProvider: AP`, `languageAssumed: true`.

Both ways a voice note is transcribed, from the run's `dictus_debug.log` (timestamps removed):

```
# The app was alive and transcribed the note itself.
<APP> VoiceNote started id=5EC32123 seconds=10 chunks=1 mode=autoDetect activeModelEngine=WK
<APP> TranscriptionService languageResolution resolved mode=autoDetect keyboard=fr engine=AP stt=fr sttEffective=yes
<APP> VoiceNote finished id=5EC32123 chars=104 engine=AP lang=fr assumed=true savedToHistory=true elapsedMs=377

# The app was suspended: the share extension transcribed it, then the app adopted the result (the video).
<SHARE> VoiceNoteShare route route=shareExtension lang=fr source=dictationLanguage engine=simulator-host-speechanalyzer voiceNoteLanguage=auto keyboard=fr …
<SHARE> VoiceNoteShare finished id=BC1CED2A seconds=10 chars=104 lang=fr assumed=true engine=simulator-host-speechanalyzer savedToHistory=true …
<APP> VoiceNote adopted id=BC1CED2A chars=104 engine=simulator-host-speechanalyzer lang=fr assumed=true savedToHistory=true queueCommitted=true
```

On develop, `started` names the downloaded model's engine as `engine=` (`engine=PK` in the issue's log), `finished`
names neither engine nor language, and the record is `auto` with that engine.

Not shown here: an iPhone with Apple's real model, WhatsApp, a real voice, and English, German and Spanish
screens (the strings are in `Localizable.xcstrings`, not captured).
