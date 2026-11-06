#!/usr/bin/env bash
# ==============================================================================
# ALPORA Desktop Environment 1-Click Installer
# Alias entry point to install/get.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/install/get.sh" ]]; then
    exec bash "$SCRIPT_DIR/install/get.sh" "$@"
else
    # Fallback to online curl if executed standalone without repository
    curl -fsSL https://raw.githubusercontent.com/pnam-it309/alpora/main/install/get.sh | bash -s -- "$@"
fi
