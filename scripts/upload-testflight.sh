#!/bin/sh
# upload-testflight.sh — archive, sign and upload the current build to TestFlight.
#
# The step that used to be "Xcode → Product ▸ Archive → upload". This does it
# headless, so a cut can finish without a window opening.
#
# WHY it authenticates with the App Store Connect API key rather than the Xcode
# account (learned the hard way on 2026-09-07):
#
#   Xcode 26 stores its signed-in Apple Account somewhere `xcodebuild` does not
#   read. The CLI still resolves the legacy `IDEProvisioningTeams` preference,
#   finds a stale free-Personal-Team entry with no keychain token, and exits with
#
#       DVTDeveloperAccountManager: Failed to load credentials for <old-account>:
#         missing Xcode-Token
#       error: exportArchive No Accounts
#       error: exportArchive No signing certificate "iOS Distribution" found
#
#   …while Xcode's own Settings ▸ Apple Accounts shows the right account, signed
#   in and healthy. Nothing is broken; the two just read different stores. Adding
#   the account again does not help, because the CLI never looks there.
#
#   Passing the API key bypasses the account system entirely: xcodebuild talks to
#   App Store Connect directly, creates the distribution certificate and the App
#   Store profiles it needs, and signs. It also makes this reproducible on a
#   machine that has never opened Xcode.
#
# Prerequisites:
#   - `asc` installed and authenticated (`asc auth doctor` all green).
#   - Two environment variables naming the App Store Connect API key. Both are
#     shown in App Store Connect > Users and Access > Integrations >
#     App Store Connect API (Team Keys tab). They are the names `asc` itself
#     reads, so exporting them also serves as its fallback credentials.
#       ASC_KEY_ID     the key's Key ID (10 characters)
#       ASC_ISSUER_ID  the Issuer ID shown above the keys table (a UUID)
#     e.g. in ~/.zshrc:
#       export ASC_KEY_ID=<your-key-id>
#       export ASC_ISSUER_ID=<your-issuer-id>
#   - The API key's .p8 readable at ~/.asc/keys/AuthKey_<ASC_KEY_ID>.p8. It must
#     NOT live in ~/Downloads, ~/Desktop or ~/Documents: macOS TCC blocks a
#     terminal from reading those, and the failure looks like "Operation not
#     permitted" on a file `ls` can see perfectly well.
#
# Usage:
#   scripts/upload-testflight.sh          # after scripts/cut-testflight.sh
#   ASC_PROCESSING_TIMEOUT=60m scripts/upload-testflight.sh   # a longer processing wait
#
# See docs/VERSIONING.md for where this sits in the release flow.
set -eu

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT"
PB=/usr/libexec/PlistBuddy

ASC_APP_ID="6761262378"
# Key ID and Issuer ID come from the environment, never from this file. Checked
# before anything else runs, so a missing one costs nothing.
require_env() {
  if [ -z "$2" ]; then
    echo "error: $1 is not set." >&2
    echo "  Find it in App Store Connect > Users and Access > Integrations >" >&2
    echo "  App Store Connect API, then: export $1=$3" >&2
    exit 1
  fi
}
require_env ASC_KEY_ID "${ASC_KEY_ID:-}" "<your-key-id>"
require_env ASC_ISSUER_ID "${ASC_ISSUER_ID:-}" "<your-issuer-id>"
ASC_KEY_PATH="$HOME/.asc/keys/AuthKey_${ASC_KEY_ID}.p8"

VERSION=$($PB -c "Print :CFBundleShortVersionString" DictusApp/Info.plist)
BUILD=$($PB -c "Print :CFBundleVersion" DictusApp/Info.plist)
STEM="Dictus-${VERSION}-${BUILD}"
ARCHIVE=".asc/artifacts/${STEM}.xcarchive"
IPA=".asc/artifacts/${STEM}.ipa"
DERIVED="build/DerivedData"

# --- Safety gates -----------------------------------------------------------
if [ ! -r "$ASC_KEY_PATH" ]; then
  echo "error: cannot read $ASC_KEY_PATH" >&2
  echo "  The key is also in the system keychain (asc uses it from there), but" >&2
  echo "  xcodebuild needs a file. Copy it out of ~/Downloads with Finder —" >&2
  echo "  a terminal cannot, TCC blocks that folder." >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree is not clean. Aborting." >&2
  exit 1
fi
if ! git rev-parse -q --verify "refs/tags/build/$BUILD" >/dev/null; then
  echo "error: tag build/$BUILD does not exist. Run scripts/cut-testflight.sh first." >&2
  exit 1
fi

echo "→ version : $VERSION ($BUILD)"
echo "→ commit  : $(git rev-parse --short HEAD)"
echo "→ archive : $ARCHIVE"

# --- 1. Resolve packages -----------------------------------------------------
# No FluidAudio patch step any more: 0.15.7 compiles unpatched, and the
# Swift 5 patch script was deleted with that bump (#558).
xcodebuild -resolvePackageDependencies \
  -project Dictus.xcodeproj -scheme DictusApp -derivedDataPath "$DERIVED" >/dev/null

# --- 2. Archive -------------------------------------------------------------
mkdir -p .asc/artifacts
asc xcode archive \
  --project "Dictus.xcodeproj" \
  --scheme "DictusApp" \
  --configuration Release \
  --archive-path "$ARCHIVE" \
  --overwrite \
  --xcodebuild-flag=-destination \
  --xcodebuild-flag=generic/platform=iOS \
  --xcodebuild-flag=-derivedDataPath \
  --xcodebuild-flag="$DERIVED"

# --- 3. Export, signed for the App Store ------------------------------------
asc xcode export \
  --archive-path "$ARCHIVE" \
  --ipa-path "$IPA" \
  --xcodebuild-flag=-allowProvisioningUpdates \
  --xcodebuild-flag=-authenticationKeyPath \
  --xcodebuild-flag="$ASC_KEY_PATH" \
  --xcodebuild-flag=-authenticationKeyID \
  --xcodebuild-flag="$ASC_KEY_ID" \
  --xcodebuild-flag=-authenticationKeyIssuerID \
  --xcodebuild-flag="$ASC_ISSUER_ID"

# --- 4. Refuse to upload a development-signed IPA ---------------------------
# get-task-allow is the bit that separates a development build from a store one,
# and Apple rejects the upload rather than the archive. Cheaper to catch here.
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA" "Payload/DictusApp.app/embedded.mobileprovision" -d "$WORK"
security cms -D -i "$WORK/Payload/DictusApp.app/embedded.mobileprovision" > "$WORK/pp.plist"
if ! $PB -c "Print :Entitlements:get-task-allow" "$WORK/pp.plist" 2>/dev/null | grep -q false; then
  echo "error: $IPA is not signed for distribution (get-task-allow is not false)." >&2
  exit 1
fi

# --- 4b. Refuse to upload an IPA that names another commit -------------------
# The `Generate build info` phase writes `git rev-parse --short HEAD` into
# DictusBuildInfo.plist, in the app and in the keyboard. A tester's debug log reports
# that sha; if it is not this checkout's HEAD, every log points at the wrong code.
HEAD_SHORT=$(git rev-parse --short HEAD)
for BI in Payload/DictusApp.app/DictusBuildInfo.plist \
          Payload/DictusApp.app/PlugIns/DictusKeyboard.appex/DictusBuildInfo.plist; do
  if ! unzip -q -o "$IPA" "$BI" -d "$WORK" 2>/dev/null; then
    echo "error: $IPA has no $BI. Not uploading." >&2
    exit 1
  fi
  GOT=$($PB -c "Print :GitCommitSHA" "$WORK/$BI" 2>/dev/null || echo "unreadable")
  if [ "$GOT" != "$HEAD_SHORT" ]; then
    echo "error: $BI names commit $GOT, HEAD is $HEAD_SHORT. Not uploading." >&2
    exit 1
  fi
done
echo "→ build info: $HEAD_SHORT in the app and the keyboard"

# --- 5. Upload, then wait for processing ------------------------------------
# Two calls, not `asc builds upload --wait`. With --wait, the upload bounds its wait
# for the build by ASC_TIMEOUT, which is the limit of ONE request: the nightly exports
# 90s for its reads, and on 2026-11-26 the wait for build 46 died 90 s after
# "Upload committed" ("context deadline exceeded"), though the build then processed
# fine. So the upload runs without ASC_TIMEOUT (asc's own limits; each part is bounded
# by ASC_UPLOAD_TIMEOUT), and the processing wait has its own limit,
# ASC_PROCESSING_TIMEOUT (default 45m; processing takes 10 to 30 minutes).
#
# Exit status: 0 uploaded and processed; 75 uploaded, not processed yet (the build is
# in App Store Connect and finishes on its own: nothing is lost); 1 anything else.
env -u ASC_TIMEOUT asc builds upload --app "$ASC_APP_ID" --ipa "$IPA"

PROCESSING_TIMEOUT="${ASC_PROCESSING_TIMEOUT:-45m}"
echo "→ uploaded; waiting for processing (up to $PROCESSING_TIMEOUT)"
WAIT_RC=0
asc builds wait --app "$ASC_APP_ID" --build-number "$BUILD" --platform IOS --version "$VERSION" \
  --timeout "$PROCESSING_TIMEOUT" --poll-interval 30s --fail-on-invalid --report-pending \
  || WAIT_RC=$?
if [ "$WAIT_RC" -ne 0 ]; then
  # 7 is --report-pending's "still processing". Any other status may be a failed build
  # or a failed read: ask App Store Connect which.
  STATE=$(asc builds info --app "$ASC_APP_ID" --build-number "$BUILD" --platform IOS \
    --output json 2>/dev/null | jq -r '.data.attributes.processingState // empty' 2>/dev/null || true)
  case "$STATE" in
    FAILED|INVALID)
      echo "error: App Store Connect reports build $BUILD as $STATE." >&2
      exit 1 ;;
  esac
  echo ""
  echo "⏳ $VERSION ($BUILD) is uploaded; App Store Connect is still processing it (state: ${STATE:-unknown})."
  echo "   It finishes on its own. To wait again:"
  echo "   asc builds wait --app $ASC_APP_ID --build-number $BUILD --platform IOS"
  exit 75
fi

echo ""
echo "✅ $VERSION ($BUILD) uploaded and processed."
echo "   Next: What to Test —"
echo "   asc builds test-notes create --app $ASC_APP_ID --latest --locale en-GB --whats-new \"…\""
