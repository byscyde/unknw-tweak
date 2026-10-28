# Deploying the UNKNW license server (api.scyde.dev)

A **standalone** deployment — its own directory, system user, database, port and
service. It shares nothing with any other project (e.g. Luma / Founders): do not
point it at another app's database or process.

Target: the tweak calls `https://api.scyde.dev` (set in
`Sources/Core/UNKNWLicense.m`). These steps put this server behind that domain.

Assumes Ubuntu/Debian. Run as a sudo-capable user.

---

## 1. DNS

Create an **A record**: `api.scyde.dev` → your server's public IP. Wait until
`dig +short api.scyde.dev` returns that IP.

## 2. Install Node.js + build tools

`better-sqlite3` is a native module, so it needs a compiler and python.

```bash
sudo apt-get update
sudo apt-get install -y curl ca-certificates build-essential python3
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v   # should be v20.x
```

## 3. Dedicated user + directory (isolation)

```bash
sudo useradd --system --home /opt/unknw-server --shell /usr/sbin/nologin unknw
sudo mkdir -p /opt/unknw-server/data
```

## 4. Get the server code

```bash
sudo git clone https://github.com/byscyde/unknw-tweak /opt/unknw-server/app
cd /opt/unknw-server/app/server
sudo npm install --omit=dev
sudo chown -R unknw:unknw /opt/unknw-server
```

(To update later: `sudo -u unknw git -C /opt/unknw-server/app pull && cd /opt/unknw-server/app/server && sudo -u unknw npm install --omit=dev && sudo systemctl restart unknw-server`.)

## 5. Generate an admin token

```bash
openssl rand -hex 24      # copy the output; it is your ADMIN_TOKEN
```

## 6. systemd service

Create `/etc/systemd/system/unknw-server.service`:

```ini
[Unit]
Description=UNKNW license server
After=network.target

[Service]
Type=simple
User=unknw
WorkingDirectory=/opt/unknw-server/app/server
Environment=PORT=8080
Environment=DB_PATH=/opt/unknw-server/data/unknw.db
Environment=ADMIN_TOKEN=PASTE_YOUR_TOKEN_HERE
ExecStart=/usr/bin/node /opt/unknw-server/app/server/server.js
Restart=on-failure
RestartSec=3
# hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/opt/unknw-server/data
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now unknw-server
sudo systemctl status unknw-server          # should be active (running)
curl -s http://127.0.0.1:8080/healthz        # -> {"ok":true}
```

The server listens on `127.0.0.1:8080` only — not exposed directly.

## 7. HTTPS reverse proxy

### Option A — Caddy (simplest, automatic TLS)

```bash
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update && sudo apt-get install -y caddy
```

Append to `/etc/caddy/Caddyfile` (a separate block — leave other sites intact):

```
api.scyde.dev {
    reverse_proxy 127.0.0.1:8080
}
```

```bash
sudo systemctl reload caddy
```

Caddy fetches the Let's Encrypt certificate automatically.

### Option B — Nginx + certbot

```bash
sudo apt-get install -y nginx certbot python3-certbot-nginx
```

`/etc/nginx/sites-available/api.scyde.dev`:

```nginx
server {
    listen 80;
    server_name api.scyde.dev;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/api.scyde.dev /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d api.scyde.dev
```

## 8. Firewall

```bash
sudo ufw allow 80
sudo ufw allow 443
# do NOT open 8080 — it stays local
```

## 9. Verify end to end

```bash
curl -s https://api.scyde.dev/healthz        # {"ok":true}

# mint a key (2 devices, 1 year)
curl -s -X POST https://api.scyde.dev/admin/keys \
  -H "X-Admin-Token: YOUR_TOKEN" -H 'Content-Type: application/json' \
  -d '{"note":"test","days":365,"maxDevices":2}'
```

In the UNKNW app: **Account & License → enter the key → Save & Activate** →
should report "License activated". `GET /admin/keys/<key>` then lists the device.

---

## Notes

- Back up `/opt/unknw-server/data/unknw.db` (it holds keys, activations, saved
  settings). A WAL file sits next to it; copy both or stop the service first.
- Rotate `ADMIN_TOKEN` by editing the unit and `systemctl restart unknw-server`.
- Revoke a key: `UPDATE licenses SET revoked=1 WHERE key='...';` via
  `sqlite3 /opt/unknw-server/data/unknw.db`.
- This deployment is independent; nothing here reads or writes any other
  project's data.
