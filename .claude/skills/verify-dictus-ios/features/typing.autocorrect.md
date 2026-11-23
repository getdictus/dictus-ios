# Autocorrect and suggestions

- **ID:** `typing.autocorrect`
- **Tier:** Gratuit (Free)
- **Targets:** DictusKeyboard + DictusCore
- **Screens:** `kbd.keys`, `kbd.suggestions` (not captured) — see [screens.md](screens.md)

## Sub-features

- `typing.suggestions`: Suggestion bar with predictions and corrections.
- `typing.autocorrect-on-space`: A mistyped word is corrected when space is pressed. In French, after an elision (`d'` `l'` `j'` `m'` `n'` `t'` `s'` `c'` `qu'` `jusqu'` `lorsqu'` `puisqu'`) the correction never starts with a consonant other than h: `d'cirre` is kept rather than written `d'votre`, `l'homne` still gives `l'homme` (#1034).
- `typing.autocorrect-on-punctuation`: A mistyped word is also corrected by `, . ; : ! ?` and Return, never by `'` or `-` (#872). Never inside an e-mail address or a URL, whatever the field (#919): a token holding `@` or `://`, starting with `www.`, or with a `.` `:` `/` `_` glued to a letter, a digit or `/ _ @ + -` is left alone. The first segment, corrected at its `.` or `:`, is put back by the next key glued to the mark (`helene.` → `gelée.`, then `b` → `helene.b`).
- `typing.autocorrect-on-space`, French `a` or `à` (#501): a typed `a` becomes `à` when the words before prove a verb precedes it (`je vais a` → `je vais à`, `est arrivé a`, `du mal a`), and stays `a` after a subject, an object pronoun, a noun or inside a relative clause (`il a`, `il y a`, `le train a`, `ce que tu as fait a`). The first word of a sentence becomes `à`, capital kept (`A demain` → `À demain`, #979), but not a clause start after a comma. The suggestion bar previews `à` before space. French only.
- `typing.undo-correction`: The suggestion bar offers to undo the last correction.
- `typing.refused-correction`: Erasing into a correction, Undo, or tapping the quoted typed word refuses it: the word committed at that place next is kept and learned (#872). A text replacement shortcut is the exception: typed again at that place, it expands again (#1022).
- `typing.auto-full-stop`: Double space inserts a full stop.
- `typing.accents`: Long-press a letter for its accents.
- `typing.dead-keys`: Dead keys compose accented letters.
- `typing.autocorrect-toggle`: « Correction automatique » switch in Réglages → Clavier.
- `typing.spatial-autocorrect`: Debug builds only, off by default (#1011). With the App Group switch `debug.spatialAutocorrect` on, the space bar reads where the finger landed on each key of the word (Hex's noisy-channel decoder, models `fr.hextm` and `en.hextm`) before the trie reads its letters: `trouce` with the `c` tapped on the edge of `v` becomes `trouve`, `jusge` becomes `juste`, a missed space splits (`donnequoi` → `donne quoi`). It runs after the lexicon, the overrides and the contractions, never on a learned word, and leaves the word to the trie when it keeps it. The Debug log prints `AUTOCORRECT branch=spatial`. No row in Réglages yet (#992 owns SettingsView).
- `typing.adaptive-touch`: Debug builds only, off by default, and only with `typing.spatial-autocorrect` on (#1014). With the App Group switch `debug.adaptiveTouch` on, the keyboard learns where this user lands on each letter key (Hex's Adaptive touch) from words that stood as typed, an undone correction, a same-length suggestion picked, a letter erased and retyped as a neighbour; never from a correction left in place, a slide, a popup accent, or a field where autocorrect does not run or that holds a secret. After 400 labelled taps over 3 sessions, while the profile fits recent taps better than the stock centres, the decoder reads the taps with those centres; a correction it puts in must still clear the stock centres' margin. The averages (no text) are a 23 KB file in the App Group (`AdaptiveTouch/adaptive-touch.bin`); « Reset learned words » (`learned-words.reset`) deletes it.
- `typing.contacts-and-replacements`: Contact names and iOS text replacements (#873). A contact name or a phrase-only replacement is never corrected, a lowercase contact name takes its casing (`zofiak` → `Zofiak`), a shortcut is replaced by its phrase with the undo chip (`qqc` → `Quelque chose` at sentence start). Since #1022 a shortcut expands like on Apple's keyboard: with « Correction automatique » off, in a field that turns autocorrection off (search, URL, e-mail, username), for a shortcut holding a digit (`adr1`), and after any number of refusals at the same place. It never expands in a secure or password field, nor at the end of an e-mail address or a URL (#919; Apple's behaviour there is unchecked). Contact casing and curated names stay autocorrections: off when autocorrect is off.
- `typing.cursor-trackpad` (#950): Hold the space bar 0.35 s without sliding: the keys go blank and the space bar is a trackpad. The cursor follows the finger through the text in two dimensions, line to line, at the text's own scale, faster the faster the finger (Hex's model, MIT). Lifting types no space. A quick tap that drifts stays a space. A second finger types nothing. No haptic of its own. No selection: a keyboard cannot make one.

## How to get to it (user POV)

1. Type with the Dictus keyboard in Notes or Messages.
2. Suggestions appear above the keys; a mistyped word is corrected when you press space.

## Driving it with axe + Argent

Measured 2026-10-20 (iPhone 17, iOS 26.5): a misspelling followed by space, typed through the Dictus keys in a Rappels field, is corrected.

```bash
D=.claude/skills/verify-dictus-ios/scripts/drive.sh
E=.claude/skills/verify-dictus-ios/scripts/evidence.sh
$D set-default dictus.autocorrectDebugLogging -bool YES   # Debug builds: logs each decision
$D full-access && $D select-keyboard                     # makes Dictus the current keyboard
xcrun simctl launch <udid> com.apple.reminders
$D tap-label Continuer                                   # first-run splash
$D tap-label "Plus tard"                                 # iCloud sync prompt
$D tap-label Rappel                                      # new reminder, title field focused
$D wait-id inputView 10
M=$($D log-mark)
$D type bonjoru                                          # the misspelling, key by key
$E typed-misspelling
$D space                                                 # autocorrect runs on space
$D wait-log 'APPLIED orig="Bonjoru" → "Bonjour"' 10 "$M"
$E after-space
argent run describe --udid <udid>                        # AXTextField "Titre" value="Bonjour "
```

The proof is two facts together: the field's value becomes `Bonjour ` and the log carries `APPLIED orig="Bonjoru" → "Bonjour"` after the mark. After the space the suggestion bar shows the undo chip `↶ Bonjoru` (`kbd.suggestions`); tapping it is `typing.undo-correction`. The first letter is capitalised by the host field, hence `Bonjoru`.

Measured 2026-10-30 (iPhone 17 Pro, iOS 27.0, build `fef07756`), keys tapped by coordinate in Messages: `la cuisinr,` → `La cuisine,` and `le bureai` + Return → `le bureau`, each followed by the undo chip; `la montagnr` → `montagne`, the word erased and retyped, logs `REFUSED corrected="montagne" by=backspace` then `AUTOCORRECT-SKIP word="montagnr" reason=refused-here`. The punctuation keys are on the `123` page.

Measured 2026-11-13 (iPhone 17, iOS 26.5, builds `fd92aaa0` and `bbaa7b36`, #919), in the Notes field of a Rappels item (tap under the title, « Ajouter une note »), every key tapped on the Dictus keys: `contact helene.bethmont@gmail.com site https://github.com/x et www.getdictus.com puis bonjoru. ` gives `Contact gelée.bethmont@émail.com site héros://github.com/x et wax.getdictus.com puis bonjour. ` before the fix and the text as typed, `bonjour.` aside, after it. The after log carries `ADDRESS-REVERT orig="helene" undone="gelée"`, `ADDRESS-REVERT orig="https" undone="héros"` and `AUTOCORRECT-SKIP word=… reason=address` for every later segment. `drive.sh type` has no punctuation; the keys were tapped at these points (iPhone 17, `inputView` at y = 548): letters rows y = 610 / 665 / 719 on the 40.2 pt pitch of `drive.sh`, `123` / `ABC` (25, 772), space (210, 772); on the `123` page `-` (20, 664), `/` (60, 664), `:` (100, 664), `@` (340, 664), `.` (104, 718), delete (371, 718). The keyboard stays on `123` after a mark, and goes back to letters by itself after `. ` and space.

Measured 2026-11-17 (iPhone 17, iOS 26.5, build `c9361321`, #501), same recipe: `je vais a elle a ` typed on the Dictus keys in a Rappels title reads `Je vais à elle a `, with `APPLIED orig="a" → "à" prev="vais"` then `AUTOCORRECT-SKIP word="a" reason=already-valid` in the log.

## Gotchas

- `typing.spatial-autocorrect`: turn it on by launching the Debug app with `-DictusDebugSpatialAutocorrect YES` (`xcrun simctl launch <udid> com.pivi.dictus -DictusDebugSpatialAutocorrect YES`, or `xcrun devicectl device process launch … com.pivi.dictus -DictusDebugSpatialAutocorrect YES` on the iPhone), or with `drive.sh set-default debug.spatialAutocorrect -bool YES`, then make the keyboard reappear. Measured 2026-11-21 (iPhone 17, iOS 26.5): the key reads `1` in the group's plist after the launch with `YES`, `0` after `NO`. `simctl spawn defaults write group.solutions.pivi.dictus …` does not reach it: that domain is not the group container's plist. `drive.sh type` taps the key centres, which tells the decoder nothing the letters do not: its measure is `tools/keyboard-bench/run.sh --spatial` (synthetic and device-journal taps) and, for real fingers, the iPhone (Physical test shortlist).
- `typing.cursor-trackpad`: a multi-line field is needed, and a slimmed device has no Notes. A `<textarea>` page served from the Mac works in Safari (`python3 -m http.server --bind 127.0.0.1`, then `simctl openurl <udid> http://127.0.0.1:<port>/`; `simctl openurl` refuses `data:` URLs). `axe drag --hold 0.7 --start-x 210 --start-y 772 --end-x <x> --end-y <y> --duration 1 --steps 90` holds the space bar, then slides. Measured 2026-11-22 (iPhone 17, iOS 26.5), with Apple's keyboard on the same gestures as the reference: `docs/study-captures/trackpad/` on the `study/trackpad` branch. Safari shares about 60 characters around the cursor, cut anywhere, so a line whose start it has not shown is laid out by guess until it does. The feel, the speed curve on a real finger and the haptics are iPhone-only.

- `typing.adaptive-touch`: `-DictusDebugAdaptiveTouch YES` on the Debug app's launch line turns it on (the decoder's switch must be on too), `-DictusDebugAdaptiveTouchReset YES` forgets the profile. `drive.sh type` taps the key centres, so the simulator never shows a bias to learn: its measure is `tools/keyboard-bench/run.sh --spatial --adaptive learn|frozen` with `--adaptive-load`/`--adaptive-save` (learn on one device session, score on another), and for a real thumb the iPhone.

- Safari's address bar turns suggestions off: typing there shows no suggestion bar. Test in Rappels. A slimmed iOS 26.5 device has no Notes app (`simctl launch com.apple.mobilenotes` fails), and on 2026-11-13 Messages opened a conversation without drawing its compose box.
- Reset the user dictionary first (`typing.learned-words`): a learned word silently changes what autocorrect does.
- `axe type` does not exercise autocorrect: it sends hardware keyboard events that reach the field without going through the extension. `drive.sh type` taps the Dictus keys instead (lowercase a–z, AZERTY letters page, offsets measured on iPhone 17).
- `typing.contacts-and-replacements`: create the contact in Contacts and the replacement in Réglages → Général → Clavier → Remplacement, then make the keyboard reappear: the lexicon is read in `viewWillAppear`. The Debug log prints `NOTE lexicon loaded: <n> shortcuts, <n> words`, then `AUTOCORRECT-SKIP ... reason=lexicon` or `AUTOCORRECT branch=lexicon`. Measured 2026-10-30 on iOS 27.0 (#873).
- `typing.contacts-and-replacements` with autocorrect off: write `dictus.autocorrectEnabled -bool NO` and `dictus.autocorrectDebugLogging -bool YES` into the App Group plist, type the shortcut and space. The log carries `AUTOCORRECT branch=text-replacement`, a line written only when autocorrect did not run. Measured 2026-11-21 (iPhone 17, iOS 26.5, #1022) in a Rappels title, without Full Access: `jrv` + space → `J’arrive ! `. `jrv` → « J’arrive ! » is iOS's own French replacement, present on a fresh device. On that runtime Réglages → Général → Clavier stayed blank, slimmed or not (Settings logs `PreferencesPluginError`), so no replacement could be added by hand that day.
- Host spell-check underlines are not a usable probe in the simulator (`docs/agents/simulator.md` §8).
- A refusal is remembered per place in the current document, in RAM, until the text before it is erased. Clearing a field by backspace forgets it; the field emptied by the host (a sent message) may not, if the host keeps the same `documentIdentifier`.
