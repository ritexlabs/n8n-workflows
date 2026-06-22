# n8n Local Setup

> Self-hosted [n8n](https://n8n.io) workflow automation running in Docker, with optional Cloudflare Tunnel for public HTTPS access — no public IP, no port forwarding required.

[![CI](https://github.com/ritexlabs/n8n-workflows/actions/workflows/ci.yml/badge.svg)](https://github.com/ritexlabs/n8n-workflows/actions/workflows/ci.yml)

**Free to run. Works on macOS and Windows.**

---

## What You Get

- n8n running locally in Docker (with external task runners for JS/Python isolation).
- Optional public HTTPS via Cloudflare Tunnel:
  - **Custom domain** — stable URL like `https://n8n.example.com` (requires a Cloudflare-managed domain).
  - **Random URL** — instant `*.trycloudflare.com` URL, no login or domain needed.
- One-script setup and start for macOS and Windows.

---

## Architecture

```
Browser / Webhook Caller
        │
        │ HTTPS
        ▼
Cloudflare Edge (DNS + TLS)
        │
        ▼
cloudflared (tunnel daemon on your machine)
        │
        ▼
Docker Compose
  ├── n8n          (localhost:5678)  — editor + webhook engine
  └── n8n-runners                   — isolated JS/Python sandbox
```

See [docs/architecture.md](docs/architecture.md) for details.

---

## Quick Start — macOS

### Option A: Local only (no public URL)

```bash
git clone https://github.com/ritexlabs/n8n-workflows.git
cd n8n-workflows
./scripts/setup.sh        # choose option 3 (local only)
./scripts/start.sh
```

Open `http://localhost:5678`.

### Option B: Public URL with custom domain

Requires a Cloudflare account and a domain managed in Cloudflare DNS.
See [docs/cloudflare.md](docs/cloudflare.md) for the full account + domain setup guide.

```bash
./scripts/setup.sh        # choose option 1, follow prompts
./scripts/start.sh        # starts n8n + Cloudflare tunnel
```

Open `https://your-subdomain.example.com`.

### Option C: Public URL with random trycloudflare.com address

No domain or Cloudflare account needed.

```bash
./scripts/setup.sh        # choose option 2
./scripts/start.sh        # prints your random URL in the terminal
```

---

## Quick Start — Windows

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and start it.
2. Download `cloudflared.exe` and add it to your PATH — see [docs/cloudflare.md → Part 3](docs/cloudflare.md#part-3-install-cloudflared).
3. Copy `.env.sample` to `.env` and fill in your values (at minimum, set `N8N_RUNNERS_AUTH_TOKEN`).
4. Double-click `scripts\start.bat`.

For the full Cloudflare account, domain, and tunnel setup on Windows, see [docs/cloudflare.md](docs/cloudflare.md).

---

## Configuration

All settings are in `.env` (copy from `.env.sample`):

| Variable | Required | Description |
|----------|----------|-------------|
| `N8N_RUNNERS_AUTH_TOKEN` | Yes | Shared secret for the runner process. Generate: `openssl rand -hex 32` |
| `N8N_HOST` | No | Your public hostname. Leave empty for local-only. |
| `N8N_PROTOCOL` | No | `https` when using Cloudflare, `http` for local. |
| `N8N_SECURE_COOKIE` | No | `true` when using HTTPS. |
| `WEBHOOK_URL` | No | Full public URL for webhook callbacks (same as `https://N8N_HOST/`). |
| `N8N_EDITOR_BASE_URL` | No | Same as `WEBHOOK_URL`. |
| `GENERIC_TIMEZONE` | No | Your timezone (e.g. `Asia/Kolkata`). |
| `N8N_DATA_PATH` | No | Where n8n data is stored. Default: `./n8n_data`. |
| `CLOUDFLARE_HOSTNAME` | No | Your subdomain. Leave empty for random URL mode. |
| `CLOUDFLARE_TUNNEL_NAME` | No | Name of your named tunnel. Default: `n8n-tunnel`. |

---

## Daily Operations

### macOS

| Task | Command |
|------|---------|
| Start n8n + tunnel | `./scripts/start.sh` |
| Stop everything | `./scripts/stop.sh` |
| Start tunnel only | `./scripts/cloudflare-tunnel.sh` |
| View logs | `docker compose logs -f n8n` |
| Restart n8n | `docker compose restart n8n` |
| Update n8n | `docker compose pull && docker compose up -d` |

### Windows

| Task | Command |
|------|---------|
| Start n8n + tunnel | `scripts\start.bat` |
| Stop everything | `scripts\stop.bat` |
| Start tunnel only | `scripts\cloudflare-tunnel.bat` |
| View logs | `docker compose logs -f n8n` |
| Update n8n | `docker compose pull && docker compose up -d` |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `HTTP 530` from Cloudflare | `cloudflared` is not running, or DNS CNAME points to a deleted tunnel — see [Troubleshooting](docs/cloudflare.md#troubleshooting) |
| `503 No ingress rules` in tunnel logs | `~/.cloudflared/config.yml` is missing — see [Part 6](docs/cloudflare.md#part-6-create-the-cloudflare-config-file) |
| `tunnel is neither ID nor name` error | Tunnel name in `.env` doesn't match — run `cloudflared tunnel list` to find the correct name |
| DNS error 1003 on `tunnel route dns` | Delete the existing CNAME in Cloudflare Dashboard → DNS first, then re-run the command |
| Webhooks show `localhost` | Set `WEBHOOK_URL=https://your-domain.com/` in `.env` and restart n8n |
| SSL redirect loop | Cloudflare → SSL/TLS → set mode to **Full** or **Full (Strict)** |
| `cert.pem` not found | Run `cloudflared tunnel login` on this machine first |

Full details: [docs/cloudflare.md → Troubleshooting](docs/cloudflare.md#troubleshooting)

---

## Documentation

- [Architecture](docs/architecture.md) — component diagram and data flow
- [Development Guide](docs/development.md) — setup, daily commands, switching modes
- [Cloudflare Tunnel](docs/cloudflare.md) — detailed setup for macOS and Windows
- [Deployment](docs/deployment.md) — backups, auto-start, migration to VPS

---

## Security

- Never commit `.env` — it contains your runner auth token.
- Back up `n8n_data/encryption.key` — without it, stored credentials cannot be decrypted.
- Consider adding [Cloudflare Zero Trust Access](docs/cloudflare.md#optional-cloudflare-zero-trust-access) for extra authentication.

See [.github/SECURITY.md](.github/SECURITY.md) for the vulnerability reporting policy.

---

## License

[MIT](LICENSE)
