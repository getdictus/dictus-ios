# Typing journal: proof (#1001)

Measured on 2026-11-20 at `24253b5e`, iPhone 17 simulator, iOS 26.5, Xcode 27.2, on this
Mac. Simulator timings compare runs with each other, never with a device.

## The journal changes nothing the keyboard types

The #954 replay (1607 taps, 20 French and 20 English sentences), three ways:

| Build | Command | `commits.tsv` sha256 | `texts.tsv` sha256 |
|---|---|---|---|
| Release settings, no journal | `run.sh --udid <udid>` | `11ef46a5…f7bc93` | `45e3dbfb…5afea` |
| DEBUG, toggle off | `run.sh --udid <udid> --debug` | `11ef46a5…f7bc93` | `45e3dbfb…5afea` |
| DEBUG, toggle on, journal recording | `run.sh --udid <udid> --journal` | `11ef46a5…f7bc93` | `45e3dbfb…5afea` |

Byte-identical (`cmp`), autocorrect outcomes included.

## What it costs a keystroke

The journal's tap call, timed where `GiellaKeyboardView` would make it (`journal_ns`, µs):

| lang | taps | toggle off p50 / p95 / max | toggle on p50 / p95 / max |
|---|---:|---|---|
| fr | 821 | 0.0 / 0.1 / 0.6 | 0.2 / 0.3 / 2.7 |
| en | 784 | 0.0 / 0.1 / 0.6 | 0.2 / 0.8 / 2.7 |

The engine work per letter, which with the toggle on also counts the bar's partial-word
lines the journal takes instead of writing (ms):

| lang | key | toggle off p50 / p95 | toggle on p50 / p95 |
|---|---|---|---|
| fr | letter | 0.11 / 0.51 | 0.11 / 0.50 |
| fr | space | 0.10 / 0.45 | 0.10 / 0.44 |
| en | letter | 0.95 / 1.81 | 0.95 / 1.79 |
| en | space | 0.05 / 0.69 | 0.06 / 0.69 |

The tap call is a lock, a `Date()` and an append to an array; the formatting and the
file write run on a utility queue, once per word or every 2 s. Its p95 is 0.3 to 0.8 µs,
about 0.001 ms, against the 0.1 ms the issue allows. The engine's per-letter p95 moves by
0.01 to 0.02 ms between the two runs, in the journal's favour, which is run-to-run noise:
with the toggle on, the bar's partial-word checks skip their file write.

## A journal replays

`journal.log` of the `--journal` run, through `journal_to_run.py`, then `run.sh`:

- 1604 of 1604 taps resolved to the same key (the original's 2 taps that reached no key are
  not recorded, and its one `return` tap ends a sentence).
- 306 of 307 committed words identical. The other is `irning` → `Irning`: after the return
  tap the converter starts a new sentence, as the device would, so its first word is
  capitalised.

## On the simulator, typed with the Dictus keyboard

In Reminders, typed key by key with `axe` through the Dictus keys: `je suis tres contnet`,
space after each word, two backspaces, `t`, space. `sim-session-journal.log` is the
journal of that session as exported. One block per word:

```
TJ TAP k=c dx=+0.0154 dy=+0.3148 dt=2411 kb=fr-azerty
...
TJ TAP k=space dx=+0.2342 dy=+0.2778 dt=2330 kb=fr-azerty
TJ WORD #4 typed="contnet" prev="très" final="content" outcome=autocorrected by=space branch=trie bar=undoAvailable["tres"] previews=12
TJ WHY #4 TRIE-CANDIDATES word="contnet" winner="content" ranked=["content"(cost=0.70 freq=40339 ctx=0), ...]
TJ WHY #4 AUTOCORRECT branch=trie orig="contnet" corr="content" prev="très"
TJ TAP k=backspace dx=+0.0231 dy=+0.3148 dt=1247 kb=fr-azerty
TJ TAP k=backspace dx=+0.0231 dy=+0.3148 dt=952 kb=fr-azerty
TJ REACT #4 deleted taps=2
TJ REACT #4 undo by=backspace
```

Converted and replayed, it types `Je suis très content`, what Reminders held.

Screens: `sim-01-toggle-on.png` (Settings, Developer), `sim-03`/`04`/`05` (Debug Logs:
the first words, a word with its candidates, the reactions), `sim-06` (the Debug Logs
menu with Clear typing journal), `sim-07` (after it). Clear took the file from 235 lines
to 49: 186 lines with typed text removed, all 53 `TJ` lines among them, and every
diagnostic line kept.

## Release builds hold none of it

```
$ xcodebuild build -project Dictus.xcodeproj -scheme DictusApp -configuration Release \
    -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO -derivedDataPath build/DerivedData-release
** BUILD SUCCEEDED **
$ scripts/check-journal-release.sh build/DerivedData-release/Build/Products/Release-iphoneos
DictusApp.app/DictusApp (1 file(s)): 0 journal symbols, 0 journal strings
DictusApp.app/PlugIns/DictusKeyboard.appex/DictusKeyboard (1 file(s)): 0 journal symbols, 0 journal strings
PASS: no journal in the Release build
$ scripts/check-journal-release.sh --debug build/DerivedData/Build/Products/Debug-iphonesimulator
DictusApp.app/DictusApp (2 file(s)): 1623 journal symbols, 7 journal strings
DictusApp.app/PlugIns/DictusKeyboard.appex/DictusKeyboard (2 file(s)): 1631 journal symbols, 6 journal strings
PASS: the Debug build carries the journal
```

The Release keyboard binary is not stripped of symbols (123 474 `nm` lines), so the zero
is a real absence: it holds no `AutocorrectDebugLog` symbol either.
