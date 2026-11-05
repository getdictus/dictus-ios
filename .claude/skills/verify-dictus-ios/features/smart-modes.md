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

**Apple Intelligence refusal, end to end** (#455, run on 2026-11-04; it records, so only when the task asks). Three Debug keys make the fan armable and every call refused: `dictus.debugProEntitlementForced`, `dictus.debugAppleIntelligenceForced` (the fan's armability reads it, not the engine) and `dictus.debugPolishRefusalForced` (Réglages → Developer → « Force Apple Intelligence refusal », a CheckBox: `axe tap --label "Force Apple Intelligence refusal" --element-type CheckBox`). Then a model, the mic grant, `full-access`, `select-keyboard` and one warm-up take, as in `dictation.keyboard.md` (With a model). The fan opens **downwards** from the mic, rows ~52 pt apart (Normal ~610 pt, the fourth pinned mode ~772 pt on iPhone 17); releasing on a row arms it and starts recording:

```bash
axe batch --udid <udid> --step "touch -x 357 -y 559 --down" --step "sleep 1.2" \
  --step "swipe --start-x 357 --start-y 559 --end-x 220 --end-y 772 --duration 1.5"   # → EN, 4th row
say -a "MacBook Pro Speakers" -v Thomas -r 150 "Bonjour, ceci est un test de dictée sur le simulateur."
axe tap -x 357 -y 559 --udid <udid>                                                    # ✓
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log 'smartModeRefused mode=translate.en outcome=engineFailed reason=safetyRefusal\|degraded' 30
```

The French text is inserted as dictated and the status slot reads « → EN : Apple Intelligence a refusé de traiter ce texte, inséré tel quel. » for ~3 s (`dictationMessageSet reason=smartModeFailed-engineFailed` → `dictationMessageCleared reason=smartModeFailed-timeout`): capture it with `simctl io … screenshot` in a loop right after ✓. Captures: `docs/agents/evidence/455/`.

## Gotchas

- **Not drivable in the simulator:** a Smart Mode rewrite. Apple Intelligence is unavailable, so the fan opens with every mode greyed out and « Les modes exigent Apple Intelligence. Activez-le dans Réglages. » `dictus.debugAppleIntelligenceForced` makes the modes armable, but the rewrite itself still fails (`engine=apple-fm reason=other:NSError`); only the forced refusal (`dictus.debugPolishRefusalForced`) gives a deterministic outcome. A real Apple refusal is device-only.
- **`say` must reach the built-in microphone.** When the Mac's default output is another device (USB, headphones), plain `say` is never heard and the take ends in `transcriptionFailed error=no speech detected`. `say -a "MacBook Pro Speakers"` routes only that clip, without changing a system default.
- Pro is reached through the trial (end of onboarding) or the Debug-only `dictus.debugProEntitlementForced` key (Settings → Developer → Force Pro entitlement).
- `kbd mic-fan` releases on nothing (`smartModeFanAborted`), so nothing records. Releasing on a mode would start a recording.
- Screenshot during the drag: after release the fan is gone.
