# Alpine lockscreen

The real screen lock remains Hyprlock 0.9.6 with its existing PAM configuration.
No password handling, fake QML lock, grace period, PAM edits, or unlock IPC was
added. Super+L, the quick-settings lock button, and Hypridle still launch the
same `hyprlock` command. Existing lock-before-sleep wiring is unchanged.

`~/.config/hypr/hyprlock.conf` supplies fallback variables, sources the generated
`~/.local/state/poly-shell/hyprlock-theme.conf`, then loads native widgets from
`assets/lockscreen/layout.conf`. The previous complete configuration is backed
up at `~/.local/state/poly-shell/backups/lockscreen-stage-before/hyprlock.conf`.
Restoring that one file restores the old appearance; no service restart needed.

The layout repeats on every output: sharp, dimmed alpine wallpaper, a sloped
clock ribbon with the same triangulated ridges as the bar, semibold clock,
Russian date, and a separate compact password field with username and layout.
There is no large login card or decorative diamond logo. The input's amber outline indicates Caps Lock,
sage indicates authentication in progress, and rose indicates failure. Existing
Super+Space keyboard-layout switching remains compositor-managed. Empty input
does not initiate authentication. The short input caption shows layout and Enter.

`poly_shell.lockscreen.sync_lockscreen` atomically updates appearance variables
on shell startup, refresh, or mode change. It reads the same saved profile
palette and interface font as the bar, theme wallpaper from the appearance
manifest (including its clock-frame asset), and the reduced-motion preference. It never reloads or stops a running
locker: a changed theme applies to the next lock. Variable values are validated
against configuration injection; wallpaper paths must point inside theme assets.
The Russian date helper does not depend on installed OS locales.

Verification: 42 Python tests and QML lint, including native Hyprlock parsing
against an explicitly nonexistent Wayland socket, atomic-write failure safety,
theme/mode separation, reduced motion and injection rejection. A real Hyprlock
was also rendered in a temporary nested Hyprland compositor on its own Wayland
socket. Rendering and PAM prompt initialization worked, without locking the
main desktop, submitting credentials, or attempting failed logins. The revised
layout was additionally captured on an isolated 1920×1080 headless output.
Clock art is repo-native SVG rasterized with `rsvg-convert -w 1320 -h 344
assets/lockscreen/alpine-clock.svg -o assets/lockscreen/alpine-clock.png`.
Password
unlock and suspend/resume must be checked by the user in their real session.

References: [Hyprlock documentation](https://wiki.hypr.land/hypr-ecosystem/user/hyprlock/)
and the [installed-version configuration definitions](https://github.com/hyprwm/hyprlock/blob/v0.9.6/src/config/ConfigManager.cpp).
