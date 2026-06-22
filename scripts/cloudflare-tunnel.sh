#!/usr/bin/env bash
# Starts a Cloudflare Tunnel for n8n.
#
# Behaviour:
#   - If CLOUDFLARE_HOSTNAME is set in .env → named tunnel with your custom domain.
#   - If CLOUDFLARE_HOSTNAME is empty       → anonymous tunnel with random *.trycloudflare.com URL.
#
# Named tunnel requires prior one-time setup (run ./scripts/setup.sh first).
# Anonymous tunnel needs no Cloudflare account or login.

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

if ! command -v cloudflared &>/dev/null; then
  fail "cloudflared not found. Install it with: brew install cloudflare/cloudflare/cloudflared"
fi

# Load .env if it exists
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT_DIR/.env"
  set +a
fi

LOCAL_PORT="${N8N_PORT:-5678}"
CLOUDFLARE_HOSTNAME="${CLOUDFLARE_HOSTNAME:-}"
TUNNEL_NAME="${CLOUDFLARE_TUNNEL_NAME:-n8n-tunnel}"

if [ -n "$CLOUDFLARE_HOSTNAME" ]; then
  # ── Named tunnel (custom domain) ──────────────────────────────────────────
  echo ""
  echo -e "${BOLD}Starting Cloudflare Tunnel (custom domain)${RESET}"
  info "Tunnel name: $TUNNEL_NAME"
  info "Public URL:  https://$CLOUDFLARE_HOSTNAME"
  echo ""
  warn "Keep this terminal open. Press Ctrl+C to stop."
  echo ""
  cloudflared tunnel run "$TUNNEL_NAME"
else
  # ── Anonymous tunnel (random URL) ─────────────────────────────────────────
  echo ""
  echo -e "${BOLD}Starting Cloudflare Tunnel (random URL)${RESET}"
  info "Tunnelling: http://localhost:$LOCAL_PORT"
  info "Cloudflare will print the assigned public URL below."
  echo ""
  warn "The URL changes every time you start this tunnel."
  warn "For persistent webhooks, configure a custom domain in .env and re-run ./scripts/setup.sh"
  warn "Keep this terminal open. Press Ctrl+C to stop."
  echo ""
  cloudflared tunnel --url "http://localhost:$LOCAL_PORT"
fi
