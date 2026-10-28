#!/usr/bin/env bash
#
# package-ipa.sh — build UNKNW and inject it into a stock (decrypted) Instagram
# .ipa, producing a ready-to-sideload .ipa. End users just import the output
# into Feather (or another sideloader) and install; there is no manual tweak
# step on their side. Signing is still performed by the sideloader with the
# user's own certificate — inherent to a non-jailbroken install.
#
# The tweak's only substrate dependency is MSHookMessageEx (Obj-C method
# swizzling), so instead of fetching a full Substrate/ElleKit this script builds
# a tiny self-contained CydiaSubstrate shim (substrate/CydiaSubstrate.m) and
# bundles it. Azule is used only to add the dylib load command + rpath.
#
# Usage:
#   ./package-ipa.sh path/to/Instagram.ipa [output.ipa]
#
# Requirements: theos with an iOS SDK + toolchain whose bin has clang, ldid,
# otool, install_name_tool, lipo; Azule (https://github.com/Al4ise/Azule);
# libplist runtime (for Azule's plist tool); zip/unzip.

set -euo pipefail

IPA_IN="${1:-}"
IPA_OUT="${2:-packages/UNKNW-Instagram.ipa}"
: "${THEOS:=$HOME/theos}"
: "${AZULE_DIR:=$HOME/Azule}"
: "${TOOLCHAIN_BIN:=$THEOS/toolchain/linux/iphone/bin}"
SDK="${SDK:-$(ls -d "$THEOS"/sdks/iPhoneOS*.sdk 2>/dev/null | sort -V | tail -1)}"
ROOT="$(cd "$(dirname "$0")" && pwd)"

die() { echo "error: $*" >&2; exit 1; }

[[ -n "$IPA_IN" ]] || die "usage: ./package-ipa.sh path/to/Instagram.ipa [output.ipa]"
[[ -f "$IPA_IN" ]] || die "input .ipa not found: $IPA_IN"
[[ -d "$THEOS" ]] || die "THEOS not found at $THEOS"
[[ -n "$SDK" && -d "$SDK" ]] || die "no iOS SDK found under $THEOS/sdks"
[[ -x "$AZULE_DIR/azule" ]] || die "Azule not found at $AZULE_DIR (git clone https://github.com/Al4ise/Azule)"

export PATH="$TOOLCHAIN_BIN:$PATH"

echo "==> Building UNKNW"
( cd "$ROOT" && env -u PATH PATH="/usr/bin:/bin:/usr/local/bin" THEOS="$THEOS" make package FINALPACKAGE=1 )
DEB="$(ls -t "$ROOT"/packages/*.deb 2>/dev/null | head -1 || true)"
[[ -n "$DEB" ]] || die "no .deb produced"
echo "    $DEB"

echo "==> Building CydiaSubstrate shim (arm64)"
clang -target arm64-apple-ios14.0 -isysroot "$SDK" -dynamiclib \
    -install_name @rpath/CydiaSubstrate.framework/CydiaSubstrate \
    -framework Foundation -lobjc \
    -o "$ROOT/substrate/CydiaSubstrate" "$ROOT/substrate/CydiaSubstrate.m"
ldid -S "$ROOT/substrate/CydiaSubstrate"

echo "==> Injecting dylib + rpath with Azule"
WORK="$(mktemp -d)"
"$AZULE_DIR/azule" -j -U -n UNKNW -i "$IPA_IN" -o "$WORK" -f "$DEB"
RESULT="$(ls -t "$WORK"/*.ipa 2>/dev/null | head -1 || true)"
[[ -n "$RESULT" ]] || die "Azule produced no .ipa"

echo "==> Bundling CydiaSubstrate.framework into the app"
APPREL="$(cd "$WORK" && unzip -Z1 "$RESULT" | grep -oE '^Payload/[^/]+\.app/' | head -1)"
FWREL="${APPREL}Frameworks/CydiaSubstrate.framework"
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/$FWREL"
cp "$ROOT/substrate/CydiaSubstrate" "$STAGE/$FWREL/CydiaSubstrate"
cat > "$STAGE/$FWREL/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>CydiaSubstrate</string>
    <key>CFBundleIdentifier</key><string>com.saurik.substrate</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>CydiaSubstrate</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>MinimumOSVersion</key><string>14.0</string>
</dict>
</plist>
PLIST
( cd "$STAGE" && zip -gq "$RESULT" "$FWREL/CydiaSubstrate" "$FWREL/Info.plist" )

mkdir -p "$(dirname "$ROOT/$IPA_OUT")"
cp "$RESULT" "$ROOT/$IPA_OUT"
rm -rf "$WORK" "$STAGE"

echo "==> Done: $IPA_OUT"
echo "    Hand this .ipa to users; they import it into Feather and install."
