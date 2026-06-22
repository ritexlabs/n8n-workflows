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

echo.
if defined CLOUDFLARE_HOSTNAME (
    if not "!CLOUDFLARE_HOSTNAME!"=="" (
        echo ==========================================================
        echo  Starting Cloudflare Tunnel [custom domain]
        echo  Tunnel : !CLOUDFLARE_TUNNEL_NAME!
        echo  URL    : https://!CLOUDFLARE_HOSTNAME!
        echo ==========================================================
        echo.
        cloudflared.exe tunnel run !CLOUDFLARE_TUNNEL_NAME!
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
    cloudflared.exe tunnel --url http://localhost:!N8N_PORT!
)

cmd /k
