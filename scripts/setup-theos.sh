#!/usr/bin/env bash
# Set up theos with the non-Swift iOS toolchain and one iPhoneOS SDK.
# Used by CI (and reproducible locally). Honors $THEOS (default ~/theos).
set -euo pipefail

: "${THEOS:=$HOME/theos}"
: "${SDK_NAME:=iPhoneOS16.5.sdk}"
ARCH="$(uname -m)"

echo "==> Cloning theos to $THEOS"
if [ ! -d "$THEOS/.git" ]; then
    git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
fi

echo "==> Installing non-Swift iOS toolchain ($ARCH)"
mkdir -p "$THEOS/toolchain"
if [ -z "$(ls -A "$THEOS/toolchain" 2>/dev/null | grep -i iphone || true)" ]; then
    curl -fL "https://github.com/L1ghtmann/llvm-project/releases/latest/download/iOSToolchain-$ARCH.tar.xz" \
        -o /tmp/iostoolchain.tar.xz
    tar -xJf /tmp/iostoolchain.tar.xz -C "$THEOS/toolchain/"
    rm -f /tmp/iostoolchain.tar.xz
fi

echo "==> Installing $SDK_NAME"
mkdir -p "$THEOS/sdks"
if [ ! -d "$THEOS/sdks/$SDK_NAME" ]; then
    rm -rf /tmp/sdks-src
    git clone --filter=blob:none --no-checkout --depth 1 https://github.com/theos/sdks /tmp/sdks-src
    git -C /tmp/sdks-src sparse-checkout init --cone
    git -C /tmp/sdks-src sparse-checkout set "$SDK_NAME"
    git -C /tmp/sdks-src checkout HEAD
    cp -a "/tmp/sdks-src/$SDK_NAME" "$THEOS/sdks/"
    rm -rf /tmp/sdks-src
fi

echo "==> theos ready:"
ls "$THEOS/toolchain/linux/iphone/bin" | grep -E '^(clang|ldid|otool|install_name_tool|lipo)$' || true
ls "$THEOS/sdks"
