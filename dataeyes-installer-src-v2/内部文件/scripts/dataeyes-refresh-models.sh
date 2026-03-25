#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Refreshing provider models from the current ~/.openclaw/openclaw.json ..."
bash "$SCRIPT_DIR/dataeyes-setup.sh"
