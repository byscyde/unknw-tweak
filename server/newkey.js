'use strict';

// Mint a license key directly against the database (no server needed).
// Usage:
//   node newkey.js "customer note" [days] [maxDevices]
//   DB_PATH=/data/unknw.db node newkey.js "yearly" 365 2

const Database = require('better-sqlite3');
const crypto = require('crypto');
const path = require('path');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'unknw.db');
const note = process.argv[2] || null;
const days = process.argv[3] ? Number(process.argv[3]) : null;
const maxDevices = process.argv[4] ? Math.max(1, parseInt(process.argv[4], 10)) : 1;

const db = new Database(DB_PATH);
db.exec(`
  CREATE TABLE IF NOT EXISTS licenses (
    key TEXT PRIMARY KEY, note TEXT, created_at INTEGER NOT NULL,
    expires_at INTEGER, max_devices INTEGER NOT NULL DEFAULT 1,
    revoked INTEGER NOT NULL DEFAULT 0
  );
`);

const now = Math.floor(Date.now() / 1000);
const key = crypto.randomBytes(18).toString('base64url');
const expiresAt = days ? now + Math.floor(days * 86400) : null;

db.prepare('INSERT INTO licenses (key, note, created_at, expires_at, max_devices) VALUES (?, ?, ?, ?, ?)')
  .run(key, note, now, expiresAt, maxDevices);

console.log('license key:', key);
console.log('expires    :', expiresAt ? new Date(expiresAt * 1000).toISOString() : 'never');
console.log('max devices:', maxDevices);
