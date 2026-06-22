#!/usr/bin/env bash
# One-time setup for macOS: installs dependencies, creates .env, configures Cloudflare.

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
step() { echo -e "\n${BOLD}==> $*${RESET}"; }

# ─── Homebrew ────────────────────────────────────────────────────────────────
step "Checking Homebrew"
if command -v brew &>/dev/null; then
  ok "Homebrew found: $(brew --version | head -1)"
else
  warn "Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "Homebrew installed."
fi

# ─── Docker ──────────────────────────────────────────────────────────────────
step "Checking Docker"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  ok "Docker is running: $(docker --version)"
else
  if command -v docker &>/dev/null; then
    warn "Docker is installed but not running. Opening Docker Desktop..."
    open -a Docker 2>/dev/null || warn "Could not open Docker Desktop automatically. Please start it manually."
    info "Waiting for Docker to start (up to 60 seconds)..."
    for i in $(seq 1 12); do
      sleep 5
      if docker info &>/dev/null 2>&1; then
        ok "Docker is now running."
        break
      fi
      if [ "$i" -eq 12 ]; then
        fail "Docker did not start in time. Please start Docker Desktop and re-run this script."
      fi
    done
  else
    warn "Docker Desktop is not installed."
    info "Download Docker Desktop from: https://www.docker.com/products/docker-desktop/"
    fail "Install Docker Desktop, start it, then re-run this script."
  fi
fi

# ─── cloudflared ─────────────────────────────────────────────────────────────
step "Checking cloudflared"
if command -v cloudflared &>/dev/null; then
  ok "cloudflared found: $(cloudflared --version)"
else
  info "Installing cloudflared via Homebrew..."
  brew install cloudflare/cloudflare/cloudflared
  ok "cloudflared installed."
fi

# ─── .env file ───────────────────────────────────────────────────────────────
step "Setting up .env"
ENV_FILE="$ROOT_DIR/.env"
SAMPLE_FILE="$ROOT_DIR/.env.sample"

if [ -f "$ENV_FILE" ]; then
  ok ".env already exists — skipping copy."
else
  cp "$SAMPLE_FILE" "$ENV_FILE"
  ok ".env created from .env.sample."

  # Generate a random runner auth token
  if command -v openssl &>/dev/null; then
    TOKEN=$(openssl rand -hex 32)
    sed -i '' "s|^N8N_RUNNERS_AUTH_TOKEN=.*|N8N_RUNNERS_AUTH_TOKEN=$TOKEN|" "$ENV_FILE"
    ok "Generated N8N_RUNNERS_AUTH_TOKEN in .env."
  else
    warn "openssl not found. Set N8N_RUNNERS_AUTH_TOKEN manually in .env."
  fi
fi

# ─── Data directory ───────────────────────────────────────────────────────────
step "Creating n8n data directory"
mkdir -p "$ROOT_DIR/n8n_data"
ok "n8n_data/ directory ready."

# ─── Cloudflare Tunnel setup ─────────────────────────────────────────────────
step "Cloudflare Tunnel setup"
echo ""
echo "How do you want to expose n8n publicly?"
echo "  1) Custom domain  (requires a domain managed in Cloudflare)"
echo "  2) Random URL     (free *.trycloudflare.com — no domain or login needed)"
echo "  3) Skip           (local access only — http://localhost:5678)"
echo ""
read -rp "Enter choice [1/2/3]: " CF_CHOICE

case "$CF_CHOICE" in
  1)
    info "You chose custom domain setup."
    echo ""
    read -rp "Enter your tunnel hostname (e.g. n8n.example.com): " CF_HOSTNAME
    read -rp "Enter a tunnel name (default: n8n-tunnel): " CF_TUNNEL_NAME
    CF_TUNNEL_NAME="${CF_TUNNEL_NAME:-n8n-tunnel}"

    info "Logging in to Cloudflare — a browser window will open..."
    cloudflared tunnel login

    info "Creating tunnel: $CF_TUNNEL_NAME"
    cloudflared tunnel create "$CF_TUNNEL_NAME"

    info "Routing tunnel to hostname: $CF_HOSTNAME"
    cloudflared tunnel route dns "$CF_TUNNEL_NAME" "$CF_HOSTNAME"

    # Update .env
    sed -i '' "s|^N8N_HOST=.*|N8N_HOST=$CF_HOSTNAME|" "$ENV_FILE"
    sed -i '' "s|^N8N_PROTOCOL=.*|N8N_PROTOCOL=https|" "$ENV_FILE"
    sed -i '' "s|^N8N_SECURE_COOKIE=.*|N8N_SECURE_COOKIE=true|" "$ENV_FILE"
    sed -i '' "s|^WEBHOOK_URL=.*|WEBHOOK_URL=https://$CF_HOSTNAME/|" "$ENV_FILE"
    sed -i '' "s|^N8N_EDITOR_BASE_URL=.*|N8N_EDITOR_BASE_URL=https://$CF_HOSTNAME/|" "$ENV_FILE"
    sed -i '' "s|^CLOUDFLARE_TUNNEL_NAME=.*|CLOUDFLARE_TUNNEL_NAME=$CF_TUNNEL_NAME|" "$ENV_FILE"
    sed -i '' "s|^CLOUDFLARE_HOSTNAME=.*|CLOUDFLARE_HOSTNAME=$CF_HOSTNAME|" "$ENV_FILE"

    ok "Tunnel '$CF_TUNNEL_NAME' configured for https://$CF_HOSTNAME"
    info "Run ./scripts/start.sh to launch n8n and the tunnel."
    ;;

  2)
    info "Random URL mode selected — no configuration needed."
    info "Each time you start the tunnel a new *.trycloudflare.com URL is assigned."
    warn "Webhook URLs will use localhost in this mode. Use a custom domain for persistent webhooks."
    # Make sure .env has local settings for random mode
    sed -i '' "s|^N8N_HOST=.*|N8N_HOST=localhost|" "$ENV_FILE"
    sed -i '' "s|^N8N_PROTOCOL=.*|N8N_PROTOCOL=http|" "$ENV_FILE"
    sed -i '' "s|^N8N_SECURE_COOKIE=.*|N8N_SECURE_COOKIE=false|" "$ENV_FILE"
    sed -i '' "s|^WEBHOOK_URL=.*|WEBHOOK_URL=|" "$ENV_FILE"
    sed -i '' "s|^N8N_EDITOR_BASE_URL=.*|N8N_EDITOR_BASE_URL=|" "$ENV_FILE"
    sed -i '' "s|^CLOUDFLARE_HOSTNAME=.*|CLOUDFLARE_HOSTNAME=|" "$ENV_FILE"
    ok "Configured for random tunnel mode."
    info "Run ./scripts/start.sh to launch n8n and get your public URL."
    ;;

  3)
    info "Skipping Cloudflare setup. n8n will be available at http://localhost:5678 only."
    sed -i '' "s|^N8N_HOST=.*|N8N_HOST=localhost|" "$ENV_FILE"
    sed -i '' "s|^N8N_PROTOCOL=.*|N8N_PROTOCOL=http|" "$ENV_FILE"
    sed -i '' "s|^N8N_SECURE_COOKIE=.*|N8N_SECURE_COOKIE=false|" "$ENV_FILE"
    sed -i '' "s|^WEBHOOK_URL=.*|WEBHOOK_URL=|" "$ENV_FILE"
    sed -i '' "s|^N8N_EDITOR_BASE_URL=.*|N8N_EDITOR_BASE_URL=|" "$ENV_FILE"
    sed -i '' "s|^CLOUDFLARE_HOSTNAME=.*|CLOUDFLARE_HOSTNAME=|" "$ENV_FILE"
    info "Run ./scripts/start.sh to launch n8n."
    ;;

  *)
    warn "Invalid choice. Run ./scripts/setup.sh again to configure Cloudflare."
    ;;
esac

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}Setup complete.${RESET}"
echo ""
echo "  Start n8n:     ./scripts/start.sh"
echo "  Stop n8n:      ./scripts/stop.sh"
echo "  Edit config:   $ENV_FILE"
echo ""
