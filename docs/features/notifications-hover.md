# Notification hover preview

Approved reference: assets/reference/notifications-hover-approved.png.

Hovering the bell opens a 420px-wide compact panel. It reuses SettingsRow and
NotificationCard from the full notification center: existing gem header, rounded
cards, semantic live colors, 16px margins and the same liquid reveal. The current
two-history-item view is 332px high, compared with the full center at 580px.
Height follows content and is bounded by the screen. No new mountains, icons,
custom palette, polling timers or texture buffers were added.

Show at most two real notifications, active first then visible history. Compact
cards retain app name, archive marker, urgency border and one plain-text summary
line, without body/actions/dismiss controls. No items produces an empty state.
DND uses the existing service and reports errors. No data is fabricated.

The footer and first bell click promote preview to the full notification center;
a repeated click closes it. Preview begins opening/closing without hover delays.
The expanded source hit region and input-only bridge permit pointer travel across
the gap. Keyboard focus and the outside-click surface read the atomic selection
preview flag directly to avoid a transient focus grab before derived bindings
update. Full center retains focus, outside-click and Escape behavior.

Validation: scripts/check passed 104 tests and strict QML lint. Three live pointer
cycles passed focus-free opening, travel at y=44/46/50/54/58/65/100, footer
promotion, bell promotion, repeat-click closure and pointer-away dismissal.
Inspected /tmp/poly-notifications-hover-live.png. No notification was dismissed,
no history was cleared and DND was not toggled during validation.
