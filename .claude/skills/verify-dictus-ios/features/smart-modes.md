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
- `smart-modes.home-ring`: the Smart Mode ring around the Home mic (`home.smartModeRing`, #489). At rest an arrow on each side of the mic breathes toward it, and the mic wears the armed mode's glyph and badge when the next dictation runs one. Long press the mic (0.35 s): a half-ring opens above it with the keyboard fan's rows, one equal sector each (2 to 4 rows: Normal and up to three pinned modes; a non-subscriber gets Normal, default modes and the Dictus Pro row). Normal is always the last sector, at the right end of the arc; the other rows fill the sectors from the left in the fan's order. Slide onto a mode: its sector lights and the mic takes its glyph. Release on it: the mode is armed in the store the keyboard reads **and a dictation starts** in it. Releasing on the starting mode (what the mic showed when the finger went down, usually Normal), on the mic itself, or well past the band cancels: nothing armed, nothing recorded. The Dictus Pro row opens the paywall; an unavailable mode is refused with a haptic. VoiceOver has no gesture: one action per row on `home.newDictation` (« Utiliser <mode> », « Dictus Pro »), which arms the mode without recording.

## How to get to it (user POV)

1. With Pro, open the Dictus keyboard in any app.
2. Hold the mic, slide up to a mode (e.g. Liste), let go, speak.
3. Choose which three modes appear: Dictus → Réglages → Dictus Pro → Mode intelligent.
4. In Dictus, tab Accueil: hold the mic, slide onto a mode on the ring around it, let go, speak. The keyboard then uses the same mode. Slide back to the starting mode before letting go to cancel.

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

The French text is inserted as dictated and the status slot reads « → EN : Apple Intelligence a refusé de traiter ce texte, inséré tel quel. » for ~3 s (`dictationMessageSet reason=smartModeFailed-engineFailed` → `dictationMessageCleared reason=smartModeFailed-timeout`): capture it with `simctl io … screenshot` in a loop right after ✓. Captures: `docs/agents/evidence/455/`. Rerun on 2026-11-05 for #826, FR and EN devices: `docs/agents/evidence/826/`. On an English device `full-access` stops at the French « Autoriser l’accès complet » row: tap `Allow Full Access` and the alert's `Allow` by hand, and pick « Dictus, Multiple languages » from the globe menu. On iOS 27 the forced refusal throws Apple's own `LanguageModelError.guardrailViolation` (iOS 26 a stand-in error), both logged `reason=safetyRefusal engine=debug-refusal`; the keyboard could not be selected on an iOS 27.2 simulator with this skill's recipes, so the capture runs on iOS 26.5.

**Home ring** (`smart-modes.home-ring`, run on 2026-11-05 at `15cff286`; nothing records). The ring needs the mic, so a model; a model can be faked for the mic alone with `dictus.downloadedModels` and `dictus.activeModel` in the App Group, with the app stopped. A release on a mode would then start a dictation on a model that is not on disk, so revoke the microphone first. Without `dictus.debugAppleIntelligenceForced` every mode sector is greyed.

```bash
U=<udid>; source "$DICTUS_VERIFY_RUN/run.env"; P="$GROUP_DIR/Library/Preferences/group.solutions.pivi.dictus.plist"
xcrun simctl privacy $U revoke microphone com.pivi.dictus
xcrun simctl terminate $U com.pivi.dictus
xcrun simctl spawn $U defaults write "$P" dictus.downloadedModels -data "$(printf '["openai_whisper-base"]' | xxd -p | tr -d '\n')"
xcrun simctl spawn $U defaults write "$P" dictus.activeModel -string openai_whisper-base
xcrun simctl spawn $U defaults write "$P" dictus.debugProEntitlementForced -bool YES
.claude/skills/verify-dictus-ios/scripts/drive.sh set-default dictus.debugAppleIntelligenceForced -bool YES   # relaunches
.claude/skills/verify-dictus-ios/scripts/drive.sh tap-label "Commencer mon essai gratuit"   # the trial sheet, first launch with Pro forced
# Mic centre on iPhone 17: (201, 678), from home.newDictation's frame in `drive.sh tree`.
# With the default pins the ring holds 4 rows of 45° each: Structuré, Liste, Traduction → EN, Normal (right end).
# Slide straight out at 67° through → EN and on past the band (> outer radius + 48 pt): the release cancels.
(axe batch --udid $U --step "touch -x 201 -y 678 --down" --step "sleep 1.0" \
  --step "swipe --start-x 201 --start-y 678 --end-x 303 --end-y 439 --duration 8" &) ; sleep 5.2
.claude/skills/verify-dictus-ios/scripts/evidence.sh ring   # DURING the drag: → EN lit, « Relâchez pour dicter : Traduction → EN »
.claude/skills/verify-dictus-ios/scripts/drive.sh wait-log 'action=smartModeRingReleased details=outcome=cancel' 15
```

Log lines, all `<APP> diagnosticProbe component=HomeView instanceID=- action=<name> details=…` (category `keyboard`, level DEBUG):

| `action=` | When | `details=` |
| --- | --- | --- |
| `smartModeRingOpened` | The long press completed and the ring is drawn | `entries=<rows on the ring> armed=<armed mode id, or normal> radii=<inner>-<outer>` |
| `smartModeRingReleased` | The finger lifted | `outcome=cancel` (starting row, mic, past the band), `record:<row id>` (armed, dictation started), `paywall` (Dictus Pro row), `refused` (unavailable mode); then `source=home` |
| `smartModeRingReleased` | The system cancelled the touch, or the long press lifted before the drag began | `outcome=interrupted source=home` |
| `smartModeChosen` | A VoiceOver action on the mic chose a row (arms it, or opens the paywall for Dictus Pro) | `row=<row id> source=homeAccessibility` |

There is no log line for a change of sector during the slide: the ring only ticks the haptic. Check the lit sector on the screenshot, and the row that won in `record:<row id>`.

Two presentation switches in `DictusApp/Views/HomeSmartModeRing.swift`, `HomeSmartModeRingStyle`, both `true` today and still under review (code constants, not settings): `blursBackdrop` blurs the cards and the history hint behind the ring while it is open (radius 14, under a wash of the background at 0.25, nearly opaque with Reduce Transparency), and `showsReleaseHint` draws the line under the mic (« Glissez sur un mode pour dicter », « Relâchez pour dicter : <mode> » over « Revenez sur <mode> pour annuler », « Relâchez pour découvrir Dictus Pro », or why a mode is unavailable). Turning either off removes only that; the ring, the gesture and VoiceOver's actions do not read them.

## Gotchas

- **Home ring in the simulator:** without Apple Intelligence the mic's face and badge show what the next dictation *runs*, which is always Normal, and the ring's mode sectors are greyed. `dictus.debugAppleIntelligenceForced` (Debug builds only: the key in `SharedKeys` and its reader in `SmartModeAvailability.engineState` are `#if DEBUG`, compiled out of Release) makes the Smart Mode surfaces read Apple Foundation Models as available. It forces what they *show*: a rewrite still asks the real model and fails here.
- **A ring release on a mode records.** Screenshot during the drag, and end the slide on the starting mode, on the mic, or past the band. `home.smartModeRing` is `accessibilityHidden`, so it is **not** in `axe describe-ui`: prove it with the screenshot and the `smartModeRing*` log lines.
- **Not drivable in the simulator:** a Smart Mode rewrite. Apple Intelligence is unavailable, so the fan opens with every mode greyed out and « Les modes exigent Apple Intelligence. Activez-le dans Réglages. » `dictus.debugAppleIntelligenceForced` makes the modes armable, but the rewrite itself still fails (`engine=apple-fm reason=other:NSError`); only the forced refusal (`dictus.debugPolishRefusalForced`) gives a deterministic outcome. A real Apple refusal is device-only.
- **`say` must reach the built-in microphone.** When the Mac's default output is another device (USB, headphones), plain `say` is never heard and the take ends in `transcriptionFailed error=no speech detected`. `say -a "MacBook Pro Speakers"` routes only that clip, without changing a system default.
- Pro is reached through the trial (end of onboarding) or the Debug-only `dictus.debugProEntitlementForced` key (Settings → Developer → Force Pro entitlement).
- `kbd mic-fan` releases on nothing (`smartModeFanAborted`), so nothing records. Releasing on a mode would start a recording.
- Screenshot during the drag: after release the fan is gone.
