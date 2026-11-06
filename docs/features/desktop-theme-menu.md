# Desktop theme picker

Right-click an exposed desktop area (including the standard two-finger secondary
click gesture) to open a compact radial theme picker. Click a thumbnail to apply
the existing theme workflow, including the saved automatic-color preference.
Work/Vibe mode and geometry remain independent. Escape, the central button or a
click outside dismisses the picker.

Seven themes fit on each page. Imported and future themes appear on subsequent
pages; click the central page indicator to advance. Full theme names
are available below the orbit on hover and as accessibility labels.

The desktop input surface sits on the bottom layer, below application windows
and desktop widgets. The temporary menu overlay takes keyboard focus only while
open. Both surfaces use separate namespaces without the broad shell blur rule.
There is no polling or idle animation. Colors and material settings use Session;
thumbnails come from the theme catalog. A failed apply leaves the menu open with
the backend error.

Per-screen IPC: `theme-menu-<screen>` provides `open(x,y)`, `close()` and
`status()` for diagnostics. The implementation is in `shell/DesktopThemeMenu.qml`.

## Motion and simplified hub

The center is a 42px circular palette/close button with seven subtle direction
points. Cards fan out from the hub along a slightly rotating path, with staggered
opacity, scale and rotation driven by a single reversible reveal timeline. Hover
and keyboard focus gently lift a card outward and tint its surface. Closing folds
the cards back into the hub; the overlay stays mapped until the timeline reaches
zero, but relinquishes keyboard focus immediately. Reopening reverses the current
transition. Durations follow panel settings, and reduced motion removes travel,
rotation and animated responses. No animation runs while the menu is settled.

The compass version adds a broken orbital rail, a direction marker that follows
hover/focus, and pointer-driven perspective. Wheel scrolling (including over a
card) or Left/Right rotates the theme orbit with an eased stop. Cards stay upright.
Reduced motion keeps the layout flat and changes orientation immediately. Page
navigation remains on the central page indicator for collections over seven.
The full name of the hovered theme appears in a small caption below the orbit,
instead of the toolkit's default tooltip.

## Drag a theme to reveal it from a point

Hold the left mouse button on a thumbnail, drag to any point of the current
screen, then release. The original card's visual size and grab offset are
preserved under the pointer. Escape cancels without applying. An ordinary click
also starts a circular reveal, originating at the selected card's center.
The drop is converted from logical screen coordinates to normalized top-left
coordinates, so display scaling does not shift the origin.

Full-size target images are predecoded on hover/press and drag start. A native
input-transparent background shader starts the circular reveal on release in
the UI event handler, bridging process/decoder latency in awww. Two image slots
keep a new hover from altering an in-progress reveal. The bridge hands display
back after the persistent renderer finishes. It stays below apps and widgets,
has no blur or extra compositor fade, and has no idle animation. The theme
transaction starts the renderer before durable backups/toolkit writes; a running
renderer no longer reloads the preceding static image on each change.

The theme controller validates the point before writing any settings and sends
awww/swww a 1.4-second grow transition at 60 fps with inverted Y. Reduced motion
uses an immediate change. The renderer is launched as a separate user service;
the wallpaper preference remembers it across shell restarts. The old wallpaper
seeds the first frame, and swaybg is retired only after a successful apply.
Failure restores the previous image.

awww and awww-daemon (or swww and swww-daemon) are required for this gesture.
This machine has awww 0.12.1 from the official Arch package installed under
`~/.local/lib/poly-shell-awww`, with links in `~/.local/bin`; no system packages
were replaced. The adapter also finds these user-local links from systemd's
minimal PATH.

Timeline uses a still frame blended for its saved time during the transition,
then hands display back to the native live Timeline surface. The transition
point is transient and never becomes part of theme/mode/geometry preferences.
