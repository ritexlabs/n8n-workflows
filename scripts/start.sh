#!/usr/bin/env bash
# Starts n8n via Docker Compose and optionally launches a Cloudflare Tunnel.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}[ok]${RESET} $*"; }
info() { echo -e "${BLUE}[--]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!!]${RESET} $*"; }
fail() { echo -e "${RED}[!!]${RESET} $*"; exit 1; }

# ─── Pre-flight ───────────────────────────────────────────────────────────────
if [ ! -f "$ROOT_DIR/.env" ]; then
  fail ".env not found. Run ./scripts/setup.sh first."
fi

if ! docker info &>/dev/null 2>&1; then
  warn "Docker is not running. Attempting to start Docker Desktop..."
  open -a Docker 2>/dev/null || fail "Could not start Docker Desktop. Please start it manually."
  echo -n "Waiting for Docker"
  for i in $(seq 1 12); do
    sleep 5
    echo -n "."
    if docker info &>/dev/null 2>&1; then
      echo ""
      ok "Docker is running."
      break
    fi
    if [ "$i" -eq 12 ]; then
      echo ""
      fail "Docker did not start. Please start Docker Desktop and re-run this script."
    fi
  done
fi

# ─── Source .env ─────────────────────────────────────────────────────────────
set -a
# shellcheck source=/dev/null
source "$ROOT_DIR/.env"
set +a

# ─── Start n8n ───────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Starting n8n...${RESET}"
cd "$ROOT_DIR"
docker compose up -d
ok "n8n started."

LOCAL_PORT="${N8N_PORT:-5678}"
info "Local access: http://localhost:$LOCAL_PORT"

# ─── Cloudflare Tunnel ───────────────────────────────────────────────────────
CLOUDFLARE_HOSTNAME="${CLOUDFLARE_HOSTNAME:-}"

if [ -z "$CLOUDFLARE_HOSTNAME" ]; then
  echo ""
  echo -e "${BOLD}Cloudflare Tunnel (random URL mode)${RESET}"

  if ! command -v cloudflared &>/dev/null; then
    warn "cloudflared not found. Skipping tunnel. Install it with: brew install cloudflare/cloudflare/cloudflared"
    echo ""
    echo -e "${GREEN}${BOLD}n8n is running at:${RESET} http://localhost:$LOCAL_PORT"
    exit 0
  fi

  info "Launching tunnel — Cloudflare will assign a random public URL..."
  info "Press Ctrl+C to stop the tunnel (n8n will keep running in Docker)."
  echo ""
  # Run in foreground so user can see the assigned URL in the logs
  cloudflared tunnel --url "http://localhost:$LOCAL_PORT"
else
  TUNNEL_NAME="${CLOUDFLARE_TUNNEL_NAME:-n8n-tunnel}"
  echo ""
  echo -e "${BOLD}Starting Cloudflare Tunnel: $TUNNEL_NAME${RESET}"
  info "Public URL: https://$CLOUDFLARE_HOSTNAME"
  info "Press Ctrl+C to stop the tunnel (n8n will keep running in Docker)."
  echo ""
  cloudflared tunnel run "$TUNNEL_NAME"
fi
