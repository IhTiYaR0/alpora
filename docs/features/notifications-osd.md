# Notifications and system indicators

Mako remains the notification daemon. Poly Shell reads its active list,
history, actions and DND state over its public commands, refreshed on D-Bus
events rather than polling. The center separates active and archived cards,
removes duplicate IDs, invokes advertised actions and dismisses notifications.
Archived actions are disabled because their application handle has expired.

“Очистить историю” clears the history displayed by Poly Shell, persistently in
`notification-history.json` next to `session.json`. Mako's underlying history
is not deleted: its public interface does not offer history deletion. Hidden
records include the daemon's D-Bus owner so restarting Mako does not suppress
new notifications that reuse an old ID. Active notifications are never hidden
by clearing history.

`poly_shell.indicators.sync_notifications` atomically generates
`~/.local/state/poly-shell/mako-theme.conf` from the saved profile palette and
the selected appearance's interface font. It runs on start, refresh and mode
changes; unchanged styling does not reload Mako. A missing Mako does not stop
the bar. On this desktop, `~/.config/mako/config` includes
`~/.config/hypr/mako.conf`, which includes the generated file. Previous Hyprland
and Mako configurations are backed up in
`~/.local/state/poly-shell/backups/notification-stage-before/`.

Hyprland media key commands retain their existing hardware adjustments and
then invoke `bin/poly-shell osd volume|microphone|brightness` on success.
The command reads the actual device value using `wpctl get-volume` or the
existing backlight adapter; it never adjusts hardware itself. The OSD is a
separate input-transparent overlay on the focused monitor, does not steal
keyboard focus, reuses one card and hides after 1.5 seconds. Repeated key
presses update the value and restart its timeout, not a notification queue.
Its colors follow `Session` and animations honor reduced motion.

Validation on 2026-10-19: 37 Python tests, all QML lint, live notification
action roundtrip (`open`), individual dismissal into history, active/history
deduplication, DND toggle and restore, all three actual device readings and
OSD automatic hiding. Hyprland configuration has no reported errors.
