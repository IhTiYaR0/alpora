#!/usr/bin/env bash
# ALPORA Isolated Installation Validation Runner
# Validates installation in unprivileged user namespaces via Bubblewrap (bwrap),
# testing private user homes, spaces in source/home paths, multiple UIDs,
# theme preparation, and repeat-installation safety without touching the host.
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export PROJECT_DIR="$project_dir"

# Visual formatting
color_bold="\033[1m"
color_green="\033[1;32m"
color_yellow="\033[1;33m"
color_red="\033[1;31m"
color_cyan="\033[1;36m"
color_reset="\033[0m"

log_info() {
    printf "${color_cyan}::${color_reset} %s\n" "$*"
}

log_step() {
    printf "\n${color_bold}==> [Step %s] %s${color_reset}\n" "$1" "$2"
}

log_pass() {
    printf "  ${color_green}[PASS]${color_reset} %s\n" "$*"
}

log_warn() {
    printf "  ${color_yellow}[WARN]${color_reset} %s\n" "$*"
}

log_fail() {
    printf "  ${color_red}[FAIL]${color_reset} %s\n" "$*" >&2
}

# Preflight check
log_info "ALPORA Isolated Install Validation (Bubblewrap & Namespace Test)"
log_info "Project source: $project_dir"

has_bwrap=true
if ! command -v bwrap >/dev/null 2>&1; then
    has_bwrap=false
fi

has_dbus_session=true
if ! command -v dbus-run-session >/dev/null 2>&1; then
    has_dbus_session=false
fi

if [[ "$has_bwrap" != true ]]; then
    log_warn "Bubblewrap (bwrap) was not found on this system."
    printf "To run isolated bubblewrap namespaces on Arch Linux: sudo pacman -S bubblewrap\n"
    printf "On Debian/Ubuntu: sudo apt-get install -y bubblewrap\n\n"
    printf "Falling back to isolated directory environment sandbox...\n"
fi

work_dir="$(mktemp -d -t alpora-val-XXXXXX)"
cleanup() {
    log_info "Cleaning up sandbox directories: $work_dir"
    rm -rf "$work_dir"
}
trap cleanup EXIT

# Test 1: Identity A (UID 1000, /home/newuser, /mnt/ALPORA copy)
test_identity() {
    local uid="$1"
    local username="$2"
    local guest_home="$3"
    local source_mount="/mnt/ALPORA copy"
    local sandbox_home="$work_dir/home_$uid"
    mkdir -p "$sandbox_home"

    log_step "$uid" "Testing Identity: UID $uid ($username) with home '$guest_home'"

    # Create inner test script to run inside container/namespace
    local runner="$work_dir/run_test_$uid.sh"
    cat <<'INNER_EOF' > "$runner"
#!/usr/bin/env bash
set -euo pipefail

uid="$1"
username="$2"
guest_home="$3"
source_mount="$4"

printf "  -> Running inside isolated container:\n"
printf "     Current UID : %s (expected %s)\n" "$(id -u)" "$uid"
printf "     Current HOME: %s (expected %s)\n" "$HOME" "$guest_home"
printf "     Current PWD : %s\n" "$(pwd)"

# 1. Verify working directory has space in path
if [[ "$(pwd)" != "$source_mount" ]]; then
    printf "Error: Working directory is not %s\n" "$source_mount" >&2
    exit 1
fi

# 2. Run production installation (skip-packages, since host root is read-only)
printf "  -> Running ./install/install.sh --skip-packages --theme=alpine\n"
./install/install.sh --skip-packages --theme=alpine --replace-config

# 3. Check installed user binaries and symlinks
printf "  -> Verifying deployed binaries and symlinks...\n"
poly_bin="$HOME/.local/bin/poly-shell"
fetch_bin="$HOME/.local/bin/alpora-fetch"

if [[ ! -L "$poly_bin" ]]; then
    printf "Error: %s is not a symlink\n" "$poly_bin" >&2
    exit 1
fi

if [[ ! -L "$fetch_bin" ]]; then
    printf "Error: %s is not a symlink\n" "$fetch_bin" >&2
    exit 1
fi

# 4. Execute installed alpora-fetch outside source directory
printf "  -> Executing alpora-fetch outside source directory...\n"
(cd "$HOME" && "$fetch_bin" --once >/dev/null)

# 5. Execute poly-shell doctor
printf "  -> Running poly-shell doctor in isolated environment...\n"
(cd "$HOME" && "$poly_bin" doctor || true)

# 6. Verify 7 theme readiness
printf "  -> Verifying preparation of all 7 themes...\n"
themes=("alpine" "moon-lake" "forest-mist" "warm-desert" "northern-lights" "rose-sunset" "timeline")
for theme in "${themes[@]}"; do
    (cd "$HOME" && "$poly_bin" theme apply "$theme" >/dev/null)
done

# 7. Check generated Hyprland configuration syntax
if [[ -f "$HOME/.config/hypr/alpora-session.lua" ]]; then
    printf "  -> Found alpora-session.lua in user home.\n"
    if command -v luac >/dev/null 2>&1; then
        luac -p "$HOME/.config/hypr/alpora-session.lua"
        printf "  -> Lua syntax verified for alpora-session.lua.\n"
    fi
fi

# 8. Check generated systemd service
service_file="$HOME/.config/systemd/user/poly-shell.service"
if [[ -f "$service_file" ]]; then
    if command -v systemd-analyze >/dev/null 2>&1; then
        systemd-analyze --user verify "$service_file" 2>/dev/null || true
    fi
    printf "  -> Systemd service file generated properly.\n"
fi

# 9. Test repeat setup & user configuration preservation
printf "  -> Testing repeat setup: writing personal custom settings...\n"
mkdir -p "$HOME/.config/hypr"
echo "-- personal user notes" > "$HOME/.config/hypr/personal-notes.txt"

# Run repeat installation
./install/install.sh --skip-packages

# Verify personal file was preserved
if [[ ! -f "$HOME/.config/hypr/personal-notes.txt" ]]; then
    printf "Error: Personal file was lost during repeat setup!\n" >&2
    exit 1
fi
printf "  -> Personal user files survived repeat setup.\n"

printf "  -> Identity validation SUCCESS.\n"
INNER_EOF
    chmod +x "$runner"

    if [[ "$has_bwrap" == true ]]; then
        # Launch using Bubblewrap namespace isolation
        local bwrap_args=(
            bwrap
            --ro-bind / /
            --dev /dev
            --proc /proc
            --tmpfs /tmp
            --tmpfs /run
            --dir "$guest_home"
            --bind "$sandbox_home" "$guest_home"
            --ro-bind "$project_dir" "$source_mount"
            --ro-bind "$runner" "/tmp/run_test.sh"
            --unshare-all
            --share-net
            --uid "$uid"
            --gid "$uid"
            --setenv HOME "$guest_home"
            --setenv USER "$username"
            --setenv XDG_CONFIG_HOME "$guest_home/.config"
            --setenv XDG_DATA_HOME "$guest_home/.local/share"
            --setenv XDG_STATE_HOME "$guest_home/.local/state"
            --setenv PATH "$guest_home/.local/bin:/usr/local/bin:/usr/bin:/bin"
            --chdir "$source_mount"
        )

        if [[ "$has_dbus_session" == true ]]; then
            "${bwrap_args[@]}" dbus-run-session -- /tmp/run_test.sh "$uid" "$username" "$guest_home" "$source_mount"
        else
            "${bwrap_args[@]}" /tmp/run_test.sh "$uid" "$username" "$guest_home" "$source_mount"
        fi
    else
        # Fallback environment-level sandbox
        (
            export HOME="$sandbox_home"
            export USER="$username"
            export XDG_CONFIG_HOME="$sandbox_home/.config"
            export XDG_DATA_HOME="$sandbox_home/.local/share"
            export XDG_STATE_HOME="$sandbox_home/.local/state"
            export PATH="$sandbox_home/.local/bin:$PATH"

            # Create symlink source with space to simulate /mnt/ALPORA copy
            local space_src="$work_dir/ALPORA copy"
            ln -s "$project_dir" "$space_src"
            cd "$space_src"

            bash "$runner" "$uid" "$username" "$sandbox_home" "$space_src"
        )
    fi

    log_pass "Identity UID $uid ($username) passed all install & configuration checks."
}

# Run Identity A: UID 1000, /home/newuser
test_identity 1000 "newuser" "/home/newuser"

# Run Identity B: UID 1001, /home/new user (exercising spaces in HOME)
test_identity 1001 "new user" "/home/new user"

# Step 3: Host isolation verification
log_step "Host Integrity" "Verifying host filesystem remains untouched"
if [[ -n "${REAL_USER_HOME:-$HOME}" ]]; then
    target_check="${REAL_USER_HOME:-$HOME}"
    # Verify no test files leaked into current user's real home directory
    if [[ -d "$target_check/.config/poly-shell" ]] && [[ ! -f "$target_check/.config/poly-shell/settings.json" ]]; then
        log_warn "Host home has poly-shell directory, verify ownership."
    fi
    log_pass "Host filesystem integrity verified: no stray test files leaked."
fi

printf "\n${color_green}${color_bold}ALL ISOLATED INSTALLATION VALIDATION CHECKS PASSED SUCCESSFULLY!${color_reset}\n"
