'use strict';

// UNKNW license + activation + settings-sync server.
//
// Endpoints (JSON):
//   POST /v1/activate     { key, deviceId, deviceName? }   -> bind a device
//   POST /v1/deactivate   { key, deviceId }                -> release a device
//   GET  /v1/status       hdr X-License-Key, X-Device-Id   -> license/device state
//   GET  /v1/settings     hdr X-License-Key                -> { settings }
//   PUT  /v1/settings     hdr X-License-Key                -> { ok }   body { settings }
//   POST /admin/keys      hdr X-Admin-Token                -> mint a key
//   GET  /admin/keys/:key  hdr X-Admin-Token               -> key + activations
//
// A license has a device limit; activation binds a deviceId until the limit is
// reached. Only the user's own UNKNW.* settings are stored — no Instagram data.
//
// Config via env: PORT, DB_PATH, ADMIN_TOKEN.

const express = require('express');
const Database = require('better-sqlite3');
const crypto = require('crypto');
const path = require('path');

const PORT = process.env.PORT || 8080;
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'unknw.db');
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.exec(`
  CREATE TABLE IF NOT EXISTS licenses (
    key         TEXT PRIMARY KEY,
    note        TEXT,
    created_at  INTEGER NOT NULL,
    expires_at  INTEGER,                 -- unix seconds, NULL = never
    max_devices INTEGER NOT NULL DEFAULT 1,
    revoked     INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS activations (
    license_key TEXT NOT NULL,
    device_id   TEXT NOT NULL,
    device_name TEXT,
    activated_at INTEGER NOT NULL,
    last_seen   INTEGER NOT NULL,
    PRIMARY KEY (license_key, device_id),
    FOREIGN KEY (license_key) REFERENCES licenses(key)
  );
  CREATE TABLE IF NOT EXISTS settings (
    license_key TEXT PRIMARY KEY,
    json        TEXT NOT NULL,
    updated_at  INTEGER NOT NULL,
    FOREIGN KEY (license_key) REFERENCES licenses(key)
  );
`);

const now = () => Math.floor(Date.now() / 1000);

function activeLicense(key) {
  if (!key) return null;
  const row = db.prepare('SELECT * FROM licenses WHERE key = ?').get(key);
  if (!row || row.revoked) return null;
  if (row.expires_at && row.expires_at < now()) return null;
  return row;
}

const deviceCount = (key) =>
  db.prepare('SELECT COUNT(*) AS n FROM activations WHERE license_key = ?').get(key).n;

const app = express();
app.use(express.json({ limit: '256kb' }));

// Bind a device to a license (idempotent for an already-bound device).
app.post('/v1/activate', (req, res) => {
  const { key, deviceId, deviceName } = req.body || {};
  const license = activeLicense(key);
  if (!license) return res.status(200).json({ activated: false, message: 'Invalid, expired or revoked key' });
  if (!deviceId) return res.status(400).json({ activated: false, message: 'deviceId required' });

  const existing = db.prepare('SELECT * FROM activations WHERE license_key = ? AND device_id = ?').get(key, deviceId);
  if (existing) {
    db.prepare('UPDATE activations SET last_seen = ?, device_name = ? WHERE license_key = ? AND device_id = ?')
      .run(now(), deviceName || existing.device_name, key, deviceId);
  } else {
    if (deviceCount(key) >= license.max_devices) {
      return res.status(403).json({
        activated: false, message: 'Device limit reached',
        deviceLimit: license.max_devices, deviceCount: deviceCount(key),
      });
    }
    db.prepare('INSERT INTO activations (license_key, device_id, device_name, activated_at, last_seen) VALUES (?, ?, ?, ?, ?)')
      .run(key, deviceId, deviceName || null, now(), now());
  }
  res.json({
    activated: true, message: 'ok',
    deviceLimit: license.max_devices, deviceCount: deviceCount(key),
    expiresAt: license.expires_at || null,
  });
});

app.post('/v1/deactivate', (req, res) => {
  const { key, deviceId } = req.body || {};
  if (!activeLicense(key)) return res.status(200).json({ ok: false, message: 'Invalid key' });
  db.prepare('DELETE FROM activations WHERE license_key = ? AND device_id = ?').run(key, deviceId);
  res.json({ ok: true, deviceCount: deviceCount(key) });
});

app.get('/v1/status', (req, res) => {
  const key = req.get('X-License-Key');
  const deviceId = req.get('X-Device-Id');
  const license = activeLicense(key);
  if (!license) return res.status(200).json({ valid: false, activated: false });
  let activated = false;
  if (deviceId) {
    const row = db.prepare('SELECT 1 FROM activations WHERE license_key = ? AND device_id = ?').get(key, deviceId);
    if (row) {
      activated = true;
      db.prepare('UPDATE activations SET last_seen = ? WHERE license_key = ? AND device_id = ?').run(now(), key, deviceId);
    }
  }
  res.json({
    valid: true, activated,
    deviceLimit: license.max_devices, deviceCount: deviceCount(key),
    expiresAt: license.expires_at || null,
  });
});

app.get('/v1/settings', (req, res) => {
  const key = req.get('X-License-Key');
  if (!activeLicense(key)) return res.status(401).json({ message: 'Invalid license' });
  const row = db.prepare('SELECT json FROM settings WHERE license_key = ?').get(key);
  res.json({ settings: row ? JSON.parse(row.json) : {} });
});

app.put('/v1/settings', (req, res) => {
  const key = req.get('X-License-Key');
  if (!activeLicense(key)) return res.status(401).json({ message: 'Invalid license' });
  const settings = (req.body && req.body.settings) || {};
  db.prepare(`
    INSERT INTO settings (license_key, json, updated_at) VALUES (?, ?, ?)
    ON CONFLICT(license_key) DO UPDATE SET json = excluded.json, updated_at = excluded.updated_at
  `).run(key, JSON.stringify(settings), now());
  res.json({ ok: true });
});

function requireAdmin(req, res) {
  if (!ADMIN_TOKEN || req.get('X-Admin-Token') !== ADMIN_TOKEN) {
    res.status(403).json({ message: 'Forbidden' });
    return false;
  }
  return true;
}

app.post('/admin/keys', (req, res) => {
  if (!requireAdmin(req, res)) return;
  const { note, days, maxDevices } = req.body || {};
  const key = crypto.randomBytes(18).toString('base64url');
  const expiresAt = days ? now() + Math.floor(days * 86400) : null;
  db.prepare('INSERT INTO licenses (key, note, created_at, expires_at, max_devices) VALUES (?, ?, ?, ?, ?)')
    .run(key, note || null, now(), expiresAt, Math.max(1, parseInt(maxDevices || 1, 10)));
  res.json({ key, expiresAt, maxDevices: Math.max(1, parseInt(maxDevices || 1, 10)) });
});

app.get('/admin/keys/:key', (req, res) => {
  if (!requireAdmin(req, res)) return;
  const license = db.prepare('SELECT * FROM licenses WHERE key = ?').get(req.params.key);
  if (!license) return res.status(404).json({ message: 'Not found' });
  const activations = db.prepare('SELECT device_id, device_name, activated_at, last_seen FROM activations WHERE license_key = ?').all(req.params.key);
  res.json({ license, activations });
});

app.get('/healthz', (_req, res) => res.json({ ok: true }));

app.listen(PORT, () => {
  console.log(`UNKNW server listening on :${PORT} (db: ${DB_PATH})`);
  if (!ADMIN_TOKEN) console.warn('WARNING: ADMIN_TOKEN is empty — /admin routes are disabled.');
});
