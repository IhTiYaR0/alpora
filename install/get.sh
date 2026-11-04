#!/usr/bin/env bash
# ==============================================================================
#                 A L P O R A   D E S K T O P   I N S T A L L E R
#                     Archcraft-style 1-Click Bootstrap
# ==============================================================================
# One-line usage:
#   curl -fsSL https://raw.githubusercontent.com/pnam-it309/alpora/main/install/get.sh | bash
# or (domain alias):
#   curl -fsSL https://alpora.dev/install.sh | bash
# ==============================================================================
set -euo pipefail

# ANSI color palette
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
RED='\033[31m'
NC='\033[0m'

print_banner() {
    cat <<EOF

${CYAN}${BOLD}                 /\\                                              ${NC}
${CYAN}${BOLD}                /  \\      /\\                                     ${NC}
${CYAN}${BOLD}               / /\\ \\    /  \\                                    ${NC}
${BLUE}${BOLD}              / /  \\ \\__/ /\\ \\                                   ${NC}
${BLUE}${BOLD}        _____/ /    \\____/  \\ \\____                              ${NC}
${BLUE}${BOLD}            / /      /\\      \\                                   ${NC}
${CYAN}${BOLD}           / /      /  \\      \\                                  ${NC}
${BOLD}       ================================================          ${NC}
${BOLD}              A L P O R A   D E S K T O P   O S                  ${NC}
${CYAN}         Mountains at sunrise. A lake after dark.                ${NC}
${CYAN}               A desktop that follows the landscape.             ${NC}
${BOLD}       ================================================          ${NC}

EOF
}

info() { printf "${CYAN}${BOLD}[*]${NC} %s\n" "$*"; }
success() { printf "${GREEN}${BOLD}[✓]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}${BOLD}[!]${NC} %s\n" "$*"; }
error() { printf "${RED}${BOLD}[✗]${NC} %s\n" "$*" >&2; exit 1; }

check_system() {
    info "Verifying system compatibility..."
    if [[ $EUID -eq 0 ]]; then
        error "Please do not run this script directly as root. Run as normal user with sudo privileges."
    fi

    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *"arch"* && "${FORCE_DISTRO:-0}" != "1" ]]; then
            warn "Non-Arch distribution detected (${NAME:-Unknown})."
            echo "ALPORA is optimized for Arch Linux and derivatives (EndeavourOS, CachyOS, Manjaro, etc.)."
            echo "To proceed anyway, run with: FORCE_DISTRO=1 bash get.sh"
            exit 1
        fi
        success "Detected supported system: ${PRETTY_NAME:-Arch Linux}"
    else
        warn "Could not verify /etc/os-release. Proceeding..."
    fi
}

request_sudo() {
    info "Authenticating for package installation..."
    if ! sudo -v; then
        error "Sudo authorization failed."
    fi
    # Keep sudo alive in background
    while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
}

install_dependencies() {
    info "Updating package databases and installing dependencies via pacman..."
    local pkgs=(
        # Core Compositor & Shell
        hyprland
        quickshell
        python
        python-pillow
        python-gobject
        python-pip
        stow
        # Audio & Media
        pipewire
        pipewire-alsa
        pipewire-pulse
        pipewire-jack
        wireplumber
        playerctl
        pavucontrol
        # Vietnamese IME (Telex native)
        fcitx5
        fcitx5-gtk
        fcitx5-qt
        fcitx5-bamboo
        fcitx5-configtool
        # Utilities & Terminal
        foot
        kitty
        nautilus
        fastfetch
        brightnessctl
        wl-clipboard
        grim
        slurp
        libnotify
        mako
        swaybg
        hyprlock
        hypridle
        hyprsunset
        upower
        networkmanager
        bluez
        bluez-utils
        git
    )

    sudo pacman -Sy --needed --noconfirm "${pkgs[@]}" || {
        warn "Some packages failed to install in batch. Retrying essential packages..."
        sudo pacman -S --needed --noconfirm hyprland quickshell python python-pillow stow fcitx5 fcitx5-bamboo foot || true
    }
    success "System packages and dependencies installed."
}

setup_repository() {
    local target_dir="${ALPORA_DIR:-$HOME/.local/share/alpora}"
    local repo_url="${ALPORA_REPO_URL:-https://github.com/pnam-it309/alpora.git}"
    local branch="${ALPORA_BRANCH:-main}"

    # If already running inside cloned repo, use current dir
    if [[ -d "./.git" && -d "./dotfiles" && -d "./shell" ]]; then
        target_dir="$(pwd)"
        info "Running from existing local workspace: $target_dir"
    elif [[ -d "$target_dir/.git" ]]; then
        info "Existing ALPORA installation found at $target_dir. Pulling latest updates..."
        git -C "$target_dir" fetch origin "$branch" --depth=1 || true
        git -C "$target_dir" checkout "$branch" || true
        git -C "$target_dir" reset --hard "origin/$branch" || true
    else
        info "Cloning ALPORA repository into $target_dir..."
        mkdir -p "$(dirname "$target_dir")"
        git clone --depth=1 --branch "$branch" "$repo_url" "$target_dir"
    fi

    ALPORA_DIR="$target_dir"
    chmod +x "$ALPORA_DIR/bin/"* "$ALPORA_DIR/install/"*.sh "$ALPORA_DIR/scripts/"*.sh || true
}

stow_dotfiles() {
    info "Stowing user dotfiles via GNU Stow..."
    local target_home="${HOME}"
    local dotfiles_dir="$ALPORA_DIR/dotfiles"

    mkdir -p "$target_home/.config/hypr"
    mkdir -p "$target_home/.config/poly-shell"
    mkdir -p "$target_home/.config/foot"
    mkdir -p "$target_home/.config/kitty"
    mkdir -p "$target_home/.config/fcitx5"
    mkdir -p "$target_home/.config/fastfetch"
    mkdir -p "$target_home/.config/fontconfig"
    mkdir -p "$target_home/.config/systemd/user"
    mkdir -p "$target_home/.local/bin"
    mkdir -p "$target_home/.local/share/fonts/alpora"

    local packages=("hypr" "fcitx5" "fontconfig" "foot" "kitty" "shell" "fastfetch" "poly-shell" "systemd")

    cd "$dotfiles_dir"
    for pkg in "${packages[@]}"; do
        if [[ -d "$pkg" ]]; then
            info "  -> Linking package: $pkg"
            stow -R -v 1 -t "$target_home" "$pkg" 2>&1 | sed 's/^/     /' || {
                warn "Stow conflict detected for $pkg. Adopting existing files..."
                stow --adopt -v 1 -t "$target_home" "$pkg" 2>&1 | sed 's/^/     /' || true
            }
        fi
    done

    # Symlink command binaries into ~/.local/bin
    ln -sf "$ALPORA_DIR/bin/poly-shell" "$target_home/.local/bin/poly-shell"
    ln -sf "$ALPORA_DIR/bin/alpora-fetch" "$target_home/.local/bin/alpora-fetch"

    success "User dotfiles and commands linked."
}

install_fonts() {
    info "Installing typography fonts (Inter, JetBrains Mono, Outfit, Nerd Symbols)..."
    local font_dir="$HOME/.local/share/fonts/alpora"
    if [[ -d "$ALPORA_DIR/assets/fonts" ]]; then
        cp -u "$ALPORA_DIR/assets/fonts/"*.ttf "$font_dir/" 2>/dev/null || true
        if command -v fc-cache >/dev/null 2>&1; then
            fc-cache -f "$font_dir" >/dev/null 2>&1 || true
        fi
        success "Typography fonts installed and cache updated."
    fi
}

enable_services() {
    info "Enabling ALPORA user systemd service..."
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable poly-shell.service 2>/dev/null || true
        success "poly-shell.service enabled for user session."
    fi

    # Enable NetworkManager and Bluetooth system services
    sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
    sudo systemctl enable --now bluetooth.service 2>/dev/null || true
}

show_completion() {
    cat <<EOF

${GREEN}${BOLD}========================================================================${NC}
${GREEN}${BOLD}         ALPORA DESKTOP ENVIRONMENT INSTALLED SUCCESSFULLY!             ${NC}
${GREEN}${BOLD}========================================================================${NC}

${CYAN}${BOLD}Quick Start Guide:${NC}
  1. Log out of your current session.
  2. At your login screen (Display Manager), select session: ${BOLD}Hyprland${NC}
  3. Log in to experience the mountains, living landscape & fluid shell!

${CYAN}${BOLD}Default Essential Shortcuts:${NC}
  • ${BOLD}Super + Return${NC}      : Terminal (Foot)
  • ${BOLD}Super + R${NC}           : Application Launcher & Search
  • ${BOLD}Super + E${NC}           : File Manager (Nautilus)
  • ${BOLD}Super + I${NC}           : Quick Settings Control Center
  • ${BOLD}Super + Tab${NC}         : Workspaces & Window Overview
  • ${BOLD}Super + V${NC}           : Clipboard History
  • ${BOLD}Ctrl + Shift${NC}        : Toggle Vietnamese (Telex) / English IME

${CYAN}${BOLD}Useful Terminal Commands:${NC}
  • ${BOLD}poly-shell settings${NC} : Open ALPORA Appearance, Widgets & Theme settings
  • ${BOLD}poly-shell doctor${NC}   : Run comprehensive system diagnostics
  • ${BOLD}alpora-fetch${NC}        : Open the faceted mountain terminal system card

${GREEN}${BOLD}Enjoy your new view!${NC}
EOF
}

main() {
    print_banner
    check_system
    request_sudo
    install_dependencies
    setup_repository
    stow_dotfiles
    install_fonts
    enable_services
    show_completion
}

main "$@"
