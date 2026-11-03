#!/usr/bin/env bash
# ALPORA One-Line Online Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/pnam-it309/alpora/main/install/get.sh | bash
set -euo pipefail

main() {
    local repo_url="${ALPORA_REPO_URL:-https://github.com/pnam-it309/alpora.git}"
    local branch="${ALPORA_BRANCH:-main}"
    local target_dir="${ALPORA_DIR:-$HOME/.local/share/alpora}"

    printf '\n\033[1;36m==> ALPORA Online Installer\033[0m\n'

    if ! command -v git >/dev/null 2>&1; then
        echo "Error: 'git' is required to download and install ALPORA." >&2
        if command -v pacman >/dev/null 2>&1; then
            echo "Please run: sudo pacman -S --needed git" >&2
        elif command -v apt-get >/dev/null 2>&1; then
            echo "Please run: sudo apt install git" >&2
        fi
        exit 1
    fi

    if [[ -d "$target_dir/.git" ]]; then
        printf '==> Existing ALPORA repository found at %s. Updating...\n' "$target_dir"
        git -C "$target_dir" fetch origin "$branch" --depth=1
        git -C "$target_dir" checkout "$branch"
        git -C "$target_dir" reset --hard "origin/$branch"
    else
        printf '==> Cloning ALPORA repository into %s...\n' "$target_dir"
        mkdir -p "$(dirname "$target_dir")"
        git clone --depth=1 --branch "$branch" "$repo_url" "$target_dir"
    fi

    printf '==> Launching ALPORA installer...\n\n'
    chmod +x "$target_dir/install/"*.sh "$target_dir/scripts/"*.sh

    if [[ -t 0 ]]; then
        bash "$target_dir/install/install.sh" "$@"
    elif [[ -r /dev/tty ]]; then
        bash "$target_dir/install/install.sh" "$@" < /dev/tty
    else
        bash "$target_dir/install/install.sh" "$@"
    fi
}

main "$@"
