# n8n Local Setup

> Self-hosted [n8n](https://n8n.io) workflow automation running in Docker, with optional Cloudflare Tunnel for public HTTPS access — no public IP, no port forwarding required.

[![CI](https://github.com/ritexlabs/n8n-workflows/actions/workflows/ci.yml/badge.svg)](https://github.com/ritexlabs/n8n-workflows/actions/workflows/ci.yml)

**Free to run. Works on macOS, Windows, and Linux.**

---

## What You Get

- n8n running locally in Docker (with external task runners for JS/Python isolation).
- Optional public HTTPS via Cloudflare Tunnel:
  - **Custom domain** — stable URL like `https://n8n.example.com` (requires a Cloudflare-managed domain).
  - **Random URL** — instant `*.trycloudflare.com` URL, no login or domain needed.
- One script, [`scripts/launch.py`](scripts/launch.py), for setup, start, stop, status, and logs — identical on macOS, Windows, and Linux (Python 3, no dependencies to install).

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

## Quick Start

Requires [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine on Linux) and Python 3. Optionally [`cloudflared`](docs/cloudflare.md#part-3-install-cloudflared) for public HTTPS.

```bash
git clone https://github.com/ritexlabs/n8n-workflows.git
cd n8n-workflows
python3 scripts/launch.py setup   # creates .env, prompts for local-only / random URL / custom domain
python3 scripts/launch.py start   # starts n8n + runners (+ tunnel if configured), tails logs
```

On Windows, use `python` instead of `python3`:

```cmd
python scripts\launch.py setup
python scripts\launch.py start
```

- **Local only** — choose option 3 during setup. Open `http://localhost:5678`.
- **Random public URL** (`*.trycloudflare.com`, no account needed) — choose option 2.
- **Custom domain** (requires a Cloudflare account + domain) — choose option 1. See [docs/cloudflare.md](docs/cloudflare.md) for the full account + domain walkthrough.

Ctrl+C stops log tailing only — n8n and the tunnel keep running in the background. Run `python3 scripts/launch.py stop` to stop everything.

---

## Configuration

All settings are in `.env` (copy from `.env.sample`):

| Variable | Required | Description |
|----------|----------|-------------|
| `N8N_RUNNERS_AUTH_TOKEN` | Yes | Shared secret for the runner process. Generate: `openssl rand -hex 32` |
| `N8N_HOST` | No | Your public hostname. Leave empty for local-only. |
| `N8N_BIND_ADDRESS` | No | Host interface for the n8n port. Default `127.0.0.1` (loopback-only — keep it this way unless you deliberately want LAN access). |
| `N8N_PROTOCOL` | No | `https` when using Cloudflare, `http` for local. |
| `N8N_SECURE_COOKIE` | No | `true` when using HTTPS. |
| `WEBHOOK_URL` | No | Full public URL for webhook callbacks (same as `https://N8N_HOST/`). |
| `N8N_EDITOR_BASE_URL` | No | Same as `WEBHOOK_URL`. |
| `GENERIC_TIMEZONE` | No | Your timezone (e.g. `Asia/Kolkata`). |
| `N8N_DATA_PATH` | No | Where n8n data is stored. Default: `./n8n_data`. n8n's file-read/write nodes are separately sandboxed to `<this>/files` — they can't touch `database.sqlite` or `encryption.key` even though it's nested under the same folder. |
| `N8N_SMTP_HOST` | No | SMTP server for "forgot password" / invite emails. Leave empty to disable — no error, just no email. |
| `N8N_SMTP_USER` / `N8N_SMTP_PASS` / `N8N_SMTP_SENDER` | No | SMTP credentials. For Gmail, `N8N_SMTP_PASS` must be an [App Password](https://myaccount.google.com/apppasswords), not your account password. |
| `CLOUDFLARE_HOSTNAME` | No | Your subdomain. Leave empty for random URL mode. |
| `CLOUDFLARE_TUNNEL_NAME` | No | Name of your named tunnel. Default: `n8n-tunnel`. |

After changing any `.env` value, use `python3 scripts/launch.py restart` (not `docker compose restart`, which reuses the old container config and won't pick up the change).

---

## Daily Operations

Same commands on macOS, Windows, and Linux — use `python3` on macOS/Linux, `python` on Windows.

| Task | Command |
|------|---------|
| Start n8n + runners + tunnel, tail logs | `python3 scripts/launch.py start` |
| Stop everything (n8n, runners, tunnel) | `python3 scripts/launch.py stop` |
| Restart n8n + runners | `python3 scripts/launch.py restart` |
| Status + health check | `python3 scripts/launch.py status` |
| Tail logs on demand | `python3 scripts/launch.py logs` (add `--all` for runners too) |
| Start the tunnel only, in the foreground | `python3 scripts/launch.py tunnel` |
| Update n8n | `docker compose pull && docker compose up -d` |

`start` always brings the Cloudflare Tunnel up alongside n8n (if `cloudflared` is installed and configured), and `stop` always tears both down — there's no way to leave the tunnel running unattended after `stop`.

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
| "n8n isn't set up to send email" on forgot-password | Set `N8N_SMTP_*` in `.env` (see Configuration above), then `python3 scripts/launch.py restart` |
| Locked out and can't reset password (no SMTP configured) | `docker compose exec n8n n8n user-management:reset`, then restart — this only clears the user table, not workflows/credentials, and you'll get the owner setup screen again |

Full details: [docs/cloudflare.md → Troubleshooting](docs/cloudflare.md#troubleshooting)

---

## Documentation

- [Architecture](docs/architecture.md) — component diagram and data flow
- [Development Guide](docs/development.md) — setup, daily commands, switching modes
- [Cloudflare Tunnel](docs/cloudflare.md) — detailed setup for macOS and Windows
- [Deployment](docs/deployment.md) — backups, auto-start, migration to VPS

---

## Security

- Never commit `.env` — it contains your runner auth token. It's gitignored and should be `chmod 600` (done automatically by `launch.py setup`).
- n8n's port is bound to `127.0.0.1` by default (`N8N_BIND_ADDRESS` in `.env`) — it's reachable only from this machine and through the Cloudflare Tunnel, never directly from your LAN, unless you deliberately opt in.
- `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` and `N8N_DIAGNOSTICS_ENABLED=false` are set in `docker-compose.yml` so workflow Code nodes can't read host environment variables and n8n doesn't phone home telemetry.
- Both containers run with `no-new-privileges`, `cap_drop: ALL`, and are not exposed beyond the ports documented in [docs/architecture.md](docs/architecture.md#ports). Neither container mounts the Docker socket.
- Back up `n8n_data/encryption.key` — without it, stored credentials cannot be decrypted. The `n8n_data/` directory is `chmod 700`.
- **The Cloudflare Tunnel exposes n8n's login page to the entire internet** (that's the point of a tunnel). n8n's own login screen is the only thing standing between a stranger and your workflows once they have the URL — a leaked/guessed URL plus a weak owner password is a real path in. For anything beyond quick testing with the random-URL mode, add [Cloudflare Zero Trust Access](docs/cloudflare.md#optional-cloudflare-zero-trust-access) in front of n8n — it gates every request behind Google/GitHub/email-OTP login at Cloudflare's edge, before it ever reaches n8n.
- Never set `N8N_USER_MANAGEMENT_DISABLED=true` (or otherwise disable n8n's login) on an instance reachable through the tunnel — doing so removes the only authentication layer n8n itself provides.
- Only run `docker compose pull` from this repository's own `docker-compose.yml`, which pins images to the official `n8nio/n8n` and `n8nio/runners` Docker Hub images — don't repoint it at a different registry or image.

See [.github/SECURITY.md](.github/SECURITY.md) for the vulnerability reporting policy.

---

## License

[MIT](LICENSE)
