# History of transcriptions

- **ID:** `history`
- **Tier:** Pro
- **Targets:** DictusApp + DictusCore
- **Screens:** `app.history`, `app.pro.history`, `app.history.detail` (not captured) — see [screens.md](screens.md)

## Sub-features

- `history.list`: The last 200 dictations, kept on the phone only.
- `history.search`: « Rechercher dans les transcriptions ».
- `history.delete`: Delete one entry (swipe or context menu).
- `history.detail`: An entry's detail: copy, share, add a word to the vocabulary.
- `history.clear`: « Effacer l'historique » in Réglages → Transcription. Since #906 it empties the history **and** the polish journal (`polish_events.jsonl` in the App Group, every dictation of the last 7 days, Pro or not). The row shows for a subscriber, and for anyone with saved transcriptions or a non-empty journal, so a free user who dictated this week sees it; it is enabled while either store holds something, and the count is drawn only when the history is not empty.
- `history.toggle`: « Historique » on/off switch.
- `history.home-entry`: « Historique » button on Home (swipe up).

## How to get to it (user POV)

1. With Pro, open Dictus → Accueil.
2. Tap « Historique » (or swipe up) to see past dictations; tap one for details.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Accueil
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label Historique
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-label "Aucune transcription pour l’instant"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label Fermer
```

### Clear history empties the polish journal (#906)

No recording needed: seed the two App Group files while the app is terminated, then clear from Réglages. A run of this recipe, before and after the fix, is in `docs/agents/evidence/906/`.

```bash
D=.claude/skills/verify-dictus-ios/scripts/drive.sh
source <(grep -E '^(UDID|GROUP_DIR)=' "$DICTUS_VERIFY_RUN/run.env")
# Free user: the launch starts the reverse trial; end it with Réglages → Developer → « End the trial now ».
# Pro user instead: $D set-default dictus.debugProEntitlementForced -bool YES
xcrun simctl terminate "$UDID" com.pivi.dictus
cp <seed>/polish_events.jsonl "$GROUP_DIR/"              # one PolishDebugEntry JSON per line
cp <seed>/transcription_history.json "$GROUP_DIR/"       # Pro case only: a JSON array of TranscriptionRecord
xcrun simctl launch "$UDID" com.pivi.dictus
$D tab Réglages
$D tap-label "Effacer l’historique"                      # Pro with one record: "Effacer l’historique, 1"
$D tap-label "Tout supprimer"
wc -c < "$GROUP_DIR/polish_events.jsonl"                 # 0
cat "$GROUP_DIR/transcription_history.json"              # []
```

Seed lines are easiest to produce with `PolishEventStore.encoder` and `TranscriptionHistoryStore.encoder` from a throwaway test in `DictusCore` (delete it afterwards). After the clear, a free user's row disappears (nothing left to delete); a Pro user's stays, disabled, with no count.

## Gotchas

- **Not drivable in the simulator without a real dictation:** a non-empty list, the detail screen, search results. Entries come only from a transcription (model + recording). The empty state is what an agent can show.
- `Historique` also labels the Pro hub row and the switch on its page: use the Home tab first so the right one is on top.
