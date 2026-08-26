# Development Guide

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Docker Desktop (or Docker Engine on Linux) | Latest | [docker.com](https://www.docker.com/products/docker-desktop/) |
| Python | 3.8+ | Pre-installed on macOS / most Linux; [python.org](https://www.python.org/downloads/) on Windows |
| cloudflared | Latest (optional) | `brew install cloudflare/cloudflare/cloudflared` (macOS) — see [cloudflare.md](cloudflare.md) for Windows/Linux |
| Git | Any | Pre-installed on macOS / Windows |

## First-Time Setup

Same command on every platform — `python3` on macOS/Linux, `python` on Windows:

```bash
python3 scripts/launch.py setup
```

This:
1. Checks that Docker (and, optionally, `cloudflared`) are installed.
2. Copies `.env.sample` → `.env` and generates a secure runner auth token (`chmod 600` on macOS/Linux).
3. Creates `n8n_data/` for persistent storage (`chmod 700` on macOS/Linux).
4. Guides you through Cloudflare Tunnel configuration (custom domain, random URL, or local-only).

## Configuration

All settings live in `.env` (copied from `.env.sample`). Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `N8N_HOST` | `localhost` | Public hostname (set to your subdomain if using Cloudflare with custom domain) |
| `N8N_PORT` | `5678` | Port n8n listens on |
| `N8N_BIND_ADDRESS` | `127.0.0.1` | Host interface the n8n port is published on. Keep at `127.0.0.1` unless you intentionally want LAN access. |
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

Identical on macOS, Windows, and Linux (`python3` vs `python`):

```bash
# Start n8n + runners + tunnel (if configured), then tail n8n logs
# Ctrl+C stops tailing only — everything keeps running in the background
python3 scripts/launch.py start

# Stop n8n, runners, and the Cloudflare tunnel — all of it
python3 scripts/launch.py stop

# Restart n8n + runners (recreates the container, so .env edits take effect)
python3 scripts/launch.py restart

# Container + tunnel status and a local health check
python3 scripts/launch.py status

# Tail logs on demand (add --all for runners too, -n N for history)
python3 scripts/launch.py logs

# Start only the tunnel, in the foreground (n8n assumed already running)
python3 scripts/launch.py tunnel

# Update n8n to latest image
docker compose pull && docker compose up -d

# Open a shell inside n8n container
docker exec -it $(docker ps -q --filter "ancestor=n8nio/n8n:latest") sh
```

## Switching Modes

### Local only → Custom domain
1. Edit `.env`:
   - Set `N8N_HOST`, `WEBHOOK_URL`, `N8N_EDITOR_BASE_URL` to your subdomain.
   - Set `N8N_PROTOCOL=https` and `N8N_SECURE_COOKIE=true`.
   - Set `CLOUDFLARE_HOSTNAME` to your subdomain.
2. If you haven't created a named tunnel yet: run `python3 scripts/launch.py setup` and choose option 1.
3. Restart everything: `python3 scripts/launch.py stop && python3 scripts/launch.py start`

### Custom domain → Random URL
1. Edit `.env`:
   - Clear `N8N_HOST`, `WEBHOOK_URL`, `N8N_EDITOR_BASE_URL`, `CLOUDFLARE_HOSTNAME`.
   - Set `N8N_PROTOCOL=http` and `N8N_SECURE_COOKIE=false`.
2. Restart everything: `python3 scripts/launch.py stop && python3 scripts/launch.py start`
