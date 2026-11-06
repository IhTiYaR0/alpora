# Bottom dock

Each monitor has a `Dock` layer, with its own bottom-edge summon region. Closed
docks accept input only in a three-pixel central strip. An open dock and its
context menu have bounded input regions; those regions are released immediately
when closing starts. The layer never requests keyboard focus or reserves space.
Window sizes and monitor configuration are untouched.

One root hover observer covers the input surface. It keeps reveal ownership
stable while the surface expands under the pointer. The icon hit areas remain
56 × 64 logical pixels: only their visuals lift and scale. The context menu
keeps the right-click anchor as the pointer crosses the gap, and both it and the
dock close on pointer exit. The available horizontal strip scrolls on small
screens or with a large favorite list.

`DockState` uses Quickshell's existing native Hyprland toplevel model, without
polling clients or launching helper processes. It matches app IDs, startup
classes and icon names to desktop entries, preferring pinned aliases so that
favorites are not duplicated as running apps. Unknown applications retain a
generic icon and focusable windows. Scratchpad workspaces are excluded.
Workspace labels come from the native workspace object, including after moves.

Favorites use AppCatalog's existing persisted IDs and icon cache. Right-click
pin/unpin updates the same favorites as the launcher. Clicking a running group
cycles its active window; selecting a window uses its validated compositor
address. Desktop entries launch through their native execute method. Repeated
launches have a short finite cooldown to avoid double-click duplicate launches.
Middle-click invokes the same desktop entry and applications control reuse.

The launcher retains its opening source in BarState's atomic selection. The
dock button supplies a screen-local anchor and its layer window. The shared
Launcher opens above that anchor, with its reveal originating below the panel;
the top button and Super+R use the original top placement. The same search,
favorites and app grid serve both positions. Placement is retained while closing,
and changing source while open preserves the query. The dock stays visible while
its launcher is active. The keyboard grab first focuses search, then includes
the dock as an allowed pointer destination. Dock app actions dismiss the menu;
window focus dispatch waits for the grab to release. Escape, outside click and
the originating button close the menu. After closing, the idle surface returns
to its prepared top origin for shortcut-following typing.

Every material, stroke and highlight uses Session/Theme semantic colors.
Application icons stay recognizable through AppCatalog's live icon theme.
Radius, outline, shadow and glass alpha follow panel appearance settings;
Work/Vibe and wallpaper preferences are unchanged. Reduced motion removes
travel and scaling. Motion is finite, and no idle animation or frame-driven
process runs in the dock. The existing `poly-shell-*` layer rule disables
duplicate compositor animations. Fullscreen on a monitor, the overview, sleep
and other open shell panels suppress its summon region (its own launcher is
the exception).

Validation on this laptop:

- `scripts/check`: 136 backend tests and strict QML lint passed.
- Native bottom-edge reveal and pointer exit were exercised; opening preserved
  application keyboard focus and hovering all icons preserved button geometry.
- Clicking Foot launched a real application. Two temporary Foot windows formed
  one icon and were cycled between workspaces 4 and 6. The right-click menu
  retained its anchor across pointer transit and selected a real window.
- A temporary fullscreen Foot window suppressed the dock and its trigger;
  closing it restored availability. Overview and the clipboard panel also
  suppressed the dock. Temporary windows were removed and the original desk,
  application focus and pointer were restored.
- Pin/unpin through the context menu was written to the favorites file and the
  original favorite order/file were restored after the check.
- Final visual inspection confirmed semantic glass, real icons, active/running
  indicators, multi-window badges and workspace labels.
- Launcher placement was checked through both physical buttons: below from
  the dock and above from the bar, including switching source while open,
  source-button toggle, Escape and outside dismissal. Bottom search accepted
  text and Enter launched a temporary Foot window. Moving the open menu to the
  top preserved its query and focus; choosing a dock app released the grab and
  focused that application. The existing launcher input regression then passed
  all 12 immediate US/RU shortcut-following typing attempts and rapid reopen.

Multi-monitor hardware, fractional scaling and every theme/mode combination
have not been physically exercised. They follow the existing per-screen and
semantic-theme bindings. `dock.status` reports groups and window addresses;
`dock-<screen>.status` reports reveal/input bounds, item geometry and menu state.
