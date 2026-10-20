---
name: verify-dictus-ios
description: Verify the Dictus iOS app (DictusApp, the Dictus keyboard extension, its App Group hand-off) on a headless iOS Simulator created for the run — build, install, launch, check health, drive a mapped feature by accessibility identifier, capture evidence, delete the simulator. Use when a change to DictusApp or DictusKeyboard has to be seen working in the real app rather than in `swift test`, when a feature from features/README.md must be exercised, or when screens need re-capturing.
---

# Verify Dictus on the iOS Simulator

Five steps, always in this order: **Launch → Doctor → Drive → Evidence → Cleanup**. Each one is a script under `scripts/`, run from the repository root. The simulator is created by Launch for this run and deleted by Cleanup; evidence outlives both.

Read first: `docs/agents/simulator.md` is the authority on what a simulator can and cannot do here, and `features/README.md` maps every user feature to its recipe. A pass here is not a device validation (CLAUDE.md): what only a physical iPhone can show is listed in each feature's Gotchas.

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
| `voiceNoteReaderClose`, `voiceNoteReaderDelete`, `voiceNoteReaderEmpty`, `voiceNoteReaderOpen`, `voiceNoteReaderInsert` | Keyboard voice-note reader (inside the keyboard, so not in the host's tree) |

Labels that are stable and unique (French device): tabs `Accueil` / `Modèles` / `Réglages` (RadioButtons, no identifier); `Dictus Pro, Pro actif`; the Pro hub rows `Mode intelligent, …`, `Historique, …`, `Vocabulaire, …`, `Messages vocaux, …`; `Langues prises en charge`; `Sons`, `Diagnostic`, `Debug Logs`, `Licences`, `Exporter les logs`; navigation back is the identifier `BackButton`, a modal close `xmark` or the label `Fermer`.

**The Dictus keyboard is one opaque element**, `inputView`, in the host app's tree: none of its keys or buttons is listed. `drive.sh kbd <control>` presses them at measured offsets from that frame, and the App Group log is what proves the press landed.

```bash
D=.claude/skills/verify-dictus-ios/scripts/drive.sh
$D tap-id onboarding.primary          # by identifier
$D tap-label "Modèles"                # by label (tabs: $D tab Modèles)
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

## Helpers

All executable, all run from the repository root, all read the run from the argument, else `DICTUS_VERIFY_RUN`, else this session's pointer `~/dev/dictus-evidence/verify-skill/sessions/<session>` (never another session's).

| Script | Invocation | Ends with |
| --- | --- | --- |
| `scripts/launch.sh` | `launch.sh [--skip-onboarding] [--lang fr\|en]` | `READY udid=… run=… pid=… screen=…` |
| `scripts/doctor.sh` | `doctor.sh [run-dir]` | `DOCTOR OK` / `DOCTOR FAIL <n>` |
| `scripts/drive.sh` | `drive.sh <tap-id\|tap-label\|wait-id\|wait-label\|gone-id\|tab\|tree\|log-mark\|wait-log\|relaunch\|set-default\|full-access\|select-keyboard\|kbd\|type\|space> [args]` | one line per action; exit 1 with `error:` when an element never appears |
| `scripts/evidence.sh` | `evidence.sh <name> [run-dir]` | `evidence <name>: <path>.png` |
| `scripts/cleanup.sh` | `cleanup.sh [run-dir]` | `CLEANUP OK udid=… deleted=yes` |
| `scripts/lib.sh` | sourced, not run | `find_frame`, `wait_for`, `stable_frame`, `tap`, `tap_until`, `wait_log` |

Overrides: `DICTUS_VERIFY_RUN` (run directory), `DICTUS_VERIFY_SESSION` (session name), `DICTUS_VERIFY_EVIDENCE` (evidence root), `DICTUS_VERIFY_DEVICE_TYPE`, `DICTUS_VERIFY_RUNTIME`.
