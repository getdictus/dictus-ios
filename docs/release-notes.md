# Release notes

One file per version and language, used in three places (#974):

- **The app's sheet.** After an update, the first launch that can show it opens a sheet at half
  height over the tabs (drag it up for the full height) with the version's **highlights**: at
  most three, a bold title and one line each.
- **Settings › About › What's new.** Every change of the running version.
- **App Store Connect.** The App Store version's « What's New », from **every change**, in the
  five store locales.

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

Blocks separated by a blank line: the title (naming the version), then two sections opened by
`## Highlights` and `## All changes`, written in English in every language. Each block in a
section is one change, on two lines: a short title, then one sentence.

```
What's new in 2.0.2

## Highlights

Write to us from the app
Settings > About > Send feedback.

Addresses and links kept as typed
The keyboard no longer corrects e-mail addresses or links.

## All changes

Write to us from the app
Settings > About > Send feedback, with the debug log if you want.

Addresses stay as you type them
The Dictus keyboard no longer autocorrects e-mail addresses or web addresses.
```

- **Highlights**: 1 to 3, what a user would want to know first. Titles of a few words, one
  line of text, short enough for the half-height sheet on an iPhone SE.
- **All changes**: every change users can see, highlights included, in the store's words. One
  or two lines each. No colon in the sentence: the store line already puts one after the title.
- The same number of highlights and of changes in the four languages.
- French says *vous*, German *du*, Spanish *tú*. No em dashes.

`ReleaseNotesTests` (DictusCore) fails if a version folder is missing a language, a block or a
heading is malformed, there are no or more than three highlights or no change, the languages
disagree on those counts, the title does not name the version, or a file passes 4,000
characters.

## Who writes them

At each version bump, before the file is written:

1. An agent drafts the full list from what users can see in the version (not from PR titles),
   in plain words, and proposes up to three highlights from it.
2. **Pierre validates the highlights** (which ones, and their wording) and the full list.
3. Only then is `ReleaseNotes/<version>/` written, in the version bump PR.

A version without a folder shows nothing in the app: its launch records it as seen, and the
Settings row is hidden.

## What App Store Connect gets

`scripts/release-notes.sh` turns `## All changes` into the store's plain text: the title line,
then one line per change, `• <title> : <sentence>` in French and `• <title>: <sentence>`
elsewhere. The highlights stay in the app.

```
What's new in 2.0.2
• Write to us from the app: Settings > About > Send feedback, with the debug log if you want.
• Addresses stay as you type them: The Dictus keyboard no longer autocorrects e-mail addresses or web addresses.
```

```sh
scripts/release-notes.sh 2.0.2            # print what would be sent; sends nothing
scripts/release-notes.sh 2.0.2 --apply    # set What's New on the 2.0.2 App Store version
```

`--apply` runs `asc localizations update --version <version> --platform IOS --locale <locale>
--whats-new <text>` for fr-FR, en-US, en-GB, de-DE and es-ES. The App Store version must
already exist in App Store Connect. `scripts/promote-to-appstore.sh` prints these two commands
in its checklist; no CI workflow runs them.

## Who sees the sheet

`WhatsNew` in DictusCore, tested in `WhatsNewTests`:

- Once per version: the key `dictus.lastVersionSeen` is written when the sheet is on screen.
- Never on a new install: a launch before onboarding is complete records the running version.
- Not while something else owns the screen (a dictation, a preparation, a paywall, a URL that
  opened the app); it waits for the next activation.
- 2.0.0's What's new, which replayed the onboarding scenes, is gone.
