# Simulator smoke test

One command that proves, headlessly on the maintainer's Mac, that DictusApp and the Dictus keyboard still start and talk to each other after a change (#535).

```bash
scripts/simulator-smoke-test.sh
```

It takes about two minutes, prints one line per step, and ends with exactly one of:

```
SMOKE PASS commit=<sha> device=<udid> runtime=iOS-26-5 iPhone-17
SMOKE FAIL step <n> <name>: <what was expected and did not happen>
```

The exit code matches: 0 on a pass, non-zero on any failed step or assertion. `SMOKE PASS` is printed only after the cleanup (step 11) has succeeded, so a run that could not uninstall Dictus or shut the device down ends in `SMOKE FAIL step 11 cleanup`.

## When to run it

- During the verification phase of `/ship-issue`, for any change that touches DictusApp, DictusKeyboard, onboarding, the App Group hand-off between them, or the critical navigation path. Paste the `SMOKE PASS` line and the artifact path into the PR.
- Before a TestFlight cut (`testflight-build`).

It is not a GitHub check, and it does not run in CI. Making it one is deliberately deferred until it has proved stable on this Mac over a longer stretch than the five runs that accepted it. That move also needs work this version does not do. CI runs Xcode 26.4.1, and the script's Simulator.app attach path for Xcode 26 has not been run. The iOS runtime default and the French system labels it taps are hard-coded and would have to become parameters.

## What it does

The steps follow `simulator.md`, which remains the authority on what the simulator can do.

1. **Device.** The script uses its own device, `Dictus Smoke` (iPhone 17, iOS 26.5). It creates the device the first time and reuses it afterwards. **Every run erases it.** That erase is the clean baseline: no Full Access, App Group state or half-finished onboarding left by a previous run can stand in for this one's result. It then writes the device language (`fr-FR`) and the keyboard list while the device is shut down, boots it, and waits for `bootstatus`. Because of that erase, `DICTUS_SMOKE_DEVICE_NAME` must start with `Dictus Smoke`. Any other name is refused before anything runs, so the variable cannot reach a simulator someone else uses.
2. **Build.** It resolves the packages and builds `DictusApp` into `build/DerivedData`, without CI's signing flags (an unsigned build has no App Group container on the simulator). There is no FluidAudio patch step: 0.15.7 builds as is since #558. Cleanup restores `Localizable.xcstrings`, which the build rewrites, whether the run passed or failed. It does this only if the catalog was clean before the build, so an uncommitted edit is never thrown away.
3. **Install and launch.** It checks that `pluginkit` lists `com.pivi.dictus.keyboard`.
4. **Liveness.** It waits for the onboarding intro to appear, then checks that the launched pid is still alive and that `<APP> appLaunched` is in the log. `simctl launch` alone exits 0 for an app that crashes a second later.
5. **Navigation.** On the onboarding screens it goes intro → language step → Back → intro, using the `onboarding.primary` and `onboarding.back` identifiers. It never taps the language step's Continue button, because that button starts a model download.
6. **Full Access.** It goes Settings → Général → Clavier → Claviers → Dictus. Each tap must reach the screen it leads to; when it does not, the script goes back and retries. On a heavily loaded Mac, Settings' root moved a row under the tap and sent it to Siri in two runs of five. Then it taps the switch with a physical tap, then taps Autoriser. Each tap is checked against the screen it should produce, and the sequence is retried up to three times.
7. **Keyboard.** It first terminates DictusApp and checks that it is gone: launchd no longer lists it and the launch pid has exited. If the app is still alive after 10 seconds, the run fails. The mic tap then always takes the cold-start path (see below). Granting Full Access in step 6 already kills the app (`domain:tcc(11)` in SpringBoard's log, measured 2026-10-15), but the test does not rely on that. It then marks onboarding finished in the App Group plist (`dictus.hasCompletedOnboarding`, written from inside the device while the app is not running): since #827 a mic tap before onboarding only opens Dictus on onboarding and starts no dictation, so the chain below is the one an onboarded user gets. It then focuses Safari's address field and dismisses the two first-run "Continuer" splashes. It long-presses the globe and picks `Dictus, multilingue`, then asserts that the keyboard logged `fullAccess=true`.
8. **Mic.** It taps the Dictus mic with no model installed. The mic is not in the accessibility tree, so the tap is placed from the frame of the keyboard's `inputView`, and the log assertions below are what prove it landed.
9. **Assertions**, in the App Group log (`dictus_debug.log`). Each search starts after the line the previous one matched, and the report records the line numbers:
   - `<KBD> keyboardMicTapped`, after the tap: the keyboard took the tap.
   - `<APP> appLaunched`, after the tap: a new DictusApp process started. Only a process launched by this hand-off can write this line.
   - `<APP> coldStartURLReceived isColdStart=true`, after the launch: the keyboard's URL reached that new process. The marker alone does not prove a cold start. The app logs it for every keyboard URL, and `isColdStart=true` means "this process has never been active", which a backgrounded process launched earlier and still alive also satisfies. Measured 2026-10-15 with the terminate removed: same pid, no new `appLaunched`, `isColdStart=true`.
   - `<APP> dictationFailed error=No model downloaded`, after the cold start: the app answered with the expected failure.
   - `<KBD> statusChanged from=requested to=failed`, also after the cold start but **not** required after the app's failure line. Each process appends to the log from its own asynchronous queue, so across processes the file order is the order of the writes, not of the events. This line landed before `dictationFailed` in 7 of the 9 runs measured on 2026-10-15. The causal link is proven by the line itself: the keyboard leaves `requested` for `failed` only by adopting the status the app wrote to the App Group (its watchdog resets to idle).

   It also checks that DictusApp is still running and that SpringBoard logged no crash signal for any Dictus process. SIGKILL is excluded, because the system kills the widget extension that way after every render.
10. **Evidence.** It saves screenshots and the filtered log outside the repository, and checks that the frontmost Mac app is not Simulator or DeviceHub. Reading the frontmost app needs Automation permission for System Events. Without it, the report says `foreground check NOT performed (no Automation permission for System Events)` instead of naming an app, and the run does not fail on that.
11. **Cleanup.** In the exit trap, on a pass or a failure, it restores the catalogs, uninstalls Dictus and shuts the device down. The device itself is kept for the next run. On a run that has passed so far, a failure here fails the run. Only after cleanup does it print `SMOKE PASS`.

The app is terminated before the mic tap for a reason. Otherwise the run would depend on whether iOS kept a backgrounded DictusApp alive. With the app gone, the keyboard's Darwin post goes unanswered and the URL fallback cold-starts the app (`coldStartDarwinFallback`, then `coldStartURLReceived`), which is the hand-off a user gets whenever iOS has killed the app. The warm path, where the app answers the Darwin post, is not covered.

## Artifacts

Everything goes under `$DICTUS_SMOKE_OUT` (default `$TMPDIR/dictus-smoke`), in a run directory named `<date>-<time>-<sha>`. The script refuses an output path inside the repository.

| File | What it holds |
| --- | --- |
| `report.txt` | The run's output: commit, Xcode version, device, runtime, each step, the result line |
| `keyboard.png` | The Dictus keyboard in Safari, just before the mic tap |
| `final.png` | DictusApp after the hand-off |
| `nav-1-intro.png`, `nav-2-language.png` | The onboarding screens before each navigation tap |
| `full-access.png` | The Settings screen after the grant |
| `evidence.log` | The `fullAccess=true` line and the hand-off lines after the tap |
| `dictus_debug.full.log` | The whole App Group log, copied before the uninstall deletes it |
| `build.log`, `resolve.log` | xcodebuild output |
| `failure.png`, `failure-ui.json` | On a failure only: the screen and the accessibility tree at that moment |

## What a pass proves

- The app builds, installs, launches and stays alive.
- Basic navigation in onboarding is reachable.
- The keyboard extension registers and renders.
- Full Access and keyboard selection work in the simulator.
- The keyboard can start the app-side dictation chain, through the cold-start URL path.
- App Group and persistent-log evidence is available.
- The expected no-model failure reaches the keyboard instead of crashing or hanging.

## What it does not prove

A pass is not a device validation, and it says nothing about:

- transcription quality;
- real microphone capture (no recording ever starts);
- ANE or Core ML performance;
- physical-device memory pressure (`memMB` in a simulator is not device memory, and the RAM is the Mac's, see `simulator.md` section 1);
- dead zones or the real keyboard-height constraint;
- Siri, calls or audio routes;
- whether the UX feels understandable or natural;
- App Store readiness;
- the warm Darwin hand-off path (see above);
- English system UI. The device runs in French, and its labels are what the script taps.

Those remain physical-device and human-product gates. They stay on the PR's manual test list.

## When it fails

The result line names the step. `report.txt` shows how far the run got. `failure.png` and `failure-ui.json` show the screen it stopped on, and `dictus_debug.full.log` has the whole log.

The tap targets that most often need updating:

- The French labels of system UI: `Autoriser`, `Refuser`, `Continuer`, `Clavier suivant`, `Dictus, multilingue`.
- The Settings row identifiers: `com.apple.settings.general`, `Keyboard`, `KEYBOARDS`.
- Safari's `TabBarItemTitle`.
- The mic position: 45 pt in from the trailing edge of `inputView`, 28 pt down.

A new iOS runtime is the usual cause. Read the tree with `axe describe-ui` before concluding the product broke. Also read `simulator.md` section 5 on blaming the harness, in both directions.

To delete the device:

```bash
xcrun simctl delete "Dictus Smoke"
```

## Configuration

| Variable | Default |
| --- | --- |
| `DICTUS_SMOKE_OUT` | `$TMPDIR/dictus-smoke` |
| `DICTUS_SMOKE_DEVICE_NAME` | `Dictus Smoke` |
| `DICTUS_SMOKE_DEVICE_TYPE` | `com.apple.CoreSimulator.SimDeviceType.iPhone-17` |
| `DICTUS_SMOKE_RUNTIME` | `com.apple.CoreSimulator.SimRuntime.iOS-26-5` |

Measured on Xcode 27.0 (27A266a), iOS 26.5 runtime, axe 1.8.0. A pre-A14 device type would be refused at the mic by design (#635), so keep the default device type or a newer one.
