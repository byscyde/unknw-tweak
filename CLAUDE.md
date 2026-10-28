# UNKNW — project notes

## Build / release naming conventions (owner preference)
- Do **not** use uppercase `UNKNW` in build artifacts/technical names — use
  lowercase `unknw` (e.g. `unknw.dylib`, `unknw.*`). Uppercase looks bad.
  (The product/brand name shown in the in-app panel can stay "UNKNW".)
- Name each released `.ipa` as:
  `com.burbn.instagram_<IG_VERSION>_unknw_<TWEAK_VERSION>.ipa`
  - `<IG_VERSION>` = the Instagram version of the base IPA (e.g. `453.0`)
  - `<TWEAK_VERSION>` = the UNKNW tweak version (currently `1.0`)
  - Example: `com.burbn.instagram_453.0_unknw_1.0.ipa`

## How this repo builds/ships
- GitHub Actions (`.github/workflows/release.yml`) builds UNKNW, injects it into
  the base Instagram IPA, and publishes to the `latest` release on every push to
  `main`. The owner installs via Feather (non-jailbroken sideload).
- Self-contained dylib: logos `internal` generator (no CydiaSubstrate), own
  vendored fishhook for C-function rebinding.

## Sideload stability (the hard part)
A re-signed/sideloaded Instagram is unstable on its own (beta nag, logout,
crash) — confirmed: even clean IG with no tweak crashes. The enablers that fix
it (replicated from standard techniques, same as Regram implements):
- **Integrity bypass**: block Apple App Attest (`DCAppAttestService`
  isSupported→NO, attest/assertion calls fail gracefully). This was the crash
  root cause. Loaded early in `%ctor`, independent of license.
- Beta update-nag bypass (TestFlight nudge VC).
- Keychain login persistence (strip Instagram's pinned team access-group).
- Possible future additions if needed: `isJailbroken` /
  `FBFamilyIDDeviceIsJailbroken` checks.
