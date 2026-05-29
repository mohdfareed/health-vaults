#!/usr/bin/env bash
# Launch the ModelLab Jupyter environment.

set -euo pipefail
if ! command -v uv &>/dev/null; then
    echo "error: uv is not installed."
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAB_DIR="$REPO_ROOT/ModelLab"
VENV_DIR="$REPO_ROOT/.venv"
cd "$LAB_DIR"

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# Install/update dependencies
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Starting notebook..."
jupyter notebook
