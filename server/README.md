# UNKNW license server

A small, self-hosted backend for the UNKNW tweak:

- **Licenses & activations** — a key has a device limit; activating binds a
  deviceId until the limit is reached.
- **Own-settings sync** — the tweak backs up the user's `UNKNW.*` preferences
  and restores them after a reinstall.

> Scope: this stores a user's **own tweak settings** only. Do not store scraped
> Instagram data or other people's profile data here — the Profile Analyzer and
> Stories analytics keep that on the device.

## Run

```bash
cd server
npm install
ADMIN_TOKEN="$(openssl rand -hex 24)" node server.js
```

Environment:

| Var | Default | Purpose |
|-----|---------|---------|
| `PORT` | `8080` | Listen port |
| `DB_PATH` | `./unknw.db` | SQLite file |
| `ADMIN_TOKEN` | *(empty)* | Required to mint keys via `/admin/keys`; empty disables that route |

Put it behind a TLS-terminating reverse proxy (Caddy/Nginx) so the tweak can
reach it over HTTPS, and point the app at it by setting `kDefaultBaseURL` in
`Sources/Core/UNKNWLicense.m` (or the `UNKNW_SERVER_URL` env var).

## Mint a license key

Directly (no server needed):

```bash
node newkey.js "customer@example.com" 365 2   # note, days (0/omit = never), max devices
```

Or over HTTP once the server is running:

```bash
curl -s -X POST http://localhost:8080/admin/keys \
  -H "X-Admin-Token: $ADMIN_TOKEN" -H 'Content-Type: application/json' \
  -d '{"note":"customer@example.com","days":365,"maxDevices":2}'
```

## API

| Method | Path | Auth | Body / result |
|--------|------|------|---------------|
| POST | `/v1/activate` | — | `{key, deviceId, deviceName?}` → `{activated, deviceLimit, deviceCount, expiresAt}` |
| POST | `/v1/deactivate` | — | `{key, deviceId}` → `{ok, deviceCount}` |
| GET | `/v1/status` | `X-License-Key`, `X-Device-Id` | → `{valid, activated, deviceLimit, deviceCount, expiresAt}` |
| GET | `/v1/settings` | `X-License-Key` | → `{settings}` |
| PUT | `/v1/settings` | `X-License-Key` | `{settings}` → `{ok}` |
| POST | `/admin/keys` | `X-Admin-Token` | `{note?, days?, maxDevices?}` → `{key, expiresAt, maxDevices}` |
| GET | `/admin/keys/:key` | `X-Admin-Token` | → `{license, activations}` |
| GET | `/healthz` | — | `{ok}` |

The tweak activates a key via `/v1/activate` (binding this install's generated
device id), checks `/v1/status` on launch, and syncs settings keyed by license.

## Revoking

```sql
UPDATE licenses SET revoked = 1 WHERE key = '...';
```
