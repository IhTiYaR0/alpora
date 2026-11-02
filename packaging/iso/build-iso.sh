#!/usr/bin/env bash
# ==============================================================================
# ALPORA Custom Arch Linux ISO Generator
# Uses official archiso (mkarchiso) tools
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/work"
OUT_DIR="${SCRIPT_DIR}/out"

echo "=========================================================="
echo "          ALPORA Arch Linux ISO Builder                   "
echo "=========================================================="

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root (sudo ./build-iso.sh)" >&2
    exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "mkarchiso is missing. Installing archiso package..."
    pacman -Sy --noconfirm archiso
fi

mkdir -p "${WORK_DIR}" "${OUT_DIR}"

echo "Starting mkarchiso build..."
echo "Profile directory: ${SCRIPT_DIR}"
echo "Output directory:  ${OUT_DIR}"

mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${SCRIPT_DIR}"

echo "=========================================================="
echo " Build finished successfully!"
echo " ISO image saved in: ${OUT_DIR}"
echo "=========================================================="
