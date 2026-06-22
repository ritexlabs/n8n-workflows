@echo off
REM Stops n8n Docker containers and any running cloudflared tunnel processes.

cd /d "%~dp0\.."

echo.
echo Stopping Cloudflare Tunnel (if running)...
taskkill /f /im cloudflared.exe >nul 2>&1
if errorlevel 1 (
    echo [--] No cloudflared process found.
) else (
    echo [ok] cloudflared stopped.
)

echo.
echo Stopping n8n...
docker compose down
echo [ok] n8n stopped.
echo.
pause
