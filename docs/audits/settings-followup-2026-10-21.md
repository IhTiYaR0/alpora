# Settings follow-up — 2026-10-21

## Changes

- Settings sliders ignore mouse-wheel input so the enclosing page scrolls. Drag,
  keyboard and numeric entry remain enabled. Quick-control sliders retain their
  existing behavior.
- Foot's constantly updated transparent terminal surface no longer incurs
  backdrop blur. A generated no-blur/force-RGBX window rule preserves terminal
  contents and colors; whole-window compositor opacity remains independently
  configurable. Settings has no compositor blur and no baked wallpaper material.
- Generated appearance enables Hyprland's installed new render scheduling option
  with readback validation. Current blur is size 3 / one pass; the user can still
  change it. No driver, kernel, refresh rate or power-clock settings were changed.
- The launcher uses a bounded open surface and a mapped 1×1 idle surface. Its
  focus grab handles outside interaction. The bar cannot acquire keyboard focus
  while the launcher is open, preventing lost search input with the cursor over
  the clock. Other bar panels retain normal keyboard behavior.
- Popup and launcher rules use `xray = false`: they sample the actual composed
  content underneath rather than only the wallpaper. The previous generated
  cached rules migrate with backup. A formatting-only change to the managed Lua
  include no longer blocks migration; semantic changes still do.
- Wi-Fi lists in quick access and full settings use live strength icons from
  each Network object's signalStrength. Percent/signal subtitles are removed;
  connection progress and connected state remain. Strength remains available in
  accessibility labels. No connection was changed to perform validation.

## Application palettes

GTK3 now selects an immutable named theme per palette and a stable symbolic user
stylesheet. Changing gtk-theme through GSettings causes GTK3 to reload the named
provider and resolves new colors without restarting the app. Both GTK settings.ini
versions update theme/icon names while preserving unrelated user preferences.
Chrome was already set to use its GTK system theme; its native theming receives
the same GTK3 change. Chrome was restarted through its internal restart page to
load the initial bridge while preserving tabs. Browser website content and custom
browser extensions are not recolored by GTK.

Libadwaita forces its own `Adwaita-empty` theme and ignores named GTK providers.
Therefore GTK4 uses concrete palette values and explicit opaque window/sidebar
backgrounds. An initial symbolic GTK4 attempt caused transparent Nautilus
surfaces; the concrete fallback corrected this and was visually inspected.
Nautilus needs to reload its cached user CSS. An independent one-shot systemd
timer coalesces palette changes for two seconds, saves open locations and reopens
them after a graceful quit. The GTK Application Busy property postpones refresh
while busy; the CLI re-arms the timer. No closed file manager is started, and an
unchanged CSS digest does not restart it. Other already-running libadwaita apps
may still require reopening. Window geometry/workspace and grouped tab layout
are not guaranteed to be preserved by a Nautilus relaunch; directory locations
are preserved. Backup includes the previous GTK files and dconf interface data.

## Validation and evidence

- 117 Python tests and strict full-project QML lint passed.
- Real GTK3 process changed from forest to moon palette and back without restart;
  its reported theme/color values followed each change.
- Real libadwaita probe reported `Adwaita-empty`; after fallback, its window color
  resolved to the actual forest palette rather than missing named-theme colors.
- End-to-end moon/forest changes completed the asynchronous Nautilus refresh and
  restored its open directory. Existing forest theme was restored after checks.
- Physical keyboard regression with pointer over the top bar: 12/12 US/RU trials
  at 2/5/10ms plus rapid reopen passed after correcting bar keyboard focus.
- Hyprland reports no configuration errors. No service restart of the main shell
  was used, preserving applications within its systemd cgroup.

Natural blur initially produced 11 moving window frames per 320ms open with
median 33ms intervals. With new scheduling and bounded buffers, final warmed
samples had 17 moving frames and median 18ms intervals; maximum gaps were 31–34ms.
The first sample still had a 48ms gap. These are passive Qt window frame callbacks,
not direct presentation timestamps: smooth, unbroken 60fps is not established.
Tests were performed on an interactive 1920×1080 / 60Hz AMD Radeon 610M desktop.

A final six-second closed-panel sample measured about 0.99% of one CPU core and
0% graphics-engine time for each Quickshell process. Hyprland remained at 18.75%
graphics-engine time; total GPU busy averaged 27.6% with median 0%. This is not an
idle-GPU claim and does not prove that every desktop stutter has been eliminated.
Physical suspend/reboot comparisons and other monitor scales were not tested.

Relevant primary references:

- [GTK theme selection](https://docs.gtk.org/gtk4/property.Settings.gtk-theme-name.html)
- [Chromium GTK theme integration](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux/gtk_theme_integration.md)

Backups:

- `~/.local/state/poly-shell/backups/application-theme-sync-20261021-163858/`
- `~/.local/state/poly-shell/backups/appearance-hook-20261021-164741-992411/`

Uniform material and application colors (follow-up):
- Bar, popup panels, launcher, desktop widgets and notifications now share a
  75% opacity setting and default. Bar/panel/launcher/widget outer gradients use
  the same surface-to-background material with equal alpha at both endpoints.
  Application window opacity remains 100%; nested controls retain their layers.
- GTK template primary background, surface, text and accent colors resolve to
  exact semantic palette roles. Named toolkit themes include a renderer revision
  so an already running GTK3 provider reloads after a CSS rendering change.
- Foot and Kitty configuration now gets every ANSI color plus default text,
  background, cursor and selection colors. Missing keys are added, includes
  precede owned Kitty colors, Foot color sections are preserved, and unrelated
  font/alpha/key-binding settings survive. Error/warning ANSI colors retain
  recognizable hues. Foot/Kitty PTY masters owned by the current user receive
  OSC 4/10/11/12/17/19 color updates after a successful theme transaction,
  including Timeline changes; no shell input or process restart is used.
- Verified live Foot foreground/background/ANSI green through OSC queries in
  two palettes (Moon Lake and Warm Desert), then applied the selected Alpine
  theme. Automated checks: 122 Python tests and strict QML lint pass.
- Coverage remains toolkit-dependent: application-defined truecolor content,
  website styling and private built-in application themes are not rewritten.
  The existing deferred refresh handles cached Nautilus/libadwaita styles.
