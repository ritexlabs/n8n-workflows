@echo off
setlocal enabledelayedexpansion

REM One-time setup for Windows: checks dependencies, creates .env, configures Cloudflare.

cd /d "%~dp0\.."

echo.
echo ===========================================================
echo  n8n Windows Setup
echo ===========================================================

REM ─── Docker ────────────────────────────────────────────────────────────────
echo.
echo =^> Checking Docker

docker info >nul 2>&1
if not errorlevel 1 goto docker_ok

docker --version >nul 2>&1
if errorlevel 1 (
    echo [!!] Docker Desktop is not installed.
    echo [--] Download it from: https://www.docker.com/products/docker-desktop/
    echo [!!] Install Docker Desktop, start it, then re-run this script.
    pause
    exit /b 1
)

echo [!!] Docker is installed but not running. Please start Docker Desktop.
echo [--] Waiting for Docker to start (up to 60 seconds)...
set /a DOCKER_WAIT=0

:docker_wait_loop
%SystemRoot%\System32\timeout.exe /t 5 /nobreak >nul
docker info >nul 2>&1
if not errorlevel 1 goto docker_ok
set /a DOCKER_WAIT+=1
if !DOCKER_WAIT! lss 12 goto docker_wait_loop
echo [!!] Docker did not start in time. Start Docker Desktop and re-run this script.
pause
exit /b 1

:docker_ok
for /f "tokens=*" %%v in ('docker --version 2^>nul') do echo [ok] %%v

REM ─── cloudflared ──────────────────────────────────────────────────────────
echo.
echo =^> Checking cloudflared

where cloudflared >nul 2>&1
if not errorlevel 1 goto cloudflared_ok

echo [--] cloudflared not found. Attempting install via winget...
winget install --id Cloudflare.cloudflared -e --silent
if errorlevel 1 (
    echo [!!] winget install failed or winget is unavailable.
    echo [--] Download cloudflared manually:
    echo      https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/
    echo [!!] Add cloudflared.exe to your PATH, then re-run this script.
    pause
    exit /b 1
)
echo [ok] cloudflared installed via winget.
echo [!!] Please close and re-run this script so the new PATH takes effect.
pause
exit /b 0

:cloudflared_ok
for /f "tokens=*" %%v in ('cloudflared --version 2^>nul') do echo [ok] %%v

REM ─── .env file ─────────────────────────────────────────────────────────────
echo.
echo =^> Setting up .env

if exist ".env" (
    echo [ok] .env already exists - skipping copy.
    goto env_done
)

copy ".env.sample" ".env" >nul
echo [ok] .env created from .env.sample.

REM Generate a random 32-byte hex token using PowerShell
echo $bytes = [byte[]]::new(32); [Security.Cryptography.RandomNumberGenerator]::Fill($bytes); ($bytes ^| ForEach-Object { $_.ToString('x2') }) -join '' > "%TEMP%\n8n_gen_token.ps1"
for /f "tokens=*" %%t in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\n8n_gen_token.ps1"') do set "RUNNER_TOKEN=%%t"
del "%TEMP%\n8n_gen_token.ps1" >nul 2>&1

if defined RUNNER_TOKEN (
    powershell -NoProfile -Command "(Get-Content '.env') -replace '^N8N_RUNNERS_AUTH_TOKEN=.*','N8N_RUNNERS_AUTH_TOKEN=%RUNNER_TOKEN%' | Set-Content '.env'"
    echo [ok] Generated N8N_RUNNERS_AUTH_TOKEN in .env.
) else (
    echo [!!] Could not generate token. Set N8N_RUNNERS_AUTH_TOKEN manually in .env.
)

:env_done

REM ─── Data directory ────────────────────────────────────────────────────────
echo.
echo =^> Creating n8n data directory

if not exist "n8n_data" mkdir "n8n_data"
echo [ok] n8n_data\ directory ready.

REM ─── Cloudflare Tunnel setup ───────────────────────────────────────────────
echo.
echo =^> Cloudflare Tunnel setup
echo.
echo How do you want to expose n8n publicly?
echo   1) Custom domain  (requires a domain managed in Cloudflare)
echo   2) Random URL     (free *.trycloudflare.com - no domain or login needed)
echo   3) Skip           (local access only - http://localhost:5678)
echo.
set /p CF_CHOICE="Enter choice [1/2/3]: "

if "%CF_CHOICE%"=="1" goto cf_custom
if "%CF_CHOICE%"=="2" goto cf_random
if "%CF_CHOICE%"=="3" goto cf_skip
echo [!!] Invalid choice. Run scripts\setup.bat again to configure Cloudflare.
goto done

:cf_custom
echo.
echo [--] You chose custom domain setup.
echo.
set /p CF_HOSTNAME="Enter your tunnel hostname (e.g. n8n.example.com): "
set "CF_TUNNEL_NAME=n8n-tunnel"
set /p CF_TUNNEL_NAME="Enter a tunnel name [default: n8n-tunnel]: "

echo [--] Logging in to Cloudflare - a browser window will open...
cloudflared tunnel login
if errorlevel 1 (
    echo [!!] Cloudflare login failed.
    pause
    exit /b 1
)

echo [--] Creating tunnel: %CF_TUNNEL_NAME%
cloudflared tunnel create "%CF_TUNNEL_NAME%"
if errorlevel 1 (
    echo [!!] Failed to create tunnel.
    pause
    exit /b 1
)

echo [--] Routing tunnel to hostname: %CF_HOSTNAME%
cloudflared tunnel route dns "%CF_TUNNEL_NAME%" "%CF_HOSTNAME%"
if errorlevel 1 (
    echo [!!] Failed to route DNS. Check that your domain is managed in Cloudflare.
    pause
    exit /b 1
)

powershell -NoProfile -Command "$c=Get-Content '.env'; $c=$c -replace '^N8N_HOST=.*','N8N_HOST=%CF_HOSTNAME%'; $c=$c -replace '^N8N_PROTOCOL=.*','N8N_PROTOCOL=https'; $c=$c -replace '^N8N_SECURE_COOKIE=.*','N8N_SECURE_COOKIE=true'; $c=$c -replace '^WEBHOOK_URL=.*','WEBHOOK_URL=https://%CF_HOSTNAME%/'; $c=$c -replace '^N8N_EDITOR_BASE_URL=.*','N8N_EDITOR_BASE_URL=https://%CF_HOSTNAME%/'; $c=$c -replace '^CLOUDFLARE_TUNNEL_NAME=.*','CLOUDFLARE_TUNNEL_NAME=%CF_TUNNEL_NAME%'; $c=$c -replace '^CLOUDFLARE_HOSTNAME=.*','CLOUDFLARE_HOSTNAME=%CF_HOSTNAME%'; $c | Set-Content '.env'"

echo [ok] Tunnel '%CF_TUNNEL_NAME%' configured for https://%CF_HOSTNAME%
echo [--] Run scripts\start.bat to launch n8n and the tunnel.
goto done

:cf_random
echo [--] Random URL mode selected - no configuration needed.
echo [--] Each time you start the tunnel a new *.trycloudflare.com URL is assigned.
echo [!!] Webhook URLs will use localhost in this mode. Use a custom domain for persistent webhooks.

powershell -NoProfile -Command "$c=Get-Content '.env'; $c=$c -replace '^N8N_HOST=.*','N8N_HOST=localhost'; $c=$c -replace '^N8N_PROTOCOL=.*','N8N_PROTOCOL=http'; $c=$c -replace '^N8N_SECURE_COOKIE=.*','N8N_SECURE_COOKIE=false'; $c=$c -replace '^WEBHOOK_URL=.*','WEBHOOK_URL='; $c=$c -replace '^N8N_EDITOR_BASE_URL=.*','N8N_EDITOR_BASE_URL='; $c=$c -replace '^CLOUDFLARE_HOSTNAME=.*','CLOUDFLARE_HOSTNAME='; $c | Set-Content '.env'"

echo [ok] Configured for random tunnel mode.
echo [--] Run scripts\start.bat to launch n8n and get your public URL.
goto done

:cf_skip
echo [--] Skipping Cloudflare setup. n8n will be available at http://localhost:5678 only.

powershell -NoProfile -Command "$c=Get-Content '.env'; $c=$c -replace '^N8N_HOST=.*','N8N_HOST=localhost'; $c=$c -replace '^N8N_PROTOCOL=.*','N8N_PROTOCOL=http'; $c=$c -replace '^N8N_SECURE_COOKIE=.*','N8N_SECURE_COOKIE=false'; $c=$c -replace '^WEBHOOK_URL=.*','WEBHOOK_URL='; $c=$c -replace '^N8N_EDITOR_BASE_URL=.*','N8N_EDITOR_BASE_URL='; $c=$c -replace '^CLOUDFLARE_HOSTNAME=.*','CLOUDFLARE_HOSTNAME='; $c | Set-Content '.env'"

echo [--] Run scripts\start.bat to launch n8n.

:done
echo.
echo ===========================================================
echo  Setup complete.
echo ===========================================================
echo.
echo   Start n8n:   scripts\start.bat
echo   Stop n8n:    scripts\stop.bat
echo   Edit config: %CD%\.env
echo.
pause
