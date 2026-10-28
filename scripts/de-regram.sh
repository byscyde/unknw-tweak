#!/usr/bin/env bash
# Produce a clean Instagram base from a pre-injected IPA WITHOUT touching the
# main executable: replace the injected third-party tweak dylibs (the ones the
# base loads via @executable_path) with empty stubs of the same name, and drop
# the tweak's bundles/extensions/assets. The main binary is left byte-for-byte
# unchanged (no load-command surgery, so no chained-fixups corruption). UNKNW is
# injected afterwards by package-ipa.sh.
#
# Usage: ./de-regram.sh input.ipa output.ipa
set -euo pipefail

IPA_IN="$1"
OUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
: "${THEOS:=$HOME/theos}"
: "${TOOLCHAIN_BIN:=$THEOS/toolchain/linux/iphone/bin}"
SDK="${SDK:-$(ls -d "$THEOS"/sdks/iPhoneOS*.sdk 2>/dev/null | sort -V | tail -1)}"
export PATH="$TOOLCHAIN_BIN:$PATH"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
unzip -q "$IPA_IN" -d "$WORK"
APP="$(find "$WORK/Payload" -maxdepth 1 -name '*.app' | head -1)"
EXEC="$APP/$(python3 -c "import plistlib;print(plistlib.load(open('$APP/Info.plist','rb'))['CFBundleExecutable'])")"

echo 'void _unknw_stub(void){}' > "$WORK/stub.c"

# Replace each @executable_path/<name>.dylib (an injected tweak lib) with an
# empty stub of the same install name. Instagram's own libs use @rpath, so this
# targets only the bundled tweak.
otool -L "$EXEC" | awk '/@executable_path\/.*\.dylib/{print $1}' | while read -r lc; do
    name="$(basename "$lc")"
    [ -f "$APP/$name" ] || continue
    clang -target arm64-apple-ios14.0 -isysroot "$SDK" -dynamiclib -install_name "$lc" -o "$APP/$name" "$WORK/stub.c"
    ldid -S "$APP/$name"
    echo "stubbed $name"
done

# Drop the tweak's non-dylib leftovers (resource bundles, app extensions, icons).
find "$APP" -maxdepth 1 -iname 'Regram*.png' -delete 2>/dev/null || true
rm -rf "$APP/Regram.bundle" 2>/dev/null || true
find "$APP/PlugIns" -maxdepth 1 -iname '*Regram*.appex' -exec rm -rf {} + 2>/dev/null || true

rm -f "$OUT"
( cd "$WORK" && zip -qry "$OUT" Payload )
echo "clean base: $OUT"
