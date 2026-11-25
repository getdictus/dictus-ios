# #1074: swipe typing in Spanish, simulator proof

PR: https://github.com/getdictus/dictus-ios/pull/1074, head `3d4050a4`.

**Build.** Debug, built by `verify-dictus-ios` `launch.sh` from the PR's working tree just before
it was committed (the app reports `aaa7c06d-dirty`). Every file of the commit was last changed
before the build started, so the app is `3d4050a4`'s content. Xcode 27.2.

**Simulator.** iPhone 17, iOS 26.5, slimmed (simslim), created for the run and deleted after it.
Driven with AXe v2.2.0 (the official release binary). Recorded with
`xcrun simctl io <udid> recordVideo --codec h264`.

**State.** `dictus.language = es` (the keyboard's Spanish QWERTY, « espacio », no ñ key),
`dictus.keyboard.swipeTyping = YES` (Experiments), Dictus selected in Safari on a local page with
a `<textarea>`. Full Access off: Réglages → Général → Clavier stays blank on iOS 26.5 (a known
gotcha, `typing.swipe.md`), so the bar shows « Accès complet requis » instead of the other
readings. The swipe types without it.

| File | What it shows |
|---|---|
| `swipe-es.mp4` | 9.5 s, H.264. The two swipes, sped up 5.7× (seconds 3 to 48.5 of the full video in 8 s), then 1.5 s at normal speed on the result. A swipe through h-o-l-a types « Hola » (capital from the empty field), then a swipe through m-a-n-a-n-a, the n key standing for ñ, types « mañana »: the field reads **« Hola mañana »**. The trail follows the finger. |
| `swipe-es-full.mp4` | The same recording, uncut: 51 s, H.264, 1206 × 2622. AXe sends a multi-key swipe one touch at a time (about 0.4 s per point), so the strokes are slow. |
| `keyboard-log.txt` | The keyboard's swipe lines: `swipeTypingConfigured on=true` at each appearance, then one `swipeEnded … outcome=word` per swipe (counts only, never the word). Decode times are a Debug build's on the simulator. |

A simulator run is not a device validation: a real thumb's paths, decode time and memory while
swiping are for the iPhone.
