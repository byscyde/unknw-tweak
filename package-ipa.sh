#!/usr/bin/env bash
#
# package-ipa.sh — build UNKNW and inject it into a stock (decrypted) Instagram
# .ipa, producing a ready-to-sideload .ipa. End users just import the output
# into Feather (or another sideloader) and install; there is no manual tweak
# step on their side. Signing is still performed by the sideloader with the
# user's own certificate — inherent to a non-jailbroken install.
#
# Injection is done with explicit tools (no reliance on an external wrapper
# script): the dylib is built unstripped so install_name_tool can rewrite its
# load paths to @rpath, a self-contained CydiaSubstrate shim is bundled, and the
# load command is added to the app binary with insert_dylib.
#
# Usage:
#   ./package-ipa.sh path/to/Instagram.ipa [output.ipa]
#
# Requirements: theos with an iOS SDK + toolchain (clang, ldid, otool,
# install_name_tool in its bin); insert_dylib (from Azule's bin/linux, or set
# INSERT_DYLIB); python3; zip/unzip.

set -euo pipefail

IPA_IN="${1:-}"
IPA_OUT="${2:-packages/UNKNW-Instagram.ipa}"
: "${THEOS:=$HOME/theos}"
: "${AZULE_DIR:=$HOME/Azule}"
: "${TOOLCHAIN_BIN:=$THEOS/toolchain/linux/iphone/bin}"
: "${INSERT_DYLIB:=$AZULE_DIR/bin/linux/insert_dylib}"
SDK="${SDK:-$(ls -d "$THEOS"/sdks/iPhoneOS*.sdk 2>/dev/null | sort -V | tail -1)}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SUBSTRATE_PATH="/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate"

die() { echo "error: $*" >&2; exit 1; }

[[ -n "$IPA_IN" ]] || die "usage: ./package-ipa.sh path/to/Instagram.ipa [output.ipa]"
[[ -f "$IPA_IN" ]] || die "input .ipa not found: $IPA_IN"
[[ -d "$THEOS" ]] || die "THEOS not found at $THEOS"
[[ -n "$SDK" && -d "$SDK" ]] || die "no iOS SDK under $THEOS/sdks"
[[ -x "$INSERT_DYLIB" ]] || die "insert_dylib not found at $INSERT_DYLIB (git clone https://github.com/Al4ise/Azule, or set INSERT_DYLIB)"

export PATH="$TOOLCHAIN_BIN:$PATH"
IPA_OUT_ABS="$ROOT/$IPA_OUT"; case "$IPA_OUT" in /*) IPA_OUT_ABS="$IPA_OUT";; esac

echo "==> Building UNKNW (optimized, unstripped)"
( cd "$ROOT" && env -u PATH PATH="/usr/bin:/bin:/usr/local/bin" THEOS="$THEOS" \
    make clean >/dev/null 2>&1; env -u PATH PATH="$TOOLCHAIN_BIN:/usr/bin:/bin" THEOS="$THEOS" \
    make package FINALPACKAGE=1 STRIP=/bin/true )
DYLIB="$ROOT/.theos/obj/UNKNW.dylib"
[[ -f "$DYLIB" ]] || die "dylib not found at $DYLIB"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Rewriting dylib load paths for sideload"
cp "$DYLIB" "$WORK/UNKNW.dylib"
install_name_tool -id @rpath/UNKNW.dylib "$WORK/UNKNW.dylib"

# With the logos "internal" generator the dylib has no external substrate
# dependency and is fully self-contained. Only if an older/substrate build
# still references CydiaSubstrate do we build and bundle a neutral-named runtime.
NEED_RUNTIME=0
if otool -L "$WORK/UNKNW.dylib" | grep -qiE 'CydiaSubstrate|UNKNWCore\.framework|/CydiaSubstrate$'; then
    NEED_RUNTIME=1
fi

if [ "$NEED_RUNTIME" = "1" ]; then
    echo "==> dylib needs a runtime; building neutral-named UNKNWCore shim"
    clang -target arm64-apple-ios14.0 -isysroot "$SDK" -dynamiclib \
        -install_name @rpath/UNKNWCore.framework/UNKNWCore \
        -framework Foundation -lobjc \
        -o "$ROOT/substrate/UNKNWCore" "$ROOT/substrate/CydiaSubstrate.m"
    ldid -S "$ROOT/substrate/UNKNWCore"
    install_name_tool -change "$SUBSTRATE_PATH" @rpath/UNKNWCore.framework/UNKNWCore "$WORK/UNKNW.dylib"
else
    echo "==> dylib is self-contained (no substrate dependency)"
fi
ldid -S "$WORK/UNKNW.dylib"

echo "==> Unpacking base IPA"
unzip -q "$IPA_IN" -d "$WORK/app"
APP="$(find "$WORK/app/Payload" -maxdepth 1 -name '*.app' | head -1)"
[[ -n "$APP" ]] || die "no .app in IPA"
EXECNAME="$(python3 -I -c "import plistlib;print(plistlib.load(open('$APP/Info.plist','rb'))['CFBundleExecutable'])")"
EXEC="$APP/$EXECNAME"
[[ -f "$EXEC" ]] || die "executable $EXECNAME not found"
mkdir -p "$APP/Frameworks"

echo "==> Bundling UNKNW.dylib"
cp "$WORK/UNKNW.dylib" "$APP/Frameworks/UNKNW.dylib"
if [ "$NEED_RUNTIME" = "1" ]; then
    echo "    + UNKNWCore.framework (neutral-named runtime)"
    FW="$APP/Frameworks/UNKNWCore.framework"
    mkdir -p "$FW"
    cp "$ROOT/substrate/UNKNWCore" "$FW/UNKNWCore"
    cat > "$FW/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>UNKNWCore</string>
    <key>CFBundleIdentifier</key><string>dev.scyde.unknw.core</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>UNKNWCore</string>
    <key>CFBundlePackageType</key><string>FMWK</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>MinimumOSVersion</key><string>14.0</string>
</dict>
</plist>
PLIST
    ldid -S "$FW/UNKNWCore"
fi

echo "==> Injecting load command into app binary"
# Preserve the app's original entitlements (keychain-access-groups, app groups,
# etc.) so the sideloader re-signs from the real baseline. insert_dylib strips
# the signature, so capture them first and re-apply after.
ldid -e "$EXEC" > "$WORK/entitlements.plist" 2>/dev/null || true
if [ "$(otool -l "$EXEC" | grep -c '@executable_path/Frameworks' || true)" -eq 0 ]; then
    install_name_tool -add_rpath @executable_path/Frameworks "$EXEC" || \
        echo "warning: could not add rpath (continuing; app usually already has it)"
fi
"$INSERT_DYLIB" --all-yes --inplace @rpath/UNKNW.dylib "$EXEC" >/dev/null
otool -L "$EXEC" | grep -q '@rpath/UNKNW.dylib' || die "load command not added"
if [ -s "$WORK/entitlements.plist" ]; then
    ldid -S"$WORK/entitlements.plist" "$EXEC"
else
    ldid -S "$EXEC"
fi

echo "==> Repacking IPA"
mkdir -p "$(dirname "$IPA_OUT_ABS")"
rm -f "$IPA_OUT_ABS"
( cd "$WORK/app" && zip -qry "$IPA_OUT_ABS" Payload )

echo "==> Done: $IPA_OUT_ABS"
echo "    Import into Feather and install. Two-finger long-press (or long-press the Home tab) opens UNKNW."
