# Smart Modes

- **ID:** `smart-modes`
- **Tier:** Pro
- **Targets:** DictusKeyboard + DictusApp + DictusCore
- **Screens:** `kbd.smart-mode-fan`, `app.pro.smart-modes`, `app.onboarding.smart-modes-scene`, `app.onboarding.smart-mode-pick` — see [screens.md](screens.md)

## Sub-features

- `smart-modes.fan`: Hold the mic, drag up, release on a mode: the dictation is rewritten in it; « Normal » clears it.
- `smart-modes.structured`: Structuré: a long dictation put in order.
- `smart-modes.list`: Liste: ideas as bullet points.
- `smart-modes.message`: Message: a clear message, ready to send.
- `smart-modes.summary`: Résumé: the gist in a few sentences.
- `smart-modes.translate`: Traduction → FR / EN / ES / DE.
- `smart-modes.pin`: Choose up to three modes shown in the keyboard (add, remove, reorder).
- `smart-modes.toggle`: « Mode intelligent » on/off switch.

## How to get to it (user POV)

1. With Pro, open the Dictus keyboard in any app.
2. Hold the mic, slide up to a mode (e.g. Liste), let go, speak.
3. Choose which three modes appear: Dictus → Réglages → Dictus Pro → Mode intelligent.

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

## Gotchas

- **Not drivable in the simulator:** a Smart Mode rewrite. Apple Intelligence is unavailable, so the fan opens with every mode greyed out and « Les modes exigent Apple Intelligence. Activez-le dans Réglages. »
- Pro is reachable only through the Debug-only `dictus.debugProEntitlementForced` key (Settings → Developer → Force Pro entitlement); a Release build has no way in while `PremiumFlags.paywallVisible = false`.
- `kbd mic-fan` releases on nothing (`smartModeFanAborted`), so nothing records. Releasing on a mode would start a recording.
- Screenshot during the drag: after release the fan is gone.
