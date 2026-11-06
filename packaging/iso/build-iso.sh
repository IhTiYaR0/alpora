#!/usr/bin/env bash
# ==============================================================================
# ALPORA Custom Arch Linux ISO Generator
# Uses official archiso (mkarchiso) tools
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORK_DIR="${WORK_DIR:-${SCRIPT_DIR}/work}"
OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/out}"

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

if [[ -d /usr/share/archiso/configs/releng ]]; then
    echo "Syncing standard bootloader files from archiso releng template..."
    cp -rn /usr/share/archiso/configs/releng/efiboot "${SCRIPT_DIR}/" 2>/dev/null || true
    cp -rn /usr/share/archiso/configs/releng/syslinux "${SCRIPT_DIR}/" 2>/dev/null || true
    cp -rn /usr/share/archiso/configs/releng/grub "${SCRIPT_DIR}/" 2>/dev/null || true
fi

# Prepare Live Desktop airootfs structure & dotfiles
echo "Preparing Live Desktop skel & dotfiles..."
mkdir -p "${SCRIPT_DIR}/airootfs/etc/skel/.config/hypr"
mkdir -p "${SCRIPT_DIR}/airootfs/etc/skel/.config/kitty"
mkdir -p "${SCRIPT_DIR}/airootfs/etc/skel/.config/foot"
mkdir -p "${SCRIPT_DIR}/airootfs/etc/skel/.config/fcitx5"
mkdir -p "${SCRIPT_DIR}/airootfs/etc/skel/.config/quickshell"
mkdir -p "${SCRIPT_DIR}/airootfs/usr/local/bin"
mkdir -p "${SCRIPT_DIR}/airootfs/opt/alpora"

if [[ -d "${PROJECT_ROOT}/dotfiles" ]]; then
    cp -r "${PROJECT_ROOT}/dotfiles/hypr/.config/hypr/"* "${SCRIPT_DIR}/airootfs/etc/skel/.config/hypr/" 2>/dev/null || true
    cp -r "${PROJECT_ROOT}/dotfiles/kitty/.config/kitty/"* "${SCRIPT_DIR}/airootfs/etc/skel/.config/kitty/" 2>/dev/null || true
    cp -r "${PROJECT_ROOT}/dotfiles/foot/.config/foot/"* "${SCRIPT_DIR}/airootfs/etc/skel/.config/foot/" 2>/dev/null || true
    cp -r "${PROJECT_ROOT}/dotfiles/fcitx5/.config/fcitx5/"* "${SCRIPT_DIR}/airootfs/etc/skel/.config/fcitx5/" 2>/dev/null || true
fi

# Bundle local ALPORA project into live filesystem /opt/alpora
if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.git' --exclude='packaging/iso/work' --exclude='packaging/iso/out' \
        "${PROJECT_ROOT}/" "${SCRIPT_DIR}/airootfs/opt/alpora/"
fi

# Link poly-shell & alpora-fetch
ln -sf /opt/alpora/bin/poly-shell "${SCRIPT_DIR}/airootfs/usr/local/bin/poly-shell"
ln -sf /opt/alpora/bin/alpora-fetch "${SCRIPT_DIR}/airootfs/usr/local/bin/alpora-fetch"
ln -sf /opt/alpora/shell "${SCRIPT_DIR}/airootfs/etc/skel/.config/quickshell/poly-shell"

chmod +x "${SCRIPT_DIR}/airootfs/usr/local/bin/"* || true
chmod +x "${SCRIPT_DIR}/airootfs/root/"*.sh 2>/dev/null || true

echo "Starting mkarchiso build..."
echo "Profile directory: ${SCRIPT_DIR}"
echo "Output directory:  ${OUT_DIR}"

mkarchiso -v -w "${WORK_DIR}" -o "${OUT_DIR}" "${SCRIPT_DIR}"

echo "=========================================================="
echo " Build finished successfully!"
echo " ISO image saved in: ${OUT_DIR}"
echo "=========================================================="
