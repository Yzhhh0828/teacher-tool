# Teacher Tool — Local development startup (Windows PowerShell)
# Uses SQLite, no Docker dependencies required.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

Write-Host "── Teacher Tool Dev Server ──" -ForegroundColor Cyan

# Ensure Python venv
$venvPath = Join-Path $root "backend\.venv"
if (-not (Test-Path $venvPath)) {
    Write-Host "Creating Python virtual environment..." -ForegroundColor Yellow
    python -m venv $venvPath
}

# Activate venv
$activateScript = Join-Path $venvPath "Scripts\Activate.ps1"
. $activateScript

# Install dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
pip install -q -r (Join-Path $root "backend\requirements.txt")

# Start backend
Write-Host "Starting backend on http://localhost:8000 ..." -ForegroundColor Green
Set-Location (Join-Path $root "backend")
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
