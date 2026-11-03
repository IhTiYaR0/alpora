# ALPORA Live Environment Shell Config
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

if [[ -f /usr/local/bin/alpora-fetch ]]; then
    /usr/local/bin/alpora-fetch --once 2>/dev/null || true
fi

printf '\n\033[1;36m==> Welcome to ALPORA OS Live Desktop!\033[0m\n'
printf '    To install ALPORA OS permanently to disk, run: \033[1;32malpora-install\033[0m\n\n'
