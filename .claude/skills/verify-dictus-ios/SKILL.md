---
name: verify-dictus-ios
description: Verify the Dictus iOS app (DictusApp, the Dictus keyboard extension, its App Group hand-off) on a headless iOS Simulator created for the run — build, install, launch, check health, drive a mapped feature by accessibility identifier, capture evidence, delete the simulator. Use when a change to DictusApp or DictusKeyboard has to be seen working in the real app rather than in `swift test`, when a feature from features/README.md must be exercised, or when screens need re-capturing.
---

# Verify Dictus on the iOS Simulator

Five steps, always in this order: **Launch → Doctor → Drive → Evidence → Cleanup**. Each one is a script under `scripts/`, run from the repository root. The simulator is created by Launch for this run and deleted by Cleanup; evidence outlives both.

Read first: `docs/agents/simulator.md` is the authority on what a simulator can and cannot do here, and `features/README.md` maps every user feature to its recipe. A pass here is not a device validation (CLAUDE.md): what only a physical iPhone can show is listed in each feature's Gotchas and gathered in [Physical test shortlist](#physical-test-shortlist).

**Headless, always.** Never `open -a Simulator`. Xcode 27 (installed here) has no Simulator.app and `axe` needs nothing; on an Xcode 26 machine `launch.sh` starts it with `open -g -a Simulator`, which does not take the focus. Doctor fails if Simulator or DeviceHub ends up frontmost.

## Launch

```bash
.claude/skills/verify-dictus-ios/scripts/launch.sh                    # French device, onboarding intro
.claude/skills/verify-dictus-ios/scripts/launch.sh --skip-onboarding  # straight to the tab bar
.claude/skills/verify-dictus-ios/scripts/launch.sh --lang en          # English device
```

What it does, in order:

1. Creates a new device `Dictus Verify <date>-<time>-<sha>` (iPhone 17, iOS 26.5 — not iOS 27, where the system may mount no third-party keyboard). It never reuses or erases an existing device.
2. Writes the device language and the keyboard list (`AppleKeyboards` with `com.pivi.dictus.keyboard`, plus `AppleKeyboardsExpanded = 1`) into its `.GlobalPreferences.plist` while it is shut down.
3. `simslim on <udid> --keep com.apple.remindd`, which boots it slimmed (~850 MB instead of ~3 GB), then `bootstatus`. Probes `axe describe-ui`.
4. `xcodebuild -resolvePackageDependencies` then `xcodebuild build -scheme DictusApp -configuration Debug -destination platform=iOS Simulator,id=<udid> -derivedDataPath build/DerivedData`, **without** CI's `CODE_SIGNING_ALLOWED=NO` (an unsigned build gets no App Group container, so no `dictus_debug.log`). If the catalogs were clean before the build, records the hash of each `.xcstrings` the build rewrote (`xcstrings-build.sha`) and restores it.
5. Installs, checks `pluginkit` lists `com.pivi.dictus.keyboard`, launches `com.pivi.dictus`.

**Ready means all three**, because `simctl launch` exits 0 for an app that crashes a second later:

- the first screen is in the accessibility tree — `onboarding.primary` (intro), or the `Accueil`/`Home` tab with `--skip-onboarding`;
- the launched pid is still alive;
- `<APP> appLaunched` is in the App Group's `dictus_debug.log`.

Last line on success, and the only one to rely on:

```
READY udid=<udid> run=/Users/…/dev/dictus-evidence/verify-skill/<run-id> pid=<pid> screen=<onboarding|home>
```

The run directory holds `run.env` (UDID, App Group path, log path, pid) that every other script reads. **There is no shared `latest` link**: each session has its own pointer, `~/dev/dictus-evidence/verify-skill/sessions/<session>`, where the session is the worktree (its name plus a hash of its path) unless `DICTUS_VERIFY_SESSION` names it. Two sessions on this Mac therefore never resolve, drive or delete each other's run. To be explicit, export the run directory from the `READY` line: `export DICTUS_VERIFY_RUN=<run-dir>`. A cold `build/DerivedData` takes about 10 minutes (FluidAudio, WhisperKit); an incremental build about one.

## Doctor

```bash
.claude/skills/verify-dictus-ios/scripts/doctor.sh            # this session's run
.claude/skills/verify-dictus-ios/scripts/doctor.sh <run-dir>  # a given run
```

Read-only: it creates, boots, taps and installs nothing. One `OK` / `WARN` / `FAIL` line per check, then `DOCTOR OK` or `DOCTOR FAIL <n>` (exit 1). It checks:

- Xcode, `axe`, `simslim`, `argent`, `python3` present; the iOS 26.5 runtime installed; the Argent tool-server healthy; leftover `Dictus Verify` devices from runs that were never cleaned up.
- The run's device exists, is booted and slimmed; Dictus is installed; the keyboard is registered; DictusApp is running (a `WARN` right after Full Access, which kills it); the App Group log exists and whether the keyboard has logged `fullAccess=true`; `axe` can read the tree; SpringBoard logged no crash signal for a Dictus process in 30 minutes (SIGKILL excluded: that is how iOS reclaims the widget extension).
- The frontmost Mac app is not Simulator or DeviceHub.

Run it after Launch and again before Evidence. A `FAIL` stops the run: fix it or report it, do not drive past it.

## Drive

Both drivers are installed; install nothing else.

- **`axe`** (`/opt/homebrew/bin/axe`) — taps, swipes, long presses, the accessibility tree in **points**. `scripts/drive.sh` wraps it.
- **Argent** (`argent run <tool>`, tool-server already running) — the same tree as text with **normalized 0–1** frames, waits, and screenshots. Use it to read a screen or wait on an element; do not mix its coordinates with `axe`'s.

```bash
argent run describe --udid <udid>
argent run await-ui-element --udid <udid> --condition visible --selector-json '{"identifier":"onboarding.primary"}' --timeoutMs 10000
argent run screenshot --udid <udid> --scale 1 --out ~/dev/dictus-evidence/verify-skill/<run-id>/<name>.png
```

**Target by identifier, then by label, then by coordinate.** The identifiers that exist in the code (complete list, `grep -rn accessibilityIdentifier`):

| Identifier | Control |
| --- | --- |
| `onboarding.primary` | The main button of every onboarding step (Commencer, Continuer, Suivant, J'ai compris) |
| `onboarding.back` / `onboarding.skip` | Back chevron (language step, Pro scenes) / Passer |
| `onboarding.openSettings`, `onboarding.later`, `onboarding.seeStepsAgain` | Keyboard-setup and Apple Intelligence steps |
| `onboarding.checkFullAccess`, `onboarding.fullAccess.why`, `onboarding.fullAccess.close`, `onboarding.fullAccess.github` | Full Access explainer |
| `onboarding.smartModePick.counter`, `onboarding.smartModePick.<mode>` | Smart Mode tiles: `structured`, `notes`, `message`, `summary`, `translate.fr/en/es/de` |
| `onboarding.firstDictation.field`, `onboarding.firstDictation.banner` | Practice field |
| `proFeatureDemoLink`, `proFeatureScene.ok` | "Voir la démonstration" on a Pro screen, its OK |
| `home.newDictation` | The round mic on Home that starts a dictation (label « Nouvelle dictée »; only with a model) |
| `voiceNoteReaderClose`, `voiceNoteReaderDelete`, `voiceNoteReaderEmpty`, `voiceNoteReaderOpen`, `voiceNoteReaderInsert` | Keyboard voice-note reader (inside the keyboard, so not in the host's tree) |

Labels that are stable and unique (French device): tabs `Accueil` / `Modèles` / `Réglages` (RadioButtons; reach them with `drive.sh tab`, since the Models screen also has a « Modèles » heading); `Dictus Pro, Pro actif`; the Pro hub rows `Mode intelligent, …`, `Historique, …`, `Vocabulaire, …`, `Messages vocaux, …`; `Langues prises en charge`; `Sons`, `Diagnostic`, `Debug Logs`, `Licences`, `Exporter les logs`; navigation back is the identifier `BackButton`, a modal close `xmark` or the label `Fermer`.

**The Dictus keyboard is one opaque element**, `inputView`, in the host app's tree: none of its keys or buttons is listed. `drive.sh kbd <control>` presses them at measured offsets from that frame, and the App Group log is what proves the press landed.

`tap-id` and `tap-label` tap only a unique match. When several elements on screen share the label (or the identifier), they refuse with exit 1 and list every candidate, so the run never taps the wrong one silently: pick the one you mean with `tap-id`. A match nested inside another (a row and its title, a tab and its icon) counts once, and the inner one is tapped. They also refuse an element whose centre is off screen (a list lays out rows below the fold, and `axe` would tap whatever sits at the edge, a Subscribe button included): scroll it into view first. The recipes (`full-access`, `select-keyboard`) keep tapping the first match, because Settings repeats its row identifiers on nested elements. A tap on a toggle row's title does not flip a SwiftUI switch: use `axe tap --label <label> --element-type CheckBox`, which touches the switch.

```bash
D=.claude/skills/verify-dictus-ios/scripts/drive.sh
$D tap-id onboarding.primary          # by identifier
$D tap-label "Diagnostic"             # by label (tabs: $D tab Modèles)
$D wait-id onboarding.back 10         # wait, fail after 10 s
$D set-default dictus.debugProEntitlementForced -bool YES   # Pro on (Debug build), relaunch
$D full-access                        # Réglages → Général → Clavier → Claviers → Dictus → Accès complet
$D select-keyboard                    # Safari address bar, long-press the globe, "Dictus, multilingue"
$D kbd mic                            # also: menu, menu-hold, emoji, abc, mic-fan
$D type bonjoru && $D space           # type through the Dictus keys (not `axe type`, which bypasses the keyboard)
$D log-mark                           # next log line number, to assert only on what follows
$D wait-log '<KBD> keyboardMicTapped' 15 <mark>
```

**The recipe this skill is proven on** — `dictation.keyboard` without a model, the keyboard → app → keyboard hand-off:

```bash
D=.claude/skills/verify-dictus-ios/scripts/drive.sh
E=.claude/skills/verify-dictus-ios/scripts/evidence.sh
$D full-access
$D select-keyboard
$D wait-log '<KBD> .*fullAccess=true' 15
$E 01-keyboard
xcrun simctl terminate <udid> com.pivi.dictus      # force the cold-start path
M=$($D log-mark)
$D kbd mic
$D wait-log '<KBD> keyboardMicTapped' 15 "$M"
$D wait-log '<APP> coldStartURLReceived isColdStart=true' 20 "$M"
$D wait-log '<APP> dictationFailed error=No model downloaded' 20 "$M"
$D wait-log '<KBD> statusChanged from=requested to=failed' 15 "$M"
$E 02-after-mic
```

Every other feature's recipe is in `features/<id>.md`, under "Driving it with axe + Argent". Rules that hold for all of them:

- **Never tap the globe** to change keyboard: a tap cycles past third-party keyboards. Long-press it (`select-keyboard` does).
- **Never download a model and never start a recording** unless the task asks for it: a simulator records the Mac's microphone, the room Pierre sits in. The onboarding's `Continuer` on the language step starts a download.
- A held press whose release matters ends with a `swipe` step inside one `axe batch`; `touch --up` does not end a SwiftUI gesture.
- Settings and full-screen covers leave the screen below them in the tree. A label that exists on both (e.g. `Historique`) can hit the hidden one: prefer the longer, unique label.

## Evidence

```bash
.claude/skills/verify-dictus-ios/scripts/evidence.sh <name>   # e.g. 02-after-mic
```

Everything lands in `~/dev/dictus-evidence/verify-skill/<run-id>/`, never in the repository:

| File | Written by | Content |
| --- | --- | --- |
| `report.txt` | all scripts | commit, Xcode, device, each step, `READY`, every capture, `CLEANUP OK` |
| `<name>.png` | `evidence.sh` | screenshot in device pixels (1206×2622) |
| `<name>.ui.json` | `evidence.sh` | `axe describe-ui` tree at that moment |
| `<name>.log` | `evidence.sh` | last 40 lines of `dictus_debug.log` |
| `dictus_debug.full.log` | `cleanup.sh` | the whole App Group log, copied before the device is deleted |
| `build.log`, `resolve.log`, `simslim.log`, `00-launch.png` | `launch.sh` | build output, the first screen |

Capture at least: the screen before the action, the screen after it, and the log lines that prove the action happened (`wait-log` prints them; paste them in the report or PR). A screenshot without the log line is a picture, not a proof. Screens that belong in the screen map are copied, resized to 874 px high (`sips -Z 874`), to `docs/agents/screens/<screen-id>.png` — the only images that go in the repository.

## Cleanup

```bash
.claude/skills/verify-dictus-ios/scripts/cleanup.sh            # this session's run
.claude/skills/verify-dictus-ios/scripts/cleanup.sh <run-dir>  # a given run
```

It copies `dictus_debug.full.log` out of the App Group, then `xcrun simctl shutdown` and `xcrun simctl delete` on **the UDID in the run's `run.env` and only that one** — and refuses if that device's name does not start with `Dictus Verify`. For `.xcstrings`, it restores a catalog **only if it is byte-identical to what a build of this run produced** (`xcstrings-build.sha`); any other change was made after the launch, by a person or an agent, and is kept with a `warning: … left untouched` line. Last line: `CLEANUP OK udid=<udid> deleted=yes`.

- Never kill a process by name (`killall Simulator`, `pkill -f simctl`): other sessions and the smoke test's `Dictus Smoke` device share this Mac. Quitting Simulator.app shuts down every device it owns.
- Never delete anything under `~/dev/dictus-evidence/`: Cleanup does not, and nothing else should.
- Run Cleanup on a failed run too. Afterwards, check: `xcrun simctl list devices | grep "<udid>"` prints nothing, and the run directory still holds its files.

## Physical test shortlist

Two lists. The first is what an agent proves alone with this skill; the second is what only Pierre's iPhone can prove, however good the simulator run was. Sources: `docs/agents/simulator.md` (§1 device identity and RAM, §8 what the simulator cannot show) and the Gotchas of each `features/<id>.md`. IDs are from [features/README.md](features/README.md).

### Simulator: the agent proves it alone

| Area | What is proven | IDs |
| --- | --- | --- |
| App starts | Build, install, launch, first screen, no crash signal (Launch + Doctor) | `app.home`, `app.onboarding.welcome` |
| Onboarding | Every step displays, back/skip/next, What's new; not the download, mic prompt or practice dictation | `onboarding.*` except `onboarding.model-download`, `onboarding.microphone`, `onboarding.first-dictation` |
| Keyboard setup | The keyboard registers, is enabled, takes Full Access, is selected from the globe menu | `dictation.requires-full-access`, `sys.settings.full-access`, `kbd.keys`, `kbd.no-full-access` |
| Hand-off, cold path | Mic tap → DictusApp cold start → `No model downloaded` → keyboard shows the failure | `dictation.handoff` (cold only), `kbd.dictation-error` |
| Dictation chain, with a model | Only when the task asks for a recording: a `say` clip played through the Mac's speakers is recorded, transcribed and inserted; the top-bar states are captured (`features/dictation.keyboard.md`, With a model). Proves the chain runs, not the voice, the quality or the timings | `dictation.start`, `dictation.stop`, `dictation.cancel`, `kbd.recording`, `kbd.transcribing`, `kbd.dictation-undo`, `dictation.undo-insert` (drivable by tapping « Annuler » within 8 s; the recipe does not) |
| Typing | Suggestions, autocorrect on space, undo, accents, dead keys, learned words, reset | `typing.*`, `learned-words.*`, `kbd.suggestions` |
| Keyboard surfaces | Languages panel, layouts, number row, 123 and `#+=` pages, emoji picker, recents, search | `keyboard.*`, `emoji.*`, `kbd.panel`, `kbd.numbers`, `kbd.symbols`, `kbd.emoji` |
| Settings and switches | Every preference changes and persists through the App Group (sounds, haptics, polish, Live Activity, history, vocabulary, voice notes) | `sounds.toggle`, `sounds.volume`, `sounds.per-event`, `haptics.toggle`, `polish.toggle`, `live-activity.toggle`, `smart-modes.toggle`, `history.toggle`, `vocabulary.toggle`, `voice-notes.toggle` |
| Pro, Debug-forced | Hub, Smart Mode pins, fan opening (greyed), vocabulary add/edit/delete, variants of your terms on a seeded History (accept with an editable review, empty variant refused, ignore, cap at 10, a term without a variant leaving « En attente d’erreurs à corriger »), history and voice-note reader empty states | `pro.hub`, `smart-modes.fan`, `smart-modes.pin`, `vocabulary.add`/`edit`/`delete`/`reset`, `vocabulary.term-variants`, `history.list` (empty), `voice-notes.reader` (empty) |
| Models | Catalogue, download (real traffic), preparation screen, select, delete, retry, languages sheet; A12/A13 refusal on a device created as `iPhone-11` | `models.*` except the RAM halves of `models.device-gating` and `models.recommended`; `app.models.loading` (screen, not timing) |
| Diagnostics | Log view, export sheet opens, App Group check (signed build) | `diagnostics.*` |

### iPhone: needs Pierre's phone

| Area | Why the simulator cannot prove it | IDs |
| --- | --- | --- |
| Real voice and microphone | A simulator records the Mac's input device: the room, or a synthesized `say` clip. A real voice, its accent and the text quality, and what depends on them (a filled history, the vocabulary effect, voice-note transcription) | `dictation.in-app`, `app.recording`, `history.detail`, `vocabulary.apply`, `vocabulary.term-variants` (rows from a real History), `voice-notes.transcribe` |
| Audio routing | AirPods, Bluetooth headsets, wired input, route changes and interruptions mid-recording: the simulator has only the Mac's devices | `dictation.start`, `dictation.in-app`, `voice-notes.transcribe` |
| Keyboard memory and jetsam | The extension's ~50 MB ceiling and its kills are device figures; simulator `memMB` carries no verdict | `dictation.keyboard`, `kbd.*` (memory only) |
| Keyboard height and dead zones | The declared height constraint (#166) and touch dead zones | `kbd.keys` |
| Warm hand-off and return | The warm path depends on iOS keeping the app alive; auto-return and the Spotlight/arbiter cases (#23) behave differently on device | `dictation.handoff` (warm), `return.auto-return`, `return.swipe-back` |
| Orange microphone dot at rest (#430) | The simulator has no privacy indicator. On the iPhone: dot during a dictation only, off at rest after a dictation and after opening the app (check at 0 s, 30 s, 5 min, and after the 10-minute window), while a keyboard press with the app in background still starts at once. Log: `audioInputMuted context=… muted=…`, never `audioInputMuteFailed` (`features/dictation.keyboard.md`, Gotchas) | `dictation.handoff` (warm), `dictation.start`, `dictation.in-app` |
| RAM-gated device tiers | `physicalMemory` is the Mac's RAM (24 GB here): the `>= 6 GB` Turbo gate and `insufficientMemory` never fire. The recommendation is RAM-gated too (Parakeet at `physicalMemoryGB >= 6`, `ModelInfo.swift:665`), so its `openai_whisper-small` branch never runs in a simulator | `models.device-gating`, `dictation.device-gating` (memory half), `models.recommended` (RAM half) |
| Model speed and cache | Compile time, Neural Engine, transcription timing, the Core ML cache across installs: all Mac silicon in a simulator | `models.preparation` (timing), `app.onboarding.model-preparation` |
| Apple Intelligence | Unavailable in the simulator: polish and every Smart Mode rewrite | `polish.clean-up`, `polish.in-keyboard`, `smart-modes.structured`/`list`/`message`/`summary`/`translate` |
| Real StoreKit purchases | A purchase and a restore are not driven, and the simulator's prices (with simslim's `store` category on, see `features/pro.subscription.md`) are not App Store Connect's prices for a French account. The paywall, trial announcement and end-of-trial screens render in the simulator | `pro.paywall`, `pro.restore`, `pro.trial`, `pro.trial-end`, `app.paywall`, `app.pro.trial-announcement` |
| Live Activity and Dynamic Island | Not reproduced by this skill; states, stop from the island, Focus dropping alerts, dev installs killing activities | `live-activity.*`, `voice-notes.progress-activity`, `widget.live-activity`, `onboarding.stop-standby` |
| Haptics and sounds | No haptic engine and no audible check; only the preference is provable | `haptics.toggle` (effect), `sounds.*` (effect) |
| Voice notes from a messaging app | No messaging app in the simulator to share from | `voice-notes.share-in`, `share.voice-note`, `app.voice-note.result` |
| Host spell-check | Host underlines are not a usable probe in the simulator (`docs/agents/simulator.md` §8) | `typing.autocorrect` |

**Rule.** A PR that changes a behavior or a screen in the iPhone list (its code, not only this table) carries the `needs-physical-test` label and goes through the `batch-device-test` skill (proposed in Pivii/skills#20, not merged yet): one local branch merges every PR waiting for a device test, without pushing; one build goes on the iPhone; Pierre fills one checklist, `#<num> OK` / `#<num> KO`; then each PR that passed is merged on its own, PR by PR. Until that skill exists, run the same steps by hand; the iPhone verdict goes on the PR's manual test list either way. The simulator run of this skill still happens first, for the first list. A green simulator run never stands in for a line of the second.

## Keeping the map current

**MANDATORY.** A PR that adds or changes a screen or a user feature updates the map in the same PR:

- `features/<id>.md` for the feature (new file, or its Sub-features, recipe and Gotchas), and its rows in [features/README.md](features/README.md), including the All IDs table and its count;
- [features/screens.md](features/screens.md) for the screen, with its capture in `docs/agents/screens/<screen-id>.png` (`evidence.sh`, then `sips -Z 874`), or « non » with the reason in the feature's Gotchas;
- a line in the [Physical test shortlist](#physical-test-shortlist) when the change moves something between the two lists.

IDs are stable: never rename one, and a removed feature keeps its ID retired. The tool for this upkeep is pstack's `/maintain-verification-skill`, which audits every feature from source and drives each one live, then ships at most one PR of proven corrections. It is user-invoked (`disable-model-invocation`): an agent writes the map changes itself and leaves that pass to a person.

## Helpers

All executable, all run from the repository root, all read the run from the argument, else `DICTUS_VERIFY_RUN`, else this session's pointer `~/dev/dictus-evidence/verify-skill/sessions/<session>` (never another session's).

| Script | Invocation | Ends with |
| --- | --- | --- |
| `scripts/launch.sh` | `launch.sh [--skip-onboarding] [--lang fr\|en]` | `READY udid=… run=… pid=… screen=…` |
| `scripts/doctor.sh` | `doctor.sh [run-dir]` | `DOCTOR OK` / `DOCTOR FAIL <n>` |
| `scripts/drive.sh` | `drive.sh <tap-id\|tap-label\|wait-id\|wait-label\|gone-id\|tab\|tree\|log-mark\|wait-log\|relaunch\|set-default\|full-access\|select-keyboard\|kbd\|type\|space> [args]` | one line per action; exit 1 with `error:` when an element never appears, and when `tap-id` or `tap-label` matches several elements (the candidates are listed: type, label, identifier, frame) or one that is off screen |
| `scripts/evidence.sh` | `evidence.sh <name> [run-dir]` | `evidence <name>: <path>.png` |
| `scripts/cleanup.sh` | `cleanup.sh [run-dir]` | `CLEANUP OK udid=… deleted=yes` |
| `scripts/lib.sh` | sourced, not run | `find_frame`, `find_matches`, `wait_for`, `stable_frame`, `tap`, `tap_unique`, `tap_until`, `wait_log` |

Overrides: `DICTUS_VERIFY_RUN` (run directory), `DICTUS_VERIFY_SESSION` (session name), `DICTUS_VERIFY_EVIDENCE` (evidence root), `DICTUS_VERIFY_DEVICE_TYPE`, `DICTUS_VERIFY_RUNTIME`.
