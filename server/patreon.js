'use strict';

// Patreon OAuth + membership check for the UNKNW server.
//
// Flow: the app opens /patreon/login (ASWebAuthenticationSession) -> Patreon
// login -> /patreon/callback. The server exchanges the code, reads the user's
// membership to YOUR campaign, and only if they are an active patron (optionally
// of an allowed tier) issues a license and redirects back to the app scheme.
//
// Env:
//   PATREON_CLIENT_ID, PATREON_CLIENT_SECRET   (from your Patreon API client)
//   PATREON_CAMPAIGN_ID                         (your campaign's numeric id)
//   PATREON_REDIRECT_URI                        (e.g. https://api.scyde.dev/patreon/callback)
//   PATREON_ALLOWED_TIERS                       (optional CSV of tier ids; empty = any tier)
//   PATREON_WEBHOOK_SECRET                      (optional, for /patreon/webhook)
//   APP_SCHEME                                  (default "unknw")

const crypto = require('crypto');

const CLIENT_ID = process.env.PATREON_CLIENT_ID || '';
const CLIENT_SECRET = process.env.PATREON_CLIENT_SECRET || '';
const CAMPAIGN_ID = process.env.PATREON_CAMPAIGN_ID || '';
const REDIRECT_URI = process.env.PATREON_REDIRECT_URI || '';
const ALLOWED_TIERS = (process.env.PATREON_ALLOWED_TIERS || '').split(',').map(s => s.trim()).filter(Boolean);
const WEBHOOK_SECRET = process.env.PATREON_WEBHOOK_SECRET || '';
const APP_SCHEME = process.env.APP_SCHEME || 'unknw';

const configured = () => CLIENT_ID && CLIENT_SECRET && CAMPAIGN_ID && REDIRECT_URI;

function authorizeURL(state) {
  const p = new URLSearchParams({
    response_type: 'code',
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    scope: 'identity identity.memberships',
    state,
  });
  return `https://www.patreon.com/oauth2/authorize?${p.toString()}`;
}

async function exchangeCode(code) {
  const body = new URLSearchParams({
    code, grant_type: 'authorization_code',
    client_id: CLIENT_ID, client_secret: CLIENT_SECRET, redirect_uri: REDIRECT_URI,
  });
  const r = await fetch('https://www.patreon.com/api/oauth2/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body,
  });
  if (!r.ok) throw new Error(`token exchange failed (${r.status})`);
  return r.json(); // { access_token, refresh_token, expires_in, ... }
}

// Returns { patreonUserId, email, name, isActivePatron, tiers: [tierId] }.
async function fetchMembership(accessToken) {
  const url = 'https://www.patreon.com/api/oauth2/v2/identity'
    + '?include=memberships,memberships.currently_entitled_tiers,memberships.campaign'
    + '&fields%5Bmember%5D=patron_status'
    + '&fields%5Buser%5D=email,full_name';
  const r = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (!r.ok) throw new Error(`identity failed (${r.status})`);
  const j = await r.json();

  const user = j.data || {};
  const patreonUserId = user.id;
  const email = user.attributes && user.attributes.email;
  const name = user.attributes && user.attributes.full_name;

  const included = j.included || [];
  const members = included.filter(x => x.type === 'member');
  let isActivePatron = false;
  let tiers = [];

  for (const m of members) {
    const campaign = m.relationships && m.relationships.campaign && m.relationships.campaign.data;
    if (!campaign || String(campaign.id) !== String(CAMPAIGN_ID)) continue;
    const status = m.attributes && m.attributes.patron_status;
    const entitled = (m.relationships && m.relationships.currently_entitled_tiers
      && m.relationships.currently_entitled_tiers.data) || [];
    tiers = entitled.map(t => String(t.id));
    if (status === 'active_patron') {
      if (ALLOWED_TIERS.length === 0 || tiers.some(t => ALLOWED_TIERS.includes(t))) {
        isActivePatron = true;
      }
    }
  }
  return { patreonUserId, email, name, isActivePatron, tiers };
}

// Verify a Patreon webhook signature (HMAC-MD5 of the raw body with the secret).
function verifyWebhook(rawBody, signature) {
  if (!WEBHOOK_SECRET || !signature) return false;
  const digest = crypto.createHmac('md5', WEBHOOK_SECRET).update(rawBody).digest('hex');
  try { return crypto.timingSafeEqual(Buffer.from(digest), Buffer.from(signature)); }
  catch { return false; }
}

module.exports = {
  configured, authorizeURL, exchangeCode, fetchMembership, verifyWebhook,
  APP_SCHEME, CAMPAIGN_ID,
};
