#!/usr/bin/env bash
# ALPORA One-Line Online Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/pnam-it309/alpora/main/install/get.sh | bash
set -e

main() {
    local slug="${REPO_SLUG:-pnam-it309/alpora}"
    local branch="${ALPORA_BRANCH:-main}"
    local dir
    dir="$(mktemp -d)"
    trap 'rm -rf "$dir"' EXIT
    curl --proto =https --proto-redir =https -fsSL "https://raw.githubusercontent.com/${slug}/${branch}/install/install.sh" -o "$dir/install.sh"
    chmod +x "$dir/install.sh"
    if [[ -t 0 ]]; then
        bash "$dir/install.sh" "$@"
    elif [[ -r /dev/tty ]]; then
        bash "$dir/install.sh" "$@" < /dev/tty
    else
        bash "$dir/install.sh" "$@"
    fi
}

main "$@"
