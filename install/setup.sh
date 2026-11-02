#!/usr/bin/env bash
# ==============================================================================
# ALPORA Dotfiles Setup & Bootstrap Script
# ==============================================================================
# Automates GNU Stow symlinking, systemd service enablement, and dependency audit.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/../dotfiles" && pwd)"
TARGET_DIR="${HOME:-/home/$USER}"

echo "========================================================================"
echo "          ALPORA Desktop Environment - Dotfiles Setup                   "
echo "========================================================================"
echo "Source: $DOTFILES_DIR"
echo "Target: $TARGET_DIR"
echo ""

# 1. Check for GNU Stow
if ! command -v stow >/dev/null 2>&1; then
    echo "[!] GNU Stow is required to manage dotfile symlinks."
    echo "    On Arch Linux: sudo pacman -S --needed stow"
    exit 1
fi

# 2. Check essential dependencies
echo "[1/4] Checking core desktop dependencies..."
missing_deps=()
for dep in hyprland quickshell python3 fcitx5 foot systemd; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        missing_deps+=("$dep")
    fi
done

if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "  [Notice] The following packages are not yet in PATH:"
    for md in "${missing_deps[@]}"; do
        echo "    - $md"
    done
    echo "  You can continue symlinking now and install missing packages later via pacman."
    echo ""
else
    echo "  [OK] All core dependencies detected."
fi

# 3. Create target directory structure
echo "[2/4] Preparing target directories..."
mkdir -p "$TARGET_DIR/.config/hypr"
mkdir -p "$TARGET_DIR/.config/poly-shell"
mkdir -p "$TARGET_DIR/.config/foot"
mkdir -p "$TARGET_DIR/.config/kitty"
mkdir -p "$TARGET_DIR/.config/fcitx5"
mkdir -p "$TARGET_DIR/.config/fontconfig"
mkdir -p "$TARGET_DIR/.config/fastfetch"
mkdir -p "$TARGET_DIR/.config/systemd/user"
mkdir -p "$TARGET_DIR/.local/share/fonts/alpora"

# 4. Stow all packages
echo "[3/5] Stowing dotfile packages into $TARGET_DIR..."
PACKAGES=(
    "hypr"
    "fcitx5"
    "fontconfig"
    "foot"
    "kitty"
    "shell"
    "fastfetch"
    "poly-shell"
    "systemd"
)

cd "$DOTFILES_DIR"
for pkg in "${PACKAGES[@]}"; do
    if [[ -d "$pkg" ]]; then
        echo "  -> Stowing package: $pkg"
        stow -R -v 1 -t "$TARGET_DIR" "$pkg" 2>&1 | sed 's/^/     /'
    else
        echo "  [Warning] Package folder $pkg not found, skipping."
    fi
done

# 5. Install Typography Fonts
echo "[4/5] Installing ALPORA typography fonts..."
if [[ -d "$SCRIPT_DIR/../assets/fonts" ]]; then
    cp -u "$SCRIPT_DIR/../assets/fonts/"*.ttf "$TARGET_DIR/.local/share/fonts/alpora/" 2>/dev/null || true
    echo "  [OK] Installed fonts: Inter, JetBrains Mono, Outfit, Symbols Nerd Font"
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$TARGET_DIR/.local/share/fonts/alpora" >/dev/null 2>&1 || true
        echo "  [OK] Font cache updated via fc-cache."
    fi
fi

# 6. Enable systemd user service
echo "[5/5] Setting up ALPORA systemd user service..."
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload 2>/dev/null || true
    if systemctl --user enable poly-shell.service 2>/dev/null; then
        echo "  [OK] poly-shell.service enabled for user session."
    else
        echo "  [Notice] Could not enable poly-shell.service right now (systemd user daemon might be inactive)."
        echo "           Run: systemctl --user enable --now poly-shell.service once logged into Wayland."
    fi
else
    echo "  [Notice] systemctl not found; skipping service activation."
fi

echo ""
echo "========================================================================"
echo "          ALPORA Dotfiles Installation Successfully Finished!          "
echo "========================================================================"
echo "To launch ALPORA manually: poly-shell run"
echo "To start as service:       systemctl --user start poly-shell.service"
echo "To check system health:    poly-shell doctor"
echo "========================================================================"

