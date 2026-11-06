#!/usr/bin/env bash
# Source-only terminal presentation. No downloads or system changes here.
# shellcheck disable=SC2034
alpora_colour() {
    alpora_reset='' alpora_bold='' alpora_dim='' alpora_accent='' alpora_warm=''
    if [[ -t 1 && "${TERM:-dumb}" != dumb && -z "${NO_COLOR:-}" ]]; then
        alpora_reset=$'\033[0m' alpora_bold=$'\033[1m' alpora_dim=$'\033[2m'
        # Resolve the selected landscape's semantic colours, including future themes.
        # Python is optional here: a clean Arch console can still show the welcome.
        local palette=()
        if command -v python3 >/dev/null; then
            mapfile -t palette < <(python3 - "${BASH_SOURCE[0]}" "${install_theme:-alpine}" <<'PALETTE'
import json, pathlib, re, sys
try:
    root = pathlib.Path(sys.argv[1]).resolve().parent.parent
    theme = sys.argv[2]
    if not re.fullmatch(r"[a-z0-9-]+", theme):
        raise ValueError("Invalid theme")
    path = root / "assets" / "themes" / (theme + ".json")
    if not path.is_file():
        path = root / "assets" / "themes" / "alpine.json"
    palette = json.loads(path.read_text())["themePalette"]
    for role in ("accent", "secondary"):
        value = palette[role]
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            raise ValueError("Invalid colour")
        print(";".join(str(int(value[i:i+2], 16)) for i in (1, 3, 5)))
except (OSError, ValueError, KeyError):
    pass
PALETTE
)
        fi
        if [[ "${TERM:-}" != linux && ${#palette[@]} -eq 2 ]]; then
            printf -v alpora_accent '\033[38;2;%sm' "${palette[0]}"
            printf -v alpora_warm '\033[38;2;%sm' "${palette[1]}"
        else
            alpora_accent=$'\033[36m' alpora_warm=$'\033[33m'
        fi
    fi
}
alpora_rule() {
    local width=${COLUMNS:-72}
    [[ "$width" =~ ^[0-9]+$ ]] || width=72
    (( width > 72 )) && width=72
    (( width < 8 )) && width=8
    printf '%s  ' "$alpora_dim"
    printf '%*s' "$((width-4))" '' | tr ' ' '-'
    printf '%s\n' "$alpora_reset"
}
alpora_banner() {
    printf '\n%s  A L P O R A%s%s     /     DESKTOP EDITION 01%s\n' "$alpora_bold$alpora_accent" "$alpora_reset" "$alpora_dim" "$alpora_reset"
    alpora_rule
    if (( ${COLUMNS:-72} >= 64 )); then
        printf '%s' "$alpora_accent"
        cat <<'MOUNTAINS'

                             .
                            / \
                   /\      /   \
              /\  /  \    / /\ \
         ____/  \/    \__/ /  \ \____
             /     /\     /    \
          / /     /  \   /      \
MOUNTAINS
        printf '%s\n' "$alpora_reset"
        printf '%s  YOUR DESKTOP. A DIFFERENT VIEW.%s\n' "$alpora_bold" "$alpora_reset"
        printf '%s  Landscapes, colour and motion. Made to feel like home.%s\n\n' "$alpora_dim" "$alpora_reset"
    else
        printf '\n%s     /\     /\%s\n' "$alpora_accent" "$alpora_reset"
        printf '%s  __/  \___/  \__%s\n\n' "$alpora_accent" "$alpora_reset"
        printf '%s  A different view.%s\n\n' "$alpora_bold" "$alpora_reset"
    fi
}
alpora_step() { printf '\n%s  [%s/6] %s%s\n' "$alpora_bold$alpora_accent" "$1" "$2" "$alpora_reset"; }
alpora_choose_theme() {
    printf '%s  Choose the landscape for your first login%s\n\n' "$alpora_bold" "$alpora_reset"
    local labels=('Alpine Dawn' 'Moon Lake' 'Forest Mist' 'Warm Desert' 'Northern Lights' 'Rose Sunset' 'Timeline')
    local ids=('alpine' 'moon-lake' 'forest-mist' 'warm-desert' 'northern-lights' 'rose-sunset' 'timeline')
    local colours=(151 147 109 215 116 175 180)
    local number entry pick
    for number in "${!labels[@]}"; do
        entry=$((number+1))
        if [[ -n "$alpora_accent" && "${TERM:-}" != linux ]]; then
            printf '  %s  \033[38;5;%sm████\033[0m  %s\n' "$entry" "${colours[number]}" "${labels[number]}"
        else printf '  %s  %s\n' "$entry" "${labels[number]}"; fi
    done
    printf '\n'
    while true; do
        read -r -p '  Landscape [1–7, Enter = Alpine Dawn]: ' pick || return 1
        pick=${pick:-1}
        if [[ "$pick" =~ ^[1-7]$ ]]; then install_theme=${ids[pick-1]}; break; fi
        printf '  Please choose a number from 1 to 7.\n'
    done
}
alpora_summary() {
    alpora_colour
    alpora_rule
    printf '\n%s  01 / LANDSCAPE%s\n' "$alpora_bold$alpora_accent" "$alpora_reset"
    printf '  Landscape      %s\n' "${install_theme:-current / Alpine Dawn}"
    printf '%s  Colours follow your landscape across the desktop.%s\n' "$alpora_dim" "$alpora_reset"
    printf '\n%s  02 / THE DETAILS%s\n' "$alpora_bold$alpora_warm" "$alpora_reset"
    printf '  Icons          Papirus + ALPORA palette folders\n'
    printf '  Cursor         Bibata Modern Ice / 24 px\n'
    printf '  Desktop        Panel / dock / widgets / robot\n'
    printf '  Workspace      Overview / lockscreen / theme controls\n'
    printf '  Applications   Foot / Kitty / Nautilus / Firefox\n'
    printf '\n%s  03 / YOUR SPACE%s\n' "$alpora_bold$alpora_accent" "$alpora_reset"
    printf '  New settings receive the ALPORA reference layout.\n'
    printf '  Existing preferences stay yours. Session changes\n'
    printf '  require consent and a configuration backup.\n\n'
    alpora_rule
}
alpora_welcome() {
    alpora_summary
    printf '\n  PREVIEW / No installation or system changes.\n\n'
}
alpora_theme_wizard() {
    alpora_choose_theme
    echo "${install_theme:-alpine}"
}
alpora_colour
