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

The store's text, as it is pasted into App Store Connect:

```
What's new in 2.0.2
• First change, in plain words.
• Second change.
• Third change.
```

- First line: the title, naming the version.
- Then 3 to 6 lines starting with `• `. The app shows one line per bullet.
- Under 4,000 characters (App Store Connect's limit).
- French says *vous*, German *du*, Spanish *tú*. No em dashes.

`ReleaseNotesTests` (DictusCore) fails if a version folder is missing a language, has fewer than
3 or more than 6 bullets, a title without the version, or more than 4,000 characters.

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
