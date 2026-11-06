# ==============================================================================
# ALPORA Shell Configuration (.bashrc)
# ==============================================================================

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Path additions
export PATH="$HOME/.local/bin:$PATH"

# Wayland & Desktop environment flags
export XDG_CURRENT_DESKTOP="Hyprland"
export XDG_SESSION_TYPE="wayland"
export QT_QPA_PLATFORM="wayland;xcb"
export QT_QPA_PLATFORMTHEME="gtk3"
export GDK_BACKEND="wayland,x11,*"

# Fcitx5 Vietnamese Input method integration
export GTK_IM_MODULE="fcitx"
export QT_IM_MODULE="fcitx"
export XMODIFIERS="@im=fcitx"
export SDL_IM_MODULE="fcitx"

# Cursor theme
export XCURSOR_THEME="Bibata-Modern-Ice"
export XCURSOR_SIZE="24"

# ALPORA Command Aliases
alias poly-doctor="poly-shell doctor"
alias poly-status="poly-shell control status"
alias poly-theme="poly-shell theme"
alias poly-tasks="poly-shell task-manager"
alias poly-exe="poly-shell exe"
alias poly-fetch="alpora-fetch"
alias poly-restart="systemctl --user restart poly-shell.service"
alias poly-logs="journalctl --user -u poly-shell.service -f"

# Standard Unix Aliases
alias ls="ls --color=auto"
alias ll="ls -lah --color=auto"
alias grep="grep --color=auto"

# PS1 Prompt (clean minimal prompt with git status)
PS1='\[\033[38;2;133;158;146m\]\u@\h\[\033[0m\]:\[\033[38;2;104;144;168m\]\w\[\033[0m\]\$ '

