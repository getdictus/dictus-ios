# Smart Modes

- **ID:** `smart-modes`
- **Tier:** Pro
- **Targets:** DictusKeyboard + DictusApp + DictusCore
- **Screens:** `kbd.smart-mode-fan`, `app.home.smart-mode-picker`, `app.pro.smart-modes`, `app.onboarding.smart-modes-scene`, `app.onboarding.smart-mode-pick` — see [screens.md](screens.md)

## Sub-features

- `smart-modes.fan`: Hold the mic, drag up, release on a mode: the dictation is rewritten in it; « Normal » clears it.
- `smart-modes.structured`: Structuré: a long dictation put in order.
- `smart-modes.list`: Liste: ideas as bullet points.
- `smart-modes.message`: Message: a clear message, ready to send.
- `smart-modes.summary`: Résumé: the gist in a few sentences.
- `smart-modes.translate`: Traduction → FR / EN / ES / DE.
- `smart-modes.pin`: Choose up to three modes shown in the keyboard (add, remove, reorder).
- `smart-modes.toggle`: « Mode intelligent » on/off switch.
- `smart-modes.home-picker`: Home shows the mode the next dictation runs, as the mic's badge and a chip beside it (`home.smartMode`, « Normal » or « → EN »); tapping the chip, holding the mic, or VoiceOver's « Choisissez un mode » action on the mic opens the fan's rows (`home.smartModePicker`); a row arms that mode in the store the keyboard reads, without starting a recording (#489).

## How to get to it (user POV)

1. With Pro, open the Dictus keyboard in any app.
2. Hold the mic, slide up to a mode (e.g. Liste), let go, speak.
3. Choose which three modes appear: Dictus → Réglages → Dictus Pro → Mode intelligent.
4. In Dictus, tab Accueil: tap the chip beside the mic (or hold the mic) and pick a mode; the keyboard uses the same mode.

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

Home picker (needs a model, so the mic exists):

```bash
.claude/skills/verify-dictus-ios/scripts/drive.sh tab Accueil
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id home.smartMode               # opens home.smartModePicker
axe touch -x <mic x> -y <mic y> --down --up --delay 0.8 --udid <udid>                 # or hold the mic (home.newDictation)
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-id home.smartModePicker.normal  # rows: normal, <mode id>, pro
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log 'smartModeChosen' 10
```

## Gotchas

- **Home badge in the simulator:** the badge and the chip show what the next dictation *runs*, and without Apple Intelligence that is always Normal. An armed mode shows only in the picker, with « Désactivé », and the rows are greyed.
- **Not drivable in the simulator:** a Smart Mode rewrite. Apple Intelligence is unavailable, so the fan opens with every mode greyed out and « Les modes exigent Apple Intelligence. Activez-le dans Réglages. »
- Pro is reached through the trial (end of onboarding) or the Debug-only `dictus.debugProEntitlementForced` key (Settings → Developer → Force Pro entitlement).
- `kbd mic-fan` releases on nothing (`smartModeFanAborted`), so nothing records. Releasing on a mode would start a recording.
- Screenshot during the drag: after release the fan is gone.
