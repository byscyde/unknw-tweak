#!/usr/bin/env bash
#
# package-ipa.sh — build UNKNW and inject it into a stock Instagram .ipa,
# producing a ready-to-sideload .ipa with ElleKit bundled. End users just
# import the output into Feather (or another sideloader) and install; there is
# no manual tweak step on their side. Signing is still performed by the
# sideloader with the user's own certificate — that is inherent to installing
# on a non-jailbroken device and cannot be pre-baked.
#
# Usage:
#   ./package-ipa.sh path/to/Instagram.ipa [output.ipa]
#
# Requirements: theos (with an iOS SDK + toolchain) and Azule
# (https://github.com/Al4ise/Azule). Azule ships the Mach-O helpers and the
# ElleKit runtime it injects, so no Cydia Substrate is needed on the device.

set -euo pipefail

IPA_IN="${1:-}"
IPA_OUT="${2:-packages/UNKNW-Instagram.ipa}"
: "${THEOS:=$HOME/theos}"
AZULE_DIR="${AZULE_DIR:-$HOME/Azule}"

die() { echo "error: $*" >&2; exit 1; }

[[ -n "$IPA_IN" ]] || die "usage: ./package-ipa.sh path/to/Instagram.ipa [output.ipa]"
[[ -f "$IPA_IN" ]] || die "input .ipa not found: $IPA_IN"
[[ -d "$THEOS" ]] || die "THEOS not found at $THEOS (set \$THEOS)"

echo "==> Building UNKNW (THEOS=$THEOS)"
export THEOS
make clean >/dev/null 2>&1 || true
make package FINALPACKAGE=1

# The .deb carries the dylib; Azule extracts and injects it.
DEB="$(ls -t packages/*.deb 2>/dev/null | head -1 || true)"
[[ -n "$DEB" ]] || die "no .deb produced in packages/ — check the build output above"
echo "==> Built package: $DEB"

# Fetch Azule on first run.
if [[ ! -x "$AZULE_DIR/azule" ]]; then
    echo "==> Azule not found at $AZULE_DIR — cloning"
    git clone --depth 1 https://github.com/Al4ise/Azule "$AZULE_DIR"
fi

WORK="$(mktemp -d)"
echo "==> Injecting into $(basename "$IPA_IN")"
# -i input ipa, -o output folder, -f files to inject (the .deb).
"$AZULE_DIR/azule" -i "$IPA_IN" -o "$WORK" -f "$DEB"

RESULT="$(ls -t "$WORK"/*.ipa 2>/dev/null | head -1 || true)"
[[ -n "$RESULT" ]] || die "Azule did not produce an .ipa (see output above)"

mkdir -p "$(dirname "$IPA_OUT")"
cp "$RESULT" "$IPA_OUT"
rm -rf "$WORK"

echo "==> Done: $IPA_OUT"
echo "    Hand this .ipa to users; they import it into Feather and install."
