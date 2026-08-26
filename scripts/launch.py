#!/usr/bin/env python3
"""Cross-platform lifecycle manager for the local n8n stack.

Single entrypoint (macOS / Windows / Linux, stdlib only) replacing the old
per-platform shell/batch scripts. Manages n8n + runners via Docker Compose
and the optional Cloudflare Tunnel.
"""

import argparse
import os
import platform
import re
import secrets
import shutil
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENV_FILE = ROOT / ".env"
SAMPLE_FILE = ROOT / ".env.sample"
DATA_DIR = ROOT / "n8n_data"
TUNNEL_LOG = ROOT / ".cloudflared-tunnel.log"

IS_WINDOWS = platform.system() == "Windows"
IS_MACOS = platform.system() == "Darwin"

# ─── Output helpers ──────────────────────────────────────────────────────────

_USE_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None
_COLORS = {"red": "\033[0;31m", "green": "\033[0;32m", "yellow": "\033[1;33m",
           "blue": "\033[0;34m", "bold": "\033[1m", "reset": "\033[0m"}


def _c(color, text):
    return f"{_COLORS[color]}{text}{_COLORS['reset']}" if _USE_COLOR else text


def ok(msg):
    print(f"{_c('green', '[ok]')} {msg}")


def info(msg):
    print(f"{_c('blue', '[--]')} {msg}")


def warn(msg):
    print(f"{_c('yellow', '[!!]')} {msg}")


def fail(msg):
    print(f"{_c('red', '[!!]')} {msg}")
    sys.exit(1)


def bold(msg):
    return _c("bold", msg)


def step(msg):
    print(f"\n{bold('==> ' + msg)}")


def enable_ansi_on_windows():
    if not IS_WINDOWS:
        return
    try:
        import ctypes
        kernel32 = ctypes.windll.kernel32
        kernel32.SetConsoleMode(kernel32.GetStdHandle(-11), 7)
    except Exception:
        pass


def unbuffer_stdout():
    # Interleaved print()/subprocess output (e.g. status) needs this — otherwise
    # print() is fully buffered when stdout isn't a tty and appears out of order.
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except Exception:
        pass


# ─── .env handling ───────────────────────────────────────────────────────────

def load_env():
    env = {}
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def set_env_value(key, value):
    text = ENV_FILE.read_text()
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
    if pattern.search(text):
        text = pattern.sub(f"{key}={value}", text)
    else:
        text = text.rstrip("\n") + f"\n{key}={value}\n"
    ENV_FILE.write_text(text)


def require_env():
    if not ENV_FILE.exists():
        fail(".env not found. Run: python3 scripts/launch.py setup")
    if not IS_WINDOWS:
        try:
            mode = oct(ENV_FILE.stat().st_mode)[-3:]
            if mode != "600":
                warn(f".env permissions are {mode} — it holds the runner auth token. "
                     f"Recommended: chmod 600 {ENV_FILE.name}")
        except OSError:
            pass


# ─── Docker helpers ───────────────────────────────────────────────────────────

def docker_available():
    return shutil.which("docker") is not None


def docker_running():
    try:
        r = subprocess.run(["docker", "info"], cwd=ROOT,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return r.returncode == 0
    except FileNotFoundError:
        return False


def wait_for_docker():
    print("Waiting for Docker", end="", flush=True)
    for i in range(12):
        time.sleep(5)
        print(".", end="", flush=True)
        if docker_running():
            print()
            ok("Docker is running.")
            return
    print()
    fail("Docker did not start in time. Please start Docker Desktop and re-run this script.")


def ensure_docker_running():
    if not docker_available():
        fail("Docker not found. Install Docker Desktop: https://www.docker.com/products/docker-desktop/")
    if docker_running():
        return
    if IS_MACOS:
        warn("Docker is not running. Attempting to start Docker Desktop...")
        subprocess.Popen(["open", "-a", "Docker"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        wait_for_docker()
    elif IS_WINDOWS:
        fail("Docker is not running. Please start Docker Desktop and try again.")
    else:
        fail("Docker is not running. Start it with: sudo systemctl start docker")


def compose(args, capture=False):
    cmd = ["docker", "compose"] + args
    if capture:
        return subprocess.run(cmd, cwd=ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    return subprocess.run(cmd, cwd=ROOT)


# ─── Cloudflare Tunnel helpers ────────────────────────────────────────────────

def cloudflared_available():
    return shutil.which("cloudflared") is not None


def tunnel_running():
    if IS_WINDOWS:
        r = subprocess.run(["tasklist", "/FI", "IMAGENAME eq cloudflared.exe"],
                            capture_output=True, text=True)
        return "cloudflared.exe" in r.stdout
    if shutil.which("pgrep"):
        return subprocess.run(["pgrep", "-x", "cloudflared"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    return False


def build_tunnel_cmd(env):
    hostname = env.get("CLOUDFLARE_HOSTNAME", "").strip()
    if hostname:
        tunnel_name = env.get("CLOUDFLARE_TUNNEL_NAME", "").strip() or "n8n-tunnel"
        return ["cloudflared", "tunnel", "run", tunnel_name], True
    bind = env.get("N8N_BIND_ADDRESS", "").strip() or "127.0.0.1"
    port = env.get("N8N_PORT", "").strip() or "5678"
    return ["cloudflared", "tunnel", "--url", f"http://{bind}:{port}"], False


def start_tunnel_background(env):
    """Spawn cloudflared detached from this process, logging to TUNNEL_LOG."""
    cmd, named = build_tunnel_cmd(env)
    popen_kwargs = {"cwd": ROOT, "stderr": subprocess.STDOUT}
    if IS_WINDOWS:
        popen_kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        popen_kwargs["start_new_session"] = True
    with open(TUNNEL_LOG, "w") as log_f:
        popen_kwargs["stdout"] = log_f
        subprocess.Popen(cmd, **popen_kwargs)

    info("Starting Cloudflare Tunnel...")
    if named:
        info(f"Public URL: https://{env.get('CLOUDFLARE_HOSTNAME')}")
        return
    url = None
    for _ in range(20):
        time.sleep(0.5)
        text = TUNNEL_LOG.read_text(errors="ignore") if TUNNEL_LOG.exists() else ""
        m = re.search(r"https://[a-zA-Z0-9-]+\.trycloudflare\.com", text)
        if m:
            url = m.group(0)
            break
    if url:
        ok(f"Public URL: {url}")
    else:
        warn(f"Tunnel starting — URL not detected yet. Check {TUNNEL_LOG.name}")


def stop_tunnel():
    if not tunnel_running():
        info("No Cloudflare Tunnel process found.")
        return
    info("Stopping Cloudflare Tunnel...")
    if IS_WINDOWS:
        subprocess.run(["taskkill", "/F", "/IM", "cloudflared.exe"],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.run(["pkill", "-x", "cloudflared"],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok("Cloudflare Tunnel stopped.")


# ─── Health check ─────────────────────────────────────────────────────────────

def health_check(url, timeout=3):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return None


# ─── Commands ─────────────────────────────────────────────────────────────────

def cmd_setup(_args):
    step("Checking prerequisites")
    if not docker_available():
        fail("Docker not found. Install Docker Desktop: https://www.docker.com/products/docker-desktop/")
    ok("Docker found.")

    if cloudflared_available():
        ok("cloudflared found.")
    else:
        warn("cloudflared not found. Install it if you want a public HTTPS URL:")
        info("  macOS:   brew install cloudflare/cloudflare/cloudflared")
        info("  Windows: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/")
        info("  Linux:   https://pkg.cloudflare.com/")

    step("Setting up .env")
    if ENV_FILE.exists():
        ok(".env already exists — skipping copy.")
    else:
        ENV_FILE.write_text(SAMPLE_FILE.read_text())
        ok(".env created from .env.sample.")
        token = secrets.token_hex(32)
        set_env_value("N8N_RUNNERS_AUTH_TOKEN", token)
        ok("Generated N8N_RUNNERS_AUTH_TOKEN in .env.")

    if not IS_WINDOWS:
        try:
            os.chmod(ENV_FILE, 0o600)
            ok(".env permissions set to 600 (owner read/write only).")
        except OSError:
            pass

    step("Creating n8n data directory")
    DATA_DIR.mkdir(exist_ok=True)
    if not IS_WINDOWS:
        try:
            os.chmod(DATA_DIR, 0o700)
        except OSError:
            pass
    ok("n8n_data/ directory ready.")

    step("Cloudflare Tunnel setup")
    print()
    print("How do you want to expose n8n publicly?")
    print("  1) Custom domain  (requires a domain managed in Cloudflare)")
    print("  2) Random URL     (free *.trycloudflare.com — no domain required)")
    print("  3) Skip           (local access only — http://localhost:5678)")
    print()
    choice = input("Enter choice [1/2/3]: ").strip()

    if choice == "1":
        hostname = input("Enter your tunnel hostname (e.g. n8n.example.com): ").strip()
        tunnel_name = input("Enter a tunnel name (default: n8n-tunnel): ").strip() or "n8n-tunnel"

        info("Logging in to Cloudflare — a browser window will open...")
        subprocess.run(["cloudflared", "tunnel", "login"], cwd=ROOT)
        info(f"Creating tunnel: {tunnel_name}")
        subprocess.run(["cloudflared", "tunnel", "create", tunnel_name], cwd=ROOT)
        info(f"Routing tunnel to hostname: {hostname}")
        subprocess.run(["cloudflared", "tunnel", "route", "dns", tunnel_name, hostname], cwd=ROOT)

        set_env_value("N8N_HOST", hostname)
        set_env_value("N8N_PROTOCOL", "https")
        set_env_value("N8N_SECURE_COOKIE", "true")
        set_env_value("WEBHOOK_URL", f"https://{hostname}/")
        set_env_value("N8N_EDITOR_BASE_URL", f"https://{hostname}/")
        set_env_value("CLOUDFLARE_TUNNEL_NAME", tunnel_name)
        set_env_value("CLOUDFLARE_HOSTNAME", hostname)
        ok(f"Tunnel '{tunnel_name}' configured for https://{hostname}")
        info("Run: python3 scripts/launch.py start")

    elif choice == "2":
        info("Random URL mode selected — no configuration needed.")
        info("Each start assigns a new *.trycloudflare.com URL.")
        warn("Webhook URLs will use localhost in this mode. Use a custom domain for persistent webhooks.")
        set_env_value("N8N_HOST", "localhost")
        set_env_value("N8N_PROTOCOL", "http")
        set_env_value("N8N_SECURE_COOKIE", "false")
        set_env_value("WEBHOOK_URL", "")
        set_env_value("N8N_EDITOR_BASE_URL", "")
        set_env_value("CLOUDFLARE_HOSTNAME", "")
        ok("Configured for random tunnel mode.")
        info("Run: python3 scripts/launch.py start")

    elif choice == "3":
        info("Skipping Cloudflare setup. n8n will be available at http://localhost:5678 only.")
        set_env_value("N8N_HOST", "localhost")
        set_env_value("N8N_PROTOCOL", "http")
        set_env_value("N8N_SECURE_COOKIE", "false")
        set_env_value("WEBHOOK_URL", "")
        set_env_value("N8N_EDITOR_BASE_URL", "")
        set_env_value("CLOUDFLARE_HOSTNAME", "")
        info("Run: python3 scripts/launch.py start")

    else:
        warn("Invalid choice. Run 'python3 scripts/launch.py setup' again to configure Cloudflare.")

    print()
    print(f"{bold(_c('green', 'Setup complete.'))}")
    print()
    print("  Start n8n:   python3 scripts/launch.py start")
    print("  Stop n8n:    python3 scripts/launch.py stop")
    print(f"  Edit config: {ENV_FILE}")
    print()


def cmd_start(_args):
    require_env()
    ensure_docker_running()
    env = load_env()

    print()
    print(bold("Starting n8n..."))
    r = compose(["up", "-d"])
    if r.returncode != 0:
        fail("docker compose up failed.")
    ok("n8n started.")

    bind = env.get("N8N_BIND_ADDRESS", "").strip() or "127.0.0.1"
    port = env.get("N8N_PORT", "").strip() or "5678"
    info(f"Local access: http://{bind}:{port}")

    if cloudflared_available():
        start_tunnel_background(env)
    else:
        warn("cloudflared not found — skipping tunnel. See docs/cloudflare.md to install it.")

    print()
    info("Tailing n8n logs — Ctrl+C stops tailing only. n8n and the tunnel keep running.")
    info("Run 'python3 scripts/launch.py stop' to stop everything.")
    print()
    time.sleep(1)
    try:
        subprocess.run(["docker", "compose", "logs", "-f", "--tail=50", "n8n"], cwd=ROOT)
    except KeyboardInterrupt:
        print()
        info("Stopped tailing logs.")


def cmd_stop(_args):
    stop_tunnel()

    if not docker_running():
        warn("Docker is not running — nothing to stop.")
        return

    print()
    print(bold("Stopping n8n..."))
    compose(["down"])
    ok("n8n stopped.")


def cmd_restart(_args):
    require_env()
    ensure_docker_running()
    print(bold("Restarting n8n..."))
    # `up -d` (not `restart`) so edits to .env / docker-compose.yml actually take
    # effect — `restart` just restarts the existing container with its old config.
    compose(["up", "-d"])
    ok("n8n restarted.")


def cmd_status(_args):
    if not docker_running():
        fail("Docker is not running.")

    print(bold("Containers"))
    compose(["ps"])

    env = load_env()
    bind = env.get("N8N_BIND_ADDRESS", "").strip() or "127.0.0.1"
    port = env.get("N8N_PORT", "").strip() or "5678"

    print()
    print(bold("Health check"))
    status = health_check(f"http://{bind}:{port}/healthz")
    if status == 200:
        ok(f"n8n responding at http://{bind}:{port} (HTTP {status})")
    elif status:
        warn(f"n8n responded with HTTP {status} at http://{bind}:{port}")
    else:
        warn(f"n8n not responding at http://{bind}:{port}")

    print()
    print(bold("Cloudflare Tunnel"))
    if tunnel_running():
        ok("cloudflared is running.")
        hostname = env.get("CLOUDFLARE_HOSTNAME", "").strip()
        if hostname:
            info(f"Public URL: https://{hostname}")
    else:
        info("cloudflared is not running.")


def cmd_logs(args):
    services = ["n8n", "runners"] if args.all else ["n8n"]
    cmd = ["docker", "compose", "logs", "-f", "--tail", str(args.tail)] + services
    try:
        subprocess.run(cmd, cwd=ROOT)
    except KeyboardInterrupt:
        pass


def cmd_tunnel(_args):
    require_env()
    if not cloudflared_available():
        fail("cloudflared not found. Install: see docs/cloudflare.md")
    env = load_env()
    cmd, named = build_tunnel_cmd(env)

    print()
    print(bold(f"Starting Cloudflare Tunnel ({'custom domain' if named else 'random URL'})"))
    if named:
        info(f"Public URL: https://{env.get('CLOUDFLARE_HOSTNAME')}")
    else:
        info(f"Tunnelling: http://{env.get('N8N_BIND_ADDRESS', '127.0.0.1')}:{env.get('N8N_PORT', '5678')}")
        warn("The URL changes every time this tunnel starts.")
    warn("Keep this terminal open. Press Ctrl+C to stop.")
    print()
    try:
        subprocess.run(cmd, cwd=ROOT)
    except KeyboardInterrupt:
        print()
        info("Tunnel stopped.")


# ─── Entrypoint ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog="launch.py",
        description="Manage the local n8n stack: Docker containers + Cloudflare Tunnel.")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("setup", help="One-time setup: .env, data dir, Cloudflare Tunnel config")
    sub.add_parser("start", help="Start n8n + runners + tunnel, then tail n8n logs")
    sub.add_parser("stop", help="Stop n8n, runners, and the Cloudflare Tunnel")
    sub.add_parser("restart", help="Restart n8n + runners")
    sub.add_parser("status", help="Show container + tunnel status and a health check")

    logs_p = sub.add_parser("logs", help="Tail logs on demand")
    logs_p.add_argument("-a", "--all", action="store_true", help="Include runners logs")
    logs_p.add_argument("-n", "--tail", default="100", help="Number of history lines (default: 100)")

    sub.add_parser("tunnel", help="Start the Cloudflare Tunnel only, in the foreground")

    args = parser.parse_args()
    enable_ansi_on_windows()
    unbuffer_stdout()
    # Some launchers (background jobs, certain process managers) start us with
    # SIGINT pre-ignored. Explicitly re-arm the default handler so Ctrl+C reliably
    # raises KeyboardInterrupt here instead of silently doing nothing.
    try:
        signal.signal(signal.SIGINT, signal.default_int_handler)
    except (ValueError, OSError):
        pass

    commands = {
        "setup": cmd_setup, "start": cmd_start, "stop": cmd_stop,
        "restart": cmd_restart, "status": cmd_status, "logs": cmd_logs,
        "tunnel": cmd_tunnel,
    }
    commands[args.command](args)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print()
        sys.exit(130)
