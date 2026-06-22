@echo off
setlocal enabledelayedexpansion

REM Starts n8n via Docker Compose and optionally launches a Cloudflare Tunnel.
REM Run from the repository root or from this scripts\ folder.

cd /d "%~dp0\.."

echo.
echo ==========================================================
echo  Starting n8n
echo ==========================================================
echo.

REM Check Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [!!] Docker is not running. Please start Docker Desktop and try again.
    pause
    exit /b 1
)

REM Load .env if it exists
if exist ".env" (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "%%A=%%B"
    )
) else (
    echo [!!] .env not found. Copy .env.sample to .env and fill in your values.
    pause
    exit /b 1
)

docker compose up -d
if errorlevel 1 (
    echo [!!] Failed to start n8n. Check the error above.
    pause
    exit /b 1
)

echo.
echo [ok] n8n started.
echo [--] Local access: http://localhost:%N8N_PORT%
echo.

REM Ask whether to start Cloudflare Tunnel
if "%CLOUDFLARE_HOSTNAME%"=="" (
    set /p START_CF="Start Cloudflare Tunnel with random URL? [y/N] "
    if /i "!START_CF!"=="y" (
        start "Cloudflare Tunnel" cmd /k "scripts\cloudflare-tunnel.bat"
    )
) else (
    echo [--] Starting Cloudflare Tunnel for %CLOUDFLARE_HOSTNAME%...
    start "Cloudflare Tunnel" cmd /k "scripts\cloudflare-tunnel.bat"
)

echo.
echo [ok] Done. n8n is running.
echo.
pause
