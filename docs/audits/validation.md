# Foundation validation

First live validation: 2026-10-19, Arch Linux.

## Environment

- Hyprland 0.56.2, Quickshell 0.3.2, Qt 6.12.0.
- One eDP-1 display: 1920×1080, 60 Hz, scale 1.5 (1280×720 logical).
- User systemd service; existing Mako, hypridle, polkit agent and wallpaper retained.

## Verified

- 13 automated tests pass, including actual child-process termination and propagation
  of a failing child's exit status, atomic state updates, concurrent mode switching,
  configuration rejection, backup and rollback with preservation of unrelated edits.
- QML lint passes with zero warnings. There is one narrow source-level suppression:
  Quickshell's platform-selected PanelWindow is creatable at runtime, while its generated
  interface metadata marks it uncreatable. Other uncreatable-type diagnostics remain enabled.
- Live IPC reports ready, one screen, Work mode, workspace 1 and no application error.
- Vibe selection updates the running shell; Vibe survives a full service restart;
  restoring Work updates the running shell again.
- Workspace selection through the same dispatcher used by panel buttons changes
  workspace 1 → 2 → 1 in the live Lua-configured Hyprland session.
- Hyprland layer inspection confirms one `poly-shell` panel and no remaining Waybar.
- Visual inspection confirms a readable single panel at fractional scale 1.5.
- The previous Waybar autostart command has a timestamped backup under
  `$XDG_STATE_HOME/poly-shell/backups/` and a startup fallback in the managed block.

## Initial performance baseline

After startup and interaction, a 10-second sample of the Quickshell process in Work mode
measured **1.70% of one CPU core**. Linux `/proc` reported **271 MiB RSS / 235 MiB PSS**.
These values are a development baseline, not a performance target or a comparison with
other shells. The rest of the user's desktop was running normally; this was not an
isolated benchmark. GPU use and frame timings were not measured.

Future profiling should distinguish Qt/rendering overhead from service subscriptions,
measure longer idle periods and wakeups, and compare equivalent functionality. Smoothness
under interactive load and battery impact still need dedicated checks.

## Remaining checks

- Multiple physical monitors and hotplug.
- Keyboard traversal of every control and assistive-technology behavior.
- Sleep/resume and the next complete login through the modified autostart.
- Persistent runtime-crash recovery and long-running resource behavior.
- Other supported Hyprland/Qt versions and non-Arch packaging.

Restore the original panel with `~/.local/bin/poly-shell deactivate`.
