# UNKNW license server

A small, self-hosted backend for the UNKNW tweak:

- **License validation** — the tweak checks a key before unlocking.
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
node newkey.js "customer@example.com" 365   # note, days (omit days = never expires)
```

Or over HTTP once the server is running:

```bash
curl -s -X POST http://localhost:8080/admin/keys \
  -H "X-Admin-Token: $ADMIN_TOKEN" -H 'Content-Type: application/json' \
  -d '{"note":"customer@example.com","days":365}'
```

## API

| Method | Path | Auth | Body / result |
|--------|------|------|---------------|
| POST | `/v1/validate` | — | `{key}` → `{valid, message, expiresAt}` |
| GET | `/v1/settings` | `X-License-Key` | → `{settings}` |
| PUT | `/v1/settings` | `X-License-Key` | `{settings}` → `{ok}` |
| POST | `/admin/keys` | `X-Admin-Token` | `{note?, days?}` → `{key, expiresAt}` |
| GET | `/healthz` | — | `{ok}` |

## Revoking

```sql
UPDATE licenses SET revoked = 1 WHERE key = '...';
```
