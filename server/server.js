'use strict';

// UNKNW license + settings-sync server.
//
// Endpoints (all JSON):
//   POST /v1/validate         { key }                 -> { valid, message }
//   GET  /v1/settings         header X-License-Key    -> { settings }
//   PUT  /v1/settings         header X-License-Key    -> { ok }   body: { settings }
//   POST /admin/keys          header X-Admin-Token    -> { key }  body: { note?, days? }
//
// Only the user's own UNKNW.* tweak settings are stored. No Instagram data and
// no third-party profile data belongs here — keep it that way.
//
// Config via env: PORT, DB_PATH, ADMIN_TOKEN.

const express = require('express');
const Database = require('better-sqlite3');
const path = require('path');

const PORT = process.env.PORT || 8080;
const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'unknw.db');
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.exec(`
  CREATE TABLE IF NOT EXISTS licenses (
    key        TEXT PRIMARY KEY,
    note       TEXT,
    created_at INTEGER NOT NULL,
    expires_at INTEGER,          -- unix seconds, NULL = never
    revoked    INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS settings (
    license_key TEXT PRIMARY KEY,
    json        TEXT NOT NULL,
    updated_at  INTEGER NOT NULL,
    FOREIGN KEY (license_key) REFERENCES licenses(key)
  );
`);

const now = () => Math.floor(Date.now() / 1000);

// Returns the license row if the key is usable, otherwise null.
function activeLicense(key) {
  if (!key) return null;
  const row = db.prepare('SELECT * FROM licenses WHERE key = ?').get(key);
  if (!row) return null;
  if (row.revoked) return null;
  if (row.expires_at && row.expires_at < now()) return null;
  return row;
}

const app = express();
app.use(express.json({ limit: '256kb' }));

app.post('/v1/validate', (req, res) => {
  const { key } = req.body || {};
  const license = activeLicense(key);
  if (!license) {
    return res.status(200).json({ valid: false, message: 'Invalid, expired or revoked key' });
  }
  res.json({ valid: true, message: 'ok', expiresAt: license.expires_at || null });
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

// Mint a new license key. Protected by ADMIN_TOKEN (required, non-empty).
app.post('/admin/keys', (req, res) => {
  if (!ADMIN_TOKEN || req.get('X-Admin-Token') !== ADMIN_TOKEN) {
    return res.status(403).json({ message: 'Forbidden' });
  }
  const { note, days } = req.body || {};
  const key = require('crypto').randomBytes(18).toString('base64url');
  const expiresAt = days ? now() + Math.floor(days * 86400) : null;
  db.prepare('INSERT INTO licenses (key, note, created_at, expires_at) VALUES (?, ?, ?, ?)')
    .run(key, note || null, now(), expiresAt);
  res.json({ key, expiresAt });
});

app.get('/healthz', (_req, res) => res.json({ ok: true }));

app.listen(PORT, () => {
  console.log(`UNKNW license server listening on :${PORT} (db: ${DB_PATH})`);
  if (!ADMIN_TOKEN) console.warn('WARNING: ADMIN_TOKEN is empty — /admin/keys is disabled.');
});
