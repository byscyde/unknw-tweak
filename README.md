# UNKNW

An original enhancement tweak for Instagram, by **SCYDE** · [scyde.dev](https://scyde.dev)

UNKNW is a [theos](https://theos.dev)/logos tweak. It injects into Instagram and
exposes its own **in-app settings panel** — no jailbreak and no Settings.app
bundle required, so it works when sideloaded with a tool like **Feather**.

> This is original code. It does not include, clone, or reverse-engineer any
> paid tweak. Features that need Instagram's private, per-version internals ship
> as documented hook stubs over working infrastructure — see
> [`FEATURES.md`](FEATURES.md) for the exact status of each one.

---

## Features

Profile Analyzer · Stories Archive · Media Downloader (with a local vault and
Photos export) · Privacy (hide seen receipts, send seen manually) · Messages
(keep unsent, hide typing, audio messages, confirm calls) · Reels (auto-advance,
session limit) · Utilities (confirm like/follow, copy text, detailed dates) ·
License + settings sync.

Full per-feature status, and the one requested option left out by design, are in
[`FEATURES.md`](FEATURES.md).

## Opening the settings panel

Inside Instagram, **two-finger long-press** (hold ~0.8s) anywhere. The panel has
a master switch, the license row, and one section per feature category. The
gesture works even when the master switch is off, so you can't lock yourself
out. Toggling a feature takes effect the next time Instagram is relaunched.

---

## Project layout

```
Makefile                      theos build config (targets Instagram, arm64/arm64e)
control                       Debian package metadata (dev.scyde.unknw)
UNKNW.plist                   MobileSubstrate filter — injects into com.burbn.instagram
Sources/
  UNKNW.h                     Keys, logging, prefs + feature-initializer declarations
  Prefs.m                     Bool/number/string prefs in the host app's NSUserDefaults
  Features.h / Features.m     The feature registry (single source of truth)
  UNKNWSettingsController.*   In-app settings panel (categories, toggle/stepper/segment)
  Tweak.x                     %ctor: installs the gesture, then loads enabled features
  Core/
    UNKNWVault.*              Media vault + download + Photos export   (working)
    UNKNWFollowerStore.*      On-device follower snapshot + diff        (working)
    UNKNWFormat.*             Detailed date formatting                  (working)
    UNKNWLicense.*            License validation + settings-sync client (working)
  Features/
    *.x                       One file per feature: %group + initializer + hook TODO
    _Template.x.example       Copy this to add a feature
server/                       Self-hosted license + settings-sync backend (Node + SQLite)
FEATURES.md                   Per-feature status and implementation notes
```

## Adding / completing a feature

Each feature's toggle, registry entry and loader wiring already exist. To make
one do its work, complete its hook:

1. Enable **Developer Logging**, relaunch Instagram, open the relevant screen,
   and read the console (`idevicesyslog` / Console.app, filter `[UNKNW]`) to
   learn the real class names.
2. Replace the `// TODO` block in the matching `Sources/Features/*.x` with
   `%hook`s against those classes, calling the ready-made `Core/` helpers.
3. Rebuild.

To add a brand-new feature, copy `Sources/Features/_Template.x.example`, add a
key + `extern` initializer in `UNKNW.h`, and one `[UNKNWFeature …]` entry in
`Features.m`.

---

## Building

Needs [theos](https://theos.dev/docs/installation) with an iOS SDK and toolchain
(builds on macOS or Linux):

```bash
export THEOS=~/theos
make clean
make package FINALPACKAGE=1            # .deb lands in ./packages/
# rootless jailbreak build:
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

## Distribution: a pre-injected IPA

UNKNW is shipped as a single Instagram `.ipa` with the tweak already injected, so
end users do no manual tweak work. You provide a stock Instagram `.ipa` and run:

```bash
export THEOS=/home/user/theos
./package-ipa.sh path/to/Instagram.ipa     # → packages/UNKNW-Instagram.ipa
```

This builds the tweak and uses [Azule](https://github.com/Al4ise/Azule) to inject
the dylib + ElleKit into the app. Users then just import `UNKNW-Instagram.ipa`
into [Feather](https://github.com/khcrysalis/Feather) and install; Feather signs
it with their certificate during install (that step is inherent to non-jailbroken
sideloading). Full details and caveats are in [`PACKAGING.md`](PACKAGING.md).

> Free Apple ID certs expire after 7 days (re-sign to renew); a paid Apple
> Developer cert lasts a year. Separately, Instagram actively detects and bans
> accounts running modified clients — that risk falls on whoever runs the app.

### Developing from Windows

Build + inject here (Linux/theos) to produce the `.ipa`; users sign + install
with Feather on the device side. No Mac is needed.

---

## License server

`server/` is a self-hosted Node + SQLite backend that validates license keys and
syncs **the user's own** UNKNW settings (so a reinstall can restore them). It
does **not** store Instagram or third-party profile data. Point the app at it via
`kDefaultBaseURL` in `Sources/Core/UNKNWLicense.m`. See [`server/README.md`](server/README.md).

## License

Original work © SCYDE. Add a license of your choice before distributing.
