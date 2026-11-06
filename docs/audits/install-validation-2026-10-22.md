# Installation validation — 22 October 2026

The release preparation was exercised with real production configuration code in
isolated user namespaces. This is stronger than changing `HOME` for unit tests,
but **it is not a clean Arch installation or a complete first-login test**.

## Isolation

Bubblewrap provided a read-only host filesystem and source checkout, private HOME,
`/tmp`, `/run`, PID/IPC namespaces and a separate `dbus-run-session`. The author's
home and system D-Bus socket were hidden. No physical GPU, input or display devices
were exposed. No package or system-service commands were run on the host.

Two namespace identities were used: UID 1000 with `/home/newuser`, and UID 1001
with `/home/new user`. Both accessed the source as `/mnt/ALPORA copy`, exercising
spaces in both source and home paths. No machine user accounts were created.
System libraries and tools came from the existing Arch installation, not a fresh
package root. The package list contains 48 names, available in the local Arch sync
database at the time of validation. Automated execution of this validation suite
is provided by [`scripts/validate-isolated-install.sh`](../scripts/validate-isolated-install.sh).

## Results

| Check | Result and scope |
| --- | --- |
| Papirus/Bibata | Downloaded without using the author's theme store; both pinned SHA-256 checks passed; extracted and linked in the private HOME |
| Production setup | Real asset, configuration, preset, theme and GSettings steps completed; **only `enable_services` was replaced with a no-op**, since no systemd manager exists inside this rootless environment |
| Seven themes | All seven prepared and passed the installed-file readiness check |
| Relocated commands | Installed `alpora-fetch --once` ran outside the checkout |
| Compositor config | Real `Hyprland --verify-config` accepted generated Lua configuration, including paths with spaces |
| Service file | Real `systemd-analyze --user verify` accepted the generated unit |
| Repeat setup | Real repeated production configuration completed; a personal Hyprland file and an existing reduced-motion preference survived |
| GUI smoke check | A private Sway headless display with pixman and Qt's software renderer loaded the real Quickshell interface and one virtual screen |
| Palette reload | All seven palettes were written through the production offline theme path; the running QML theme state observed each saved theme |
| Panels | Status, quick settings, launcher and calendar IPC calls succeeded |
| Settings | All 12 navigation pages reported the requested page; the process remained alive |
| Regression suite | `./scripts/check`: **197 tests and strict QML lint passed** |
| Working desktop | After the fixes, its readiness query succeeded; hashes of the monitored host Hyprland/service and top-level ALPORA JSON configurations were unchanged |

Settings were launched in the private display with the same `POLY_SHELL_*`
environment normally supplied by the CLI. This bypasses the unavailable user
systemd launcher, not QML initialization or settings navigation. The Sway test
is an interface-loading check, not evidence of Hyprland shortcut/window support.
Live compositor wallpaper activation was not exercised there; offline palette
preparation and QML file watching were exercised instead.

## Problems found and fixed

1. **First-start icon loading:** the isolated empty profile reproduced a native
   Qt/Quickshell crash in `QIcon::pixmap` during asynchronous icon-provider loading.
   The launcher and dock now keep `image://` providers synchronous; normal cached
   file images still load asynchronously. The change was first tested as a
   read-only overlay; the separate-UID GUI test then completed without the crash.
2. **Active but disabled services:** NetworkManager/Bluetooth could be running for
   this boot while remaining disabled for the next one. Setup now enables such
   units without restarting the current connection. A regression test checks the
   requested systemctl operations; actual service activation remains untested.
3. **Late settings-launcher conflict:** a conflicting desktop entry was detected
   after command links and the service file were written. All owned targets are
   now preflighted before those writes. The conflict regression preserves the
   user's entry and leaves no newly installed links/service behind.

## Still required before calling it fully validated

A disposable clean Arch VM or machine must run the actual `pacman -Syu` transaction,
system/user-service enablement, login through the supplied Hyprland session and a
reboot. That run must cover portals, lock/unlock/PAM, audio, Wi-Fi/Bluetooth,
monitor/input devices, GPU rendering and recovery from failures. These operations
were deliberately not run on the author's working installation. Sway/software
rendering cannot establish their correctness.

The attempted GPU-free native Hyprland launch could not create an Aquamarine
backend; an offscreen Qt platform has no PanelWindow backend. These are recorded
as unsuccessful test environments, not successful desktop runs. The isolated
headless Sway run supplied the real Wayland interface smoke check above.

[Installer](arch-installer.md) · [Known limitations](known-issues.md) · [File map](repository-layout.md) · [Validation script](../scripts/validate-isolated-install.sh)
