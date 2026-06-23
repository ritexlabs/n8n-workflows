@echo off
setlocal enabledelayedexpansion

REM Starts a Cloudflare Tunnel for n8n.
REM
REM  - If CLOUDFLARE_HOSTNAME is set in .env  -> named tunnel with your custom domain.
REM  - If CLOUDFLARE_HOSTNAME is empty         -> anonymous tunnel with random *.trycloudflare.com URL.

cd /d "%~dp0\.."

REM Load .env
if exist ".env" (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "%%A=%%B"
    )
) else (
    echo [!!] .env not found. Copy .env.sample to .env and fill in your values.
    cmd /k
    exit /b 1
)

if not defined N8N_PORT set N8N_PORT=5678
if not defined CLOUDFLARE_TUNNEL_NAME set CLOUDFLARE_TUNNEL_NAME=n8n-tunnel

REM Resolve cloudflared — check PATH first, then common install locations
set "CLOUDFLARED=cloudflared.exe"
where cloudflared.exe >nul 2>&1
if errorlevel 1 (
    if exist "C:\Program Files (x86)\cloudflared\cloudflared.exe" (
        set "CLOUDFLARED=C:\Program Files (x86)\cloudflared\cloudflared.exe"
    ) else if exist "C:\Program Files\Cloudflare\cloudflared\cloudflared.exe" (
        set "CLOUDFLARED=C:\Program Files\Cloudflare\cloudflared\cloudflared.exe"
    ) else if exist "C:\Apps\cloudflared\cloudflared.exe" (
        set "CLOUDFLARED=C:\Apps\cloudflared\cloudflared.exe"
    ) else (
        echo [!!] cloudflared.exe not found. Add it to PATH or install via winget.
        cmd /k
        exit /b 1
    )
)

echo.
if defined CLOUDFLARE_HOSTNAME (
    if not "!CLOUDFLARE_HOSTNAME!"=="" (
        echo ==========================================================
        echo  Starting Cloudflare Tunnel [custom domain]
        echo  Tunnel : !CLOUDFLARE_TUNNEL_NAME!
        echo  URL    : https://!CLOUDFLARE_HOSTNAME!
        echo ==========================================================
        echo.
        "!CLOUDFLARED!" tunnel run !CLOUDFLARE_TUNNEL_NAME!
    ) else (
        goto random_url
    )
) else (
    :random_url
    echo ==========================================================
    echo  Starting Cloudflare Tunnel [random URL]
    echo  Tunnelling: http://localhost:!N8N_PORT!
    echo  Cloudflare will print the assigned URL below.
    echo ==========================================================
    echo.
    "!CLOUDFLARED!" tunnel --url http://localhost:!N8N_PORT!
)

cmd /k
