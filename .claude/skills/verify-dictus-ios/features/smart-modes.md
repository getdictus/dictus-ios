# Smart Modes

- **ID:** `smart-modes`
- **Tier:** Pro
- **Targets:** DictusKeyboard + DictusApp + DictusCore
- **Screens:** `kbd.smart-mode-fan`, `app.home.smart-mode-ring`, `app.pro.smart-modes`, `app.onboarding.smart-modes-scene`, `app.onboarding.smart-mode-pick` — see [screens.md](screens.md)

## Sub-features

- `smart-modes.fan`: Hold the mic, drag up, release on a mode: the dictation is rewritten in it; « Normal » clears it.
- `smart-modes.structured`: Structuré: a long dictation put in order.
- `smart-modes.list`: Liste: ideas as bullet points.
- `smart-modes.message`: Message: a clear message, ready to send.
- `smart-modes.summary`: Résumé: the gist in a few sentences.
- `smart-modes.translate`: Traduction → FR / EN / ES / DE.
- `smart-modes.pin`: Choose up to three modes shown in the keyboard (add, remove, reorder).
- `smart-modes.toggle`: « Mode intelligent » on/off switch.
- `smart-modes.home-ring`: the Smart Mode ring around the Home mic (`home.smartModeRing`, #489). At rest the mic shows a chevron on each side and three dots above it, and wears the armed mode's glyph and badge when the next dictation runs one. Long press the mic (0.35 s): a half-ring of the keyboard fan's rows opens above it (Normal at the top, the pinned modes alternating left and right, the Dictus Pro row for a non-subscriber). Slide onto a mode: its sector lights and the mic takes its glyph. Release on it: the mode is armed in the store the keyboard reads **and a dictation starts** in it. Releasing on the starting mode (usually Normal), on the mic itself or below the arc cancels: nothing armed, nothing recorded. The Dictus Pro row opens the paywall; an unavailable mode is refused with a haptic. VoiceOver has no gesture: one action per row on `home.newDictation`, which arms the mode without recording.

## How to get to it (user POV)

1. With Pro, open the Dictus keyboard in any app.
2. Hold the mic, slide up to a mode (e.g. Liste), let go, speak.
3. Choose which three modes appear: Dictus → Réglages → Dictus Pro → Mode intelligent.
4. In Dictus, tab Accueil: hold the mic, slide onto a mode on the ring around it, let go, speak. The keyboard then uses the same mode. Slide back to Normal before letting go to cancel.

## Driving it with axe + Argent

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Réglages
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Dictus Pro, Pro actif"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Mode intelligent, Reformulez vos textes avec une IA embarquée, Activé"
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Ajouter Message au clavier"          # pin a mode
.claude/skills/verify-dictus-ios/scripts/drive.sh full-access && .claude/skills/verify-dictus-ios/scripts/drive.sh select-keyboard
(.claude/skills/verify-dictus-ios/scripts/drive.sh kbd mic-fan &) ; sleep 2.6
.claude/skills/verify-dictus-ios/scripts/evidence.sh fan        # screenshot DURING the drag
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log 'smartModeFanAborted' 10
```

Home ring (needs Pro and a model, so the mic exists). The simulator has no Apple Intelligence, so without the Debug-only `dictus.debugAppleIntelligenceForced` key every mode is greyed. A model can be faked for the mic alone: `dictus.downloadedModels` and `dictus.activeModel` in the App Group, with the app stopped (a release on a mode would then start a dictation on a model that is not on disk; revoke the microphone first so nothing from the room is captured).

```bash
U=<udid>; P="$GROUP_DIR/Library/Preferences/group.solutions.pivi.dictus.plist"   # from run.env
xcrun simctl privacy $U revoke microphone com.pivi.dictus
xcrun simctl terminate $U com.pivi.dictus
xcrun simctl spawn $U defaults write "$P" dictus.downloadedModels -data "$(printf '["openai_whisper-base"]' | xxd -p | tr -d '\n')"
xcrun simctl spawn $U defaults write "$P" dictus.activeModel -string openai_whisper-base
xcrun simctl spawn $U defaults write "$P" dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugAppleIntelligenceForced -bool YES   # relaunches
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Commencer mon essai gratuit"   # the trial sheet, first launch with Pro forced
# Mic centre on iPhone 17: (201, 678); its frame is home.newDictation's in axe describe-ui.
# Hold only, release on the mic: opens the ring, then cancels.
axe touch -x 201 -y 678 --down --up --delay 4 --udid $U
# Hold, slide up through Liste (right of Normal) and end on Normal: the release cancels.
(axe batch --udid $U --step "touch -x 236 -y 678 --down" --step "sleep 1.0" \
  --step "swipe --start-x 236 --start-y 678 --end-x 234 --end-y 521 --duration 8" &) ; sleep 4
.claude/skills/verify-dictus-ios/scripts/evidence.sh ring   # DURING the drag: Liste lit, « Relâchez pour dicter : Liste »
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log 'action=smartModeRingReleased details=outcome=cancel' 15
```

Log lines, all `<APP> diagnosticProbe component=HomeView instanceID=- action=<name> details=…` (category `keyboard`, level DEBUG):

| `action=` | When | `details=` |
| --- | --- | --- |
| `smartModeRingOpened` | The long press completed and the ring is drawn | `entries=<rows on the ring> armed=<armed mode id, or normal>` |
| `smartModeRingReleased` | The finger lifted | `outcome=cancel` (start mode, mic, below the arc), `record:<row id>` (armed, dictation started), `paywall` (Dictus Pro row), `refused` (unavailable mode); then `source=home` |
| `smartModeRingReleased` | The system cancelled the touch, or the long press lifted before the drag began | `outcome=interrupted source=home` |
| `smartModeChosen` | A VoiceOver action on the mic chose a row (arms it, or opens the paywall for Dictus Pro) | `row=<row id> source=homeAccessibility` |

There is no log line for a change of sector during the slide: the ring only ticks the haptic. Check the lit sector on the screenshot, and the row that won in `record:<row id>`.

Two presentation switches in `DictusApp/Views/HomeSmartModeRing.swift`, `HomeSmartModeRingStyle`, both `true` today and still under review (code constants, not settings): `dimsDashboard` fades the cards and the history hint to `dimmedOpacity` (0.25) while the ring is open, and `showsReleaseHint` draws the line under the mic (« Glissez sur un mode pour dicter », « Relâchez pour dicter : <mode> » / « Revenez sur <mode> pour annuler », or why a mode is unavailable). Turning either off removes only that; the ring, the gesture and VoiceOver's actions do not read them.

## Gotchas

- **Home ring in the simulator:** without Apple Intelligence the mic's face and badge show what the next dictation *runs*, which is always Normal, and the ring's mode sectors are greyed. `dictus.debugAppleIntelligenceForced` (Debug builds only: the key and its reader in `SmartModeAvailability.engineState` are `#if DEBUG`, compiled out of Release) makes the Smart Mode surfaces read Apple Foundation Models as available. It forces what they *show*: a rewrite still asks the real model and fails here.
- **A ring release on a mode records.** Screenshot during the drag and end the slide on the starting mode, on the mic or below the arc.
- **Not drivable in the simulator:** a Smart Mode rewrite. Apple Intelligence is unavailable, so the fan opens with every mode greyed out and « Les modes exigent Apple Intelligence. Activez-le dans Réglages. »
- Pro is reached through the trial (end of onboarding) or the Debug-only `dictus.debugProEntitlementForced` key (Settings → Developer → Force Pro entitlement).
- `kbd mic-fan` releases on nothing (`smartModeFanAborted`), so nothing records. Releasing on a mode would start a recording.
- Screenshot during the drag: after release the fan is gone.
