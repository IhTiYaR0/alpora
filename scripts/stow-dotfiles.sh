#!/usr/bin/env bash
# ALPORA dotfiles symlink management (compatible with GNU Stow and Chezmoi).
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
dotfiles_dir="$project_dir/dotfiles"
target_dir="${HOME:-/home/$USER}"
backup_base="${XDG_CONFIG_HOME:-$HOME/.config}/alpora-backups"

action="${1:-status}"
packages=("hypr" "poly-shell" "foot" "kitty" "fcitx5" "shell" "fastfetch" "systemd")

alpora_log() {
    printf ":: %s\n" "$*"
}

alpora_warn() {
    printf "\033[1;33m[WARN]\033[0m %s\n" "$*" >&2
}

alpora_error() {
    printf "\033[1;31m[ERROR]\033[0m %s\n" "$*" >&2
}

# 1. Status Command
do_status() {
    alpora_log "ALPORA Dotfiles Symlink Status"
    printf "Dotfiles Repo : %s\n" "$dotfiles_dir"
    printf "Target Root   : %s\n\n" "$target_dir"
    printf "%-32s %-12s %s\n" "Dotfile" "Status" "Target Destination"
    printf "%-32s %-12s %s\n" "--------------------------------" "------------" "----------------------------------------"

    for pkg in "${packages[@]}"; do
        pkg_path="$dotfiles_dir/$pkg"
        if [[ ! -d "$pkg_path" ]]; then continue; fi

        while IFS= read -r -d '' file; do
            rel="${file#"$pkg_path/"}"
            dest="$target_dir/$rel"

            if [[ -L "$dest" ]]; then
                resolved="$(readlink -f "$dest" 2>/dev/null || true)"
                src_resolved="$(readlink -f "$file" 2>/dev/null || true)"
                if [[ "$resolved" == "$src_resolved" ]]; then
                    status="\033[1;32m[LINKED]\033[0m"
                else
                    status="\033[1;33m[OTHER]\033[0m"
                fi
            elif [[ -e "$dest" ]]; then
                status="\033[1;31m[EXISTS]\033[0m"
            else
                status="\033[1;30m[MISSING]\033[0m"
            fi

            printf "%-32s %-20b %s\n" "$pkg/$rel" "$status" "$dest"
        done < <(find "$pkg_path" -type f -print0)
    done

    # Check shell binaries
    printf "\n%-32s %-12s %s\n" "Binary Commands" "Status" "Target Destination"
    printf "%-32s %-12s %s\n" "--------------------------------" "------------" "----------------------------------------"
    for bin_name in poly-shell alpora-fetch; do
        bin_src="$project_dir/bin/$bin_name"
        bin_dest="$target_dir/.local/bin/$bin_name"
        if [[ -L "$bin_dest" ]]; then
            resolved="$(readlink -f "$bin_dest" 2>/dev/null || true)"
            if [[ "$resolved" == "$(readlink -f "$bin_src")" ]]; then
                bstatus="\033[1;32m[LINKED]\033[0m"
            else
                bstatus="\033[1;33m[OTHER]\033[0m"
            fi
        elif [[ -e "$bin_dest" ]]; then
            bstatus="\033[1;31m[EXISTS]\033[0m"
        else
            bstatus="\033[1;30m[MISSING]\033[0m"
        fi
        printf "%-32s %-20b %s\n" "bin/$bin_name" "$bstatus" "$bin_dest"
    done
    printf "\n"
}

# 2. Link Command (GNU Stow or safe fallback)
do_link() {
    alpora_log "Linking dotfiles to $target_dir..."

    # Use GNU Stow if available
    if command -v stow >/dev/null 2>&1; then
        alpora_log "Using GNU Stow for clean package symlinking..."
        for pkg in "${packages[@]}"; do
            if [[ -d "$dotfiles_dir/$pkg" ]]; then
                stow -v -R -t "$target_dir" -d "$dotfiles_dir" "$pkg"
            fi
        done
    else
        alpora_log "GNU Stow not found; using internal safe symlink manager..."
        local backup_dir
        backup_dir="$backup_base/$(date +%Y%m%d-%H%M%S)"
        local backed_up=false

        for pkg in "${packages[@]}"; do
            pkg_path="$dotfiles_dir/$pkg"
            if [[ ! -d "$pkg_path" ]]; then continue; fi

            while IFS= read -r -d '' file; do
                rel="${file#"$pkg_path/"}"
                dest="$target_dir/$rel"

                # Check conflict
                if [[ -e "$dest" && ! -L "$dest" ]]; then
                    if [[ "$backed_up" == false ]]; then
                        mkdir -p "$backup_dir"
                        backed_up=true
                        alpora_log "Backing up conflicting files to $backup_dir"
                    fi
                    mkdir -p "$(dirname "$backup_dir/$rel")"
                    mv "$dest" "$backup_dir/$rel"
                    alpora_log "Backed up: $dest -> $backup_dir/$rel"
                elif [[ -L "$dest" ]]; then
                    rm -f "$dest"
                fi

                mkdir -p "$(dirname "$dest")"
                ln -sf "$file" "$dest"
                printf "  -> Linked: %s -> %s\n" "$rel" "$dest"
            done < <(find "$pkg_path" -type f -print0)
        done
    fi

    # Link local binaries
    mkdir -p "$target_dir/.local/bin"
    for bin_name in poly-shell alpora-fetch; do
        bin_src="$project_dir/bin/$bin_name"
        bin_dest="$target_dir/.local/bin/$bin_name"
        if [[ -e "$bin_dest" && ! -L "$bin_dest" ]]; then
            mv "$bin_dest" "${bin_dest}.bak-$(date +%Y%m%d-%H%M%S)"
        fi
        ln -sf "$bin_src" "$bin_dest"
        printf "  -> Linked binary: %s -> %s\n" "$bin_name" "$bin_dest"
    done

    # Link Quickshell UI shell
    mkdir -p "$target_dir/.config/quickshell"
    qs_dest="$target_dir/.config/quickshell/poly-shell"
    if [[ -e "$qs_dest" && ! -L "$qs_dest" ]]; then
        mv "$qs_dest" "${qs_dest}.bak-$(date +%Y%m%d-%H%M%S)"
    fi
    ln -sfn "$project_dir/shell" "$qs_dest"
    printf "  -> Linked QML shell -> %s\n" "$qs_dest"

    alpora_log "Symlink creation complete! Edits in ~/.config will now sync directly with the repository."
}

# 3. Unlink Command
do_unlink() {
    alpora_log "Unlinking dotfiles from $target_dir..."
    if command -v stow >/dev/null 2>&1; then
        for pkg in "${packages[@]}"; do
            if [[ -d "$dotfiles_dir/$pkg" ]]; then
                stow -v -D -t "$target_dir" -d "$dotfiles_dir" "$pkg" || true
            fi
        done
    else
        for pkg in "${packages[@]}"; do
            pkg_path="$dotfiles_dir/$pkg"
            if [[ ! -d "$pkg_path" ]]; then continue; fi

            while IFS= read -r -d '' file; do
                rel="${file#"$pkg_path/"}"
                dest="$target_dir/$rel"
                if [[ -L "$dest" ]]; then
                    rm -f "$dest"
                    printf "  Removed symlink: %s\n" "$dest"
                fi
            done < <(find "$pkg_path" -type f -print0)
        done
    fi

    rm -f "$target_dir/.local/bin/poly-shell" "$target_dir/.local/bin/alpora-fetch"
    rm -f "$target_dir/.config/quickshell/poly-shell"
    alpora_log "All ALPORA symlinks removed cleanly."
}

case "$action" in
    status|check)
        do_status
        ;;
    link|stow|apply)
        do_link
        ;;
    unlink|unstow|delete)
        do_unlink
        ;;
    restow)
        do_unlink
        do_link
        ;;
    -h|--help)
        cat <<'EOF'
ALPORA Dotfiles Symlink Manager (Stow / Chezmoi compatible)
Usage: ./scripts/stow-dotfiles.sh [COMMAND]

Commands:
  status, check   Show status of all dotfile symlinks in target directory
  link, stow      Link dotfiles using GNU Stow (or safe fallback symlinker)
  unlink, unstow  Remove active dotfile symlinks
  restow          Re-link all dotfiles and refresh target paths
  --help, -h      Display this help menu
EOF
        ;;
    *)
        alpora_error "Unknown action: $action. Use status, link, unlink, or restow."
        exit 1
        ;;
esac
