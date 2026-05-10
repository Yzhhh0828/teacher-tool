# Build Flutter web in release mode and let the FastAPI backend serve it.
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File scripts\build_web.ps1
#
# After this finishes, start the backend with:
#   cd backend
#   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
# and open http://localhost:8000

param(
    [switch]$SkipPubGet
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$flutterApp = Join-Path $root "flutter_app"
$flutterBin = Join-Path $root "flutter\bin\flutter.bat"

if (-not (Test-Path $flutterBin)) {
    Write-Host "[!] Flutter SDK not found at $flutterBin" -ForegroundColor Red
    Write-Host "    Falling back to 'flutter' on PATH" -ForegroundColor Yellow
    $flutterBin = "flutter"
}

Write-Host "[*] Flutter web release build starting..." -ForegroundColor Cyan
Write-Host "    Project: $flutterApp"

if (-not $SkipPubGet) {
    Write-Host "[*] flutter pub get" -ForegroundColor Cyan
    Push-Location $flutterApp
    try {
        & $flutterBin pub get
        if ($LASTEXITCODE -ne 0) { throw "pub get failed" }
    } finally {
        Pop-Location
    }
}

Write-Host "[*] flutter build web --release" -ForegroundColor Cyan
$buildArgs = @(
    "build", "web",
    "--release",
    "--pwa-strategy", "offline-first",
    "--base-href", "/"
)
Push-Location $flutterApp
try {
    & $flutterBin @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "build web failed" }
} finally {
    Pop-Location
}

$buildDir = Join-Path $flutterApp "build\web"
if (-not (Test-Path $buildDir)) { throw "Build output missing: $buildDir" }

# Print size summary
$totalBytes = (Get-ChildItem -Recurse $buildDir | Measure-Object -Property Length -Sum).Sum
$totalMB = [math]::Round($totalBytes / 1MB, 2)
Write-Host ""
Write-Host "[OK] Build complete." -ForegroundColor Green
Write-Host "     Output : $buildDir"
Write-Host "     Size   : $totalMB MB"
Write-Host ""
Write-Host "Next step: start the backend, it will auto-serve the build."
Write-Host "  cd backend"
Write-Host "  python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"
Write-Host ""
Write-Host "Then open http://localhost:8000 in your browser." -ForegroundColor Cyan
