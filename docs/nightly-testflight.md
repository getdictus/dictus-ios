# Internal TestFlight build of develop: one a day, in the morning

`scripts/nightly-testflight.sh` builds `origin/develop` and uploads it to **internal**
TestFlight (`Team PIVI`, which has access to every build). It runs once a day, on this
Mac, through launchd:

| Slot | When | LaunchAgent template |
| --- | --- | --- |
| `matin` (default, the only slot) | 06:00, and 06:30 as a second attempt | `scripts/launchd/solutions.pivi.dictus.morning-testflight.plist` (`--slot matin`) |

**Pierre's rule, 2026-11-27: one internal TestFlight build per day, at 06:00, with a retry
at 06:30.** The earlier `soir` (22:00) and `midi` (12:00, 12:30) slots are gone, with their
templates.

The build is internal only: the script adds no group, submits nothing to beta review and
never touches the App Store. The slot sets the file names and the What to Test header, and
nothing else. The steps and what makes a run skip are listed in the script's header.

## Read the result

`<stem>` is `<date>-matin`. Before this slot, the daily log was `<date>.log` (the `soir`
slot, which ran without `--slot`); whatever read that file must now read
`<date>-matin.log`.

| What | Where |
| --- | --- |
| Summary: status, reason, build, sha, CI, App Store Connect state, PRs, What to Test | `~/dev/proofs/nightly/<stem>.md` |
| Full log, credentials redacted; its last line is `end: status=<status> reason=…` | `~/Library/Logs/dictus-nightly/<stem>.log` |
| A run that did not build, while the day's summary already says `built` or `uploaded` | `~/dev/proofs/nightly/<stem>.retry.md` |
| What launchd itself printed (before the script's log opens) | `~/Library/Logs/dictus-nightly/launchd-matin.log` |
| The latest IPA (only that one is kept) | `~/Library/Caches/dictus-nightly/ipa/` |

The status is one of:

- `built`: uploaded, processed, tagged `build/NN`, What to Test set.
- `uploaded`: uploaded and tagged, but App Store Connect was still processing it when the
  run stopped waiting (see "Upload and processing" below). Team PIVI gets it when Apple
  finishes. Nothing to redo.
- `skipped`: the reason says why; nothing was built.
- `failed`: the reason says where.

**The 06:30 attempt never hides the 06:00 one.** When 06:00 built, 06:30 finds the tag
`build/NN` on `develop`'s tip and skips. A skip or failure never overwrites a summary of
the same day that says `built` or `uploaded`: it goes to `<stem>.retry.md`, and the log
(appended, one file per day) holds both runs. When 06:00 is still uploading at 06:30,
06:30 finds the lock and writes `<stem>.md.concurrent`.

A dry run writes `<stem>.dry-run.log` and `<stem>.dry-run.md`, so it never overwrites a
real run.

## Try it without building

```sh
scripts/nightly-testflight.sh --dry-run
```

It runs the reads for real (git fetch, tags, the CI of `develop`'s tip, each merged PR's
body, App Store Connect's latest build) and prints the rest: the worktree, the build
number, the archive, the tag and the What to Test text. It writes only its own log and
summary. When a tag already points to the tip, it says so, still prints the What to Test
counted from the build before, and names the file a real run would write (`.retry.md`
when the day's summary says `built`).

To try it without touching the real directories (and without taking the real lock):

```sh
NIGHTLY_CACHE_DIR=/tmp/n/cache NIGHTLY_LOG_DIR=/tmp/n/logs NIGHTLY_PROOF_DIR=/tmp/n/proofs \
  scripts/nightly-testflight.sh --dry-run
```

## What to Test, from each PR

The notes list the PRs merged since the previous `build/NN` tag. Each PR may say what the
tester should read, in a block of its body (`.github/pull_request_template.md` has it):

```markdown
## TestFlight
fr: Glissez depuis la touche Supprimer pour effacer mot par mot.
en: Swipe from the Delete key to erase word by word.
test: yes
switch: none
```

- `fr`, `en`: one sentence for the tester, in plain words.
- `test`: `yes`, listed under « À tester » / "To test"; `no`, listed under « Sans test
  (interne) » / "No test (internal)": CI, docs, refactors, anything a tester cannot see.
- `switch`: the setting that turns the change on, or `none` when it is on for everyone.

The script reads it with `gh pr view N --json body`, read only, one call per PR under the
90-second read timeout. A PR without the block, a line left empty, or a `gh` error: the
PR's title stands in, under « À tester ». After one `gh` error the remaining PRs use their
titles, so a dead network costs one timeout. The result:

```text
Build du matin de develop (aaa7c06d)

À tester :
• Glissez depuis la touche Supprimer pour effacer mot par mot. (#1047)
• Saisie par glissement, en et fr. (#1052, réglage : Expériences > Saisie par glissement)

Sans test (interne) :
• CI: run build and tests in a single macOS job (#1045)
```

The English header is "Morning develop build (sha)". The build is internal, so the notes
keep the PR numbers. The public beta has its own text (last
section).

## Upload and processing

`scripts/upload-testflight.sh` uploads with `asc builds upload`, then waits with
`asc builds wait`, two calls. The processing wait has its own limit,
`ASC_PROCESSING_TIMEOUT` (45 minutes; processing takes 10 to 30). `ASC_TIMEOUT` (90
seconds) stays the limit of one read, and the upload runs without it.

Why: on 2026-11-26 the run used `asc builds upload --wait`, which bounds its wait for the
build by `ASC_TIMEOUT`. The upload of build 46 was committed, the wait died 90 seconds
later (`Error: builds upload: context deadline exceeded`), the run failed, and the cleanup
deleted the tag it had not pushed. Apple processed build 46 anyway.

Once the upload is committed the build exists in App Store Connect, so a processing wait
that runs out is not a failure. `upload-testflight.sh` exits 75 ("uploaded, processing")
and the nightly waits 45 minutes more. If Apple is still processing after that, the run
still checks the IPA, pushes the tag (the number is used and names this commit), sets What
to Test (App Store Connect takes notes once the build is visible, before it is valid), and
ends `uploaded`. Only a build App Store Connect reports `FAILED` or `INVALID` fails the
run.

## Install

Wait until the script is on `develop`. An agent runs the copy in the checkout it points
to, so that checkout must be on `develop` and pulled.

The morning agent replaces the evening one (`solutions.pivi.dictus.nightly-testflight`),
and the midday one (`solutions.pivi.dictus.midday-testflight`) if it is still installed.
Take them out first; `bootout` of an agent that is not loaded prints an error and changes
nothing:

```sh
launchctl bootout gui/$(id -u)/solutions.pivi.dictus.nightly-testflight
rm -f ~/Library/LaunchAgents/solutions.pivi.dictus.nightly-testflight.plist
launchctl bootout gui/$(id -u)/solutions.pivi.dictus.midday-testflight
rm -f ~/Library/LaunchAgents/solutions.pivi.dictus.midday-testflight.plist
```

Then the morning one:

```sh
REPO=$HOME/dev/dictus
PLIST=solutions.pivi.dictus.morning-testflight.plist
mkdir -p ~/Library/Logs/dictus-nightly
sed -e "s#__REPO__#$REPO#g" -e "s#__HOME__#$HOME#g" \
  "$REPO/scripts/launchd/$PLIST" > ~/Library/LaunchAgents/$PLIST
plutil -lint ~/Library/LaunchAgents/$PLIST
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$PLIST
launchctl print gui/$(id -u)/solutions.pivi.dictus.morning-testflight | sed -n '/calendar/,/}/p'
```

The last line should show two entries, 06:00 and 06:30. macOS shows a "Background Items
Added" notification the first time. That is expected.

Run one now, instead of waiting:

```sh
launchctl kickstart gui/$(id -u)/solutions.pivi.dictus.morning-testflight
```

### The no-build window: from 05:55 until the run ends

A run skips when an `xcodebuild` is running or an `asc` has been running for over a
minute. So from **05:55**, do not start an archive, a cut, an upload or a device build on
this Mac until the last line of `~/Library/Logs/dictus-nightly/<date>-matin.log` reads
`end: status=…`. The run needs about 10 minutes of build, then the upload and Apple's
processing (up to 45 minutes, plus 45 more in the worst case). A build started at 05:55
makes 06:00 skip. 06:30 then tries again, and if that skips too, there is no build that
day; the summary says why. After a 06:00 that built, the 06:30 attempt skips within
seconds and appends its own `end: status=skipped` line: wait for that one too.

## Uninstall

```sh
launchctl bootout gui/$(id -u)/solutions.pivi.dictus.morning-testflight
rm ~/Library/LaunchAgents/solutions.pivi.dictus.morning-testflight.plist
```

## What it needs

- `gh` signed in, `asc` signed in (`asc auth doctor`), and the API key file at
  `~/.asc/keys/AuthKey_<key id>.p8`, as for `scripts/upload-testflight.sh`. When
  `ASC_KEY_ID` and `ASC_ISSUER_ID` are not exported (launchd does not read `~/.zshrc`),
  the script takes them from asc's default profile, which keeps them in the login keychain.
- A logged-in session with the login keychain unlocked. launchd runs a `gui/` agent only
  while Pierre is logged in. If the Mac is asleep at the slot's time, the run starts when
  it wakes.
- Every call that could wait on a prompt (keychain, SSH, gh, asc, codesign) runs under a
  timeout. A prompt turns into a `TIMEOUT:` line and a `failed` summary, never a wait.
  Before archiving, the script signs a scratch file, so a keychain dialog fails in 30
  seconds, not halfway through an archive.

## When it skips

- another run holds the lock (06:30 while 06:00 is still running), an `xcodebuild` is running, or an
  `asc` has been running for over a minute (an upload or a processing wait);
- today already has a build, whatever `develop`'s tip is now: `<stem>.uploaded` exists (written the moment App Store Connect accepts an upload, before any later step can fail), or the day's summary says `built` or `uploaded`. A tag's date does not count (a fetch stamps it too). It writes `end: status=skipped reason=already built today (build NN)` and goes to `<stem>.retry.md`;
- a `build/NN` tag already points to `develop`'s tip;
- the CI run of that commit on `develop` does not have its two jobs green (`SwiftLint`,
  `iOS (build + DictusCore + App Tests)`, the names in `CI_JOBS`). It reads the run and
  never re-runs it;
- `develop`'s marketing version is the one on `main`: App Store Connect refuses new builds
  for a version that is already released.

## How the build number is set without a commit

`NN` = the highest of App Store Connect's latest build number and the highest `build/NN`
tag, plus one. The plists hold a literal number, so it cannot be passed as a build setting.
The script writes `NN` into the four plists of a throwaway detached worktree, checks that
the diff is those four lines and nothing else, and marks the four files `skip-worktree` in
that worktree's own index so `upload-testflight.sh` sees a clean tree. The worktree, and the
flag with it, is deleted at the end of the run. `DictusBuildInfo.plist` reads
`git rev-parse --short HEAD`, which a working-tree edit does not change: the script and
`upload-testflight.sh` both check that the app and the keyboard name `develop`'s tip.

## Public beta (manual, not automated)

The morning run never gives a build to the `Public Beta` group or submits it to beta
review. That stays a decision someone takes, by hand, on a build that is already
processed and was tried internally. Below: the commands, the tester text, and the same steps in App Store
Connect. Nothing here runs on its own.

**What to Test is one text per build and locale, seen by every group that has the build.**
Replacing the internal notes with the public text below also changes what Team PIVI reads
for that build. Do it on the build you give to the public, at the moment you give it.

### Commands

Replace `NN` with the build number (46 is the build these notes were written for:
`develop` at `aaa7c06d`, the public beta has 45).

```sh
APP=6761262378
NN=46

# 1. The build is processed (processingState VALID), and which groups have it (read only).
BUILD_ID=$(asc builds info --app "$APP" --build-number "$NN" --platform IOS --output json \
  | jq -r '.data.id')
asc builds info --build-id "$BUILD_ID" --output table
asc builds groups list --build-id "$BUILD_ID" --output table

# 2. The tester text (fr-public.txt and en-public.txt hold the text below).
asc builds test-notes update --app "$APP" --build-number "$NN" --platform IOS \
  --locale fr-FR --whats-new "$(cat fr-public.txt)"
asc builds test-notes update --app "$APP" --build-number "$NN" --platform IOS \
  --locale en-GB --whats-new "$(cat en-public.txt)"
# A locale the build does not have yet: `create` instead of `update`, same flags.

# 3. Preview, then give the build to Public Beta and submit it to beta review.
asc builds add-groups --app "$APP" --build-number "$NN" --platform IOS \
  --group "Public Beta" --dry-run
asc builds add-groups --app "$APP" --build-number "$NN" --platform IOS \
  --group "Public Beta" --submit --confirm

# 4. The review's state (read only).
asc builds beta-app-review-submission view --app "$APP" --build-number "$NN" --platform IOS
```

`add-groups` checks processing, expiry, encryption and beta-review state before it sends
anything, and stops when App Store Connect does not give it enough to prove the build is
ready. The first build of a marketing version (2.1.0 here) goes through Beta App Review,
usually within a day; Apple can let later builds of the same version through without it.

### What to Test for the public beta

Only what is on by default in that build, in user words, no PR numbers. For build 46,
these are left out: swipe typing (off by default, Experiments page), spatial autocorrect
(Debug builds only), and everything testers cannot see (CI, tests, scripts).

fr-FR:

```text
Nouveautés de cette bêta :
• Sans modèle Dictus téléchargé, vous pouvez dicter avec le modèle d'Apple (iOS 26).
• Glissez depuis la touche Supprimer pour effacer mot par mot.
• Appui long sur une lettre : tous les accents de votre langue (œ, æ…), dans l'ordre du clavier d'Apple.
• Un nom de marque mal tapé est corrigé vers la marque, avec sa casse (iphon devient iPhone, whatsap devient WhatsApp).
• Les réglages du clavier ont leur propre page dans Réglages.
• Quand une dictée échoue, le message reste affiché jusqu'à ce que vous agissiez.
• Emoji : ABC et la loupe répondent dès la première touche.
• L'historique ne perd plus de dictée quand l'app et le clavier écrivent en même temps.
• Sur iPad, l'app parle de votre iPad, plus de votre iPhone.
• Le clavier reconnaît mieux le mode paysage.

Un souci ? Réglages > À propos > Envoyer un retour.
```

en-GB:

```text
New in this beta:
• With no Dictus model downloaded, you can dictate with Apple's model (iOS 26).
• Swipe from the Delete key to erase word by word.
• Long-press a letter for every accent of your language (œ, æ…), in the order of Apple's keyboard.
• A mistyped brand name is corrected to the brand, with its capitals (iphon becomes iPhone, whatsap becomes WhatsApp).
• Keyboard settings have their own page in Settings.
• When a dictation fails, its message stays until you act.
• Emoji: ABC and the search button respond to the first tap.
• History no longer loses a dictation when the app and the keyboard write at the same time.
• On iPad, the app talks about your iPad, not your iPhone.
• The keyboard detects landscape more reliably.

Something wrong? Settings > About > Send feedback.
```

### The same in App Store Connect

1. App Store Connect > Apps > Dictus > TestFlight > iOS builds: open build `NN` and check
   its status reads "Ready to Submit" or "Testing", not "Processing".
2. Test Information (the build's page): paste the French text in French, the English text
   in English (U.K.). Save.
3. TestFlight > External Testing > `Public Beta` > Builds > "+": choose build `NN`.
4. Leave "Automatically notify testers" on, then "Submit for Review". Answer the export
   compliance question as for the earlier builds if it is asked.
5. The build shows "Waiting for Review", then "Approved"; testers get it then.
