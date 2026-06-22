# Architecture

## Overview

This setup runs n8n locally in Docker and optionally exposes it to the internet via Cloudflare Tunnel — no public IP, no port forwarding, no VPN required.

## Component Diagram

```
Browser / Webhook Caller
        |
        | HTTPS
        v
Cloudflare Edge (DNS + TLS termination)
        |
        v
cloudflared (Cloudflare Tunnel daemon)
        |  encrypted outbound connection
        v
Your Machine (macOS / Windows)
        |
        v
Docker Compose
  ├── n8n          (port 5678)  — workflow engine + editor UI
  └── n8n-runners              — isolated JS/Python execution sandbox
```

## Components

### n8n
- Image: `n8nio/n8n:latest`
- Runs the workflow engine and the browser-based editor.
- Persists all data (workflows, credentials, execution history) to `n8n_data/` on the host.
- Configured via environment variables loaded from `.env`.

### n8n-runners
- Image: `n8nio/runners:latest`
- Runs user-written JavaScript and Python code nodes in an isolated child process, separate from the main n8n process.
- Communicates with n8n over a local TCP broker port (default `5679`).
- Configuration for allowed builtins and timeouts is in `n8n-task-runners.json`.

### Cloudflare Tunnel (`cloudflared`)
- Runs on the host (not inside Docker).
- Opens an outbound encrypted connection to Cloudflare's edge — no inbound firewall rules needed.
- Two modes:
  - **Named tunnel** (custom domain): requires one-time setup; gives a stable HTTPS URL at your subdomain.
  - **Anonymous tunnel** (random URL): no login needed; gives a new `*.trycloudflare.com` URL each time.

## Data Flow — Webhook Example

```
External Service  →  POST https://n8n.example.com/webhook/...
                   →  Cloudflare edge (TLS)
                   →  cloudflared (tunnel)
                   →  http://localhost:5678/webhook/...
                   →  n8n processes the workflow
```

## Ports

| Port | Service | Note |
|------|---------|------|
| 5678 | n8n editor + webhook receiver | Exposed to host; Cloudflare tunnels to this |
| 5679 | n8n runner broker | Internal only — not exposed to host |
| 5681 | JS runner health check | Internal only |
| 5682 | Python runner health check | Internal only |

## Data Persistence

n8n stores everything in a single directory mounted at `/home/node/.n8n` inside the container.
The host path is controlled by `N8N_DATA_PATH` in `.env` (default: `./n8n_data`).

This directory contains:
- `database.sqlite` — all workflows, credentials, executions
- `encryption.key` — encryption key for stored credentials (back this up!)
- `config` — n8n settings

**Back up `n8n_data/` regularly**, especially `encryption.key`. Without it, stored credentials cannot be decrypted.
