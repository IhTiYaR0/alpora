# Auto-start Hyprland on TTY1 login in Live environment
if [[ -z "$WAYLAND_DISPLAY" ]] && [[ -z "$DISPLAY" ]] && [[ "$(tty)" = "/dev/tty1" ]]; then
    exec Hyprland
fi

