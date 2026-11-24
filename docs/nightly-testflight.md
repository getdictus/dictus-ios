# Nightly TestFlight build of develop

`scripts/nightly-testflight.sh` builds `origin/develop` every night at 22:00 and uploads it
to **internal** TestFlight (`Team PIVI`, which has access to every build). It adds no group,
submits nothing to beta review and never touches the App Store. It runs on this Mac,
through launchd. The steps and what makes it skip are listed in the script's header.

## Read the result

| What | Where |
| --- | --- |
| Morning summary: status `built` / `skipped` / `failed`, reason, build, sha, CI, App Store Connect state, PRs | `~/dev/proofs/nightly/<date>.md` |
| Full log, credentials redacted | `~/Library/Logs/dictus-nightly/<date>.log` |
| What launchd itself printed (before the script's log opens) | `~/Library/Logs/dictus-nightly/launchd.log` |
| Tonight's IPA (only the latest is kept) | `~/Library/Caches/dictus-nightly/ipa/` |

A dry run writes `<date>.dry-run.log` and `<date>.dry-run.md` instead, so it never
overwrites a real night.

## Try it without building

```sh
scripts/nightly-testflight.sh --dry-run
```

It runs the reads for real (git fetch, tags, the CI of `develop`'s tip, App Store Connect's
latest build) and prints the rest: the worktree, the build number, the archive, the tag and
the What to Test text. It writes nothing anywhere.

## Install

Wait until the script is on `develop`. The agent runs the copy in the checkout it points
to, so that checkout must be on `develop` and pulled. The main clone is the obvious choice.

```sh
REPO=$HOME/dev/dictus
PLIST=solutions.pivi.dictus.nightly-testflight.plist
mkdir -p ~/Library/Logs/dictus-nightly
sed -e "s#__REPO__#$REPO#g" -e "s#__HOME__#$HOME#g" \
  "$REPO/scripts/launchd/$PLIST" > ~/Library/LaunchAgents/$PLIST
plutil -lint ~/Library/LaunchAgents/$PLIST
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$PLIST
launchctl print gui/$(id -u)/solutions.pivi.dictus.nightly-testflight | head -20
```

macOS shows a "Background Items Added" notification the first time. That is expected.

Run it once now, instead of waiting for 22:00:

```sh
launchctl kickstart gui/$(id -u)/solutions.pivi.dictus.nightly-testflight
```

## Uninstall

```sh
launchctl bootout gui/$(id -u)/solutions.pivi.dictus.nightly-testflight
rm ~/Library/LaunchAgents/solutions.pivi.dictus.nightly-testflight.plist
```

## What it needs

- `gh` signed in, `asc` signed in (`asc auth doctor`), and the API key file at
  `~/.asc/keys/AuthKey_<key id>.p8`, as for `scripts/upload-testflight.sh`. When
  `ASC_KEY_ID` and `ASC_ISSUER_ID` are not exported (launchd does not read `~/.zshrc`),
  the script takes them from asc's default profile, which keeps them in the login keychain.
- A logged-in session with the login keychain unlocked. launchd runs a `gui/` agent only
  while Pierre is logged in. If the Mac is asleep at 22:00, the run starts when it wakes.
- Every call that could wait on a prompt (keychain, SSH, gh, asc, codesign) runs under a
  timeout. A prompt turns into a `TIMEOUT:` line and a `failed` summary, never a wait.
  Before archiving, the script signs a scratch file, so a keychain dialog fails in 30
  seconds, not halfway through an archive.

## When it skips

- another nightly holds the lock, an `xcodebuild` is running, or an `asc` has been running
  for over a minute (an upload or a processing wait);
- a `build/NN` tag already points to `develop`'s tip;
- the CI run of that commit on `develop` does not have its four jobs green (`Build (iOS
  Simulator)`, `SwiftLint`, `DictusCore Tests`, `App Tests (iOS Simulator)`). It reads the
  run and never re-runs it;
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
