# Clipboard history

`ClipboardState` owns one long-lived Python process, with two event-driven
`wl-paste --watch` clients for text and images. No polling, timers, subprocesses
per animation frame or separate user service are used for collection. Each copy
invokes a small ingest helper. The Python owner accepts newline JSON commands and
publishes snapshots through stdout. Collectors report changes through their
inherited pipes. A private advisory lock prevents duplicate owners.

Linux parent-death signals stop both clients even if Quickshell kills the owner
during a hot reload. Exiting the shell closes stdin and tears down the clients.
Unexpected failures surface in the panel and retry after three seconds.

SQLite transactions serialize the watchers with UI actions. SHA-256 of MIME plus
raw bytes deduplicates records while preserving pin state. Recording respects
`CLIPBOARD_STATE`; pause is checked inside the ingest transaction. Recent records
are retained within count/byte limits, with pinned records protected. Copy uses
an argv command and raw stdin to `wl-copy`, preserving trailing newlines and
binary bytes without shell interpolation. No simulated Ctrl+V is sent.

The panel reuses BarPopup's existing motion, material, dismissal surface and
monitor placement. Hover opens a 380 px preview with up to three records and a
content-sized height. It requests no keyboard focus or full-screen input region.
The source button, its transit area and the panel's top gap form a continuous
pointer route. Leaving closes immediately through the shared pointer-exit guard.
The source bridge extends vertically without covering neighboring buttons.
Hovering a different bar button immediately transfers preview ownership, even
while the old panel is closing. Hover requests cannot replace a full panel.
The shared popup's exit guard only acts for its currently selected page, so an
outgoing page cannot dismiss the newly hovered menu.
Clicking the source or the open-all action expands the same panel to 480 × 600;
Super+V also promotes an existing preview. Full history stays open on pointer
exit. ClipboardEntry supplies both compact and full cards, preserving pin/image
semantics and the shared theme. Search receives exclusive layer keyboard focus
in the full version.
Its transparent full-screen input region catches outside clicks on the same
surface; the visible panel keeps its compact bar-anchored geometry. This avoids
cross-surface focus conflicts with exclusive layer-shell input;
closing
releases the layer focus to the original application. Clipboard and pin glyphs
are native paths using the live semantic foreground. Surfaces and typography
follow Session, Theme, configured radius, padding and reduced motion.

The database and image-preview files live in `$XDG_STATE_HOME/poly-shell/clipboard`
(default `~/.local/state/poly-shell/clipboard`), with directory mode 0700 and files
0600. No clipboard content is logged or synchronized externally. Image previews
are bounded to 160 pixels for decoding; removing records removes exported previews.

Validation: the hover check exercises three-record geometry, unchanged app focus,
pointer travel over the gap, pointer-exit close, icon-click expansion, open-all,
direct full Super+V, Escape, outside dismissal and exact copying from the preview.
Neighbor transitions were additionally checked in both directions with
notifications, quick settings, calendar and launcher, including rapid changes,
exit into the neutral strip beside the button and exit onto the desktop.
Backend tests cover lossless text and image copy, deduplication,
durable pin state, pause, sensitive/empty/invalid text, retention budgets and
clear preserving pins. Live checks exercise native Super+V, immediate search
typing, Enter selection and return of application focus, lossless PNG transfer,
pause, Escape, the bar button and outside dismissal. The collector lifecycle is
checked by killing its owner and verifying that the old clients disappear and
exactly two replacements are started. Temporary test records are removed and
the previous clipboard, keyboard layout and pointer are restored.

IPC `clipboard.status` reports counts/readiness/errors without payload content;
`clipboard.action(action,id)` supports list/copy/pin/delete/clear/pause. The shared
`bar-popup-<screen>.motionStatus` includes filtered count, search text/focus and
selected index for UI diagnostics. Multi-monitor and non-default themes use
the shared architecture; full physical coverage of all monitors/themes is not
claimed.
