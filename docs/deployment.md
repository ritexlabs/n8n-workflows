# Deployment Guide

This repository is designed for **local self-hosting** — n8n runs in Docker on your own machine and is optionally exposed via Cloudflare Tunnel.

## Production Checklist

Before treating this setup as production-ready:

- [ ] `N8N_RUNNERS_AUTH_TOKEN` is a strong random secret (32+ hex chars). Generate with: `openssl rand -hex 32`
- [ ] `N8N_SECURE_COOKIE=true` — required when running over HTTPS.
- [ ] `N8N_PROTOCOL=https` and `WEBHOOK_URL` point to your public domain.
- [ ] `n8n_data/` is backed up regularly, especially `n8n_data/encryption.key`.
- [ ] Cloudflare SSL/TLS mode set to **Full** or **Full (Strict)**.
- [ ] Cloudflare Zero Trust Access configured (optional but recommended — see [cloudflare.md](cloudflare.md)).
- [ ] Docker Compose restart policy is `always` (already set in `docker-compose.yml`).

## Updating n8n

```bash
# Pull latest images and restart
docker compose pull
docker compose up -d
```

n8n applies database migrations automatically on startup.

## Backing Up

```bash
# Stop n8n before backup to avoid corruption
docker compose stop n8n

# Archive the data directory
tar -czf n8n-backup-$(date +%Y%m%d).tar.gz n8n_data/

# Start n8n again
docker compose start n8n
```

Restore by extracting the archive over `n8n_data/` and restarting.

## Starting on Login (macOS)

To have n8n start automatically when you log in:

1. Open **System Settings → General → Login Items**.
2. Add **Docker Desktop** so the daemon starts automatically.
3. Create a Launch Agent to run `./scripts/start.sh` at login — or simply add it to a login item script.

Alternatively, use a launchd plist (requires the Docker daemon to be running first):

```xml
<!-- ~/Library/LaunchAgents/com.n8n.local.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.n8n.local</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/path/to/n8n-workflows/scripts/start.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/n8n-start.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/n8n-start.err</string>
</dict>
</plist>
```

Load it with: `launchctl load ~/Library/LaunchAgents/com.n8n.local.plist`

## Starting on Boot (Windows)

1. Press `Win + R`, type `shell:startup`, press Enter.
2. Create a shortcut to `scripts\start.bat` in that folder.

## Migrating to a VPS / Cloud

The workflow data in `n8n_data/` is fully portable. To migrate:

1. Back up `n8n_data/` from the local machine.
2. Copy it to the VPS.
3. Install Docker on the VPS.
4. Clone this repository and set up `.env` with the new domain.
5. `docker compose up -d` — n8n reads the existing data directory.

No Cloudflare Tunnel needed on a VPS (use a reverse proxy like Nginx + Let's Encrypt instead), but you can keep using it if preferred.
