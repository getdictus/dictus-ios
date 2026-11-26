# Evidence for #1082 (issue #1081): Adaptive touch status line, Debug export, decoder

Simulator `feature/1081-adaptive-status` (iPhone 17, iOS 26.5, French UI, status bar 9:41, slimmed
with simslim), Xcode 27.2, AXe 2.2.0 official release binary. Deleted after the run. No device.

## Builds

| Sha | Config | What it proved |
|---|---|---|
| `ad860659` | Debug | first status lines, the keyboard learning, the on→off race below |
| `91e00dca` | Debug | the race fixed: on and off lines agree |
| `481f8801` | Debug | export with named keys, share sheet, save to Files, missing-file message |
| `8de16dd9` | Debug + Release | Release compiles (fix of #1018 included); button absent from Release |

## 1. The keyboard learns, and says so at each appearance

The real Dictus keyboard in Reminders' title (`1-dictus-keyboard-reminders.png`), switches set by
`-DictusDebugSpatialAutocorrect YES -DictusDebugAdaptiveTouch YES`. One French sentence per keyboard
session, typed with AXe at +4 pt x, +10 pt y from each key centre (a constant bias to learn).
Full log lines: `keyboard-log-adaptive-touch.txt` (no typed text in it; each appearance logs twice,
`newView` then `viewWillAppear`, like `adaptiveTouchConfigured`).

```
14:49:18Z adaptiveTouchStatus on=true labelled=0 sessions=0 profile=no active=no promotions=0 maxShift=0
14:51:36Z adaptiveTouchStatus on=true labelled=86 sessions=1 profile=no active=no promotions=0 maxShift=0
14:53:39Z adaptiveTouchStatus on=true labelled=172 sessions=2 profile=yes active=no promotions=3 maxShift=0.187@a
14:55:41Z adaptiveTouchStatus on=true labelled=258 sessions=3 profile=yes active=no promotions=7 maxShift=0.235@a
14:57:44Z adaptiveTouchStatus on=true labelled=344 sessions=4 profile=yes active=no promotions=10 maxShift=0.238@a
14:59:47Z adaptiveTouchStatus on=true labelled=430 sessions=5 profile=yes active=yes promotions=14 maxShift=0.240@a
```

`active=yes` once past 400 labelled taps and 3 sessions, as the gate says.

## 2. Switch on, then off (build `91e00dca`)

```
15:08:03Z adaptiveTouchConfigured on=true trigger=newView
15:08:03Z adaptiveTouchStatus on=true labelled=688 sessions=8 profile=yes active=yes promotions=24 maxShift=0.242@slot0
          (one more session typed, then the app relaunched with -DictusDebugAdaptiveTouch NO)
15:09:14Z adaptiveTouchConfigured on=false trigger=newView
15:09:14Z adaptiveTouchStatus on=false stored=yes labelled=731 sessions=9 profile=yes active=yes promotions=26 maxShift=0.242@slot0
```

`@slot0`: a fresh keyboard process has not typed on the page yet, so it does not know the letters
(the file holds none); it names the key once it has (`@a` above).

**Race found and fixed:** on build `ad860659` the first off line read the file before the dropped
learner's save had landed (`15:06:13Z … stored=yes labelled=400 … active=no` then
`labelled=688 … active=yes` on the next line). `91e00dca` waits for queued writes; its unit test fails
without the fix with the same 400-vs-latest symptom.

## 3. Debug export (build `481f8801`)

- `2-debug-export-button.png`: Réglages → Developer → « Exporter le toucher adaptatif ».
- `3-share-sheet.png`: « Format texte et 1 document, 25 ko » (the `.bin` and the `.txt`).
- `4-save-to-files.png`: saved to Fichiers › Sur mon iPhone; copied out of the simulator's File
  Provider Storage: `adaptive-touch-20261126-161333.bin` (identical, `cmp`, to the App Group's
  `AdaptiveTouch/adaptive-touch.bin`) and `adaptive-touch-20261126-161333.txt` (the app's report).
- `5-missing-file-message.png`: after `-DictusDebugAdaptiveTouchReset YES`, the button says
  « Aucun fichier AdaptiveTouch/adaptive-touch.bin : le clavier n'a encore rien appris … ».

## 4. Decoded on the Mac

`swift run --package-path DictusCore -c release adaptive-touch-status adaptive-touch-20261126-161333.bin`
→ `decoded-with-adaptive-touch-status.txt`:

```
geometry 4db779dcaad11650: azerty letter page, key pitch 43.0 x 56.5 pt

adaptiveTouchStatus labelled=731 sessions=9 profile=yes active=yes promotions=26 maxShift=0.242@a
context 0: … learning=yes inUse=yes snapshot=yes eligible=yes keys=named
  labelled=731 (weak=731 picked=0 strong=0) sessions=9 promotions=26 …
  0  a  102.0  +0.124  +0.207
  2  e   70.0  +0.088  +0.207
  …
```

Every key moved about +0.10 keycap right and +0.17–0.21 down: the bias typed. The app's `.txt` carries
the same lines.

## 5. Absent from Release (build `8de16dd9`, both configs)

`release-absence.txt` (`strings -a` over every executable and dylib of the `.app`, `nm -a` for symbols):

| | Debug | Release |
|---|---|---|
| `Exporter le toucher adaptatif` | 1 | 0 |
| `settings.debug.exportAdaptiveTouch` | 2 | 0 |
| `adaptive-touch-export` (export folder) | 1 | 0 |
| `AdaptiveTouchExportSection` (strings / symbols) | 5 / 434 | 0 / 0 |
| `adaptiveTouchStatus` (the log line, wanted in both) | 12 | 12 |

`6-release-settings-no-developer-section.png`: the Release app's Réglages go from Clavier straight to
À propos.

Before `8de16dd9`, Release did not compile (`cannot find 'TypingJournalFieldGate' in scope`, from
#1018: the field gate Adaptive touch calls in every build was inside `#if DEBUG`).
