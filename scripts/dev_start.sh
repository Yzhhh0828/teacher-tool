#!/usr/bin/env bash
# Teacher Tool — Local development startup (Linux / macOS)
# Uses SQLite, no Docker dependencies required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "── Teacher Tool Dev Server ──"

# Ensure Python venv
VENV="$ROOT/backend/.venv"
if [ ! -d "$VENV" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV"
fi

# Activate venv
source "$VENV/bin/activate"

# Install dependencies
echo "Installing Python dependencies..."
pip install -q -r "$ROOT/backend/requirements.txt"

# Start backend
echo "Starting backend on http://localhost:8000 ..."
cd "$ROOT/backend"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
