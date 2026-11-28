#!/usr/bin/env bash
# Makes Apple's French autocorrect run on an iOS 26.5 simulator (measured 2026-11-19).
#
# Why it does not run out of the box: the runtime ships RequiredAssets_fr.bundle with an
# empty AssetData folder (English ships 50 files), and the keyboard daemon (kbd) asks
# MobileAsset for com.apple.MobileAsset.LinguisticData with AssetLocale=fr,
# _CompatibilityVersion=18, _SupportedPlatforms="iOS Simulator". Apple's live catalog
# (455 assets) holds a French "iOS Simulator" asset only at compatibility version 17,
# so the query returns nothing and French has no lexicon and no language model.
#
# What this does, on YOUR OWN simulator only:
#   1. relabels that compatibility-17 French simulator asset as 18 in the device's
#      local copy of the catalog;
#   2. downloads it from Apple's public CDN (144 MB) and installs it where mobileassetd
#      keeps installed assets, with its Info.plist relabelled the same way;
#   3. restarts mobileassetd and kbd.
# Caveat: the asset is the February 2026 build (content version 449), not whatever an
# iPhone on iOS 26.5 has downloaded. Treat results as Apple's French model of that
# build, and cross-check on a device.
#
# Prerequisites: the simulator is booted and NOT slimmed (simslim off <udid>), the
# French keyboard is in AppleKeyboards, and the keyboard has been shown once so kbd
# has fetched the catalog (com_apple_MobileAsset_LinguisticData.xml exists).
#
# Usage: install-apple-french-sim.sh <udid> <scratch dir>
set -euo pipefail
UDID="$1"; SCRATCH="$2"
AV2="$HOME/Library/Developer/CoreSimulator/Devices/$UDID/data/private/var/MobileAsset/AssetsV2/com_apple_MobileAsset_LinguisticData"
CATALOG="$AV2/com_apple_MobileAsset_LinguisticData.xml"
[[ -f "$CATALOG" ]] || { echo "no catalog yet: show the French keyboard once, then rerun" >&2; exit 1; }
mkdir -p "$SCRATCH"

# 1. Find the French simulator asset and relabel it in the local catalog.
REL=$(python3 -I - "$CATALOG" <<'PY'
import plistlib, sys
path = sys.argv[1]
d = plistlib.load(open(path, "rb"))
hit = None
for a in d["Assets"]:
    if a.get("AssetLocale") == "fr" and a.get("_SupportedPlatforms") == ["iOS Simulator"] \
            and a.get("_CompatibilityVersion") in (17, 18):
        a["_CompatibilityVersion"] = 18
        hit = a
if hit is None:
    sys.exit("no French iOS Simulator asset in the catalog")
plistlib.dump(d, open(path, "wb"), fmt=plistlib.FMT_XML)
print(hit["__BaseURL"] + hit["__RelativePath"])
PY
)
NAME=$(basename "$REL" .zip)

# 2. Download from Apple's CDN and install as an asset directory.
[[ -f "$SCRATCH/$NAME.zip" ]] || curl -sS -o "$SCRATCH/$NAME.zip" "$REL"
DEST="$AV2/$NAME.asset"
mkdir -p "$DEST"
unzip -q -o "$SCRATCH/$NAME.zip" -d "$DEST"
plutil -replace MobileAssetProperties._CompatibilityVersion -integer 18 "$DEST/Info.plist"

# 3. Restart the asset daemon and the keyboard daemon so both rescan.
xcrun simctl spawn "$UDID" launchctl kickstart -k system/com.apple.mobileassetd >/dev/null 2>&1 || true
xcrun simctl spawn "$UDID" launchctl kickstart -k user/501/com.apple.TextInput.kbd >/dev/null 2>&1 || true
echo "installed $NAME; type 'tres prendrr ' on Apple's French keyboard: expect 'très prendre '"
