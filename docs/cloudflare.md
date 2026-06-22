# Cloudflare Tunnel Setup

Expose your locally running n8n over HTTPS without a public IP, port forwarding, or VPN — for free.

## Why Cloudflare Tunnel?

- Free on Cloudflare's free plan
- Automatic HTTPS — no certificate management
- No inbound firewall rules needed (tunnel is outbound-only)
- Works with Google OAuth, Slack webhooks, and any service that requires a reachable HTTPS callback URL

## Two Modes

| Mode | URL | Requires | Best for |
|------|-----|----------|----------|
| **Custom domain** | `https://n8n.yourdomain.com` | Cloudflare account + domain | Production, persistent webhooks |
| **Random URL** | `https://abc123.trycloudflare.com` | Nothing | Quick testing, no domain needed |

---

## Mode A — Custom Domain (Full Setup)

### Part 1: Create a Cloudflare Account

1. Go to [cloudflare.com](https://cloudflare.com) and click **Sign Up**.
2. Enter your email and a strong password → **Create Account**.
3. Skip the "Add a site" prompt for now — you can do it on the next screen.

### Part 2: Add Your Domain to Cloudflare

> If your domain is already on Cloudflare, skip to Part 3.

1. In the Cloudflare dashboard click **Add a domain**.
2. Enter your domain (e.g. `example.com`) → **Continue**.
3. Select the **Free** plan → **Continue**.
4. Cloudflare scans your existing DNS records and imports them. Review the list → **Continue**.
5. Cloudflare shows you **two nameserver addresses**, e.g.:
   ```
   alba.ns.cloudflare.com
   bob.ns.cloudflare.com
   ```
6. Log in to your domain registrar (GoDaddy, Namecheap, Google Domains, etc.) and replace the existing nameservers with the two Cloudflare ones.
7. Back in Cloudflare click **Done, check nameservers**.
8. Nameserver propagation takes 5 minutes to 24 hours. Cloudflare emails you when the domain is active.

### Part 3: Install cloudflared

**macOS**
```bash
brew install cloudflare/cloudflare/cloudflared
cloudflared --version
```

**Windows**

Download `cloudflared.exe` from the [Cloudflare install page](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/) and place it somewhere in your PATH (e.g. `C:\Windows\System32\` or `C:\Apps\cloudflared\`).

Verify:
```cmd
cloudflared.exe --version
```

### Part 4: Log In to Cloudflare

**macOS**
```bash
cloudflared tunnel login
```

**Windows**
```cmd
cloudflared.exe tunnel login
```

A browser window opens. Select your Cloudflare account → click the domain you just added → **Authorize**.

This saves `~/.cloudflared/cert.pem` (macOS/Linux) or `C:\Users\<YOU>\.cloudflared\cert.pem` (Windows). This file is your account-level credential — keep it safe, never commit it.

### Part 5: Create the Tunnel

**macOS**
```bash
cloudflared tunnel create ritexlabs-n8n
```

**Windows**
```cmd
cloudflared.exe tunnel create ritexlabs-n8n
```

Output looks like:
```
Created tunnel ritexlabs-n8n with id 40ed253a-c4db-4756-b538-f1fd95b83e4b
Tunnel credentials written to /Users/<YOU>/.cloudflared/40ed253a-c4db-4756-b538-f1fd95b83e4b.json
```

Two things are created:
- A tunnel entry in your Cloudflare account
- A local credentials JSON file — **do not delete or commit this file**

> The tunnel name (`ritexlabs-n8n`) must match `CLOUDFLARE_TUNNEL_NAME` in your `.env`.

### Part 6: Create the Cloudflare Config File

Create `~/.cloudflared/config.yml` (macOS/Linux) or `C:\Users\<YOU>\.cloudflared\config.yml` (Windows):

```yaml
tunnel: <YOUR-TUNNEL-ID>
credentials-file: /Users/<YOU>/.cloudflared/<YOUR-TUNNEL-ID>.json

ingress:
  - hostname: n8n.yourdomain.com
    service: http://localhost:5678
  - service: http_status:404
```

Replace `<YOUR-TUNNEL-ID>` with the UUID from Step 5, and set `hostname` to your actual subdomain.

**Example** (the config used in this project):
```yaml
tunnel: 40ed253a-c4db-4756-b538-f1fd95b83e4b
credentials-file: /Users/ritesh/.cloudflared/40ed253a-c4db-4756-b538-f1fd95b83e4b.json

ingress:
  - hostname: ritexlabsn8n.robokingmaster.in
    service: http://localhost:5678
  - service: http_status:404
```

### Part 7: Route Your Subdomain to the Tunnel

**Important:** If a DNS record already exists for the subdomain, delete it first in the Cloudflare dashboard (DNS → Records → find the row for your subdomain → Edit → Delete). If you skip this step the command will fail with error 1003.

**macOS**
```bash
cloudflared tunnel route dns ritexlabs-n8n n8n.yourdomain.com
```

**Windows**
```cmd
cloudflared.exe tunnel route dns ritexlabs-n8n n8n.yourdomain.com
```

Expected output:
```
INF Added CNAME n8n.yourdomain.com which will route to this tunnel tunnelID=40ed253a-...
```

This creates a CNAME record in Cloudflare DNS pointing `n8n.yourdomain.com` → `<tunnel-id>.cfargotunnel.com`. The orange proxy cloud is enabled automatically.

### Part 8: Update .env

```env
N8N_HOST=n8n.yourdomain.com
N8N_PROTOCOL=https
N8N_SECURE_COOKIE=true
WEBHOOK_URL=https://n8n.yourdomain.com/
N8N_EDITOR_BASE_URL=https://n8n.yourdomain.com/
CLOUDFLARE_TUNNEL_NAME=ritexlabs-n8n
CLOUDFLARE_HOSTNAME=n8n.yourdomain.com
```

### Part 9: Start n8n and the Tunnel

**macOS**
```bash
docker compose down && docker compose up -d
./scripts/start.sh
```

**Windows**
```cmd
docker compose down && docker compose up -d
scripts\start.bat
```

The tunnel logs should show:
```
INF Starting tunnel tunnelID=40ed253a-...
INF Registered tunnel connection connIndex=0 ... location=bom10 protocol=quic
INF Registered tunnel connection connIndex=1 ... location=blr01 protocol=quic
```

Four connections registered = tunnel is healthy.

### Part 10: Verify

```bash
curl -sI https://n8n.yourdomain.com
```

Expected: `HTTP/2 200` or `HTTP/2 301`.

Then open `https://n8n.yourdomain.com` in your browser — the n8n login screen should appear.

---

## Mode B — Random URL (No Account Needed)

In `.env`, leave `CLOUDFLARE_HOSTNAME` empty, then:

**macOS**
```bash
./scripts/start.sh
```

**Windows**
```cmd
scripts\start.bat
```

`cloudflared` prints the assigned URL:
```
INF +--------------------------------------------------------------------------------------------+
INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable): |
INF |  https://abc123-example.trycloudflare.com                                                  |
INF +--------------------------------------------------------------------------------------------+
```

Open that URL to access n8n. The URL changes every time the tunnel restarts — not suitable for persistent webhooks but fine for testing.

---

## Moving to a New Machine

The tunnel itself lives in your Cloudflare account and is not tied to a machine. To run it from a new machine:

1. Install `cloudflared` on the new machine.
2. Run `cloudflared tunnel login` to create a new `cert.pem`.
3. **Do not** run `cloudflared tunnel create` — the tunnel already exists.
4. Copy the credentials JSON from the old machine:
   - From: `~/.cloudflared/<TUNNEL-ID>.json`
   - To: `~/.cloudflared/<TUNNEL-ID>.json` on the new machine
5. Copy `~/.cloudflared/config.yml` to the new machine as well.
6. Run `./scripts/start.sh` — the tunnel will connect using the existing credentials.

> If you cannot copy the JSON file, delete the tunnel in Cloudflare, recreate it on the new machine (Part 5), delete the old CNAME in Cloudflare DNS, and re-run the route command (Part 7).

---

## Troubleshooting

### HTTP 530 — Cloudflare can't reach the tunnel

Causes in order of likelihood:
1. **`cloudflared` is not running** — run `./scripts/start.sh` or `cloudflared tunnel run ritexlabs-n8n`
2. **Stale DNS CNAME** — the CNAME points to an old/deleted tunnel. Fix:
   - Go to Cloudflare Dashboard → DNS → Records
   - Delete the CNAME for your subdomain
   - Re-run: `cloudflared tunnel route dns ritexlabs-n8n n8n.yourdomain.com`
3. **Wrong tunnel name in `.env`** — `CLOUDFLARE_TUNNEL_NAME` must exactly match the name used in `cloudflared tunnel create`
4. **Credentials JSON missing** — `~/.cloudflared/<TUNNEL-ID>.json` must exist on the machine running `cloudflared`

### Error 1003 — Record already exists

```
Failed to add route: code: 1003, reason: An A, AAAA, or CNAME record with that host already exists
```

Fix: Delete the existing record in Cloudflare Dashboard → DNS → Records, then re-run:
```bash
cloudflared tunnel route dns ritexlabs-n8n n8n.yourdomain.com
```

### `No ingress rules were defined` — 503 on all requests

`~/.cloudflared/config.yml` is missing or has no `ingress` block. Create it as shown in Part 6.

### `n8n-tunnel is neither the ID nor the name of any of your tunnels`

The tunnel name in `.env` doesn't match any tunnel in your account. Check:
```bash
cloudflared tunnel list
```
Update `CLOUDFLARE_TUNNEL_NAME` in `.env` to match the actual name shown.

### `cert.pem` not found / origin cert error

You haven't logged in on this machine yet:
```bash
cloudflared tunnel login
```

### Webhooks show `localhost` in their URL

`WEBHOOK_URL` is empty or set to `http://localhost`. Set it in `.env` and restart n8n:
```bash
docker compose down && docker compose up -d
```

### SSL redirect loop

In Cloudflare → SSL/TLS → Overview, set mode to **Full** or **Full (Strict)**.

---

## Optional: Cloudflare Zero Trust Access

Add a login gate in front of n8n (Google, GitHub, or email OTP) without changing anything in n8n:

1. Cloudflare Dashboard → **Zero Trust** → **Access** → **Applications** → **Add an application**
2. Type: **Self-hosted**
3. Application domain: `n8n.yourdomain.com`
4. Add a policy → Action: **Allow** → Include: your email or email domain
5. Identity providers: Google / GitHub / One-time PIN

Every visitor must authenticate through Cloudflare Access before reaching the n8n login page.
