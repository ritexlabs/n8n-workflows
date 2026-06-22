# Development Guide

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop | Latest | [docker.com](https://www.docker.com/products/docker-desktop/) |
| cloudflared | Latest | `brew install cloudflare/cloudflare/cloudflared` (macOS) |
| Git | Any | Pre-installed on macOS / Windows |

## First-Time Setup

### macOS (one command)

```bash
./scripts/setup.sh
```

This script:
1. Checks / installs Homebrew, Docker Desktop, and cloudflared.
2. Copies `.env.sample` → `.env` and generates a secure runner auth token.
3. Creates `n8n_data/` for persistent storage.
4. Guides you through Cloudflare Tunnel configuration (custom domain, random URL, or local-only).

### Windows (manual steps)

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and start it.
2. Download `cloudflared.exe` from [Cloudflare docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/) and place it somewhere in your `PATH` (e.g. `C:\Apps\cloudflared\`).
3. Copy `.env.sample` to `.env` and fill in the values (see [Configuration](#configuration)).
4. Create the data directory: `mkdir n8n_data` (or whatever path you set in `N8N_DATA_PATH`).
5. Follow the [Cloudflare setup](cloudflare.md) doc if you need external access.

## Configuration

All settings live in `.env` (copied from `.env.sample`). Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_HOST` | `localhost` | Public hostname (set to your subdomain if using Cloudflare with custom domain) |
| `N8N_PORT` | `5678` | Port n8n listens on |
| `N8N_PROTOCOL` | `http` | `http` for local, `https` for Cloudflare |
| `N8N_SECURE_COOKIE` | `false` | Set `true` when using HTTPS |
| `WEBHOOK_URL` | _(empty)_ | Full public URL for webhook callbacks |
| `N8N_EDITOR_BASE_URL` | _(empty)_ | Full public URL for the editor |
| `GENERIC_TIMEZONE` | `UTC` | Your local timezone |
| `N8N_RUNNERS_AUTH_TOKEN` | _(required)_ | Shared secret for the runner process |
| `N8N_DATA_PATH` | `./n8n_data` | Directory for n8n persistent data |
| `CLOUDFLARE_TUNNEL_NAME` | `n8n-tunnel` | Name of your Cloudflare named tunnel |
| `CLOUDFLARE_HOSTNAME` | _(empty)_ | Your subdomain — empty = random URL mode |

## Daily Commands

### macOS

```bash
# Start n8n + Cloudflare tunnel
./scripts/start.sh

# Stop everything
./scripts/stop.sh

# Start only the tunnel (n8n already running in background)
./scripts/cloudflare-tunnel.sh

# View n8n logs
docker compose logs -f n8n

# Restart n8n only
docker compose restart n8n

# Update n8n to latest image
docker compose pull && docker compose up -d

# Open a shell inside n8n container
docker exec -it $(docker ps -q --filter "ancestor=n8nio/n8n:latest") sh
```

### Windows

```cmd
REM Start everything
scripts\start.bat

REM Stop everything
scripts\stop.bat

REM Cloudflare tunnel only
scripts\cloudflare-tunnel.bat

REM View logs
docker compose logs -f n8n

REM Update n8n
docker compose pull && docker compose up -d
```

## Switching Modes

### Local only → Custom domain
1. Edit `.env`:
   - Set `N8N_HOST`, `WEBHOOK_URL`, `N8N_EDITOR_BASE_URL` to your subdomain.
   - Set `N8N_PROTOCOL=https` and `N8N_SECURE_COOKIE=true`.
   - Set `CLOUDFLARE_HOSTNAME` to your subdomain.
2. If you haven't created a named tunnel yet: run `./scripts/setup.sh` and choose option 1.
3. Restart n8n: `docker compose down && docker compose up -d`
4. Start tunnel: `./scripts/cloudflare-tunnel.sh`

### Custom domain → Random URL
1. Edit `.env`:
   - Clear `N8N_HOST`, `WEBHOOK_URL`, `N8N_EDITOR_BASE_URL`, `CLOUDFLARE_HOSTNAME`.
   - Set `N8N_PROTOCOL=http` and `N8N_SECURE_COOKIE=false`.
2. Restart n8n: `docker compose down && docker compose up -d`
3. Start tunnel: `./scripts/cloudflare-tunnel.sh`
