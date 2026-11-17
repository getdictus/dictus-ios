# Release notes

One text per version and language, used in two places (#974):

- **In the app.** After an update, the first launch that can show it opens on the new
  version's notes, once. Settings › About › What's new reopens them at any time.
- **In App Store Connect.** The App Store version's « What's New », in the five store locales.

## Where they live

```
ReleaseNotes/
  2.0.2/
    fr.txt   → fr-FR
    en.txt   → en-US and en-GB
    de.txt   → de-DE
    es.txt   → es-ES
```

The folder is copied whole into the app bundle (a folder reference in the DictusApp target).
The app reads the running version's folder (`CFBundleShortVersionString`), in the app's
language; any other language reads `en.txt`.

## Format

Blocks separated by a blank line. The first block is the title, naming the version. Every
other block is one change, on three lines: an SF Symbol name, a short title, one sentence.

```
What's new in 2.0.2

envelope.fill
Write to us from the app
Settings > About > Send feedback, with the debug log attached if you want.

at
Addresses stay as you type them
The Dictus keyboard no longer autocorrects e-mail addresses or web addresses.
```

- 3 to 6 changes. The app shows each as its symbol on a blue tile, the title in bold and the
  sentence under it.
- The same symbols, in the same order, in the four languages. Pick them in Apple's SF Symbols
  app; the name must exist on iOS 17 (`ReleaseNotesSymbolTests` checks it on the simulator).
- Titles short enough for one line on an iPhone SE, sentences of one or two lines. No colon in
  the sentence: the store line already puts one after the title.
- French says *vous*, German *du*, Spanish *tú*. No em dashes.

`ReleaseNotesTests` (DictusCore) fails if a version folder is missing a language, a block is
malformed, a language has fewer than 3 or more than 6 changes or other symbols than French, the
title does not name the version, or a file passes 4,000 characters.

## What App Store Connect gets

`scripts/release-notes.sh` turns the file into the store's plain text: the title line, then one
line per change, `• <title> : <sentence>` in French and `• <title>: <sentence>` elsewhere. The
symbol lines stay in the app.

```
What's new in 2.0.2
• Write to us from the app: Settings > About > Send feedback, with the debug log attached if you want.
• Addresses stay as you type them: The Dictus keyboard no longer autocorrects e-mail addresses or web addresses.
```

## Who writes them

The version bump PR adds `ReleaseNotes/<version>/`. An agent writes the notes in plain words,
from what users can see in the version, not from PR titles; Pierre approves them in that PR.

A version without a folder shows nothing in the app: its launch records it as seen, and the
Settings row is hidden.

## Sending them to App Store Connect

```sh
scripts/release-notes.sh 2.0.2            # print what would be sent; sends nothing
scripts/release-notes.sh 2.0.2 --apply    # set What's New on the 2.0.2 App Store version
```

`--apply` runs `asc localizations update --version <version> --platform IOS --locale <locale>
--whats-new <text>` for fr-FR, en-US, en-GB, de-DE and es-ES. The App Store version must
already exist in App Store Connect. `scripts/promote-to-appstore.sh` prints these two commands
in its checklist; no CI workflow runs them.

## Who sees the screen

`WhatsNew` in DictusCore, tested in `WhatsNewTests`:

- Once per version: the key `dictus.lastVersionSeen` is written when the notes are on screen.
- Never on a new install: a launch before onboarding is complete records the running version.
- Not while something else owns the screen (a dictation, a preparation, a paywall, a URL that
  opened the app); it waits for the next activation.
- 2.0.0's What's new, which replayed the onboarding scenes, is gone.
