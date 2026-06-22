#!/usr/bin/env bash
# Stops n8n Docker containers and any running cloudflared tunnel processes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}[ok]${RESET} $*"; }
info() { echo -e "${BLUE}[--]${RESET} $*"; }
warn() { echo -e "${YELLOW}[!!]${RESET} $*"; }

# ─── Stop cloudflared ────────────────────────────────────────────────────────
if pgrep -x cloudflared &>/dev/null; then
  info "Stopping cloudflared tunnel..."
  pkill -x cloudflared || true
  ok "cloudflared stopped."
else
  info "No cloudflared process found."
fi

# ─── Stop n8n ────────────────────────────────────────────────────────────────
if ! docker info &>/dev/null 2>&1; then
  warn "Docker is not running — nothing to stop."
  exit 0
fi

echo ""
echo -e "${BOLD}Stopping n8n...${RESET}"
cd "$ROOT_DIR"
docker compose down
ok "n8n stopped."
echo ""
