# Desktop responsiveness, 2026-10-21

Live session: Hyprland 0.56.2, Radeon 610M, eDP-1 1920×1080 at
60.008 Hz. Approximately 12 GiB RAM available, no swap use, no failed user
units or compositor configuration errors. The inspected kernel log had no
GPU reset. Previous conversations already reported unresolved frame stalls.

Compared three openings each of launcher, calendar and quick settings using
each surface's `frameSwapped` trace, restricted to 0 < animation progress < 1.
These are client frame-swap intervals, not compositor presentation timestamps.
The desktop and terminal remained active; results are short diagnostic samples,
not a guarantee of system-wide frame pacing.

With original appearance (blur enabled, size 3 / passes 2, application opacity
94%/96%), p95 intervals were 19 / 64 / 49 ms respectively, with maximum
34 / 66 / 51 ms. Disabling blur alone reduced p95 to 18 / 20 / 18 ms.
Reducing blur to size 1 / pass 1, or using cached wallpaper blur, still left
calendar and quick-settings intervals above the display's frame budget.
Cached wallpaper blur was tested temporarily and was not retained: it also
changes what content appears behind a panel.

Applied through the transactional appearance API:

- `blurEnabled: false`
- `activeOpacity: 100`, `inactiveOpacity: 100`
- `blurPasses: 1` (used if blur is enabled again)

Panel transparency, theme palette, geometry, shadows and animations remain as
configured. Existing render scheduling remains enabled. No packages, GPU
drivers, CPU governor or power profile were changed.

Settings were read back after `hyprctl reload`. Final repeated openings gave
p95 17 / 18 / 17 ms and maximum 18 / 19 / 19 ms, with no interval over 25 ms
in those opening traces. Raw samples and reproduction scripts are under
`performance-evidence/2026-10-21/`. The first exploratory test with duplicated
DRM client counters was excluded; retained scripts deduplicate client IDs.

Pre-change files are backed up at
`~/.local/state/poly-shell/backups/smooth-desktop-20261021-225336/`.
Blur and opacity remain adjustable in Appearance; saved preferences survive
refresh and theme switching through the existing mode-independent visual config.

Remaining issue: `check-launcher-input --live` passed 10/12 immediate-input
attempts but lost leading characters in the US and RU 2 ms trials. This focus
race is not fixed by the rendering settings and must not be reported as passing.
The physical cursor, application scrolling and workspace switching still need
confirmation from the user under their usual workload.
