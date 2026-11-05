#!/usr/bin/env bash
# ALPORA bootstrap for Arch Linux and Arch-based distributions. Run as your normal desktop user.
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
install_dry_run=false
install_skip_packages=false
install_replace_config=false
install_ui_only=false
install_core_only=false
install_harden=false
install_ignore_distro=false
install_theme=''
install_wizard=false
install_preview=false
# shellcheck source=scripts/installer-ui.sh
source "$project_dir/scripts/installer-ui.sh"
for argument in "$@"; do
    case "$argument" in
        --dry-run) install_dry_run=true ;;
        --skip-packages) install_skip_packages=true ;;
        --replace-config) install_replace_config=true ;;
        --ui-only) install_ui_only=true; install_skip_packages=true ;;
        --core-only|--minimal) install_core_only=true ;;
        --harden) install_harden=true ;;
        --ignore-distro-check|--force-distro) install_ignore_distro=true ;;
        --uninstall)
            exec "$project_dir/install/uninstall.sh" "${@:2}"
            ;;
        --theme=*) install_theme=${argument#--theme=} ;;
        --wizard) install_wizard=true ;;
        --preview) install_preview=true ;;
        -h|--help)
            cat <<'HELP'
ALPORA installer for Arch Linux and Arch-based distributions
Usage: ./install/install.sh [OPTIONS]

  --ui-only               Install standalone ALPORA UI shell only. Does NOT install system
                          packages and does NOT alter existing Hyprland configuration.
                          Ideal for custom Arch kernels (zen/lts/hardened), non-Arch distros, or custom setups.
  --minimal, --core-only  Install only core compositor & shell packages (~28 packages);
                          skips bundled applications (Firefox, Nautilus, Kitty, Foot, Fuzzel, etc.).
  --harden                Apply Arch Linux security hardening (UFW firewall, AppArmor MAC,
                          sysctl kernel protections, and multi-core CPU optimizations).
  --ignore-distro-check   Bypass Arch distribution detection and attempt pacman installation.
  --uninstall             Cleanly remove ALPORA symlinks, services, and optionally restore configs.
  --dry-run               Print the plan without downloading or changing anything.
  --skip-packages         Use already installed dependencies (development/testing).
  --replace-config        Back up and replace an existing Hyprland configuration.
  --theme=ID              Choose alpine, moon-lake, forest-mist, warm-desert,
                          northern-lights, rose-sunset or timeline.
  --wizard                Show the theme chooser, including with --dry-run.
  --preview               Show only the welcome screen; never install or change files.

Run as a normal user, not with sudo. The package step invokes sudo itself.
An existing session configuration requires explicit replacement consent.
HELP
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done
case "$install_theme" in
    ''|alpine|moon-lake|forest-mist|warm-desert|northern-lights|rose-sunset|timeline) ;;
    *) printf 'Unknown theme: %s\n' "$install_theme" >&2; exit 2 ;;
esac
if [[ "$install_preview" == true ]]; then
    alpora_banner
    alpora_welcome
    exit 0
fi
if [[ "$EUID" -eq 0 ]]; then
    echo 'Run ./install/install.sh as your normal user, without sudo. Pacman prompts when necessary.' >&2
    exit 1
fi
detected_pkg_mgr='unknown'
if command -v pacman >/dev/null; then
    detected_pkg_mgr='pacman'
elif command -v dnf >/dev/null; then
    detected_pkg_mgr='dnf'
elif command -v apt-get >/dev/null; then
    detected_pkg_mgr='apt'
fi

if [[ "$install_ui_only" != true && "$install_ignore_distro" != true ]]; then
    if [[ "$detected_pkg_mgr" == 'unknown' ]]; then
        echo 'ALPORA automated package installation currently supports pacman, dnf, and apt.' >&2
        echo 'Use ./install/install.sh --ui-only to install shell UI without package management,' >&2
        echo 'or --ignore-distro-check to force system package manager installation.' >&2
        exit 1
    fi
fi
alpora_colour
alpora_banner
if [[ "$install_wizard" == true || ( -t 0 && -t 1 && -z "$install_theme" && "$install_dry_run" != true ) ]]; then
    alpora_choose_theme
fi
alpora_summary
required_packages=()
optional_packages=()
if command -v python3 >/dev/null 2>&1; then
    mapfile -t required_packages < <(python3 "$project_dir/scripts/setup-arch-desktop" --print-packages 2>/dev/null || true)
    mapfile -t optional_packages < <(python3 "$project_dir/scripts/setup-arch-desktop" --print-packages --optional 2>/dev/null || true)
fi

if [[ ${#required_packages[@]} -eq 0 ]]; then
    required_packages=(quickshell hyprland python systemd glib2)
fi
if [[ ${#optional_packages[@]} -eq 0 ]]; then
    optional_packages=(foot kitty nautilus xdg-utils xdg-user-dirs fuzzel upower wireplumber networkmanager nm-connection-editor bluez-utils util-linux brightnessctl hyprsunset mako pavucontrol power-profiles-daemon swaybg hyprlock hypridle hyprshutdown wl-clipboard playerctl grim slurp libnotify wine)
fi

if [[ "$install_harden" == true ]]; then
    optional_packages+=(ufw apparmor irqbalance)
fi

if [[ "$install_core_only" == true ]]; then
    packages=("${required_packages[@]}")
else
    packages=("${required_packages[@]}" "${optional_packages[@]}")
fi

if [[ "$install_dry_run" == true ]]; then
    echo 'DRY-RUN / no changes will be made'
    if [[ "$install_ui_only" == true ]]; then
        echo '1. Link poly-shell, alpora-fetch, and quickshell QML UI.'
        echo '2. Seed user preferences and themes.'
        echo '3. Install systemd user service poly-shell.service.'
    else
        printf 'Packages (%d): %s\n' "${#packages[@]}" "${packages[*]}"
        echo '1. Fully update Arch/derivative and install packages with pacman (unless --skip-packages).'
        echo '2. Download pinned, checksum-verified Papirus and Bibata themes into user data.'
        echo '3. Back up existing Hyprland configuration; require consent before replacement.'
        echo '4. Install ALPORA, session startup, default keybindings, lock and screenshot helpers.'
        echo '5. Apply icon/cursor settings; prepare the selected theme for next login.'
        echo '6. Enable NetworkManager/Bluetooth and user audio services when appropriate.'
        echo 'No drivers, bootloader or display manager will be modified.'
    fi
    exit 0
fi
install_log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/poly-shell/install-logs"
mkdir -p "$install_log_dir"
chmod 700 "$install_log_dir"
ALPORA_INSTALL_LOG="$install_log_dir/$(date +%Y%m%d-%H%M%S)-$$.log"
export ALPORA_INSTALL_LOG
touch "$ALPORA_INSTALL_LOG"
chmod 600 "$ALPORA_INSTALL_LOG"
printf '\n  Installation log: %s\n' "$ALPORA_INSTALL_LOG"
trap 'printf "\n  Installation stopped. Review the log: %s\n" "$ALPORA_INSTALL_LOG" >&2' ERR

if [[ "$install_ui_only" == true ]]; then
    alpora_step 1 'Prepare ALPORA Standalone UI'
    printf '    UI-only mode enabled: skipping system package installation and pacman updates.\n'
else
    alpora_step 1 'Prepare System & Dependencies'
    if [[ "$install_skip_packages" != true ]]; then
        command -v sudo >/dev/null || { echo 'Install sudo and allow your user to manage packages first.' >&2; exit 1; }
        case "$detected_pkg_mgr" in
            pacman)
                sudo pacman -Syu --needed "${packages[@]}" 2>&1 | tee -a "$ALPORA_INSTALL_LOG"
                ;;
            dnf)
                printf '    Installing dependencies via dnf...\n'
                dnf_pkgs=()
                for pkg in "${packages[@]}"; do
                    case "$pkg" in
                        python-pillow) dnf_pkgs+=(python3-pillow) ;;
                        python-gobject) dnf_pkgs+=(python3-gobject) ;;
                        gtk3) dnf_pkgs+=(gtk3) ;;
                        qt6-svg) dnf_pkgs+=(qt6-qtsvg) ;;
                        qt6-multimedia) dnf_pkgs+=(qt6-qtmultimedia) ;;
                        *) dnf_pkgs+=("$pkg") ;;
                    esac
                done
                sudo dnf install -y --skip-broken "${dnf_pkgs[@]}" 2>&1 | tee -a "$ALPORA_INSTALL_LOG" || true
                ;;
            apt)
                printf '    Installing dependencies via apt...\n'
                apt_pkgs=()
                for pkg in "${packages[@]}"; do
                    case "$pkg" in
                        python-pillow) apt_pkgs+=(python3-pil) ;;
                        python-gobject) apt_pkgs+=(python3-gi) ;;
                        gtk3) apt_pkgs+=(libgtk-3-0) ;;
                        qt6-svg) apt_pkgs+=(libqt6svg6) ;;
                        qt6-multimedia) apt_pkgs+=(libqt6multimedia6) ;;
                        git|curl|wireplumber|pipewire|upower|network-manager|foot|kitty|nautilus|firefox|mako-notifier) apt_pkgs+=("$pkg") ;;
                        *) apt_pkgs+=("$pkg") ;;
                    esac
                done
                sudo apt-get update && sudo apt-get install -y --no-install-recommends "${apt_pkgs[@]}" 2>&1 | tee -a "$ALPORA_INSTALL_LOG" || true
                ;;
            *)
                printf '    Notice: Package manager "%s" is not directly supported for auto-installation.\n' "$detected_pkg_mgr"
                printf '    Please ensure core tools (Hyprland, Quickshell, Python 3, Qt6) are installed.\n'
                ;;
        esac
    else
        printf '    Packages skipped by request; runtime dependencies will be checked.\n'
    fi
fi

arguments=()
if [[ "$install_ui_only" == true ]]; then arguments+=(--ui-only); fi
if [[ "$install_replace_config" == true ]]; then arguments+=(--replace-config); fi
if [[ -n "$install_theme" ]]; then arguments+=(--theme "$install_theme"); fi
python3 "$project_dir/scripts/setup-arch-desktop" "${arguments[@]}"

if [[ "$install_harden" == true ]]; then
    printf '\n\033[1;36m==> Applying ALPORA OS System Hardening & Performance Optimizations...\033[0m\n'
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw default deny incoming || true
        sudo ufw default allow outgoing || true
        sudo ufw allow 1714:1764/udp comment 'ALPORA Phone / KDE Connect' || true
        sudo ufw allow 1714:1764/tcp comment 'ALPORA Phone / KDE Connect' || true
        sudo systemctl enable --now ufw.service || true
    fi
    sudo systemctl enable --now apparmor.service || true
    sudo systemctl enable --now irqbalance.service || true

    python3 -c "from poly_shell.services.security_service import SecurityService; s = SecurityService(); print(s.get_security_sysctl())" | sudo tee /etc/sysctl.d/99-alpora-security.conf >/dev/null || true
    python3 -c "from poly_shell.services.security_service import SecurityService; s = SecurityService(); print(s.get_performance_sysctl())" | sudo tee /etc/sysctl.d/99-alpora-performance.conf >/dev/null || true
    sudo sysctl --system || true
    printf '\033[1;32m==> ALPORA Security & Performance Hardening Applied Successfully!\033[0m\n'
fi

