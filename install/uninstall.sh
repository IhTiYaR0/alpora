#!/usr/bin/env bash
# ALPORA clean uninstaller. Run as your normal desktop user.
set -euo pipefail

uninstall_dry_run=false
uninstall_purge=false
uninstall_restore_config=false

for argument in "$@"; do
    case "$argument" in
        --dry-run) uninstall_dry_run=true ;;
        --purge) uninstall_purge=true ;;
        --restore-config) uninstall_restore_config=true ;;
        -h|--help)
            cat <<'HELP'
ALPORA uninstaller
Usage: ./install/uninstall.sh [OPTIONS]

  --dry-run          Print actions that would be performed without removing files.
  --restore-config   Restore latest Hyprland configuration backup if available.
  --purge            Remove all ALPORA user configuration and state (~/.config/poly-shell, ~/.local/state/poly-shell).

Removes:
  - User symlinks: ~/.local/bin/poly-shell, ~/.local/bin/alpora-fetch
  - Quickshell UI symlink: ~/.config/quickshell/poly-shell
  - Systemd user service: ~/.config/systemd/user/poly-shell.service
  - Desktop launcher: ~/.local/share/applications/poly-shell-settings.desktop
HELP
            exit 0 ;;
        *) printf 'Unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done

if [[ "$EUID" -eq 0 ]]; then
    echo 'Run ./install/uninstall.sh as your normal user, without sudo.' >&2
    exit 1
fi

echo "=== ALPORA Uninstaller ==="

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
bin_dir="$HOME/.local/bin"

# 1. Stop active services and running instances
if [[ "$uninstall_dry_run" == true ]]; then
    echo "[dry-run] Would stop poly-shell service and running instance"
else
    echo "Stopping poly-shell service..."
    systemctl --user stop poly-shell.service 2>/dev/null || true
    systemctl --user stop poly-shell-settings.service 2>/dev/null || true
    systemctl --user disable poly-shell.service 2>/dev/null || true
    pkill -u "$UID" -f "quickshell.*shell.qml" 2>/dev/null || true
fi

# 2. Remove symlinks and desktop entries
targets=(
    "$bin_dir/poly-shell"
    "$bin_dir/alpora-fetch"
    "$config_home/quickshell/poly-shell"
    "$config_home/systemd/user/poly-shell.service"
    "$data_home/applications/poly-shell-settings.desktop"
    "$data_home/applications/poly-shell-task-manager.desktop"
)

for target in "${targets[@]}"; do
    if [[ -L "$target" || -f "$target" ]]; then
        if [[ "$uninstall_dry_run" == true ]]; then
            echo "[dry-run] Would remove: $target"
        else
            echo "Removing: $target"
            rm -f "$target"
        fi
    fi
done

if [[ "$uninstall_dry_run" != true ]]; then
    systemctl --user daemon-reload 2>/dev/null || true
fi

# 3. Restore Hyprland configuration backup if requested
if [[ "$uninstall_restore_config" == true ]]; then
    backup_root="$state_home/poly-shell/backups"
    if [[ -d "$backup_root" ]]; then
        latest_backup=$(find "$backup_root" -mindepth 1 -maxdepth 1 -type d | sort -r | head -n 1)
        if [[ -n "$latest_backup" && -d "$latest_backup" ]]; then
            hypr_dir="$config_home/hypr"
            if [[ "$uninstall_dry_run" == true ]]; then
                echo "[dry-run] Would restore Hyprland config from: $latest_backup"
            else
                echo "Restoring Hyprland configuration from $latest_backup..."
                mkdir -p "$hypr_dir"
                cp -a "$latest_backup/." "$hypr_dir/"
                echo "Hyprland configuration restored."
            fi
        else
            echo "Notice: No backup directory found in $backup_root"
        fi
    else
        echo "Notice: No backup root found ($backup_root)"
    fi
fi

# 4. Purge state and configuration if requested
if [[ "$uninstall_purge" == true ]]; then
    purge_dirs=(
        "$config_home/poly-shell"
        "$state_home/poly-shell"
    )
    for pdir in "${purge_dirs[@]}"; do
        if [[ -d "$pdir" ]]; then
            if [[ "$uninstall_dry_run" == true ]]; then
                echo "[dry-run] Would purge directory: $pdir"
            else
                echo "Purging directory: $pdir"
                rm -rf "$pdir"
            fi
        fi
    done
fi

echo "=== ALPORA Uninstallation Complete ==="
if [[ "$uninstall_restore_config" != true ]]; then
    echo "Tip: Use ./install/uninstall.sh --restore-config if you need to recover pre-install Hyprland configs."
fi

