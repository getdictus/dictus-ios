# Swipe typing

- **ID:** `typing.swipe`
- **Tier:** Gratuit (Free), Experiments page only: test builds (Debug, TestFlight)
- **Targets:** DictusKeyboard + DictusCore (+ one write in DictusApp)
- **Screens:** `kbd.keys`, `kbd.suggestions` (states, no screen of its own) — see [screens.md](screens.md)

## Sub-features

- `typing.swipe-gesture` (#948): slide from a letter through the letters of a word and lift: the word goes in (Hex's decoder, models `en.hextm`, `fr.hextm`, `es.hextm` and `de.hextm`, ported in DictusCore `SwipeDecoder`). A touch on a letter becomes a swipe once it is further than the next key from where it went down (1.2 key units, counted in key widths across and rows down, so the key below and the staggered row's diagonal neighbour stay slides); a tap, a slide to the next key and a hold for accents (still 0.5 s) behave as before. Delete right after a swipe deletes only the selection when there is one. No swipe starts on any other key (delete, space and its trackpad, shift, 123, emoji, globe), in a field with no suggestion bar (address, URL, password), off the letter pages, or outside English, French, Spanish and German. A stroke that comes back to its key within 1.6 pitches is a tap of that key.
- `typing.swipe-trail`: a light trail follows the finger (the last 0.45 s of the path, blue at 42% in light mode, white at 50% in dark), and fades on lift. Its own switch, « Show swipe trail ».
- `typing.swipe-readings`: while the finger moves, the bar shows what the path reads as so far (decoded off the main thread, at most every 70 ms). On lift the best reading goes in with one key-tap haptic (« Haptique » setting; none during the stroke, none for a swipe that read as nothing), after a space unless the text before ends in one or in opening punctuation, with a capital when shift is on or when that space starts a sentence (`Hi.` then a swipe gives ` There`), in capitals with caps lock. The next three readings wait in the bar, the likeliest in the centre slot; a tap puts one in the word's place and offers the word back. Space and punctuation never autocorrect a swiped word; a letter tapped right after one goes in after a space (`hello` then `w` gives `hello w`), punctuation goes against it (`hello,`). English reads Dictus's own contraction list beside the model (`won't`, `let's`, `I'll`…).
- `typing.swipe-spanish`: Spanish swipes on Dictus's QWERTY, which has no ñ key (ñ is held on n): the model (`es.hextm`, Hex's, unmodified) reads ñ on the n key and the accented vowels on their base keys, so the same path through a-n-o reads « año » (the commoner word) with « ano » among the others, and « mañana », « niño », « español », « también » swipe through their plain letters. One path, two common words (« esta »/« está », « el »/« él », « que »/« qué »): the other one waits in the bar.
- `typing.swipe-german` (#948): German swipes on QWERTZ (its default), and on QWERTY or AZERTY if chosen. The model (`de.hextm`) is Dictus's own: Google Books counts kept for the words of a CC0 list (`tools/typing-model/README.md`). ä ö ü are swiped through their own keys on QWERTZ and through a o u elsewhere; ß, which no layout has a key for (it is held on s), is swiped through s: s-t-r-a-s-e reads « Straße », and « groß », « weiß », « heißt » go in the same way. Nouns go in with their capital, mid-sentence too (« Haus », « Straße », « Zeit »), verbs and adjectives in lowercase (« gehen », « groß »), from `de.capitals`; a word that is both (« Leben »/« leben », « Frage »/« frage ») takes its capital only after an article or a determiner (« das Leben », « zu leben »). Long compounds swipe like any word (« Bundesverfassungsgericht »), as long as the model has them: a compound rarer than its 95,000 words reads as something else.
- `typing.swipe-take-back`: Delete right after a swiped word takes back the whole word and the space the swipe added.
- `typing.swipe-toggle`: « Swipe typing » switch in Réglages → Clavier → Expériences (`dictus.keyboard.swipeTyping`, off by default; Iris's #1051). The keyboard applies it only on a test build: the app writes where it was installed from (`dictus.appDistribution`: `debug`, `testFlight`, `appStore`) and an App Store build, or a keyboard that finds no value, ignores the switch. Learned words are not read by the decoder (ADR 0004: a swipe types its reading without a tap).

## How to get to it (user POV)

1. In a test build, Réglages → Clavier → Expériences → « Swipe typing » on.
2. Make the keyboard reappear, choose English, French, Spanish or German, and slide across the letters of a word.

## Driving it with axe + Argent

Measured 2026-11-24 (iPhone 17, iOS 27.2, build `84ec0742`), Debug, in a `<textarea>` served from the Mac: Safari's address bar and a slimmed device's Rappels are no use (see Gotchas). The page, in an empty folder of its own outside the repository:

```bash
SCRATCH="$(mktemp -d)"   # an empty folder of its own, outside the repository
mkdir -p "$SCRATCH/www" && cat > "$SCRATCH/www/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<textarea autofocus style="width:100%;height:160px;font:22px -apple-system"></textarea>
HTML
(cd "$SCRATCH/www" && python3 -I -m http.server 8765 --bind 127.0.0.1) &
xcrun simctl openurl <udid> http://127.0.0.1:8765/   # then tap into the textarea (150, 160)
```

```bash
D=.claude/skills/verify-dictus-ios/scripts/drive.sh
$D set-default dictus.keyboard.swipeTyping -bool YES     # the app relaunches and records "debug"
# Full Access by hand on iOS 27.2 (see Gotchas), then select-keyboard, then tap into the textarea.
# A straight swipe, one HID call, at a finger's pace (AZERTY "pour": p to r on the top row):
axe drag --start-x 347 --start-y 612 --end-x 141 --end-y 612 --duration 2.5 --steps 150 --udid <udid>
# A swipe through several keys: one `touch -x … -y … --down` per point, then `touch … --up`,
# in one `axe batch` (keycap centres as `drive.sh type` computes them: 39.5 pt pitch from
# 23.25 pt, rows +81.5 / +135.5 / +189.5 pt below inputView's top; QWERTY's middle row +19.75).
```

The proof is the field's text, the bar, and the keyboard's log: `swipeTypingConfigured on=true channel=debug reason=viewWillAppear:on` at each appearance, then `swipeEnded points=… decodeMs=… readings=8 outcome=word` per swipe (counts only, never the word). With the switch off the line reads `on=false … reason=…:off`, no `swipeEnded` is ever logged, and the same drag types the key under the finger on lift, as before. A Release build records `appStore` and logs `on=false channel=appStore reason=…:appStore` with the switch on.

Captures in `docs/agents/evidence/948/`: the trail and the live reading, three readings after `merci` and after `world`, a reading tapped, Delete taking the word back, the switch off, the Release build.

## Gotchas

- `axe batch` delivers each `touch` step about 0.4 s apart on a loaded Mac (measured 2026-11-24: 101 steps in 43 s), so a multi-key swipe is slow and its trail short; `axe drag` moves at the pace it is given but draws a straight line. A word starting on a key with accents (`a`, `e`, `u`…) can sit still past the 0.5 s hold before the second step and open the accent popup instead: that is the hold working, not a failed swipe.
- Full Access: Réglages → Général → Clavier stays blank on iOS 26.5 (slimmed or not), and on 27.2 `drive.sh full-access` does not reach it by identifier; tapping the rows by coordinate works on 27.2 (Général, Clavier, Claviers, Dictus, then the switch with `--tap-style physical` and « Autoriser »). Without Full Access the top bar shows « Accès complet requis » instead of the readings, but the swipe still types.
- `typing.swipe-toggle`: in a Release simulator build the app records `appStore` (no sandbox receipt), so swipe typing stays off. To time a Release decode, write `dictus.appDistribution` = `testFlight` into the group's plist with the app terminated (`simctl spawn <udid> defaults write <plist> …`); `drive.sh set-default` relaunches the app, which writes `appStore` back.
- The haptic on lift is iPhone-only: the simulator has no haptic engine.
- Decode time and memory are device figures (Physical test shortlist). On the simulator, Release, 2026-11-24: 0.6–4.9 ms per swipe on lift (median 1.6 ms over 14 swipes, en and fr); the keyboard's `KeyboardMemory` tick read 38–39 MB before and while swiping. Debug decodes 10–20 times slower (23–68 ms).
