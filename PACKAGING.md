# Packaging UNKNW into a ready-to-install Instagram IPA

The distribution model: you provide a stock **Instagram `.ipa`**, UNKNW is
injected into it (with the ElleKit runtime bundled), and the output is a single
`.ipa` you hand to users. Users just import it into **Feather** (or another
sideloader) and install — there is no manual tweak step on their side.

> **Signing** is still done by the sideloader with the user's own certificate.
> That is required to install any app on a non-jailbroken device and cannot be
> pre-baked into the IPA. For the user it is just "import → install"; Feather
> signs during install. Free Apple ID certs expire after 7 days (re-sign to
> renew); a paid Apple Developer cert lasts a year.

## One-time setup (build machine — this Linux box or any Linux/macOS)

1. **theos** with an iOS SDK + toolchain whose `bin/` has `clang`, `ldid`,
   `otool`, `install_name_tool`, `lipo`. On this environment it is installed at
   `/home/user/theos` (non-Swift iOS toolchain + iPhoneOS 16.5 SDK).
   Elsewhere: https://theos.dev/docs/installation
2. **Azule** cloned to `~/Azule` (`git clone https://github.com/Al4ise/Azule`),
   or set `AZULE_DIR`. Used only to add the dylib load command + rpath.
3. **libplist** runtime (Azule's plist tool needs `libplist-2.0.so.4`):
   `sudo apt-get install -y libplist-2.0-4`.

> **Substrate:** the injected tweak needs only `MSHookMessageEx`. Rather than
> download a full Substrate/ElleKit, the script compiles the tiny shim in
> `substrate/CydiaSubstrate.m` and bundles it as `CydiaSubstrate.framework`.
> That keeps the build self-contained and offline-friendly.

## Input IPA must be decrypted

The script injects into the app binary, so the Instagram `.ipa` must be a
**decrypted** dump (`cryptid 0`), not a straight App Store download. Check with
`otool -l Instagram | grep -A4 LC_ENCRYPTION_INFO`.

## Build the injected IPA

```bash
export THEOS=/home/user/theos
./package-ipa.sh path/to/Instagram.ipa
# → packages/UNKNW-Instagram.ipa
```

What the script does:

1. Builds `UNKNW` from source (`make package FINALPACKAGE=1`) → a `.deb`
   carrying the `UNKNW.dylib`.
2. Runs Azule to inject that dylib into the Instagram app inside the IPA, add
   the load command, and bundle ElleKit so the logos/substrate hooks resolve on
   a stock device.
3. Writes `packages/UNKNW-Instagram.ipa`.

## What the user does

1. Open Feather, import `UNKNW-Instagram.ipa`.
2. Install (Feather signs with their certificate / Apple ID).
3. Launch Instagram, **two-finger long-press** → the UNKNW panel opens.

## Important: current state of the injected app

The app **boots with a working UNKNW settings panel** (toggles, license row,
vault, developer logging). But most feature **hooks are still stubs** — each
toggle is wired, yet the Instagram-specific `%hook` that makes it act is a
documented `// TODO` (see `FEATURES.md`). So today an injected build is a
functional shell: the panel works and Developer Logging works, but e.g. Media
Downloader won't actually grab media until its hook is completed.

Complete the hooks (using Developer Logging to find class names), rebuild, and
re-run `package-ipa.sh` to produce an updated IPA.

## Instagram version

Instagram's internal class/method names vary by app version. Build and test the
hooks against the **same Instagram version** you ship the IPA for, and note that
version in your release so users install a matching base app.
